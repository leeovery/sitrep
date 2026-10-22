/**
 * Reading sitrep's folder, as the CLI does at each run: a session
 * found by its id in whichever project files it, and every project with
 * the sessions filed under it. A session is read under today's layout and
 * the old alike, as one, the old first (core's layouts.ts).
 */
import {
  filedIds,
  foldSession,
  isSafeName,
  isSessionId,
  LOG_SUFFIX,
  mergedFiles,
  oldSessionsDir,
  parseMeta,
  parsePresence,
  parseProject,
  PRESENCE_SUFFIX,
  projectFrom,
  projectPaths,
  projectsDir,
  readOldFirst,
  recordedName,
  summarise,
  sessionPaths,
  sessionsDir,
  writerOf,
  type FolderFiles,
  type Presence,
  type ProjectRead,
  type ProjectSessions,
  type Where,
  type Session,
  type SessionFiles,
  type SessionFolder,
  type SessionPaths,
} from '../core'
import type { Io, Listed } from './io'
import { windowsOf } from './screen'

/** A session as found: the project it is filed under, its paths and files, and the session they fold to. */
export type Found = { project: string; paths: SessionPaths; files: SessionFiles; session: Session }

export const foldersIn = async (io: Io, dir: string) =>
  (await io.fs.list(dir)).filter(entry => entry.kind === 'dir').map(entry => entry.name)

/** The key of every project folder. */
export const projectKeys = async (io: Io, root: string) =>
  (await foldersIn(io, projectsDir(root))).filter(isSafeName)

/** The sessions a project files, under today's layout or the old, each once. */
export const sessionsFiled = async (io: Io, root: string, project: string) => {
  const { now, old } = await readOldFirst(
    oldSessionsDir(root, project),
    sessionsDir(root, project),
    dir => foldersIn(io, dir),
  )

  return filedIds(now, old).filter(isSessionId)
}

/** A file's text; undefined while it is not there. */
export const textAt = (io: Io, path: string) =>
  io.fs.read(path).catch((): string | undefined => undefined)

/** The texts of the files with the suffix that `entries`, the listing of `dir`, shows, by the writer each is named for; undefined for one that does not read. */
const readListed = async (io: Io, dir: string, entries: readonly Listed[], suffix: string) => {
  const files = entries.flatMap(entry => {
    const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

    return writer === undefined ? [] : [{ writer, path: `${dir}/${entry.name}` }]
  })

  return Promise.all(
    files.map(async ({ writer, path }) => ({ writer, path, text: await textAt(io, path) })),
  )
}

/** The texts of a folder's files with the suffix, as listed, by the writer each is named for; undefined for one that does not read. */
const readBy = async (io: Io, dir: string, suffix: string) =>
  readListed(io, dir, await io.fs.list(dir), suffix)

/** The texts of the files with the suffix a listing shows, by the writer each is named for; a file gone by its read, as a run moving it at once leaves it, is not there. */
const byWriter = async (io: Io, dir: string, entries: readonly Listed[], suffix: string) =>
  Object.fromEntries(
    (await readListed(io, dir, entries, suffix)).flatMap(({ writer, text }) =>
      text === undefined ? [] : [[writer, text]],
    ),
  )

/**
 * A session folder's heartbeats under one layout: those that read, and when
 * each that does not was written, as one torn mid-rewrite or one there that
 * cannot be read; one gone by its read is not there.
 */
export const heartbeatsIn = async (io: Io, folder: SessionFolder) => {
  const read = (await readBy(io, folder.presence, PRESENCE_SUFFIX)).map(
    ({ writer, path, text }) => ({
      path,
      beat: text === undefined ? undefined : parsePresence(text, writer),
    }),
  )
  const unread = await Promise.all(
    read
      .filter(({ beat }) => beat === undefined)
      .map(async ({ path }) => (await io.fs.stat(path))?.mtimeMs),
  )

  return {
    beats: read.flatMap(({ beat }): Presence[] => (beat === undefined ? [] : [beat])),
    unread: unread.filter(at => at !== undefined),
  }
}

/** Whether a folder's listing, `entries`, shows `path` as an entry of the kind. */
const isListed = (dir: string, entries: readonly Listed[], path: string, kind: Listed['kind']) =>
  entries.some(entry => entry.kind === kind && `${dir}/${entry.name}` === path)

/**
 * A session's folder under one layout, as its listing shows it: its meta
 * read, and its inbox and presence listed, only where it lists them, as the
 * mod's readers read. A folder the session is not filed in costs one look.
 * The heartbeats are read before everything else, and the folder listed
 * again after them where it has any: a window writes a send's lines down
 * before its heartbeat stops saying the send, so lines read after the
 * heartbeat miss nothing it no longer says.
 */
