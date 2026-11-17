/**
 * Where a session's files are: in the folder of the project it was started
 * in, for good, which every ref the window keeps names (a `FolderKey`). A
 * ref a view drew names the project it showed the session in (a
 * `ProjectKey`); the folder is found here, by the session's id, and only
 * here is a kept ref made of a drawn one.
 */
import { folderKey, sessionPaths, type FolderKey } from '../core'
import type { SessionKey, SitrepSessionRef } from '../types'
import type { Host } from './host'
import { metaOf, projectKeys } from './projects'

/** A ref as the window keeps it: naming the folder its session's files are in. */
export type InItsFolder<T extends SitrepSessionRef<SessionKey>> = Omit<T, 'project'> & {
  project: FolderKey
}

/** The key of every project folder on the board, as the folder of each session in it. */
export const folderKeys = async (host: Host, root: string) =>
  (await projectKeys(host, root)).map(folderKey)

/** The key of the folder holding a session, by its id, whichever project's it is; undefined when none holds it. */
export const folderHolding = async (host: Host, root: string, id: string) => {
  for (const key of await projectKeys(host, root)) {
    if ((await metaOf(host, root, key, id)) !== undefined) {
      return folderKey(key)
    }
  }

  return undefined
}

/**
 * The key of the folder a session's files are in, found by its id: the
 * folder `at` names, where the session's session.json reads there, else
 * whichever project's folder holds it; the one named where none does.
 */
export const folderOf = async (
  host: Host,
  root: string,
  at: SitrepSessionRef<SessionKey>,
): Promise<FolderKey> =>
  (await metaOf(host, root, at.project, at.session)) === undefined
    ? ((await folderHolding(host, root, at.session)) ?? folderKey(at.project))
    : folderKey(at.project)

/** A session's paths, its folder found by its id. */
export const pathsOf = async (host: Host, root: string, at: SitrepSessionRef<SessionKey>) =>
  sessionPaths(root, await folderOf(host, root, at), at.session)

/** A ref to a session, by either kind of key, as the window keeps it: naming the folder its files are in. */
export const inFolder = async <T extends SitrepSessionRef<SessionKey>>(
  host: Host,
  root: string,
  at: T,
): Promise<InItsFolder<T>> => ({ ...at, project: await folderOf(host, root, at) })
