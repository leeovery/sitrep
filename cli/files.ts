/**
 * Reading sitrep's folder, as the CLI does at each run: a piece of work
 * found by its id in whichever project files it, and every project with
 * the works filed under it.
 */
import {
  foldWork,
  isSafeName,
  isWorkId,
  LOG_SUFFIX,
  parseMeta,
  parseProject,
  PRESENCE_SUFFIX,
  projectFrom,
  projectPaths,
  projectsDir,
  recordedName,
  summarise,
  workPaths,
  worksDir,
  writerOf,
  type ProjectWorks,
  type Where,
  type Work,
  type WorkFiles,
  type WorkPaths,
} from '../core'
import type { Io } from './io'
import { windowsOf } from './screen'

/** A piece of work as found: the project it is filed under, its paths and files, and the work they fold to. */
export type Found = { project: string; paths: WorkPaths; files: WorkFiles; work: Work }

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

/** A piece of work's files as they stand, and its project's; work.json's text is empty while it is not there. */
export const readWork = async (io: Io, paths: WorkPaths): Promise<WorkFiles> => {
  const [meta = '', project, logs, inbox, presence] = await Promise.all([
    textAt(io, paths.meta),
    textAt(io, paths.project.file),
    byWriter(io, paths.dir, LOG_SUFFIX),
    byWriter(io, paths.inbox, LOG_SUFFIX),
    byWriter(io, paths.presence, PRESENCE_SUFFIX),
  ])

  return { meta, project, logs, inbox, presence }
}

/** A piece of work by its id, as it stands at `now`, in whichever project files it; undefined when none does. */
export const findWork = async (
  io: Io,
  root: string,
  id: string,
  now: number,
): Promise<Found | undefined> => {
  for (const project of await projectKeys(io, root)) {
    const paths = workPaths(root, project, id)
    const files = await readWork(io, paths)
    const work = foldWork(files, now)

    if (work !== undefined) {
      return { project, paths, files, work }
    }
  }

  return undefined
}

/** The files of each work filed under a project, in the order listed. */
const filesIn = async (io: Io, root: string, project: string) =>
  Promise.all(
    (await foldersIn(io, worksDir(root, project)))
      .filter(isWorkId)
      .map(id => readWork(io, workPaths(root, project, id))),
  )

/** A project and its works, but those whose work.json is missing or torn; undefined for a folder with no file and no work. */
const readProject = async (io: Io, root: string, key: string, now: number) => {
  const file = parseProject((await textAt(io, projectPaths(root, key).file)) ?? '')
  const files = await filesIn(io, root, key)
  const works = files.map(each => foldWork(each, now)).filter(work => work !== undefined)
  const project = projectFrom(key, file, recordedName(files.map(each => parseMeta(each.meta))))

  return project === undefined ? undefined : { project, works }
}

/** What `readProjects` gives: every project with its works in brief, and the windows each work is in, by its id. */
export type ProjectsRead = {
  projects: ProjectWorks[]
  windows: ReadonlyMap<string, readonly Where[]>
}

/** Every project, with its works in brief as they stand at `now`, and the windows each work is in. */
export const readProjects = async (io: Io, root: string, now: number): Promise<ProjectsRead> => {
  const read = (
    await Promise.all((await projectKeys(io, root)).map(key => readProject(io, root, key, now)))
  ).filter(each => each !== undefined)

  return {
    projects: read.map(({ project, works }) => ({ project, works: works.map(summarise) })),
    windows: new Map(
      read.flatMap(({ works }) => works.map(work => [work.id, windowsOf(work, now)] as const)),
    ),
  }
}
