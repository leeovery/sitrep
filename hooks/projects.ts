/**
 * The projects on the board, as the mod reads them: every folder under
 * `projects/`, named by its project.json, else, for a folder from before
 * projects were named, as a session of its recorded it. Also which folder
 * holds a session's files, found by its id, as a moved session's stay
 * where it was started; and the project a start or a move files a session
 * under. A project's file is written only as a project is made, renamed or
 * given a directory.
 */
import {
  filedAs,
  filedUnder,
  isSafeName,
  newProjectKey,
  parseMeta,
  parseProject,
  projectFrom,
  projectNamed,
  projectPaths,
  projectsDir,
  projectText,
  recordedName,
  sessionPaths,
  type Project,
  type ProjectChange,
  type ProjectFile,
  type Session,
} from '../core'
import type { SitrepSessionRef } from '../types'
import type { Host } from './host'
import { foldersIn, sessionsFiled, textAt } from './reader'
import type { Filed } from './scene'

/** Who first writes a project's file, and when. */
type Writing = Pick<ProjectFile, 'created' | 'by'>

/** The project a start or a move files a session under, and what its answer says of it: `a new project, …` or `the existing project …`. */
export type Filing = { project: Project; said: string }

/** The key of every project folder. */
export const projectKeys = async (host: Host, root: string) =>
  (await foldersIn(host, projectsDir(root))).filter(isSafeName)

/** A project's file; undefined while it has none, or it is torn. */
const fileOf = async (host: Host, root: string, key: string) =>
  parseProject((await textAt(host, projectPaths(root, key).file)) ?? '')

/** A session's meta; undefined where its session.json does not read. */
const metaOf = async (host: Host, root: string, key: string, id: string) =>
  parseMeta((await textAt(host, sessionPaths(root, key, id).meta)) ?? '')

/** The meta of each session filed under a project, in the order listed; undefined for one that does not read. */
const metasIn = async (host: Host, root: string, key: string) =>
  Promise.all(
    (await sessionsFiled(host, root, key)).map(id => metaOf(host, root, key, id)),
  )

/** A project as its folder has it; undefined for a folder with no file and no session. */
export const readProject = async (host: Host, root: string, key: string) => {
  const file = await fileOf(host, root, key)
  const recorded = file === undefined ? recordedName(await metasIn(host, root, key)) : undefined

  return projectFrom(key, file, recorded)
}

/** The projects these folders hold. */
export const readProjects = async (host: Host, root: string, keys: readonly string[]) =>
  (await Promise.all(keys.map(key => readProject(host, root, key)))).filter(
    project => project !== undefined,
  )

/** The key of the folder a session's files are in, whichever project's it is; undefined when none files it. */
export const projectFiling = async (host: Host, root: string, id: string) => {
  for (const key of await projectKeys(host, root)) {
    if ((await metaOf(host, root, key, id)) !== undefined) {
      return key
    }
  }

  return undefined
}

/**
 * The key of the folder a session's files are in, found by its id: the
 * project `at` names, where the session's session.json reads there, else
 * whichever project's folder files it; the project named where none does.
 */
export const folderOf = async (host: Host, root: string, at: SitrepSessionRef) =>
  (await metaOf(host, root, at.project, at.session)) === undefined
    ? ((await projectFiling(host, root, at.session)) ?? at.project)
    : at.project

/** A session's paths, its folder found by its id. */
export const pathsOf = async (host: Host, root: string, at: SitrepSessionRef) =>
  sessionPaths(root, await folderOf(host, root, at), at.session)

/** A session as read in a project's folder: that project's key, and the session folded. */
export type InFolder = { folder: string; session: Session }

/** A session filed under its project, and the key of the folder its files are in. */
export type FiledIn = Filed & { folder: string }

/** Each project's name as the board names it, by its key, each read once: what a session filed under it goes by. */
export const projectNames = (host: Host, root: string) => {
  const names = new Map<string, Promise<string>>()

  return (key: string) => {
    const name = names.get(key) ?? readProject(host, root, key).then(read => read?.name ?? key)

    names.set(key, name)

    return name
  }
}

/**
 * A session read in its folder, filed under the project its lines name
 * among the project folders `keys` (core's `filedUnder`), and named by that
 * project, as `nameOf` gives its name.
 */
export const fileIn =
  (keys: readonly string[], nameOf: (key: string) => Promise<string>) =>
  async ({ folder, session }: InFolder): Promise<FiledIn> => {
    const project = filedUnder(folder, session, key => keys.includes(key))

    return {
      folder,
      project,
      session: project === folder ? session : filedAs(session, await nameOf(project)),
    }
  }

/** A session read in its folder, filed as `fileIn` files it, the project folders listed only for one that moved. */
export const fileOne = async (host: Host, root: string, found: InFolder) =>
  fileIn(
    found.session.movedTo === undefined ? [] : await projectKeys(host, root),
    projectNames(host, root),
  )(found)

/** Every session id filed, in any project: a new one is unlike them all, as join looks in every project. */
export const sessionIdsIn = async (host: Host, root: string, keys: readonly string[]) =>
  new Set((await Promise.all(keys.map(key => sessionsFiled(host, root, key)))).flat())

const writeProject = (host: Host, root: string, key: string, file: ProjectFile) =>
  host.fs.write(projectPaths(root, key).file, projectText(file))

/**
 * Writes a project's file with the change made, and gives the project as it
 * now stands. A folder from before projects were named gets its first file,
 * written as `writing` says.
 */
export const changeProject = async (
  host: Host,
  root: string,
  project: Project,
  change: ProjectChange,
  writing: Writing,
): Promise<Project> => {
  const { name, directory, created, by } = (await fileOf(host, root, project.key)) ?? {
    ...project,
    ...writing,
  }
  const changed = {
    name: change.name ?? name,
    directory: change.directory ?? directory,
    created,
    by,
  }

  await writeProject(host, root, project.key, changed)

  return { key: project.key, name: changed.name, directory: changed.directory }
}

/** What a start says of an existing project whose directory is another than the one given. */
const livesElsewhere = (project: Project, directory?: string) =>
  directory === undefined || project.directory === directory
    ? ''
    : `, which lives in ${project.directory}; the project tool changes that`

/** The project folders on the board, by key, and the projects they hold. */
export type OnBoard = { keys: readonly string[]; projects: readonly Project[] }

/** The project folders on the board, and the projects they hold. */
export const onBoard = async (host: Host, root: string): Promise<OnBoard> => {
  const keys = await projectKeys(host, root)

  return { keys, projects: await readProjects(host, root, keys) }
}

/**
 * The project a start or a move names, of those on the board: the one whose
 * name matches, given the directory where it has none; else a new one, its
 * key its name's slug.
 */
export const filingFor = async (
  host: Host,
  root: string,
  { keys, projects }: OnBoard,
  wanted: ProjectFile,
): Promise<Filing> => {
  const { name, directory, ...writing } = wanted
  const existing = projectNamed(projects, name)

  if (existing === undefined) {
    const key = newProjectKey(name, new Set(keys))

    await writeProject(host, root, key, wanted)

    return { project: { key, name, directory }, said: `a new project, ${name}` }
  }

  const project =
    directory !== undefined && existing.directory === undefined
      ? await changeProject(host, root, existing, { directory }, writing)
      : existing

  return {
    project,
    said: `the existing project ${project.name}${livesElsewhere(project, directory)}`,
  }
}
