/**
 * Replies other works left in the held work's inbox, taken in. The window
 * that delivers for the work (the one attached longest) submits them as
 * Lee's own message, and once Claude Code has taken it writes one delivered
 * mark; the band flashes how many came in.
 *
 * One delivery is in flight at a time, kept in `$.state` until its mark is
 * written, so a reply already submitted is never submitted again: not at the
 * next look, nor by the load after a reload, which hears the message start
 * its turn instead and marks it then.
 *
 * It looks on a timer of its own, started with the session rather than by a
 * tool call, so the engine never takes it for a hook holding the turn; and
 * its submit waits outside the hold's turn (`serially`), since it can wait
 * out a turn of Claude's whose tool calls take that turn too.
 */
import type { Timer } from 'claude-code'
import { boardMessage, toDeliver, type DeliveredBody } from '../core'
import type { SitrepDelivering } from '../types'
import { workOf } from './board'
import { refusalOf } from './deliver'
import { logFailure, type Host } from './host'
import { postKnown } from './seen'
import { refresh, serially, WATCH_MS } from './window'

/** How long the band flashes the replies that came in. */
export const FLASH_MS = 5_000

let timer: Timer | undefined

let flashing: Timer | undefined

/** Whether this load is writing a mark: a look meanwhile leaves it be, and one a reload cut short is written again. */
let isMarking = false

const flash = async (host: Host, count: number) => {
  flashing?.cancel()
  await host.state.flash.write(count)
  flashing = host.clock.after(
    FLASH_MS,
    () => void host.state.flash.write(0).catch(logFailure(host, 'the flash')),
  )
}

/** Writes the delivered mark, a line Claude knows of, while the window still holds the work; the delivery is over once it is down. */
const mark = async (host: Host, delivery: SitrepDelivering) => {
  if (isMarking) {
    return
  }

  isMarking = true

  try {
    const marked: DeliveredBody = { type: 'delivered', replies: delivery.replies }
    const isMarked = await serially(async () => {
      const work = await refresh(host)

      return work?.id === delivery.work && (await postKnown(host, work, [marked])) !== undefined
    })

    await host.state.delivering.write(null)

    if (isMarked) {
      await flash(host, delivery.replies.length)
    }
  } finally {
    isMarking = false
  }
}

/**
 * The message `text` entered, heard from its submit or from the turn it
 * starts: the mark is written once, by whichever hears of it first.
 */
export const heardTaken = async (host: Host, text: string) => {
  let taken: SitrepDelivering | undefined

  await host.state.delivering.update(delivery => {
    taken = delivery?.text === text && !delivery.isTaken ? delivery : undefined

    return taken === undefined ? delivery : { ...taken, isTaken: true }
  })

  if (taken !== undefined) {
    await mark(host, taken)
  }
}

/** Takes the delivery; false while another is on its way. */
const claim = async (host: Host, delivery: SitrepDelivering) => {
  let isClaimed = false

  await host.state.delivering.update(current => {
    isClaimed = current === null

    return isClaimed ? delivery : current
  })

  return isClaimed
}

const submit = async (host: Host, delivery: SitrepDelivering) => {
  const refusal = await refusalOf(host, delivery.text)

  if (refusal === undefined) {
    await heardTaken(host, delivery.text)

    return
  }

  host.log(`sitrep: the inbox's replies were not taken (${refusal}); trying again`)
  await host.state.delivering.update(current => (current?.text === delivery.text ? null : current))
}

/** A delivery left by a hold the window has since let go is dropped; one taken but not marked is marked again. */
const followUp = async (host: Host, delivery: SitrepDelivering, held: string) => {
  if (delivery.work !== held) {
    await host.state.delivering.write(null)
  } else if (delivery.isTaken) {
    await mark(host, delivery)
  }
}

/** Submits the inbox replies waiting for the held work, when this window delivers them and none is on its way. */
const receive = async (host: Host) => {
  const [held, board, delivering] = await Promise.all([
    host.state.attachment.read(),
    host.state.board.read(),
    host.state.delivering.read(),
  ])

  if (held === null || board === null) {
    return
  }

  if (delivering !== null) {
    return followUp(host, delivering, board.id)
  }

  const work = workOf(board)
  const replies = toDeliver(work, held.writer)
  const text = boardMessage(work, replies)

  if (text === undefined) {
    return
  }

  const delivery = { work: work.id, replies: replies.map(reply => reply.id), text, isTaken: false }

  if (await claim(host, delivery)) {
    await submit(host, delivery)
  }
}

/** Looks for inbox replies to take in at the watch's pace, from the session's start. */
export const receiveEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(
    WATCH_MS,
    () => void receive(host).catch(logFailure(host, 'taking in the inbox')),
  )
}
