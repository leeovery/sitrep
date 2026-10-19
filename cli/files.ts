/**
 * Reading sitrep's folder, as the CLI does at each run: a session
 * found by its id in whichever project files it, and every project with
 * the sessions filed under it.
 */
import {
  foldSession,
  isSafeName,
  isSessionId,
  LOG_SUFFIX,
  parseMeta,
  parseProject,
  PRESENCE_SUFFIX,
  projectFrom,
  projectPaths,
  projectsDir,
  recordedName,
  summarise,
  sessionPaths,
  sessionsDir,
  writerOf,
  type ProjectSessions,
  type Where,
  type Session,
  type SessionFiles,
  type SessionPaths,
} from '../core'
import type { Io } from './io'
import { windowsOf } from './screen'

/** A session as found: the project it is filed under, its paths and files, and the session they fold to. */
export type Found = { project: string; paths: SessionPaths; files: SessionFiles; session: Session }

const foldersIn = async (io: Io, dir: string) =>
  (await io.fs.list(dir)).filter(entry => entry.kind === 'dir').map(entry => entry.name)

/** The key of every project folder. */
const projectKeys = async (io: Io, root: string) =>
  (await foldersIn(io, projectsDir(root))).filter(isSafeName)

/** A file's text; undefined while it is not there. */
const textAt = (io: Io, path: string) => io.fs.read(path).catch((): string | undefined => undefined)

/** The texts of a folder's files with the suffix, by the writer each is named for. */
const byWriter = async (io: Io, dir: string, suffix: string) => {
  const files = (await io.fs.list(dir)).flatMap(entry => {
    const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

    return writer === undefined ? [] : [{ writer, path: `${dir}/${entry.name}` }]
  })

  return Object.fromEntries(
    await Promise.all(files.map(async ({ writer, path }) => [writer, await io.fs.read(path)])),
  )
}

/** A session's files as they stand, and its project's; work.json's text is empty while it is not there. */
export const readSession = async (io: Io, paths: SessionPaths): Promise<SessionFiles> => {
  const [meta = '', project, logs, inbox, presence] = await Promise.all([
    textAt(io, paths.meta),
    textAt(io, paths.project.file),
    byWriter(io, paths.dir, LOG_SUFFIX),
    byWriter(io, paths.inbox, LOG_SUFFIX),
    byWriter(io, paths.presence, PRESENCE_SUFFIX),
  ])

  return { meta, project, logs, inbox, presence }
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
const filesIn = async (io: Io, root: string, project: string) =>
  Promise.all(
    (await foldersIn(io, sessionsDir(root, project)))
      .filter(isSessionId)
      .map(id => readSession(io, sessionPaths(root, project, id))),
  )

/** A project and its sessions, but those whose work.json is missing or torn; undefined for a folder with no file and no session. */
const readProject = async (io: Io, root: string, key: string, now: number) => {
  const file = parseProject((await textAt(io, projectPaths(root, key).file)) ?? '')
  const files = await filesIn(io, root, key)
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
