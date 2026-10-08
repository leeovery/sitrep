/**
 * Reading sitrep's folder, as the CLI does at each run: where the folder is
 * and which project the CLI runs in, a piece of work found by its id, and
 * the works filed under each project.
 */
import {
  COMMON_DIR,
  foldWork,
  identityOf,
  isWorkId,
  LOG_SUFFIX,
  PRESENCE_SUFFIX,
  projectKeys,
  projectOf,
  projectsDir,
  rootOf,
  workPaths,
  worksDir,
  writerOf,
  type Project,
  type Work,
  type WorkFiles,
  type WorkPaths,
} from '../core'
import type { Io } from './io'
import type { ProjectRead } from './output'

/** Where the CLI stands: sitrep's folder, and the project of the folder it runs in. */
export type Place = { root: string; here: Project }

/** A piece of work as found: the project it is filed under, its paths and files, and the work they fold to. */
export type Found = { project: string; paths: WorkPaths; files: WorkFiles; work: Work }

/** The project is known as the mod knows it: by git's common dir, else the folder itself. */
export const placeOf = async (io: Io): Promise<Place> => ({
  root: rootOf(io.env),
  here: projectOf(identityOf(io.cwd, await io.run(COMMON_DIR, io.cwd).catch(() => undefined))),
})

const foldersIn = async (io: Io, dir: string) =>
  (await io.fs.list(dir)).filter(entry => entry.kind === 'dir').map(entry => entry.name)

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

/** A piece of work's files as they stand; work.json's text is empty while it is not there. */
export const readWork = async (io: Io, paths: WorkPaths): Promise<WorkFiles> => {
  const [meta, logs, inbox, presence] = await Promise.all([
    io.fs.read(paths.meta).catch(() => ''),
    byWriter(io, paths.dir, LOG_SUFFIX),
    byWriter(io, paths.inbox, LOG_SUFFIX),
    byWriter(io, paths.presence, PRESENCE_SUFFIX),
  ])

  return { meta, logs, inbox, presence }
}

/**
 * A piece of work by its id, as it stands at `now`: looked up in this
 * project first, then every other; undefined when none files it.
 */
export const findWork = async (
  io: Io,
  { root, here }: Place,
  id: string,
  now: number,
): Promise<Found | undefined> => {
  for (const project of projectKeys(here.key, await foldersIn(io, projectsDir(root)))) {
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

/** This project's works, or with `isAll` every project's, this one first. */
export const readProjects = async (
  io: Io,
  { root, here }: Place,
  isAll: boolean,
  now: number,
): Promise<ProjectRead[]> => {
  const keys = isAll ? projectKeys(here.key, await foldersIn(io, projectsDir(root))) : [here.key]

  return Promise.all(keys.map(async key => ({ key, works: await worksIn(io, root, key, now) })))
}
