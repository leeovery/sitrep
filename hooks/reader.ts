/**
 * Reading a session's files, and its project's. A mod cannot watch files,
 * so each read lists the session's folders and its project's, and reads
 * again only a file whose size or time moved since it was last read. A
 * session is read under today's layout and the old alike, as one, the old
 * first (core's layouts.ts), its project's folder listed anew for each: the
 * CLI moving the old layout makes today's folder as it goes. A file listed
 * and gone by its read, as the move leaves it, is not there. Also the
 * folders sitrep files projects and sessions under, a file's text where it
 * is there, and a file the window writes itself, as it stands.
 */
import type { FsEntry } from 'claude-code'
import {
  filedIds,
  LOG_SUFFIX,
  mergedFiles,
  mergedText,
  oldSessionsDir,
  PRESENCE_SUFFIX,
  projectPaths,
  readOldFirst,
  sessionsDir,
  writerOf,
  type FolderFiles,
  type SessionFiles,
  type SessionFolder,
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
 * letter, a project may file under one layout alone, and a listing that
 * fails is a line in the debug log at every look.
 */
const listedIn = (host: Host, dir: string, top: readonly FsEntry[], path: string) =>
  entryAt(top, dir, path, 'dir') === undefined ? [] : listed(host, path)

/**
 * A session's folder under one layout, as listed, `upper` the listing of
 * its project's folder: nothing where the project files nothing under that
 * layout. A project filing under both has the folder listed only once its
 * layout's folder of sessions shows it, so a session filed under one is no
 * failed listing under the other.
 */
const folderListed = async (
  host: Host,
  paths: SessionPaths,
  upper: readonly FsEntry[],
  folder: SessionFolder,
) => {
  const isFiled = (each: SessionFolder) =>
    entryAt(upper, paths.project.dir, each.sessions, 'dir') !== undefined

  if (!isFiled(folder)) {
    return []
  }

  return isFiled(paths) && isFiled(paths.old)
    ? listedIn(host, folder.sessions, await listed(host, folder.sessions), folder.dir)
    : listed(host, folder.dir)
}

/** The sessions a project files, under today's layout or the old, each once. */
export const sessionsFiled = async (host: Host, root: string, key: string) => {
  const { dir } = projectPaths(root, key)
  const { now, old } = await readOldFirst(
    oldSessionsDir(root, key),
    sessionsDir(root, key),
    async path => folderNames(await listedIn(host, dir, await listed(host, dir), path)),
  )

  return filedIds(now, old)
}

/** A file's text; undefined while it is not there, or cannot be read. */
export const textAt = (host: Host, path: string) =>
  host.fs.read(path).catch((): string | undefined => undefined)

/**
 * A file the window writes itself, as it stands; empty while it is not
 * there, and once gone by its read. One there that cannot be read rejects:
 * the window's next write, of the whole file, would lose its lines.
 */
const ownFile = async (host: Host, path: string) => {
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

/**
 * A file the window writes itself, the one `fileOf` names in a session's
 * folder, as it stands under today's layout and the old as one, so its count
 * goes on and its next write, under today's, carries every line it had;
 * empty before its first line.
 */
export const ownText = async (
  host: Host,
  paths: SessionPaths,
  fileOf: (folder: SessionFolder) => string,
) => {
  const { now, old } = await readOldFirst(fileOf(paths.old), fileOf(paths), path =>
    ownFile(host, path),
  )

  return mergedText(now, old)
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
   * A session's files under one layout, `first` its folder's listing. The
   * heartbeats are read before everything else, and the folder listed again
   * after them where it has any: a window writes a send's lines down before
   * its heartbeat stops saying the send, so lines read after the heartbeat
   * miss nothing it no longer says.
   */
  const filesIn = async (
    host: Host,
    folder: SessionFolder,
    first: readonly FsEntry[],
  ): Promise<FolderFiles> => {
    const beats = await listedIn(host, folder.dir, first, folder.presence)
    const presence = await byWriter(host, folder.presence, beats, PRESENCE_SUFFIX)
    const top = beats.length === 0 ? first : await listed(host, folder.dir)
    const inbox = await listedIn(host, folder.dir, top, folder.inbox)
    const meta = entryAt(top, folder.dir, folder.meta, 'file')

    return {
      meta: (meta === undefined ? undefined : await textOf(host, folder.meta, meta)) ?? '',
      logs: await byWriter(host, folder.dir, top, LOG_SUFFIX),
      inbox: await byWriter(host, folder.inbox, inbox, LOG_SUFFIX),
      presence,
    }
  }

  /** A session's files under one layout, and its project's folder as listed for them. */
  const layoutRead = async (host: Host, paths: SessionPaths, folder: SessionFolder) => {
    const upper = await listed(host, paths.project.dir)

    return {
      upper,
      files: await filesIn(host, folder, await folderListed(host, paths, upper, folder)),
    }
  }

  return async (host, paths) => {
    const { now, old } = await readOldFirst(paths.old, paths, folder =>
      layoutRead(host, paths, folder),
    )
    const project = entryAt(now.upper, paths.project.dir, paths.project.file, 'file')

    return {
      ...mergedFiles(now.files, old.files),
      project: project === undefined ? undefined : await textOf(host, paths.project.file, project),
    }
  }
}
