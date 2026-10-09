/**
 * The start of a conversation. Resumed, in a new process (`$.state` empty,
 * the session id the same) or by `/resume` in this one, the window takes up
 * by itself the work it was last seen in, whichever project it is filed
 * under. And Claude's first message carries every project's current pieces
 * of work with their ids, so "let's carry on with the dashboard" finds the
 * one to join, and says which this window already holds. The folder the
 * session started in only orders them: the projects living around it first.
 */
import { listedProjects, rejoinable, startText, summarise, type ProjectWorks } from '../core'
import { worksIn } from './around'
import { bearingsOf, rootFor, type Host } from './host'
import { projectKeys, readProject } from './projects'
import type { Filed } from './scene'
import { attached, attachTo } from './window'

/** Every work filed, in every project, as it stands at `now`. */
const everyWork = async (host: Host, root: string, now: number): Promise<Filed[]> => {
  const filed = await Promise.all(
    (await projectKeys(host, root)).map(async project =>
      (await worksIn(host, root, project, now)).map(work => ({ project, work })),
    ),
  )

  return filed.flat()
}

/** Takes up again the work the conversation `writer` names was last seen in, in any project, when the window holds none. */
export const rejoin = async (host: Host, writer: string) => {
  if (attached() !== undefined) {
    return
  }

  const root = await rootFor(host)
  const now = await host.clock.now()
  const filed = await everyWork(host, root, now)
  const id = rejoinable(
    filed.map(({ work }) => work),
    writer,
  )
  const last = filed.find(({ work }) => work.id === id)

  if (last !== undefined) {
    await attachTo(host, root, {
      project: last.project,
      work: last.work.id,
      writer,
      attachedAt: now,
    })
  }
}

/** A project, with its works in brief as they stand at `now`; undefined for a folder with no project in it. */
const projectWorks = async (
  host: Host,
  root: string,
  key: string,
  now: number,
): Promise<ProjectWorks | undefined> => {
  const project = await readProject(host, root, key)

  if (project === undefined) {
    return undefined
  }

  return { project, works: (await worksIn(host, root, key, now)).map(summarise) }
}

/** What the session's first message carries of sitrep: how to keep the board, and every project's current pieces of work. */
export const startListing = async (host: Host) => {
  const { root, cwd } = await bearingsOf(host)
  const now = await host.clock.now()
  const keys = await projectKeys(host, root)
  const read = await Promise.all(keys.map(key => projectWorks(host, root, key, now)))
  const projects = listedProjects(
    read.filter(each => each !== undefined),
    cwd,
    now,
  )
  const held = attached()?.work

  return startText(
    projects,
    projects.flatMap(({ works }) => works).find(work => work.id === held),
  )
}
