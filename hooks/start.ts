/**
 * The start of a conversation. Resumed, in a new process (`$.state` empty,
 * Claude Code's session id the same) or by `/resume` in this one, the
 * window takes up by itself the session it was last seen in, whichever
 * project it is filed under. And Claude's first message carries every
 * project's current sessions with their ids, so "let's carry on with the
 * dashboard" finds the one to join, and says which this window already
 * holds. The folder the window started in only orders them: the projects
 * living around it first.
 */
import { listedProjects, rejoinable, startText, summarise, type ProjectSessions } from '../core'
import { sessionsIn } from './around'
import { bearingsOf, rootFor, type Host } from './host'
import { projectKeys, readProject } from './projects'
import type { Filed } from './scene'
import { attached, attachTo } from './window'

/** Every session filed, in every project, as it stands at `now`. */
const everySession = async (host: Host, root: string, now: number): Promise<Filed[]> => {
  const filed = await Promise.all(
    (await projectKeys(host, root)).map(async project =>
      (await sessionsIn(host, root, project, now)).map(session => ({ project, session })),
    ),
  )

  return filed.flat()
}

/** Takes up again the session the conversation `writer` names was last seen in, in any project, when the window holds none. */
export const rejoin = async (host: Host, writer: string) => {
  if (attached() !== undefined) {
    return
  }

  const root = await rootFor(host)
  const now = await host.clock.now()
  const filed = await everySession(host, root, now)
  const id = rejoinable(
    filed.map(({ session }) => session),
    writer,
  )
  const last = filed.find(({ session }) => session.id === id)

  if (last !== undefined) {
    await attachTo(host, root, {
      project: last.project,
      session: last.session.id,
      writer,
      attachedAt: now,
    })
  }
}

/** A project, with its sessions in brief as they stand at `now`; undefined for a folder with no project in it. */
const projectSessions = async (
  host: Host,
  root: string,
  key: string,
  now: number,
): Promise<ProjectSessions | undefined> => {
  const project = await readProject(host, root, key)

  if (project === undefined) {
    return undefined
  }

  return { project, sessions: (await sessionsIn(host, root, key, now)).map(summarise) }
}

/** What the conversation's first message carries of sitrep: how to keep the board, and every project's current sessions. */
export const startListing = async (host: Host) => {
  const { root, cwd } = await bearingsOf(host)
  const now = await host.clock.now()
  const keys = await projectKeys(host, root)
  const read = await Promise.all(keys.map(key => projectSessions(host, root, key, now)))
  const projects = listedProjects(
    read.filter(each => each !== undefined),
    cwd,
    now,
  )
  const held = attached()?.session

  return startText(
    projects,
    projects.flatMap(({ sessions }) => sessions).find(session => session.id === held),
  )
}
