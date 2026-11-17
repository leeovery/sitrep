/**
 * Which project a session is filed under, as the mod reads it: core's
 * filing.ts, of the projects on the board reading the name of the one a
 * session's latest move names alone. Where its files are is folders.ts's.
 */
import {
  fileRead,
  projectPaths,
  type Filed,
  type FolderKey,
  type ReadName,
  type Session,
} from '../core'
import type { Host } from './host'
import { projectOfText, readProject } from './projects'
import { textAt } from './reader'

/** A session as read in a project's folder: that folder's key, and the session folded. */
export type InFolder = { folder: FolderKey; session: Session }

/** A session filed under its project, and the key of the folder its files are in. */
export type FiledIn = Filed & { folder: FolderKey }

/** The name the board gives a project, by its key, read once each for every session filed by the same reads; undefined for a key no project on the board has. */
export const projectNames = (host: Host, root: string): ReadName => {
  const names = new Map<string, Promise<string | undefined>>()

  return key => {
    const name = names.get(key) ?? readProject(host, root, key).then(read => read?.name)

    names.set(key, name)

    return name
  }
}

/**
 * The names the board gives projects, each read again only once its
 * project's file's text changed: for the hold, which files its session at
 * each fold, every 1.5 seconds.
 */
export const namesKept = (host: Host, root: string): ReadName => {
  const names = new Map<string, { text: string | undefined; name: string | undefined }>()

  return async key => {
    const text = await textAt(host, projectPaths(root, key).file)
    const last = names.get(key)

    if (last !== undefined && last.text === text) {
      return last.name
    }

    const name = (await projectOfText(host, root, key, text))?.name

    names.set(key, { text, name })

    return name
  }
}

/** Sessions read in their folders, filed, each name read by `readName`. */
export const filingWith =
  (readName: ReadName) =>
  async ({ folder, session }: InFolder): Promise<FiledIn> => ({
    folder,
    ...(await fileRead(folder, session, readName)),
  })

/** A session read in its folder, filed. */
export const fileOne = (host: Host, root: string, found: InFolder) =>
  filingWith(projectNames(host, root))(found)
