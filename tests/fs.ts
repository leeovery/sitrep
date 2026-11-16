/**
 * A file system in memory: its files by path, and what the folders hold as
 * the files under them imply it. The mod's world and the CLI's each keep one,
 * and a pure test's host answers the mod from one as the engine would.
 */
import type { FsEntry } from 'claude-code'
import type { Host } from '../hooks/host'

export type File = { text: string; mtimeMs: number }

export const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

/** The files and folders directly in `dir`, as the files under it imply them: each a file, held there, or a folder. */
export const entriesIn = (files: ReadonlyMap<string, File>, dir: string) => {
  const entries = new Map<string, File | 'dir'>()

  for (const [path, file] of files) {
    if (isUnder(dir, path)) {
      const [name = '', ...deeper] = path.slice(dir.length + 1).split('/')

      entries.set(name, deeper.length > 0 ? 'dir' : file)
    }
  }

  return [...entries].map(([name, entry]) => ({ name, entry }))
}

/** The text of a file, failing the test when it is not there. */
export const textIn = (files: ReadonlyMap<string, File>, path: string) => {
  const file = files.get(path)

  if (file === undefined) {
    throw new Error(`no file at ${path}`)
  }

  return file.text
}

/** Why the engine refuses a look at a path that is not there. */
export const missing = (path: string) => `ENOENT: no such file or directory, ${path}`

/** Whether the engine finds something at `path`: a file, or a folder the files imply. */
export const isThere = (files: ReadonlyMap<string, File>, path: string) =>
  files.has(path) || [...files.keys()].some(each => isUnder(path, each))

/** The listing of `dir` as the engine gives it, a file's size in bytes; empty where the files imply no folder there. */
export const listingIn = (files: ReadonlyMap<string, File>, dir: string): FsEntry[] =>
  entriesIn(files, dir).map(({ name, entry }) => ({
    name,
    ...(entry === 'dir'
      ? { kind: 'dir' as const, size: 0, mtimeMs: 0 }
      : {
          kind: 'file' as const,
          size: new TextEncoder().encode(entry.text).length,
          mtimeMs: entry.mtimeMs,
        }),
    isLink: false,
  }))

/** The mod's file system over `files`, answering as the engine does with no engine beneath, what it writes stamped at `now`. */
export const fsOn = (files: Map<string, File>, now: number): Host['fs'] => {
  const refused = (path: string) => Promise.reject(new Error(missing(path)))

  return {
    read: async path => files.get(path)?.text ?? refused(path),
    write: async (path, text) => {
      files.set(path, { text, mtimeMs: now })
    },
    list: async dir => {
      const listing = listingIn(files, dir)

      return listing.length === 0 ? refused(dir) : listing
    },
    exists: async path => isThere(files, path),
  }
}
