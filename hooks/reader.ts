/**
 * Reading a session's files, and its project's. A mod cannot watch files,
 * so each read lists the session's folders and its project's, and reads
 * again only a file whose size or time moved since it was last read. A file
 * listed that does not read by its read is not there. Also the folders
 * sitrep files projects and sessions under, a file's text where it is
 * there, and a file the window writes itself, as it stands.
 */
import type { FsEntry } from 'claude-code'
import {
  LOG_SUFFIX,
  PRESENCE_SUFFIX,
  projectPaths,
  sessionsDir,
  writerOf,
  type SessionFiles,
  type SessionPaths,
} from '../core'
import type { Host } from './host'

/** A session's files as they stand, each read again only once it changed. */
export type Reader = (host: Host, paths: SessionPaths) => Promise<SessionFiles>

/** A file's text, and the size and time it had when read. */
type Held = { size: number; mtimeMs: number; text: string }

const listed = (host: Host, dir: string) => host.fs.list(dir).catch((): FsEntry[] => [])

/** The entry `entries`, the listing of `dir`, has for `path`, of the kind given. */
const entryAt = (entries: readonly FsEntry[], dir: string, path: string, kind: FsEntry['kind']) =>
  entries.find(entry => entry.kind === kind && `${dir}/${entry.name}` === path)

const folderNames = (entries: readonly FsEntry[]) =>
  entries.filter(entry => entry.kind === 'dir').map(entry => entry.name)

/** The names of the folders in `dir`; none while it is not there. */
export const foldersIn = async (host: Host, dir: string) => folderNames(await listed(host, dir))

/**
 * A folder's entries, listed only once `top`, the listing of the folder
 * `dir` it sits in, shows it: an inbox is not there before its first
 * letter, a project may file no session yet, and a listing that fails is a
 * line in the debug log at every look.
 */
const listedIn = (host: Host, dir: string, top: readonly FsEntry[], path: string) =>
  entryAt(top, dir, path, 'dir') === undefined ? [] : listed(host, path)

/** The sessions a project files. */
export const sessionsFiled = async (host: Host, root: string, key: string) => {
  const { dir } = projectPaths(root, key)

  return folderNames(await listedIn(host, dir, await listed(host, dir), sessionsDir(root, key)))
}

/** A file's text; undefined while it is not there, or cannot be read. */
export const textAt = (host: Host, path: string) =>
  host.fs.read(path).catch((): string | undefined => undefined)

/**
 * A file the window writes itself, as it stands, so its count goes on and
 * its next write carries every line it had; empty before its first line,
 * and once gone by its read. One there that cannot be read rejects: the
 * window's next write, of the whole file, would lose its lines.
 */
export const ownText = async (host: Host, path: string) => {
  if (!(await host.fs.exists(path))) {
    return ''
  }

  try {
    return await host.fs.read(path)
  } catch (error) {
    if (await host.fs.exists(path)) {
      throw error
    }

    return ''
  }
}

export const createReader = (): Reader => {
  const held = new Map<string, Held>()

  /** A listed file's text, read again only once it changed; undefined once it is gone. */
  const textOf = async (host: Host, path: string, { size, mtimeMs }: FsEntry) => {
    const last = held.get(path)

    if (last?.size === size && last.mtimeMs === mtimeMs) {
      return last.text
    }

    const text = await textAt(host, path)

    if (text !== undefined) {
      held.set(path, { size, mtimeMs, text })
    }

    return text
  }

  /** The texts of a folder's files with the suffix, by the writer each is named for. */
  const byWriter = async (host: Host, dir: string, entries: readonly FsEntry[], suffix: string) => {
    const files = entries.flatMap(entry => {
      const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

      return writer === undefined ? [] : [{ writer, entry }]
    })
    const texts = await Promise.all(
      files.map(async ({ writer, entry }) => ({
        writer,
        text: await textOf(host, `${dir}/${entry.name}`, entry),
      })),
    )

    return Object.fromEntries(
      texts.flatMap(({ writer, text }) => (text === undefined ? [] : [[writer, text]])),
    )
  }

  /**
   * A session's files, `first` its folder's listing. The heartbeats are read
   * before everything else, and the folder listed again after them where it
   * has any: a window writes a send's lines down before its heartbeat stops
   * saying the send, so lines read after the heartbeat miss nothing it no
   * longer says.
   */
  const filesIn = async (host: Host, paths: SessionPaths, first: readonly FsEntry[]) => {
    const beats = await listedIn(host, paths.dir, first, paths.presence)
    const presence = await byWriter(host, paths.presence, beats, PRESENCE_SUFFIX)
    const top = beats.length === 0 ? first : await listed(host, paths.dir)
    const inbox = await listedIn(host, paths.dir, top, paths.inbox)
    const meta = entryAt(top, paths.dir, paths.meta, 'file')

    return {
      meta: (meta === undefined ? undefined : await textOf(host, paths.meta, meta)) ?? '',
      logs: await byWriter(host, paths.dir, top, LOG_SUFFIX),
      inbox: await byWriter(host, paths.inbox, inbox, LOG_SUFFIX),
      presence,
    }
  }

  return async (host, paths): Promise<SessionFiles> => {
    const upper = await listed(host, paths.project.dir)
    const first =
      entryAt(upper, paths.project.dir, paths.sessions, 'dir') === undefined
        ? []
        : await listed(host, paths.dir)
    const project = entryAt(upper, paths.project.dir, paths.project.file, 'file')

    return {
      ...(await filesIn(host, paths, first)),
      project: project === undefined ? undefined : await textOf(host, paths.project.file, project),
    }
  }
}
