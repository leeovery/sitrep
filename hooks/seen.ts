/**
 * What Claude has been told of the board. The board's text as Claude last
 * saw it is kept, so a turn is told of the board only once it moved on: a
 * change Claude did not make (another window's, Lee's, the CLI's) is never
 * taken as known. The text lists what the held session's project's other
 * sessions parked, as the look around last read them, so another session
 * parking or resolving something moves it on too.
 *
 * A look can rewrite what the sessions around parked at any moment, so what
 * is kept as seen is always the very text Claude was given, or the one its
 * own change made of the text it had seen, each built from one read of
 * them: never a text built again later, which could hold a change of
 * another's that Claude was never told.
 */
import {
  boardText,
  parkedBy,
  projectParked,
  type Body,
  type ProjectParked,
  type Session,
} from '../core'
import type { Host } from './host'
import { attached, post, refresh } from './window'

/** What heads the board's text where it rides into a turn. */
const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

/** What every session of the held session's project but the held one parked, as the look around last read it. */
export const parkedAround = async (host: Host): Promise<readonly ProjectParked[]> => {
  const key = attached()?.project

  return (await host.state.projects.read()).find(project => project.key === key)?.parked ?? []
}

/** The board as Claude has seen it, as it still stands: the held session, and what the sessions around parked, as one read gave them. */
export type Seen = { session: Session; parked: readonly ProjectParked[] }

/** The held session's board as Claude has seen it, where it still stands so; undefined once it moved on. */
const seenNow = async (host: Host, session: Session): Promise<Seen | undefined> => {
  const parked = await parkedAround(host)
  const text = await host.state.seen.read()

  return boardText(session, parked) === text ? { session, parked } : undefined
}

/** The held session's board as Claude has seen it, where it still stands so; undefined once it moved on, or with none held. */
export const seenHere = async (host: Host) => {
  const session = await refresh(host)

  return session === undefined ? undefined : seenNow(host, session)
}

/** Keeps `text` as the board Claude has seen. */
const keepSeen = (host: Host, text: string) => host.state.seen.write(text)

/** The held session's board, as Claude is given it now, kept as seen: the text. */
export const markSeen = async (host: Host, session: Session) => {
  const text = boardText(session, await parkedAround(host))

  await keepSeen(host, text)

  return text
}

/**
 * Keeps the board of a session Claude has just started as seen: what Claude
 * gave it, and none of what its project's other sessions parked, which
 * Claude has not been told, so it rides into the next turn.
 */
export const markStarted = (host: Host, session: Session) => keepSeen(host, boardText(session))

/**
 * Posts lines Claude knows of (its own, or replies it has just been sent):
 * the board counts as seen after them, unless it had already moved on from
 * what Claude last saw.
 */
export const postKnown = async (host: Host, session: Session, bodies: readonly Body[]) => {
  const seen = await seenNow(host, session)
  const after = await post(host, bodies)

  if (seen !== undefined && after !== undefined) {
    await keepSeen(host, boardText(after, seen.parked))
  }

  return after
}

/** A change Claude made to items another session of the held session's project parked: that session as it stands after it, and the items it changed. */
export type ChangedThere = { there: Session; items: readonly string[] }

/** What the sessions around parked, each changed item as the change left it, and nothing else of theirs changed. */
const changedIn = (parked: readonly ProjectParked[], { there, items }: ChangedThere) =>
  projectParked([
    ...parked.filter(each => each.session !== there.id || !items.includes(each.id)),
    ...parkedBy(there).filter(each => items.includes(each.id)),
  ])

/** Keeps as seen the board Claude had seen, `seen`, as its own changes to items other sessions parked made it. */
export const changedKnown = (host: Host, seen: Seen, changes: readonly ChangedThere[]) =>
  keepSeen(host, boardText(seen.session, changes.reduce(changedIn, seen.parked)))

/** The board's text as a turn takes it, when it moved on since Claude last saw it. */
export type BoardChange = { text: string; context: string }

/** The context a turn takes for the held session, when its board moved on since Claude last saw it; undefined when it did not. */
export const boardChange = async (host: Host): Promise<BoardChange | undefined> => {
  const session = await refresh(host)

  if (session === undefined) {
    return undefined
  }

  const text = boardText(session, await parkedAround(host))

  return text === (await host.state.seen.read())
    ? undefined
    : { text, context: `${CHANGED}\n${text}` }
}

/** Keeps the board a turn took as seen: the very text it was given. */
export const markTold = (host: Host, { text }: BoardChange) => keepSeen(host, text)
