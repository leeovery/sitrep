/**
 * Writing into a session the window does not hold: to the end of a
 * writer's own file there, read back under either layout and written whole
 * under today's, since a mod's `$.fs` writes only whole files. What it
 * writes is made from the session as it stands with that file, so a line
 * already there is not written again.
 */
import { append, foldSession, sessionPaths, type Body, type Session, type Stamp } from '../core'
import type { SitrepSessionRef } from '../types'
import { rootFor, type Host } from './host'
import { createReader, ownText } from './reader'

/** A session, and the writer whose file there is written. */
export type Into = SitrepSessionRef & { writer: string }

/**
 * Writes what `linesOf` makes of the session as it stands, nothing when it
 * makes none, each line as of now or as of the time `at` gives it; false
 * when the session no longer folds.
 */
export const writeInto = async (
  host: Host,
  { project, session: id, writer }: Into,
  linesOf: (session: Session) => readonly Body[],
  at?: Stamp,
) => {
  const paths = sessionPaths(await rootFor(host), project, id)
  const [text, files, now] = await Promise.all([
    ownText(host, paths, folder => folder.log(writer)),
    createReader()(host, paths),
    host.clock.now(),
  ])
  const session = foldSession({ ...files, logs: { ...files.logs, [writer]: text } }, now)
  const lines = session === undefined ? [] : linesOf(session)

  if (lines.length > 0) {
    await host.fs.write(paths.log(writer), append(text, lines, at ?? now).text)
  }

  return session !== undefined
}
