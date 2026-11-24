/**
 * Replies other sessions left in the held session's inbox, taken in. The
 * window that delivers for the session (the one attached longest) submits
 * them as Lee's own message, claimed only with no other message in flight
 * (deliver.ts); once Claude Code has taken it, one delivered mark names
 * exactly the replies the message carries, and the band flashes how many
 * came in.
 *
 * It looks on a timer of its own, started with the window rather than by a
 * tool call, so the engine never takes it for a hook holding the turn; and
 * its submit waits outside the hold's turn (`serially`), since it can wait
 * behind a turn of Claude's whose tool calls take that turn too. A message
 * it claims while Claude is mid-turn the window holds until the turn ends,
 * as it holds a send, though with no take-back: Lee sent those replies from
 * elsewhere. While a message is in flight a look takes in nothing more: it
 * writes down one Claude Code took whose writing failed, and sends the first
 * the window still holds between turns, as after an update at the turn's end
 * that failed, or once the message ahead of it ended. A look finding it held
 * while a turn runs writes nothing. The inbox's message held while the
 * window is stopped, which can wait long, is let go once this window no
 * longer delivers for its session, its replies left in the inbox for the
 * window that does.
 */
import type { Timer } from 'claude-code'
import { boardMessage, toDeliver, type Reply, type ReplyBody } from '../core'
import type { SitrepInFlight } from '../types'
import { sessionOf } from './board'
import { deliver, letGoHeldOne, sendHeld, writeTaken } from './deliver'
import { logFailure, oneAtATime, type Host } from './host'
import { WATCH_MS } from './window'

let timer: Timer | undefined

/** A reply as the line it was read from: its own fields, what the fold made of it left out. */
const lineOf = ({
  by,
  at,
  delivery,
  deliveredAt,
  voidedAt,
  voided,
  isHistory,
  ...line
}: Reply): ReplyBody => ({ type: 'reply', ...line })

/** Whether this window still delivers the inbox of the session a message of the inbox's goes to. */
const isDelivering = async (host: Host, message: SitrepInFlight) => {
  const [held, board] = await Promise.all([host.state.attachment.read(), host.state.board.read()])

  if (held === null || board === null) {
    return false
  }

  const session = sessionOf(board)

  return session.id === message.session && session.deliverer === held.writer
}

/** Whether the first message in flight is the inbox's, held while the window is stopped, for a session this window no longer delivers for. */
const isStale = async (host: Host, first: SitrepInFlight) =>
  first.source === 'inbox' &&
  (await host.state.stopped.read()) &&
  !(await isDelivering(host, first))

/** Carries the first message in flight on: written down once taken, else submitted as it can be, but for one gone stale (`isStale`), let go. */
const carry = async (host: Host, first: SitrepInFlight) => {
  if (!first.isHeld) {
    return writeTaken(host)
  }

  return (await isStale(host, first)) ? letGoHeldOne(host, first) : sendHeld(host)
}

/** Submits the inbox replies waiting for the held session, when this window delivers them and no message is in flight; or carries on the first message in flight. */
const receive = async (host: Host) => {
  const [first] = await host.state.inFlight.read()

  if (first !== undefined) {
    await carry(host, first)

    return
  }

  // Only now the board: one read before a send's claim ended may predate its
  // writing down, and show an answer it voided still on its way.
  const [held, board] = await Promise.all([host.state.attachment.read(), host.state.board.read()])

  if (held === null || board === null) {
    return
  }

  const session = sessionOf(board)
  const message = boardMessage(session, toDeliver(session, held.writer))

  if (message !== undefined) {
    await deliver(host, {
      source: 'inbox',
      project: held.project,
      session: session.id,
      writer: held.writer,
      text: message.text,
      replies: message.replies.map(lineOf),
    })
  }
}

/** Looks for inbox replies to take in at the watch's pace, from the window's start, skipping a tick while its last look is under way. */
export const receiveEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(
    WATCH_MS,
    oneAtATime(() => receive(host).catch(logFailure(host, 'taking in the inbox'))),
  )
}
