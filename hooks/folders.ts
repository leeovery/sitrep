/**
 * Where a session's files are: in the folder of the project it was started
 * in, for good, which every ref the window keeps names (a `FolderKey`). A
 * ref a view drew names the project it showed the session in (a
 * `ProjectKey`); the folder is found here, by the session's id, and only
 * here is a kept ref made of a drawn one.
 */
import { folderKey, type FolderKey } from '../core'
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

/**
 * The key of the folder holding a session, by its id, whichever project's
 * it is: the one whose session.json of it reads, `first` tried first;
 * undefined when none does.
 */
export const folderHolding = async (host: Host, root: string, id: string, first?: string) => {
  const keys = await folderKeys(host, root)
  const tried = [...keys.filter(key => key === first), ...keys.filter(key => key !== first)]

  for (const key of tried) {
    if ((await metaOf(host, root, key, id)) !== undefined) {
      return key
    }
  }

  return undefined
}

/**
 * A ref to a session, by either kind of key, as the window keeps it: naming
 * the folder its files are in, found by its id, the one `at` names tried
 * first, as an unmoved session's folder is its project's; undefined when no
 * folder's session.json of it reads.
 */
export const inFolder = async <T extends SitrepSessionRef<SessionKey>>(
  host: Host,
  root: string,
  at: T,
): Promise<InItsFolder<T> | undefined> => {
  const folder = await folderHolding(host, root, at.session, at.project)

  return folder === undefined ? undefined : { ...at, project: folder }
}
