/**
 * Sending Ready to send. The replies to other sessions are written into their
 * inboxes first (letters.ts). The held session's go in as Lee's own message
 * (deliver.ts), their reply ids fixed as the send is claimed, and only once
 * Claude Code has taken it are they written, each reply and one delivered
 * mark together, into the session they answer, the replies as of the claim.
 * A send it refuses leaves every reply queued. A send carries a reply only
 * while its item takes it (`sendable`): one to an item that took another
 * answer of Lee's first, or closed, stays in Ready to send, saying why.
 *
 * A message sent while Claude is mid-turn waits for that turn to end, so a
 * send can wait minutes; the replies it carries stay frozen in the queue.
 */
import { boardMessage, type Session } from '../core'
import type { SitrepQueued } from '../types'
import { deliver, STILL_THERE } from './deliver'
import type { Host } from './host'
import { sendLetters } from './letters'
import { answered, queuedFor, replyBodies, sendable } from './queue'
import { attached, refresh, serially } from './window'

const CHANGED = `Nothing to send: the items replied to have changed since. ${STILL_THERE}`

const TAKEN = `Nothing to send: the items replied to are answered or closed already. ${STILL_THERE}`

const BEHIND = `Not sent yet: replies from another session are going in first. ${STILL_THERE}`

/** The held session as it stands, and the window's hold on it. */
const heldNow = (host: Host) =>
  serially(async () => {
    const session = await refresh(host)
    const held = attached()

    return session === undefined || held === undefined ? undefined : { session, held }
  })

/** Why a send carried none of the held session's replies: their items changed, or, still fitting some, those items took an answer already or closed. */
const nothingSent = (session: Session, queued: readonly SitrepQueued[]) =>
  queued.some(reply => answered(session, reply) !== undefined) ? TAKEN : CHANGED

/**
 * Sends the held session's replies in Ready to send that its items take
 * now (`sendable`), `claimed` running once their message is claimed;
 * whether it was.
 */
const sendHere = async (host: Host, claimed: () => Promise<void>) => {
  const here = await heldNow(host)

  if (here === undefined) {
    return false
  }

  const { session, held } = here
  const queue = await host.state.queue.read()
  const message = boardMessage(session, sendable(session, queue))

  if (message === undefined) {
    const queued = queuedFor(queue, session.id)

    if (queued.length > 0) {
      host.ui.toast(nothingSent(session, queued))
    }

    return false
  }

  const ahead = await deliver(
    host,
    {
      source: 'send',
      project: held.project,
      session: session.id,
      writer: held.writer,
      text: message.text,
      replies: replyBodies(session, message.replies),
    },
    claimed,
  )

  if (ahead?.source === 'inbox') {
    host.ui.toast(BEHIND)
  }

  return ahead === undefined
}

/**
 * Sends everything in Ready to send that its item takes now: other
 * sessions' into their inboxes, then the held session's. `claimed` runs
 * once, as soon as any of it has gone: the held session's message claimed,
 * else the letters written; never once nothing went.
 */
export const send = async (host: Host, claimed: () => Promise<void>) => {
  const isLettered = await sendLetters(host)
  const isClaimed = await sendHere(host, claimed)

  if (isLettered && !isClaimed) {
    await claimed()
  }
}
