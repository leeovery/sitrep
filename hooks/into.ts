/**
 * Writing into a writer's own file in a session. Into a session the window
 * does not hold: to the end of the file there, read back and written whole,
 * since a mod's `$.fs` writes only whole files. Into the one it holds as
 * that writer: through the hold, which keeps the file's text and would
 * write a line put beside it over. What it writes is made from the session
 * as it stands with that file, so a line already there is not written
 * again.
 */
import {
  append,
  foldSession,
  parseEntries,
  type Body,
  type Entry,
  type Session,
} from '../core'
import type { SitrepSessionRef } from '../types'
import { rootFor, type Host } from './host'
import { pathsOf } from './projects'
import { createReader, ownText } from './reader'
import { attached, heldLines, isHoldOn, refresh, serially } from './window'

/** A session, and the writer whose file there is written. */
export type Into = SitrepSessionRef & { writer: string }

/** What a write makes of a session as it stands, and of the writer's own lines there, its file as read: the lines it writes there. */
export type LinesOf = (session: Session, own: readonly Entry[]) => readonly Body[]

/** How the hold posts lines made from the held session: as lines Claude knows of, or as a change it did not make. */
export type PostHeld = (session: Session, bodies: readonly Body[]) => Promise<unknown>

/** Writes what `linesOf` makes of the session as it stands, its folder found by its id, nothing when it makes none; false when the session no longer folds. */
export const writeInto = async (host: Host, into: Into, linesOf: LinesOf) => {
  const { writer } = into
  const paths = await pathsOf(host, await rootFor(host), into)
  const [text, files, now] = await Promise.all([
    ownText(host, paths.log(writer)),
    createReader()(host, paths),
    host.clock.now(),
  ])
  const session = foldSession({ ...files, logs: { ...files.logs, [writer]: text } }, now)
  const lines = session === undefined ? [] : linesOf(session, parseEntries(text))

  if (lines.length > 0) {
    await host.fs.write(paths.log(writer), append(text, lines, now).text)
  }

  return session !== undefined
}

/** Writes what `linesOf` makes of the held session as it stands, posted by `postHeld`; false when the session no longer folds. */
export const writeHeld = async (host: Host, linesOf: LinesOf, postHeld: PostHeld) => {
  const session = await refresh(host)
  const lines = session === undefined ? [] : linesOf(session, heldLines())

  if (session !== undefined && lines.length > 0) {
    await postHeld(session, lines)
  }

  return session !== undefined
}

/**
 * Writes what `linesOf` makes of a session as it stands into the writer's
 * own file there, in turn with whatever else reads or changes the hold:
 * through the hold, by `postHeld`, where it is the window's hold on it,
 * else read back and written whole. False when the session no longer folds.
 */
export const writeOwnFile = (host: Host, into: Into, linesOf: LinesOf, postHeld: PostHeld) =>
  serially(() =>
    isHoldOn(attached(), into)
      ? writeHeld(host, linesOf, postHeld)
      : writeInto(host, into, linesOf),
  )
