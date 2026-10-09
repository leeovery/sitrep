/**
 * Sending Ready to send. The replies to other works are written into their
 * inboxes first (letters.ts). The held work's go in as Lee's own message
 * (deliver.ts), their reply ids fixed as the send is claimed, and only once
 * Claude Code has taken it are they written, each reply and one delivered
 * mark together, into the work they answer. A send it refuses leaves every
 * reply queued.
 *
 * A message sent while Claude is mid-turn waits for that turn to end, so a
 * send can wait minutes; the replies it carries stay frozen in the queue.
 */
import { boardMessage } from '../core'
import { deliver, STILL_THERE } from './deliver'
import type { Host } from './host'
import { sendLetters } from './letters'
import { queuedFor, replyBodies } from './queue'
import { attached, refresh, serially } from './window'

const CHANGED = `Nothing to send: the items replied to have changed since. ${STILL_THERE}`

const BEHIND = `Not sent yet: replies from another session are going in first. ${STILL_THERE}`

/** The held work as it stands, and the window's hold on it. */
const heldNow = (host: Host) =>
  serially(async () => {
    const work = await refresh(host)
    const held = attached()

    return work === undefined || held === undefined ? undefined : { work, held }
  })

/**
 * Sends the held work's replies in Ready to send that still fit their
 * items, `claimed` running once their message is claimed; whether it was.
 */
const sendHere = async (host: Host, claimed: () => Promise<void>) => {
  const here = await heldNow(host)

  if (here === undefined) {
    return false
  }

  const { work, held } = here
  const queued = queuedFor(await host.state.queue.read(), work.id)
  const message = boardMessage(work, queued)

  if (message === undefined) {
    if (queued.length > 0) {
      host.ui.toast(CHANGED)
    }

    return false
  }

  const ahead = await deliver(
    host,
    {
      source: 'send',
      project: held.project,
      work: work.id,
      writer: held.writer,
      text: message.text,
      replies: replyBodies(work, message.replies),
    },
    claimed,
  )

  if (ahead?.source === 'inbox') {
    host.ui.toast(BEHIND)
  }

  return ahead === undefined
}

/**
 * Sends everything in Ready to send that still fits its item: other works'
 * into their inboxes, then the held work's. `claimed` runs once, as soon as
 * any of it has gone: the held work's message claimed, else the letters
 * written; never once nothing went.
 */
export const send = async (host: Host, claimed: () => Promise<void>) => {
  const isLettered = await sendLetters(host)
  const isClaimed = await sendHere(host, claimed)

  if (isLettered && !isClaimed) {
    await claimed()
  }
}
