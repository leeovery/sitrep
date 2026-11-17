/**
 * Reading sitrep's folder, as the CLI does at each run: a session found by
 * its id in whichever project's folder holds it, and every project with the
 * sessions filed under it: those in its folder, but those moved to another
 * project since, and those moved to it (core's filing.ts).
 */
import {
  fileRead,
  folderKey,
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
  refiled,
  summarise,
  sessionPaths,
  sessionsDir,
  writerOf,
  type Filed,
  type FolderKey,
  type ProjectRead,
  type ProjectSessions,
  type ReadName,
  type Session,
  type SessionFiles,
  type SessionPaths,
} from '../core'
import type { Io, Listed } from './io'

/** A session as found: filed under its project, named by it, with its paths and files. */
export type Found = Filed & { paths: SessionPaths; files: SessionFiles }

const foldersIn = async (io: Io, dir: string) =>
  (await io.fs.list(dir)).filter(entry => entry.kind === 'dir').map(entry => entry.name)

/** The key of every project folder. */
const projectKeys = async (io: Io, root: string) =>
  (await foldersIn(io, projectsDir(root))).filter(isSafeName).map(folderKey)

/** The sessions a project files. */
const sessionsFiled = async (io: Io, root: string, project: string) =>
  (await foldersIn(io, sessionsDir(root, project))).filter(isSessionId)

/** A file's text; undefined while it is not there. */
export const textAt = (io: Io, path: string) =>
  io.fs.read(path).catch((): string | undefined => undefined)

/** The texts of the files with the suffix a listing shows, by the writer each is named for; a file that does not read is not there. */
const byWriter = async (io: Io, dir: string, entries: readonly Listed[], suffix: string) => {
  const files = entries.flatMap(entry => {
    const writer = entry.kind === 'file' ? writerOf(entry.name, suffix) : undefined

    return writer === undefined ? [] : [{ writer, path: `${dir}/${entry.name}` }]
  })
  const texts = await Promise.all(
    files.map(async ({ writer, path }) => ({ writer, text: await textAt(io, path) })),
  )

  return Object.fromEntries(
    texts.flatMap(({ writer, text }) => (text === undefined ? [] : [[writer, text]])),
  )
}

/** Whether a folder's listing, `entries`, shows `path` as an entry of the kind. */
const isListed = (dir: string, entries: readonly Listed[], path: string, kind: Listed['kind']) =>
  entries.some(entry => entry.kind === kind && `${dir}/${entry.name}` === path)

/**
 * A session's files but its project's, as its folder's listing shows them:
 * its meta read, and its inbox and presence listed, only where it lists
 * them, as the mod's readers read; the meta's text is empty while there is
 * none. A folder the session is not filed in costs one look. The heartbeats
 * are read before everything else, and the folder listed again after them
 * where it has any: a window writes a send's lines down before its
 * heartbeat stops saying the send, so lines read after the heartbeat miss
 * nothing it no longer says.
 */
export const readFolder = async (
  io: Io,
  paths: SessionPaths,
): Promise<Omit<SessionFiles, 'project'>> => {
  const first = await io.fs.list(paths.dir)
  const hasBeats = isListed(paths.dir, first, paths.presence, 'dir')
  const presence = hasBeats
    ? await byWriter(io, paths.presence, await io.fs.list(paths.presence), PRESENCE_SUFFIX)
    : {}
  const top = hasBeats ? await io.fs.list(paths.dir) : first
  const within = async (dir: string, suffix: string) =>
    isListed(paths.dir, top, dir, 'dir') ? byWriter(io, dir, await io.fs.list(dir), suffix) : {}
  const [meta = '', logs, inbox] = await Promise.all([
    isListed(paths.dir, top, paths.meta, 'file') ? textAt(io, paths.meta) : undefined,
    byWriter(io, paths.dir, top, LOG_SUFFIX),
    within(paths.inbox, LOG_SUFFIX),
  ])

  return { meta, logs, inbox, presence }
}

/** A session's files as they stand, and its project's. */
export const readSession = async (io: Io, paths: SessionPaths): Promise<SessionFiles> => {
  const [folder, project] = await Promise.all([
    readFolder(io, paths),
    textAt(io, paths.project.file),
  ])

  return { ...folder, project }
}

/** A session as read: its files, and the session they fold to, where its session.json reads. */
export type SessionRead = { files: SessionFiles; session?: Session }

/** How a project's sessions are read: each by the key of the project filing it and its id, given the text of that project's file, read once for all of them. */
export type SessionReader = (key: FolderKey, id: string, project?: string) => Promise<SessionRead>

/** Each session's meta alone, no session folded: what names a project with no file. */
const metasOf =
  (io: Io, root: string): SessionReader =>
  async (key, id) => ({
    files: { meta: (await textAt(io, sessionPaths(root, key, id).meta)) ?? '', logs: {} },
  })

/** Each session as it stands at `now`, read whole. */
const readAt =
  (io: Io, root: string, now: number): SessionReader =>
  async (key, id, project) => {
    const files = { ...(await readFolder(io, sessionPaths(root, key, id))), project }

    return { files, session: foldSession(files, now) }
  }

/** A project and the sessions in its folder, each read by `read`, but those whose session.json is missing or torn; undefined for a folder with no file and no session. */
const readProject = async (io: Io, root: string, key: FolderKey, read: SessionReader) => {
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

/** The name the board gives a project, by its key, as its folder has it, its sessions' metas read only where it has no file; undefined for a folder with neither. */
const nameIn =
  (io: Io, root: string): ReadName =>
  async key =>
    (await readProject(io, root, folderKey(key), metasOf(io, root)))?.project.name

/** A session by its id, as it stands at `now`, in whichever project's folder holds it, filed under its project; undefined when none holds it. */
export const findSession = async (
  io: Io,
  root: string,
  id: string,
  now: number,
): Promise<Found | undefined> => {
  for (const folder of await projectKeys(io, root)) {
    const paths = sessionPaths(root, folder, id)
    const files = await readSession(io, paths)
    const session = foldSession(files, now)

    if (session !== undefined) {
      return { paths, files, ...(await fileRead(folder, session, nameIn(io, root))) }
    }
  }

  return undefined
}

/** Every project, and the sessions filed under it, each read by `read` in its folder. */
export const readBoard = async (
  io: Io,
  root: string,
  read: SessionReader,
): Promise<ProjectRead[]> =>
  refiled(
    (
      await Promise.all((await projectKeys(io, root)).map(key => readProject(io, root, key, read)))
    ).filter(each => each !== undefined),
  )

/** Every project, and the sessions filed under it, as they stand at `now`. */
export const readBoardAt = (io: Io, root: string, now: number) =>
  readBoard(io, root, readAt(io, root, now))

/** Every project, with its sessions in brief as they stand at `now`. */
export const readProjects = async (
  io: Io,
  root: string,
  now: number,
): Promise<ProjectSessions[]> =>
  (await readBoardAt(io, root, now)).map(({ project, sessions }) => ({
    project,
    sessions: sessions.map(summarise),
  }))
