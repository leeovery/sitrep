/**
 * Replies other works left in the held work's inbox, taken in. The window
 * that delivers for the work (the one attached longest) submits them as
 * Lee's own message, the window's one message in flight (deliver.ts); once
 * Claude Code has taken it, one delivered mark names exactly the replies the
 * message carries, and the band flashes how many came in.
 *
 * It looks on a timer of its own, started with the session rather than by a
 * tool call, so the engine never takes it for a hook holding the turn; and
 * its submit waits outside the hold's turn (`serially`), since it can wait
 * out a turn of Claude's whose tool calls take that turn too. While a
 * message is in flight a look submits nothing, and writes down one Claude
 * Code took whose writing failed.
 */
import type { Timer } from 'claude-code'
import { boardMessage, toDeliver, type Reply, type ReplyBody } from '../core'
import { workOf } from './board'
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

/** Submits the inbox replies waiting for the held work, when this window delivers them and no message is in flight. */
const receive = async (host: Host) => {
  const [held, board, inFlight] = await Promise.all([
    host.state.attachment.read(),
    host.state.board.read(),
    host.state.inFlight.read(),
  ])

  if (inFlight !== null) {
    return writeTaken(host)
  }

  if (held === null || board === null) {
    return
  }

  const work = workOf(board)
  const message = boardMessage(work, toDeliver(work, held.writer))

  if (message !== undefined) {
    await deliver(host, {
      source: 'inbox',
      project: held.project,
      work: work.id,
      writer: held.writer,
      text: message.text,
      replies: message.replies.map(lineOf),
    })
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
