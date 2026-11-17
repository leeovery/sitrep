/**
 * Which project a session is filed under (see "A session moves to another
 * project at Lee's word" in DESIGN.md). A session's folder is the one it was
 * started in, for good, and a move is a line in it naming another project
 * by its key. So it is filed under the project its latest move names, where
 * that project is on the board, else under its folder's; and it is named by
 * that project, as the board names it. Every reader, the mod's and the
 * CLI's, files each session it folds here.
 *
 * The two keys are kept apart by type alone (types/index.d.ts mirrors
 * them): the folder a session's files are in, which every ref the window
 * keeps names, and the project it is filed under, which the board's views
 * draw by. Filing is what makes the second of the first.
 */
import type { ProjectRead } from './feed'
import type { Session } from './types'

/** The key of the folder a session's files are in, which no move changes. Type-only. */
export type FolderKey = string & { readonly __folder: true }

/** The key of the project a session is filed under: its folder's, or the one its latest move names. Type-only. */
export type ProjectKey = string & { readonly __project: true }

/** A project folder's key, as the folder of each session found in it: where a reader lists the board's folders. */
export const folderKey = (key: string) => key as FolderKey

/** The project a session is filed under while no move of it is read: its folder's. */
export const projectOfFolder = (folder: FolderKey) => folder as string as ProjectKey

/** The name the board gives a project, by its key; undefined for a key no project on the board has. */
export type NameOf = (key: string) => string | undefined

/** The name the board gives a project, by its key, as a reader reads it; undefined for a key no project on the board has. */
export type ReadName = (key: string) => Promise<string | undefined>

/** A session, and the key of the project it is filed under. */
export type Filed = { project: ProjectKey; session: Session }

/**
 * A session read in the folder `folder` keys, filed: under the project its
 * latest move names, where `nameOf` names it as one on the board, and named
 * by it; else under its folder's, as read.
 */
export const fileSession = (folder: FolderKey, session: Session, nameOf: NameOf): Filed => {
  const key = session.movedTo
  const name = key === undefined || key === folder ? undefined : nameOf(key)

  if (key === undefined || name === undefined) {
    return { project: projectOfFolder(folder), session }
  }

  return {
    project: key as ProjectKey,
    session: session.project === name ? session : { ...session, project: name },
  }
}

/** A session read in its folder, filed by `fileSession`, of the projects on the board reading by `readName` the name of the one its latest move names alone. */
export const fileRead = async (
  folder: FolderKey,
  session: Session,
  readName: ReadName,
): Promise<Filed> => {
  const { movedTo } = session
  const name = movedTo === undefined || movedTo === folder ? undefined : await readName(movedTo)

  return fileSession(folder, session, key => (key === movedTo ? name : undefined))
}

/** The projects read, each with the sessions filed under it, from the sessions read in each one's folder. */
export const refiled = (read: readonly ProjectRead[]): ProjectRead[] => {
  const names = new Map(read.map(({ project }) => [project.key, project.name]))
  const filed = read.flatMap(({ project, sessions }) =>
    sessions.map(session => fileSession(folderKey(project.key), session, key => names.get(key))),
  )

  return read.map(({ project }) => ({
    project,
    sessions: filed.filter(each => each.project === project.key).map(each => each.session),
  }))
}
