/**
 * A project: what Claude names it as it starts a piece of work, the name as
 * Lee would say it, and where it lives. Its file, `project.json` in its
 * folder, is rewritten only as the project is made, renamed or given a
 * directory. A folder from before projects were named has none: it is named
 * as its works recorded it, its first letter a capital.
 *
 * Two names are one project's when their letters and digits match, case
 * aside: `Sitrep` and `Sit Rep` are SitRep's.
 */
import { VERSION } from './entries'
import type { WorkMeta } from './meta'

/** A project's file: its name and directory, and when and by whom it was first written. */
export type ProjectFile = {
  name: string
  /** Where the project lives: an absolute path. */
  directory?: string
  created: number
  by: string
}

/** A project as the front ends know it: its folder's key, its name, and where it lives. */
export type Project = {
  /** The project's folder: a new project's name as a slug. */
  key: string
  name: string
  directory?: string
}

/** The longest slug a new key keeps. */
const SLUG_LENGTH = 32

/** The slug for a name with no letters or digits that a folder name keeps. */
const NAMELESS = 'project'

/** A name as a folder-safe slug, its accents dropped from the letters they sit on. */
const slug = (name: string) =>
  name
    .normalize('NFKD')
    .replace(/\p{M}+/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .slice(0, SLUG_LENGTH)
    .replace(/^-+|-+$/g, '') || NAMELESS

/** What a name is matched by: its letters and digits, accents kept, case aside. */
const matchOf = (name: string) =>
  name
    .normalize('NFC')
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, '')

/** Whether a name has anything to match by: a letter or a digit. */
export const isNameable = (name: string) => matchOf(name) !== ''

/** Whether two names name one project. */
export const isSameName = (a: string, b: string) => matchOf(a) === matchOf(b)

/** The project of those given that a name names; undefined for none. */
export const projectNamed = <T extends Pick<Project, 'name'>>(
  projects: readonly T[],
  name: string,
) => projects.find(project => isSameName(project.name, name))

/** A new project's key: its name as a slug, numbered on where a folder already has it. */
export const newProjectKey = (name: string, taken: ReadonlySet<string>) => {
  const base = slug(name)

  for (let count = 2, key = base; ; key = `${base}-${count++}`) {
    if (!taken.has(key)) {
      return key
    }
  }
}

/** A name as a folder from before projects were named shows it: its first letter a capital. */
const capitalised = (name: string) => name.charAt(0).toUpperCase() + name.slice(1)

/**
 * The name a folder from before projects were named goes by, as its works
 * recorded it: the first of them whose work.json reads, in the order listed.
 */
export const recordedName = (metas: readonly (Pick<WorkMeta, 'project'> | undefined)[]) =>
  metas.find(meta => meta !== undefined)?.project

/** A project's name: its file's, else the name its works recorded, first letter a capital. */
export const projectName = (file: ProjectFile | undefined, recorded: string) =>
  file?.name ?? capitalised(recorded)

/**
 * A project as its folder has it: its file's name and directory, else the
 * name its works recorded, first letter a capital; undefined when neither
 * says (a folder with no file and no work).
 */
export const projectFrom = (
  key: string,
  file: ProjectFile | undefined,
  named: string | undefined,
): Project | undefined => {
  if (file !== undefined) {
    return { key, name: file.name, directory: file.directory }
  }

  return named === undefined ? undefined : { key, name: capitalised(named) }
}

export const projectText = (file: ProjectFile) => `${JSON.stringify({ v: VERSION, ...file })}\n`

/** A project's file; undefined when it is torn, bad or of another version. */
export const parseProject = (text: string): ProjectFile | undefined => {
  let raw: { [key: string]: unknown }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const { v, name, directory, created, by } = raw
  const isWhole =
    v === VERSION &&
    typeof name === 'string' &&
    (directory === undefined || typeof directory === 'string') &&
    typeof created === 'number' &&
    typeof by === 'string'

  return isWhole ? { name, directory, created, by } : undefined
}

/** A path without the slashes after it; `/` stays itself. */
export const directoryOf = (path: string) => path.replace(/\/+$/, '') || '/'

/** Whether a directory holds a folder: is it, or is above it. */
const holds = (directory: string, folder: string) =>
  folder === directory || folder.startsWith(directory === '/' ? '/' : `${directory}/`)

/** How near a project lives to a folder: its directory's length when it holds the folder, else -1. */
const nearness = (project: Pick<Project, 'directory'>, folder: string) =>
  project.directory !== undefined && holds(project.directory, directoryOf(folder))
    ? project.directory.length
    : -1

/** Projects in the order given, but those whose directory holds the folder first, the nearest first. */
export const nearestFirst = <T extends Pick<Project, 'directory'>>(
  projects: readonly T[],
  folder: string,
) => [...projects].sort((a, b) => nearness(b, folder) - nearness(a, folder))

/** The project a folder is in: the nearest whose directory holds it; undefined for none. */
export const projectAround = <T extends Pick<Project, 'directory'>>(
  projects: readonly T[],
  folder: string,
) => {
  const nearest = nearestFirst(projects, folder).at(0)

  return nearest !== undefined && nearness(nearest, folder) >= 0 ? nearest : undefined
}
