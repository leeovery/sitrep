/**
 * Sending Ready to send. The replies to other sessions are written into their
 * inboxes first (letters.ts). The held session's go in as Lee's own message
 * (deliver.ts), and with them every pick-up, whichever session of the
 * project parked its item, their reply ids fixed as the send is claimed, and
 * only once Claude Code has taken it are they written, each reply and a
 * delivered mark together, into the session whose item each answers. A send
 * it refuses leaves every reply queued. A send carries a reply only while
 * its item takes it (`sendable`): one to an item closed, or holding another
 * answer of Lee's, stays in Ready to send, saying why.
 *
 * A message sent while Claude is mid-turn the window holds until that turn
 * ends, which can take minutes, and Lee can take it back until then
 * (deliver.ts); the replies it carries stay frozen in the queue, and taken
 * back are there as they were. Replies queued meanwhile are no part of it:
 * a send carries them as a message of their own, which goes in after it.
 */
import { boardMessage } from '../core'
import { foldedFor } from './around'
import { deliver, sendHeld, STILL_THERE } from './deliver'
import type { Host } from './host'
import { sendLetters } from './letters'
import { leftOut, replyBodies, sendable, unsentTo, type LeftOut } from './queue'
import { attached, refresh, serially } from './window'

const BEHIND = `Not sent yet: replies from another session are going in first. ${STILL_THERE}`

/** The held session as it stands, and the window's hold on it. */
const heldNow = (host: Host) =>
  serially(async () => {
    const session = await refresh(host)
    const held = attached()

    return session === undefined || held === undefined ? undefined : { session, held }
  })

/** What a send did with the held session's replies: claimed their message, met one in flight it is not claimed behind, or carried none, leaving each for why. */
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
 * Sends the replies in Ready to send that go to the held session, its own
 * and every pick-up of its project's, that no send in flight carries and
 * their items take now (`sendable`), `claimed` running once their message
 * is claimed.
 */
const sendHere = async (host: Host, claimed: () => Promise<void>): Promise<Here> => {
  const here = await heldNow(host)

  if (here === undefined) {
    return { is: 'none', left: [] }
  }

  const { session, held } = here
  const [queue, flights] = await Promise.all([host.state.queue.read(), host.state.inFlight.read()])
  const replies = unsentTo(queue, flights, held, session.id)
  const folded = await foldedFor(host, session, replies)
  const message = boardMessage(session, sendable(folded, replies), reply =>
    folded.get(reply.session),
  )

  if (message === undefined) {
    return { is: 'none', left: leftOut(folded, replies) }
  }

  const ahead = await deliver(
    host,
    {
      source: 'send',
      project: held.project,
      session: session.id,
      writer: held.writer,
      text: message.text,
      replies: replyBodies(session, message.replies, folded),
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
 * nothing at all says why it left what it held. Whatever it claimed, the
 * first message in flight goes as it can: from Lee's press, though he
 * stopped Claude's turn.
 */
export const send = async (host: Host, claimed: () => Promise<void>) => {
  const letters = await sendLetters(host)
  const here = await sendHere(host, claimed)

  await sendHeld(host)

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
