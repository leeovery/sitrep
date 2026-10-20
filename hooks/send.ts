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
import { boardMessage } from '../core'
import { deliver, STILL_THERE } from './deliver'
import type { Host } from './host'
import { sendLetters } from './letters'
import { leftOut, replyBodies, sendable, type LeftOut } from './queue'
import { attached, refresh, serially } from './window'

const BEHIND = `Not sent yet: replies from another session are going in first. ${STILL_THERE}`

/** The held session as it stands, and the window's hold on it. */
const heldNow = (host: Host) =>
  serially(async () => {
    const session = await refresh(host)
    const held = attached()

    return session === undefined || held === undefined ? undefined : { session, held }
  })

/** What a send did with the held session's replies: claimed their message, waited on one in flight, or carried none, leaving each for why. */
type Here = { is: 'claimed' } | { is: 'heldBack' } | { is: 'none'; left: readonly LeftOut[] }

/** Why a send carried nothing at all, by why it left the replies it held: their items changed, or answered or closed, or both. */
const nothingSent = (left: readonly LeftOut[]) => {
  const why = [
    left.includes('changed') && 'have changed since',
    left.some(each => each !== 'changed') && 'are answered or closed already',
  ].filter(Boolean)

  return `Nothing to send: the items replied to ${why.join(', or ')}. ${STILL_THERE}`
}

/**
 * Sends the held session's replies in Ready to send that its items take
 * now (`sendable`), `claimed` running once their message is claimed. The
 * claim's time is taken before the board is read, so an answer the board
 * gains after that read comes after the send's.
 */
const sendHere = async (host: Host, claimed: () => Promise<void>): Promise<Here> => {
  const claimedAt = await host.clock.now()
  const here = await heldNow(host)

  if (here === undefined) {
    return { is: 'none', left: [] }
  }

  const { session, held } = here
  const queue = await host.state.queue.read()
  const message = boardMessage(session, sendable(session, queue))

  if (message === undefined) {
    return { is: 'none', left: leftOut(session, queue) }
  }

  const ahead = await deliver(
    host,
    {
      claimedAt,
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

  return ahead === undefined ? { is: 'claimed' } : { is: 'heldBack' }
}

/**
 * Sends everything in Ready to send that its item takes now: other
 * sessions' into their inboxes, then the held session's. `claimed` runs
 * once, as soon as any of it has gone: the held session's message claimed,
 * else the letters written; never once nothing went. A send that carried
 * nothing at all says why it left what it held.
 */
export const send = async (host: Host, claimed: () => Promise<void>) => {
  const letters = await sendLetters(host)
  const here = await sendHere(host, claimed)

  if (letters.isLettered && here.is !== 'claimed') {
    await claimed()
  }

  if (!letters.isLettered && here.is === 'none') {
    const left = [...letters.left, ...here.left]

    if (left.length > 0) {
      host.ui.toast(nothingSent(left))
    }
  }
}
