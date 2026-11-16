/**
 * What the readers that look on and on share: `sitrep watch`, and each
 * window's look at the sessions around the one it holds. Each folds a
 * session again only once its files changed, or once time alone changes
 * it, by a rule of its own (feed.ts): `watch` folds every session again as
 * the board changes (`nextExpiry`), which stands for what it prints; a
 * window folds each session again as its own fold changes
 * (`nextFoldChange`), as it shares whole folds, where a snooze the board
 * leaves out still shows. Both read a session off the board, which changes
 * rarely and only a join or a post brings back, again only every
 * OFF_BOARD_MS.
 */
import { nextFoldChange } from './feed'
import { foldSession, type SessionFiles } from './fold'
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

/** A session as a window last folded it: the files it was folded from, what they folded to, and when that fold next changes by time alone. */
export type KeptFold = {
  files: SessionFiles
  session: Session | undefined
  changesAt: number | undefined
}

/**
 * A session's files folded at `now`: `last` where it still stands, folded
 * from the same texts and not changed since by time alone
 * (`nextFoldChange`); else folded afresh.
 */
export const refold = (last: KeptFold | undefined, files: SessionFiles, now: number): KeptFold => {
  if (
    last !== undefined &&
    (last.changesAt === undefined || now < last.changesAt) &&
    isSameFiles(last.files, files)
  ) {
    return last
  }

  const session = foldSession(files, now)

  return {
    files,
    session,
    changesAt: session === undefined ? undefined : nextFoldChange(session, now),
  }
}

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
