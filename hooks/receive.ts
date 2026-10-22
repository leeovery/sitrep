/**
 * Replies other sessions left in the held session's inbox, taken in. The
 * window that delivers for the session (the one attached longest) submits
 * them as Lee's own message, the window's one message in flight
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
 * elsewhere. While a message is in flight a look submits nothing, and
 * writes down one Claude Code took whose writing failed.
 */
import type { Timer } from 'claude-code'
import { boardMessage, toDeliver, type Reply, type ReplyBody } from '../core'
import { sessionOf } from './board'
import { deliver, writeTaken } from './deliver'
import { logFailure, type Host } from './host'
import { WATCH_MS } from './window'

let timer: Timer | undefined

const lineOf = ({ id, item, verdict, option, note }: Reply): ReplyBody => ({
  type: 'reply',
  id,
  item,
  verdict,
  option,
  note,
})

/** Submits the inbox replies waiting for the held session, when this window delivers them and no message is in flight. */
const receive = async (host: Host) => {
  const inFlight = await host.state.inFlight.read()

  if (inFlight !== null) {
    return writeTaken(host)
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

/** Looks for inbox replies to take in at the watch's pace, from the window's start. */
export const receiveEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(
    WATCH_MS,
    () => void receive(host).catch(logFailure(host, 'taking in the inbox')),
  )
}
