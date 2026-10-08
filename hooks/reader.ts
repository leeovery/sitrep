/**
 * Reading a piece of work's files. A mod cannot watch files, so each read
 * lists the work's folders and reads again only a file whose size or time
 * moved since it was last read. Also the folders sitrep files works under,
 * and a file the window writes itself, as it stands.
 */
import type { FsEntry } from 'claude-code'
import {
  LOG_SUFFIX,
  META_FILE,
  PRESENCE_SUFFIX,
  writerOf,
  type WorkFiles,
  type WorkPaths,
} from '../core'
import type { Host } from './host'

/** A work's files as they stand, each read again only once it changed. */
export type Reader = (host: Host, paths: WorkPaths) => Promise<WorkFiles>

/** A file's text, and the size and time it had when read. */
type Held = { size: number; mtimeMs: number; text: string }

const listed = (host: Host, dir: string) => host.fs.list(dir).catch((): FsEntry[] => [])

/** The names of the folders in `dir`; none while it is not there. */
export const foldersIn = async (host: Host, dir: string) =>
  (await listed(host, dir)).filter(entry => entry.kind === 'dir').map(entry => entry.name)

/** A file the window writes itself, as it stands, so its count goes on; empty before its first line. */
export const ownText = async (host: Host, path: string) =>
  (await host.fs.exists(path)) ? host.fs.read(path) : ''

/**
 * A subfolder's entries, listed only once the work's own listing shows it:
 * an inbox is not there before its first letter, and a listing that fails
 * is a line in the debug log at every look.
 */
const listedIn = (host: Host, dir: string, top: readonly FsEntry[], path: string) =>
  top.some(entry => entry.kind === 'dir' && `${dir}/${entry.name}` === path)
    ? listed(host, path)
    : []

export const createReader = (): Reader => {
  const held = new Map<string, Held>()

  const textOf = async (host: Host, path: string, { size, mtimeMs }: FsEntry) => {
    const last = held.get(path)

    if (last?.size === size && last.mtimeMs === mtimeMs) {
      return last.text
    }

    const text = await host.fs.read(path)

    held.set(path, { size, mtimeMs, text })

    return text
  }

  /** The texts of a folder's files with the suffix, by the writer each is named for. */
  const byWriter = async (host: Host, dir: string, entries: readonly FsEntry[], suffix: string) => {
    const files = entries.flatMap(entry => {
      const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

      return writer === undefined ? [] : [{ writer, entry }]
    })

    return Object.fromEntries(
      await Promise.all(
        files.map(async ({ writer, entry }) => [
          writer,
          await textOf(host, `${dir}/${entry.name}`, entry),
        ]),
      ),
    )
  }

  return async (host, paths) => {
    const top = await listed(host, paths.dir)
    const [inbox = [], presence = []] = await Promise.all(
      [paths.inbox, paths.presence].map(path => listedIn(host, paths.dir, top, path)),
    )
    const meta = top.find(entry => entry.kind === 'file' && entry.name === META_FILE)

    return {
      meta: meta === undefined ? '' : await textOf(host, paths.meta, meta),
      logs: await byWriter(host, paths.dir, top, LOG_SUFFIX),
      inbox: await byWriter(host, paths.inbox, inbox, LOG_SUFFIX),
      presence: await byWriter(host, paths.presence, presence, PRESENCE_SUFFIX),
    }
  }
}
