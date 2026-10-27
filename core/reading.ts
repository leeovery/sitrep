/**
 * How a reader that looks on and on keeps what it read: `sitrep watch`,
 * and each window's look at the sessions around the one it holds. A session
 * is folded again only once its files changed, or once its fold changes by
 * time alone (feed.ts's `nextFoldChange`); and one off the board, which
 * changes rarely and only a join or a post brings back, is read again only
 * every OFF_BOARD_MS.
 */
import type { SessionFiles } from './fold'
import type { Session } from './types'
import { isCurrent, summarise } from './views'

/** How often a reader reads again the sessions off the board. */
export const OFF_BOARD_MS = 10_000

const isSameTexts = (
  a: Readonly<Record<string, string>> = {},
  b: Readonly<Record<string, string>> = {},
) =>
  Object.keys(a).length === Object.keys(b).length &&
  Object.entries(a).every(([name, text]) => b[name] === text)

/** Whether two reads of a session's files found the same texts: folded at one moment, they come to the same session. */
export const isSameFiles = (a: SessionFiles, b: SessionFiles) =>
  a.meta === b.meta &&
  a.project === b.project &&
  isSameTexts(a.logs, b.logs) &&
  isSameTexts(a.inbox, b.inbox) &&
  isSameTexts(a.presence, b.presence)

/** Whether a session folded is off the board at `now`: no live window to hear, and finished or idle past the views. One whose session.json does not fold is not. */
export const isOffBoard = (session: Session | undefined, now: number) =>
  session !== undefined && !session.isOpen && !isCurrent(summarise(session), now)

/** Whether something done every `ms` is due at `now`, counted from `from`; each time it is, the count starts again. */
export const every = (ms: number, from: number) => {
  let last = from

  return (now: number) => {
    if (now - last < ms) {
      return false
    }

    last = now

    return true
  }
}
