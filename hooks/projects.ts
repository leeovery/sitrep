/**
 * The projects on the board, as the mod reads them: every folder under
 * `projects/`, named by its project.json, else, for a folder from before
 * projects were named, as a session of its recorded it. Also the project a
 * start or a move files a session under. A project's file is written only
 * as a project is made, renamed or given a directory.
 */
import {
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
} from '../core'
import type { Host } from './host'
import { foldersIn, sessionsFiled, textAt } from './reader'

/** Who first writes a project's file, and when. */
type Writing = Pick<ProjectFile, 'created' | 'by'>

/** The project a start or a move files a session under, and what its answer says of it: `a new project, …` or `the existing project …`. */
export type Destination = { project: Project; said: string }

/** The key of every project folder. */
export const projectKeys = async (host: Host, root: string) =>
  (await foldersIn(host, projectsDir(root))).filter(isSafeName)

/** A project's file; undefined while it has none, or it is torn. */
const fileOf = async (host: Host, root: string, key: string) =>
  parseProject((await textAt(host, projectPaths(root, key).file)) ?? '')

/** A session's meta; undefined where its session.json does not read. */
export const metaOf = async (host: Host, root: string, key: string, id: string) =>
  parseMeta((await textAt(host, sessionPaths(root, key, id).meta)) ?? '')

/** The meta of each session filed under a project, in the order listed; undefined for one that does not read. */
const metasIn = async (host: Host, root: string, key: string) =>
  Promise.all(
    (await sessionsFiled(host, root, key)).map(id => metaOf(host, root, key, id)),
  )

/** A project as its file's text has it, its sessions' metas read only where it has no file; undefined for a folder with no file and no session. */
export const projectOfText = async (
  host: Host,
  root: string,
  key: string,
  text: string | undefined,
) => {
  const file = parseProject(text ?? '')
  const recorded = file === undefined ? recordedName(await metasIn(host, root, key)) : undefined

  return projectFrom(key, file, recorded)
}

/** A project as its folder has it; undefined for a folder with no file and no session. */
export const readProject = async (host: Host, root: string, key: string) =>
  projectOfText(host, root, key, await textAt(host, projectPaths(root, key).file))

/** The projects these folders hold. */
export const readProjects = async (host: Host, root: string, keys: readonly string[]) =>
  (await Promise.all(keys.map(key => readProject(host, root, key)))).filter(
    project => project !== undefined,
  )

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

/** The project a start or a move names: one on the board, or a new one, not made yet. */
export type Named = { project: Project; isNew: boolean }

/** The project a start or a move names, of those on the board: the one whose name matches; else a new one, its key its name's slug. */
export const projectFor = ({ keys, projects }: OnBoard, name: string): Named => {
  const existing = projectNamed(projects, name)

  return existing === undefined
    ? { project: { key: newProjectKey(name, new Set(keys)), name }, isNew: true }
    : { project: existing, isNew: false }
}

/** Files a session under the project named: a new one made as `wanted` says, or one on the board given the directory where it has none. */
export const fileUnder = async (
  host: Host,
  root: string,
  { project, isNew }: Named,
  wanted: ProjectFile,
): Promise<Destination> => {
  const { name, directory, ...writing } = wanted

  if (isNew) {
    await writeProject(host, root, project.key, wanted)

    return { project: { ...project, directory }, said: `a new project, ${name}` }
  }

  const filed =
    directory !== undefined && project.directory === undefined
      ? await changeProject(host, root, project, { directory }, writing)
      : project

  return {
    project: filed,
    said: `the existing project ${filed.name}${livesElsewhere(filed, directory)}`,
  }
}
