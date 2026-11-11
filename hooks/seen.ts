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

/** What the sessions around parked, as one read gave them, where Claude has seen the held session's board as it stands so; undefined once it moved on. */
const seenNow = async (host: Host, session: Session) => {
  const parked = await parkedAround(host)
  const text = await host.state.seen.read()

  return boardText(session, parked) === text ? parked : undefined
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
  const parked = await seenNow(host, session)
  const after = await post(host, bodies)

  if (parked !== undefined && after !== undefined) {
    await keepSeen(host, boardText(after, parked))
  }

  return after
}

/** A change Claude made to items another session of the held session's project parked: that session as it stood before it, and the items it changed. */
export type ChangedThere = { before: Session; items: readonly string[] }

/**
 * What the sessions around parked, each changed item as it was before the
 * change, in its place among its session's, and the rest as they stand.
 */
const asBefore = (parked: readonly ProjectParked[], { before, items }: ChangedThere) => {
  const isThere = (item: ProjectParked) => item.session === before.id
  const isChanged = (item: ProjectParked) => items.includes(item.id)
  const standing = parked.filter(isThere)
  const was = parkedBy(before)
  const isNew = (item: ProjectParked) => !was.some(({ id }) => id === item.id)
  const there = [
    ...was.flatMap(item =>
      isChanged(item) ? [item] : standing.filter(({ id }) => id === item.id),
    ),
    ...standing.filter(item => !isChanged(item) && isNew(item)),
  ]

  return projectParked([...parked.filter(item => !isThere(item)), ...there])
}

/**
 * Keeps the board as it now stands as seen, after Claude's own changes to
 * items other sessions of the project parked, where Claude had seen it as
 * it stands but for them: each changed item as it was before. Run in the
 * window's queue, after the look that read the changes in, so no post of
 * Claude's lands between the reads and the keep, and a prompt meanwhile
 * finds the board it had seen; read, compared and kept with no wait between
 * the compare and the keep.
 */
export const changedKnown = async (host: Host, changes: readonly ChangedThere[]) => {
  const session = changes.length === 0 ? undefined : await refresh(host)

  if (session === undefined) {
    return
  }

  const [parked, seen] = await Promise.all([parkedAround(host), host.state.seen.read()])

  if (boardText(session, changes.reduce(asBefore, parked)) === seen) {
    await keepSeen(host, boardText(session, parked))
  }
}

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
