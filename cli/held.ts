/**
 * The CLI's world with its files read, and its folders listed, through what
 * was last read of them, for `watch`, which looks at the folder every
 * second: a file is read again only once its size or time has moved, as the
 * mod's readers read, and a folder listed again only once its time has,
 * which an entry made, removed or renamed in it moves. So a look costs a
 * stat of each folder and file, a listing costing several times as much.
 *
 * A file caught torn keeps the last text read of it whole until it changes
 * again, so nothing drops off the board for a look and comes back as new;
 * one that will not read keeps it until it reads. One never read whole is
 * not there. What a folder's listing no longer shows is let go, and all
 * under it.
 * - A JSON file is torn while it does not parse: a meta, a project's file,
 *   a heartbeat, caught mid-rewrite.
 * - A writer's lines are torn while they hold only the start of what was
 *   last read whole: lines are only ever added, and a mod rewrites its
 *   whole file. A torn last line needs nothing: the lines' reader skips it.
 */
import { LOG_SUFFIX } from '../core'
import type { Io, Listed, Stat } from './io'

/** A file's text as last read whole, and its size and time as last looked at. */
type Held = Stat & { text: string }

/** A folder's entries as last listed, and its size and time then. */
type Listing = Stat & { entries: Listed[] }

const parses = (text: string) => {
  try {
    JSON.parse(text)

    return true
  } catch {
    return false
  }
}

const isTorn = (path: string, text: string, whole: string | undefined) =>
  path.endsWith(LOG_SUFFIX)
    ? whole !== undefined && text.length < whole.length && whole.startsWith(text)
    : !parses(text)

const isUnmoved = (held: Stat, now: Stat) => held.size === now.size && held.mtimeMs === now.mtimeMs

/** The world given, its files read and its folders listed again only once they change, a torn file's last whole text standing. */
export const heldReads = (io: Io): Io => {
  const held = new Map<string, Held>()
  const listings = new Map<string, Listing>()

  /** Lets go of what is held under `dir` but not among the `names` listed there, and all under it. */
  const letGo = (dir: string, names: ReadonlySet<string>) => {
    for (const kept of [held, listings]) {
      for (const path of kept.keys()) {
        if (
          path.startsWith(`${dir}/`) &&
          !names.has(path.slice(dir.length + 1).split('/')[0] ?? '')
        ) {
          kept.delete(path)
        }
      }
    }
  }

  const list = async (dir: string) => {
    const stat = await io.fs.stat(dir)

    if (stat === undefined) {
      listings.delete(dir)
      letGo(dir, new Set())

      return []
    }

    const last = listings.get(dir)

    if (last !== undefined && isUnmoved(last, stat)) {
      return last.entries
    }

    const entries = await io.fs.list(dir)

    listings.set(dir, { ...stat, entries })
    letGo(dir, new Set(entries.map(entry => entry.name)))

    return entries
  }

  const read = async (path: string) => {
    const stat = await io.fs.stat(path)

    if (stat === undefined) {
      held.delete(path)

      throw new Error(`ENOENT: no such file or directory, open '${path}'`)
    }

    const last = held.get(path)

    if (last !== undefined && isUnmoved(last, stat)) {
      return last.text
    }

    const text = await io.fs.read(path).catch((): string | undefined => undefined)
    const whole = text === undefined || isTorn(path, text, last?.text) ? last?.text : text

    if (whole === undefined) {
      throw new Error(`${path} has not read whole yet`)
    }

    // A torn file is read again once it changes; one that will not read, at every look until it does.
    if (text !== undefined) {
      held.set(path, { ...stat, text: whole })
    }

    return whole
  }

  return { ...io, fs: { ...io.fs, read, list } }
}
