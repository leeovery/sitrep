/**
 * Where a session's files are, and which project it is filed under, as the
 * mod reads them (core's filing.ts). Its files are in the folder of the
 * project it was started in, for good, which every ref the window keeps
 * names, and found by its id where one names another; it is filed under the
 * project its lines name now, resolved from its fold wherever that matters.
 */
import { fileSession, sessionPaths, type Filed, type Session } from '../core'
import type { SitrepSessionRef } from '../types'
import type { Host } from './host'
import { metaOf, projectKeys, readProject } from './projects'

/** The key of the folder a session's files are in, whichever project's it is; undefined when none holds it. */
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
 * folder `at` names, where the session's session.json reads there, else
 * whichever project's folder holds it; the one named where none does.
 */
export const folderOf = async (host: Host, root: string, at: SitrepSessionRef) =>
  (await metaOf(host, root, at.project, at.session)) === undefined
    ? ((await projectFiling(host, root, at.session)) ?? at.project)
    : at.project

/** A session's paths, its folder found by its id. */
export const pathsOf = async (host: Host, root: string, at: SitrepSessionRef) =>
  sessionPaths(root, await folderOf(host, root, at), at.session)

/** A ref to a session, naming the folder its files are in. */
export const inFolder = async <T extends SitrepSessionRef>(
  host: Host,
  root: string,
  at: T,
): Promise<T> => ({ ...at, project: await folderOf(host, root, at) })

/** A session as read in a project's folder: that project's key, and the session folded. */
export type InFolder = { folder: string; session: Session }

/** A session filed under its project, and the key of the folder its files are in. */
export type FiledIn = Filed & { folder: string }

/** The name the board gives a project, by its key, read once each for every session filed by the same reads; undefined for a key no project on the board has. */
export const projectNames = (host: Host, root: string) => {
  const names = new Map<string, Promise<string | undefined>>()

  return (key: string) => {
    const name = names.get(key) ?? readProject(host, root, key).then(read => read?.name)

    names.set(key, name)

    return name
  }
}

/**
 * A session read in its folder, filed as core's `fileSession` files it: of
 * the projects on the board, it needs the name of the one its latest move
 * names alone, which `nameOf` reads.
 */
export const fileIn =
  (nameOf: (key: string) => Promise<string | undefined>) =>
  async ({ folder, session }: InFolder): Promise<FiledIn> => {
    const { movedTo } = session
    const name = movedTo === undefined ? undefined : await nameOf(movedTo)

    return { folder, ...fileSession(folder, session, key => (key === movedTo ? name : undefined)) }
  }

/** A session read in its folder, filed. */
export const fileOne = (host: Host, root: string, found: InFolder) =>
  fileIn(projectNames(host, root))(found)
