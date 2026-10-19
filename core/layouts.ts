/**
 * A session's folder under today's layout and the old, read as one. Windows
 * not yet reloaded write the old layout while the rest write today's, and the
 * CLI moves the old into today's once none does, so a reader reads both, and
 * every state partway through the move reads the same board, the old read
 * first (`readOldFirst`):
 * - a project's sessions are both layouts' folders, each once;
 * - a session's meta is today's where that reads, else the old;
 * - a writer's lines, or a sender's, are every line of its file under
 *   either, a line under both, byte for byte, once. Never the one under
 *   today's alone: a window that slept through the move wakes still writing
 *   its whole file under the old name;
 * - a window's heartbeat is the later seen of its two.
 */
import { tornLineEnd } from './entries'
import type { SessionFiles } from './fold'
import { parseMeta } from './meta'
import { LOG_SUFFIX, PRESENCE_SUFFIX, writerOf, type SessionFolder } from './paths'
import { parsePresence } from './presence'

/** A session folder's files as read under one layout: all of the session's but its project's. */
export type FolderFiles = Omit<SessionFiles, 'project'>

/** Files by their writer, as a folder's listing gives them. */
type ByWriter = Readonly<Record<string, string>>

/**
 * Reads under both layouts, the old first and then today's, never at once.
 * Each step of the move puts a file under today's name before its old name
 * loses it (a link before the unlink, an append before the remove), so a
 * read of the old then of today's never misses a file moved between the
 * two, where reads at once might find it under neither.
 */
export const readOldFirst = async <F, T>(now: F, old: F, read: (each: F) => Promise<T>) => {
  const before = await read(old)

  return { old: before, now: await read(now) }
}

/** The sessions a project files, as both layouts' folders list them: today's first, each once. */
export const filedIds = (now: readonly string[], old: readonly string[]) => [
  ...new Set([...now, ...old]),
]

const linesOf = (text: string) => text.split('\n').filter(line => line !== '')

/**
 * What `now` lacks of `old`'s lines, as text to add to it: each line of
 * `old` that `now` does not hold, once, after a newline ending a torn last
 * line of `now`; empty when it lacks none.
 */
export const linesLacking = (now: string, old: string) => {
  const held = new Set(linesOf(now))
  const lacking = [...new Set(linesOf(old))].filter(line => !held.has(line))

  return lacking.length === 0
    ? ''
    : `${tornLineEnd(now)}${lacking.map(line => `${line}\n`).join('')}`
}

/** A file's text under both layouts as one: today's, then the old's lines it lacks. */
export const mergedText = (now: string, old: string) => now + linesLacking(now, old)

/** When a heartbeat says its window was seen, whoever's it is; never, for one that does not read. */
const seenAt = (text: string) => parsePresence(text, '')?.seenAt ?? -Infinity

/** Of a window's two heartbeats, the one seen later; today's when they were seen at once. */
export const laterBeat = (now: string, old: string) => (seenAt(old) > seenAt(now) ? old : now)

/** Two folders' files by writer as one: a writer's file under one is itself, under both `merge`d. */
const mergedBy = (now: ByWriter, old: ByWriter, merge: (now: string, old: string) => string) => {
  const merged: Record<string, string> = { ...old, ...now }

  for (const [writer, text] of Object.entries(old)) {
    const held = now[writer]

    if (held !== undefined) {
      merged[writer] = merge(held, text)
    }
  }

  return merged
}

/** A session's files under today's layout and the old as one. */
export const mergedFiles = (now: FolderFiles, old: FolderFiles): FolderFiles => ({
  meta: parseMeta(now.meta) === undefined ? old.meta : now.meta,
  logs: mergedBy(now.logs, old.logs, mergedText),
  inbox: mergedBy(now.inbox ?? {}, old.inbox ?? {}, mergedText),
  presence: mergedBy(now.presence ?? {}, old.presence ?? {}, laterBeat),
})

/** What a file of a session's folder holds, as the move treats it: its meta, a writer's or a sender's lines, a heartbeat, or something else. */
export type Contents = 'meta' | 'lines' | 'beat' | 'other'

/** What a file at `path` in a session's folder holds, by its folder and name. */
export const contentsAt = (folder: SessionFolder, path: string): Contents => {
  const slash = path.lastIndexOf('/')
  const dir = path.slice(0, slash)
  const name = path.slice(slash + 1)

  if (path === folder.meta) {
    return 'meta'
  }

  if ([folder.dir, folder.inbox].includes(dir) && writerOf(name, LOG_SUFFIX) !== undefined) {
    return 'lines'
  }

  return dir === folder.presence && writerOf(name, PRESENCE_SUFFIX) !== undefined ? 'beat' : 'other'
}

/**
 * What becomes of a file of a session's old folder as it moves into
 * today's, given the file today's has in its place, if any:
 * - `rename`d in where today's has none;
 * - lines `append`ed to today's file where it has one: those it lacks,
 *   never the whole file rewritten, so a run appending to it at once keeps
 *   its line; the old then dropped;
 * - a heartbeat seen later than today's `replace`s it;
 * - `drop`ped where today's stands for it: a meta, a heartbeat seen as late;
 * - anything else under both `leave`s the old where it is.
 */
export type Moving =
  | { to: 'rename' }
  | { to: 'append'; text: string }
  | { to: 'replace' }
  | { to: 'drop' }
  | { to: 'leave' }

export const moving = (contents: Contents, old: string, now: string | undefined): Moving => {
  if (now === undefined) {
    return { to: 'rename' }
  }

  switch (contents) {
    case 'lines':
      return { to: 'append', text: linesLacking(now, old) }
    case 'beat':
      return { to: laterBeat(now, old) === now ? 'drop' : 'replace' }
    case 'meta':
      return { to: 'drop' }
    case 'other':
      return { to: 'leave' }
  }
}
