/**
 * The start of a conversation. Resumed, in a new process (`$.state` empty,
 * the session id the same) or by `/resume` in this one, the window takes up
 * by itself the work it was last seen in. And Claude's first message
 * carries the project's current pieces of work with their ids, so "let's
 * carry on with the dashboard" finds the one to join, and says which this
 * window already holds.
 */
import { isCurrent, rejoinable, startText, summarise, summariseProject } from '../core'
import { worksIn } from './around'
import { bearingsOf, type Host } from './host'
import { attached, attachTo } from './window'

/** Takes up again the work of this project the conversation `writer` names was last seen in, when the window holds none. */
export const rejoin = async (host: Host, writer: string) => {
  if (attached() !== undefined) {
    return
  }

  const { root, project } = await bearingsOf(host)
  const now = await host.clock.now()
  const work = rejoinable(await worksIn(host, root, project.key, now), writer)

  if (work !== undefined) {
    await attachTo(host, root, { project: project.key, work, writer, attachedAt: now })
  }
}

/** What the session's first message carries of sitrep: how to keep the board, and the project's current pieces of work. */
export const startListing = async (host: Host) => {
  const { root, project } = await bearingsOf(host)
  const now = await host.clock.now()
  const current = (await worksIn(host, root, project.key, now))
    .map(summarise)
    .filter(work => isCurrent(work, now))
  const { works } = summariseProject(project.key, current)

  return startText(
    works,
    works.find(work => work.id === attached()?.work),
  )
}