const filesIn = async (io: Io, folder: SessionFolder): Promise<FolderFiles> => {
  const first = await io.fs.list(folder.dir)
  const hasBeats = isListed(folder.dir, first, folder.presence, 'dir')
  const presence = hasBeats
    ? await byWriter(io, folder.presence, await io.fs.list(folder.presence), PRESENCE_SUFFIX)
    : {}
  // A folder the move emptied and removed since is not there: its files are under today's layout, read after.
  const top = hasBeats ? await io.fs.list(folder.dir).catch((): Listed[] => []) : first
  const within = async (dir: string, suffix: string) =>
    isListed(folder.dir, top, dir, 'dir') ? byWriter(io, dir, await io.fs.list(dir), suffix) : {}
  const [meta = '', logs, inbox] = await Promise.all([
    isListed(folder.dir, top, folder.meta, 'file') ? textAt(io, folder.meta) : undefined,
    byWriter(io, folder.dir, top, LOG_SUFFIX),
    within(folder.inbox, LOG_SUFFIX),
  ])

  return { meta, logs, inbox, presence }
}

/** A session's files as they stand under either layout, as one, but its project's; the meta's text is empty while neither has one. */
export const readFolders = async (io: Io, paths: SessionPaths): Promise<FolderFiles> => {
  const { now, old } = await readOldFirst(paths.old, paths, folder => filesIn(io, folder))

  return mergedFiles(now, old)
}

/** A session's files as they stand under either layout, as one, and its project's. */
export const readSession = async (io: Io, paths: SessionPaths): Promise<SessionFiles> => {
  const [folders, project] = await Promise.all([
    readFolders(io, paths),
    textAt(io, paths.project.file),
  ])

  return { ...folders, project }
}

/** A session by its id, as it stands at `now`, in whichever project files it; undefined when none does. */
export const findSession = async (
  io: Io,
  root: string,
  id: string,
  now: number,
): Promise<Found | undefined> => {
  for (const project of await projectKeys(io, root)) {
    const paths = sessionPaths(root, project, id)
    const files = await readSession(io, paths)
    const session = foldSession(files, now)

    if (session !== undefined) {
      return { project, paths, files, session }
    }
  }

  return undefined
}

/** A session as read: its files, and the session they fold to, where its session.json reads. */
export type SessionRead = { files: SessionFiles; session?: Session }

/** How a project's sessions are read: each by the key of the project filing it and its id, given the text of that project's file, read once for all of them. */
export type SessionReader = (key: string, id: string, project?: string) => Promise<SessionRead>

/** Each session as it stands at `now`, read whole. */
const readAt =
  (io: Io, root: string, now: number): SessionReader =>
  async (key, id, project) => {
    const files = { ...(await readFolders(io, sessionPaths(root, key, id))), project }

    return { files, session: foldSession(files, now) }
  }

/** A project and its sessions, each read by `read`, but those whose session.json is missing or torn; undefined for a folder with no file and no session. */
const readProject = async (io: Io, root: string, key: string, read: SessionReader) => {
  const text = await textAt(io, projectPaths(root, key).file)
  const file = parseProject(text ?? '')
  const sessions = await Promise.all(
    (await sessionsFiled(io, root, key)).map(id => read(key, id, text)),
  )
  const named =
    file === undefined ? recordedName(sessions.map(each => parseMeta(each.files.meta))) : undefined
  const project = projectFrom(key, file, named)

  return project === undefined
    ? undefined
    : { project, sessions: sessions.flatMap(each => each.session ?? []) }
}

/** Every project, and the sessions filed under it, each read by `read`. */
export const readBoard = async (
  io: Io,
  root: string,
  read: SessionReader,
): Promise<ProjectRead[]> =>
  (
    await Promise.all((await projectKeys(io, root)).map(key => readProject(io, root, key, read)))
  ).filter(each => each !== undefined)

/** What `readProjects` gives: every project with its sessions in brief, and the windows each session is in, by its id. */
export type ProjectsRead = {
  projects: ProjectSessions[]
  windows: ReadonlyMap<string, readonly Where[]>
}

/** Every project, with its sessions in brief as they stand at `now`, and the windows each session is in. */
export const readProjects = async (io: Io, root: string, now: number): Promise<ProjectsRead> => {
  const read = await readBoard(io, root, readAt(io, root, now))

  return {
    projects: read.map(({ project, sessions }) => ({ project, sessions: sessions.map(summarise) })),
    windows: new Map(
      read.flatMap(({ sessions }) =>
        sessions.map(session => [session.id, windowsOf(session, now)] as const),
      ),
    ),
  }
}
