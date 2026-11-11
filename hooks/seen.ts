/**
 * What Claude has been told of the board. The board's text as Claude last
 * saw it is kept, so a turn is told of the board only once it moved on: a
 * change Claude did not make (another window's, Lee's, the CLI's) is never
 * taken as known. The text lists what the held session's project's other
 * sessions parked, as the look around last read them, so another session
 * parking or resolving something moves it on too.
 */
import { boardText, type Body, type Session } from '../core'
import type { Host } from './host'
import { attached, post, refresh } from './window'

/** What heads the board's text where it rides into a turn. */
const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

/** What every session of the held session's project but the held one parked, as the look around last read it. */
const parkedAround = async (host: Host) => {
  const key = attached()?.project

  return (await host.state.projects.read()).find(project => project.key === key)?.parked ?? []
}

/** The held session's board as Claude reads it: its own items, and what its project's other sessions parked. */
export const boardTextOf = async (host: Host, session: Session) =>
  boardText(session, await parkedAround(host))

/** Marks the session's board as Claude now knows it, Claude having read it or made it so; gives its text. */
export const markSeen = async (host: Host, session: Session) => {
  const text = await boardTextOf(host, session)

  await host.state.seen.write(text)

  return text
}

/** Whether Claude knows the board as it stands. */
const isSeen = async (host: Host, session: Session) =>
  (await boardTextOf(host, session)) === (await host.state.seen.read())

/**
 * Posts lines Claude knows of (its own, or replies it has just been sent):
 * the board counts as seen after them, unless it had already moved on from
 * what Claude last saw.
 */
export const postKnown = async (host: Host, session: Session, bodies: readonly Body[]) => {
  const wasSeen = await isSeen(host, session)
  const after = await post(host, bodies)

  if (wasSeen && after !== undefined) {
    await markSeen(host, after)
  }

  return after
}

/**
 * Makes a change Claude knows of beyond the held session, as its act on a
 * parked item another session of its project parked: the board counts as
 * seen after it, unless it had already moved on from what Claude last saw.
 */
export const changeKnown = async <T>(host: Host, change: () => Promise<T>) => {
  const before = await refresh(host)
  const wasSeen = before !== undefined && (await isSeen(host, before))
  const changed = await change()
  const after = await refresh(host)

  if (wasSeen && after !== undefined) {
    await markSeen(host, after)
  }

  return changed
}

/**
 * The held session as it stands, and the context a turn takes for it, when
 * its board moved on since Claude last saw it; undefined when it did not.
 */
export const boardChange = async (host: Host) => {
  const session = await refresh(host)

  if (session === undefined) {
    return undefined
  }

  const text = await boardTextOf(host, session)

  return text === (await host.state.seen.read())
    ? undefined
    : { session, context: `${CHANGED}\n${text}` }
}
