/**
 * Which project a session is filed under (see "A session moves to another
 * project at Lee's word" in DESIGN.md). A session's folder is the one it was
 * started in, for good, and a move is a line in it naming another project
 * by its key. So it is filed under the project its latest move names, where
 * that project is on the board, else under its folder's; and it is named by
 * that project, as the board names it. Every reader, the mod's and the
 * CLI's, files each session it folds by `fileSession`.
 */
import type { ProjectRead } from './feed'
import type { Session } from './types'

/** The name the board gives a project, by its key; undefined for a key no project on the board has. */
export type NameOf = (key: string) => string | undefined

/** A session, and the key of the project it is filed under. */
export type Filed = { project: string; session: Session }

/**
 * A session read in the folder of the project `folder` keys, filed: under
 * the project its latest move names, where `nameOf` names it as one on the
 * board, and named by it; else under its folder, as read.
 */
export const fileSession = (folder: string, session: Session, nameOf: NameOf): Filed => {
  const key = session.movedTo
  const name = key === undefined || key === folder ? undefined : nameOf(key)

  if (key === undefined || name === undefined) {
    return { project: folder, session }
  }

  return {
    project: key,
    session: session.project === name ? session : { ...session, project: name },
  }
}

/** The projects read, each with the sessions filed under it, from the sessions read in each one's folder. */
export const refiled = (read: readonly ProjectRead[]): ProjectRead[] => {
  const names = new Map(read.map(({ project }) => [project.key, project.name]))
  const filed = read.flatMap(({ project, sessions }) =>
    sessions.map(session => fileSession(project.key, session, key => names.get(key))),
  )

  return read.map(({ project }) => ({
    project,
    sessions: filed.filter(each => each.project === project.key).map(each => each.session),
  }))
}
