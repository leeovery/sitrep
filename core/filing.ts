/**
 * Which project a session is filed under (see "A session moves to another
 * project at Lee's word" in DESIGN.md). A session's folder is the one it was
 * started in, for good, and a move is a line in it naming another project
 * by its key. So its project is the one its latest move names, where that
 * project's folder is on the board, else its folder's; and it is named by
 * that project, as the board names it. Every reader files each session it
 * folds by this, once it has folded it.
 */
import type { ProjectRead } from './feed'
import type { Session } from './types'

/** The key of the project a session whose folder is under `folder` is filed under, `isOnBoard` saying whether a project's folder is there. */
export const filedUnder = (
  folder: string,
  { movedTo }: Pick<Session, 'movedTo'>,
  isOnBoard: (key: string) => boolean,
) => (movedTo !== undefined && isOnBoard(movedTo) ? movedTo : folder)

/** A session named by the project it is filed under, as the board names that project. */
export const filedAs = (session: Session, name: string): Session =>
  session.project === name ? session : { ...session, project: name }

/**
 * The projects read, each with the sessions filed under it, from the
 * sessions read under their folders' projects: one moved to another project
 * read goes there, named by it.
 */
export const refiled = (read: readonly ProjectRead[]): ProjectRead[] => {
  const keys = new Set(read.map(({ project }) => project.key))
  const isOnBoard = (key: string) => keys.has(key)
  const filed = read.flatMap(({ project, sessions }) =>
    sessions.map(session => ({
      folder: project.key,
      key: filedUnder(project.key, session, isOnBoard),
      session,
    })),
  )

  return read.map(({ project }) => ({
    project,
    sessions: filed
      .filter(({ key }) => key === project.key)
      .map(({ folder, session }) =>
        folder === project.key ? session : filedAs(session, project.name),
      ),
  }))
}
