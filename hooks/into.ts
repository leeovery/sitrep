/**
 * Writing into a piece of work the window does not hold: to the end of a
 * writer's own file there, read back and written whole, since a mod's
 * `$.fs` writes only whole files. What it writes is made from the work as
 * it stands with that file, so a line already there is not written again.
 */
import { append, foldWork, workPaths, type Body, type Work } from '../core'
import type { SitrepWorkRef } from '../types'
import { rootFor, type Host } from './host'
import { createReader, ownText } from './reader'

/** A work, and the writer whose file there is written. */
export type Into = SitrepWorkRef & { writer: string }

/** Writes what `linesOf` makes of the work as it stands, nothing when it makes none; false when the work no longer folds. */
export const writeInto = async (
  host: Host,
  { project, work: id, writer }: Into,
  linesOf: (work: Work) => readonly Body[],
) => {
  const paths = workPaths(await rootFor(host), project, id)
  const path = paths.log(writer)
  const [text, files, now] = await Promise.all([
    ownText(host, path),
    createReader()(host, paths),
    host.clock.now(),
  ])
  const work = foldWork({ ...files, logs: { ...files.logs, [writer]: text } }, now)
  const lines = work === undefined ? [] : linesOf(work)

  if (lines.length > 0) {
    await host.fs.write(path, append(text, lines, now).text)
  }

  return work !== undefined
}
