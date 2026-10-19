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
  type ProjectSessions,
  type Where,
  type Session,
  type SessionFiles,
  type SessionFolder,
  type SessionPaths,
} from '../core'
import type { Io } from './io'
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

/** The texts of a folder's files with the suffix, as listed, by the writer each is named for; undefined for one that does not read. */
const readBy = async (io: Io, dir: string, suffix: string) => {
  const files = (await io.fs.list(dir)).flatMap(entry => {
    const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

    return writer === undefined ? [] : [{ writer, path: `${dir}/${entry.name}` }]
  })

  return Promise.all(
    files.map(async ({ writer, path }) => ({ writer, path, text: await textAt(io, path) })),
  )
}

/** The texts of a folder's files with the suffix, by the writer each is named for; a file gone by its read, as a run moving it at once leaves it, is not there. */
const byWriter = async (io: Io, dir: string, suffix: string) =>
  Object.fromEntries(
    (await readBy(io, dir, suffix)).flatMap(({ writer, text }) =>
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
    read.filter(({ beat }) => beat === undefined).map(({ path }) => io.fs.modifiedAt(path)),
  )

  return {
    beats: read.flatMap(({ beat }): Presence[] => (beat === undefined ? [] : [beat])),
    unread: unread.filter(at => at !== undefined),
  }
}

const filesIn = async (io: Io, folder: SessionFolder): Promise<FolderFiles> => {
  const [meta = '', logs, inbox, presence] = await Promise.all([
    textAt(io, folder.meta),
    byWriter(io, folder.dir, LOG_SUFFIX),
    byWriter(io, folder.inbox, LOG_SUFFIX),
    byWriter(io, folder.presence, PRESENCE_SUFFIX),
  ])

  return { meta, logs, inbox, presence }
}

/** A session's files as they stand under either layout, as one, and its project's; the meta's text is empty while neither has one. */
export const readSession = async (io: Io, paths: SessionPaths): Promise<SessionFiles> => {
  const [{ now, old }, project] = await Promise.all([
    readOldFirst(paths.old, paths, folder => filesIn(io, folder)),
    textAt(io, paths.project.file),
  ])

  return { ...mergedFiles(now, old), project }
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

/** The files of each session filed under a project, in the order listed. */
const sessionFilesIn = async (io: Io, root: string, project: string) =>
  Promise.all(
    (await sessionsFiled(io, root, project)).map(id =>
      readSession(io, sessionPaths(root, project, id)),
    ),
  )

/** A project and its sessions, but those whose session.json is missing or torn; undefined for a folder with no file and no session. */
const readProject = async (io: Io, root: string, key: string, now: number) => {
  const file = parseProject((await textAt(io, projectPaths(root, key).file)) ?? '')
  const files = await sessionFilesIn(io, root, key)
  const sessions = files
    .map(each => foldSession(each, now))
    .filter(session => session !== undefined)
  const project = projectFrom(key, file, recordedName(files.map(each => parseMeta(each.meta))))

  return project === undefined ? undefined : { project, sessions }
}

/** What `readProjects` gives: every project with its sessions in brief, and the windows each session is in, by its id. */
export type ProjectsRead = {
  projects: ProjectSessions[]
  windows: ReadonlyMap<string, readonly Where[]>
}

/** Every project, with its sessions in brief as they stand at `now`, and the windows each session is in. */
export const readProjects = async (io: Io, root: string, now: number): Promise<ProjectsRead> => {
  const read = (
    await Promise.all((await projectKeys(io, root)).map(key => readProject(io, root, key, now)))
  ).filter(each => each !== undefined)

  return {
    projects: read.map(({ project, sessions }) => ({ project, sessions: sessions.map(summarise) })),
    windows: new Map(
      read.flatMap(({ sessions }) =>
        sessions.map(session => [session.id, windowsOf(session, now)] as const),
      ),
    ),
  }
}
