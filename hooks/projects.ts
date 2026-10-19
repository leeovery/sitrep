/**
 * The projects on the board, as the mod reads them: every folder under
 * `projects/`, named by its project.json, else, for a folder from before
 * projects were named, as a session of its recorded it. Also which project
 * files a session, and the project a start files its session under. A
 * project's file is written only as a project is made, renamed or given a
 * directory.
 */
import {
  isSafeName,
  isSessionId,
  newProjectKey,
  parseMeta,
  parseProject,
  projectFrom,
  projectNamed,
  projectPaths,
  projectsDir,
  projectText,
  readOldFirst,
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

/** The project a start files its session under, and what its answer says of it. */
export type Filing = { project: Project; said: string }

/** The key of every project folder. */
export const projectKeys = async (host: Host, root: string) =>
  (await foldersIn(host, projectsDir(root))).filter(isSafeName)

/** A project's file; undefined while it has none, or it is torn. */
const fileOf = async (host: Host, root: string, key: string) =>
  parseProject((await textAt(host, projectPaths(root, key).file)) ?? '')

const metaAt = async (host: Host, path: string) => parseMeta((await textAt(host, path)) ?? '')

/** A session's meta: its session.json where that reads, else its work.json under the old layout. */
const metaOf = async (host: Host, root: string, key: string, id: string) => {
  const paths = sessionPaths(root, key, id)
  const { now, old } = await readOldFirst(paths.old.meta, paths.meta, path => metaAt(host, path))

  return now ?? old
}

/** The meta of each session filed under a project, in the order listed; undefined for one that does not read. */
const metasIn = async (host: Host, root: string, key: string) =>
  Promise.all(
    (await sessionsFiled(host, root, key))
      .filter(isSessionId)
      .map(id => metaOf(host, root, key, id)),
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

/** The project a session is filed under, whichever it is; undefined when none files it. */
export const projectFiling = async (host: Host, root: string, id: string) => {
  for (const key of await projectKeys(host, root)) {
    if ((await metaOf(host, root, key, id)) !== undefined) {
      return key
    }
  }

  return undefined
}

/** Every session id filed, in any project and under either layout: a new one is unlike them all, as join looks in every project. */
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

/**
 * The project a start names, of those these folders hold: the one whose
 * name matches, given the directory where it has none; else a new one, its
 * key its name's slug.
 */
export const filingFor = async (
  host: Host,
  root: string,
  keys: readonly string[],
  wanted: ProjectFile,
): Promise<Filing> => {
  const { name, directory, ...writing } = wanted
  const existing = projectNamed(await readProjects(host, root, keys), name)

  if (existing === undefined) {
    const key = newProjectKey(name, new Set(keys))

    await writeProject(host, root, key, wanted)

    return { project: { key, name, directory }, said: `in a new project, ${name}` }
  }

  const project =
    directory !== undefined && existing.directory === undefined
      ? await changeProject(host, root, existing, { directory }, writing)
      : existing

  return {
    project,
    said: `in the existing project ${project.name}${livesElsewhere(project, directory)}`,
  }
}
