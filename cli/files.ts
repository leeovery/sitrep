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
  parseProject,
  PRESENCE_SUFFIX,
  projectFrom,
  projectPaths,
  projectsDir,
  summarise,
  workPaths,
  worksDir,
  writerOf,
  type ProjectWorks,
  type Work,
  type WorkFiles,
  type WorkPaths,
} from '../core'
import type { Io } from './io'

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

/** A project's works as they stand at `now`; one whose work.json is missing or torn is left out. */
const worksIn = async (io: Io, root: string, project: string, now: number) => {
  const ids = (await foldersIn(io, worksDir(root, project))).filter(isWorkId)
  const works = await Promise.all(
    ids.map(async id => foldWork(await readWork(io, workPaths(root, project, id)), now)),
  )

  return works.filter(work => work !== undefined)
}

/** A project and its works in brief; undefined for a folder with no file and no work. */
const readProject = async (
  io: Io,
  root: string,
  key: string,
  now: number,
): Promise<ProjectWorks | undefined> => {
  const file = parseProject((await textAt(io, projectPaths(root, key).file)) ?? '')
  const works = await worksIn(io, root, key, now)
  const project = projectFrom(key, file, works.at(0)?.project)

  return project === undefined ? undefined : { project, works: works.map(summarise) }
}

/** Every project, with its works in brief as they stand at `now`. */
export const readProjects = async (io: Io, root: string, now: number) => {
  const read = await Promise.all(
    (await projectKeys(io, root)).map(key => readProject(io, root, key, now)),
  )

  return read.filter(each => each !== undefined)
}
