/**
 * Sending Ready to send to the held work: Lee's replies go in as Lee's own
 * message, and only once Claude Code has taken it are they written, each
 * reply and one delivered mark together. A send it refuses leaves every
 * reply queued.
 *
 * A message sent while Claude is mid-turn waits for that turn to end
 * (`$.prompt.submit` resolves as the message's own turn starts), so a send
 * can wait minutes; the replies it carries stay frozen in the queue.
 */
import type { PromptOrigin } from 'claude-code'
import { boardMessage, newItemId, type ReplyBody, type Work } from '../core'
import type { SitrepQueued } from '../types'
import { logFailure, random, type Host } from './host'
import { queuedFor, sendable, sent } from './queue'
import { LINGER_MS, tickAfter } from './scene'
import { postKnown } from './seen'
import { refresh, serially } from './window'

/** The name Claude Code knows the mod by: what a prompt it submitted carries as its origin. */
const PLUGIN = 'sitrep'

const STILL_THERE = 'Your replies are still on the board.'

/** Whether a prompt is the board's own message, sent by Lee from Ready to send. */
export const isBoardMessage = (origin: PromptOrigin) =>
  origin.kind === 'plugin' && origin.name === PLUGIN

/** The replies as lines of the work, each with an id unlike any the work uses, and the mark that Claude has them. */
const linesOf = (work: Work, replies: readonly SitrepQueued[]) => {
  const taken = new Set(work.ids)
  const bodies = replies.map(({ item, verdict, option, note }): ReplyBody => {
    const id = newItemId(random, taken)

    taken.add(id)

    return { type: 'reply', id, item, verdict, option, note }
  })

  return [...bodies, { type: 'delivered' as const, replies: bodies.map(body => body.id) }]
}

/** Writes the replies Claude has just been sent: lines Claude knows of. */
const record = async (host: Host, replies: readonly SitrepQueued[]) => {
  const work = await refresh(host)

  if (work === undefined) {
    throw new Error('the work is no longer held')
  }

  await postKnown(host, work, linesOf(work, replies))
}

/** Submits the message: undefined once Claude Code takes it, else why it did not. */
const refusalOf = async (host: Host, text: string) => {
  try {
    const entered = await host.prompt.submit(text)

    return entered.drop
  } catch {
    return 'Claude Code refused it'
  }
}

/** What follows a taken send: the replies written, and gone from the queue either way, since Claude has them. */
const delivered = async (host: Host, replies: readonly SitrepQueued[]) => {
  try {
    await serially(() => record(host, replies))
    tickAfter(host, LINGER_MS)
  } catch (error) {
    logFailure(host, 'writing the replies sent')(error)
    host.ui.toast('Claude has your replies, but the board could not write them down.')
  }

  await host.state.queue.update(queue => sent(queue, replies))
}

/** Takes the send for these replies; false while another send is on its way. */
const claim = async (host: Host, replies: readonly SitrepQueued[]) => {
  let isClaimed = false

  await host.state.sending.update(sending => {
    isClaimed = sending.length === 0

    return isClaimed ? [...replies] : sending
  })

  return isClaimed
}

/** Sends the held work's replies in Ready to send that still fit their items. */
export const send = async (host: Host) => {
  const work = await serially(() => refresh(host))

  if (work === undefined) {
    return
  }

  const queue = await host.state.queue.read()
  const replies = sendable(work, queue)
  const text = boardMessage(work, replies)

  if (text === undefined) {
    if (queuedFor(queue, work.id).length > 0) {
      host.ui.toast(`Nothing to send: the items replied to have changed since. ${STILL_THERE}`)
    }

    return
  }

  if (!(await claim(host, replies))) {
    return
  }

  try {
    const refusal = await refusalOf(host, text)

    if (refusal === undefined) {
      await delivered(host, replies)
    } else {
      host.ui.toast(`Not sent: ${refusal}. ${STILL_THERE}`)
    }
  } finally {
    await host.state.sending.write([])
  }
}
