/**
 * What the board's views show, as data: a session in brief, a project with
 * its sessions, its asks, the history of their status, what it parked and
 * what was taken off its Parked, and every project,
 * the busiest first; and every project as the start of a conversation and
 * the CLI list them, those around the folder first.
 *
 * A session shows while it is current: open, holding something for Lee, or
 * updated lately, and not finished. An older idle one, or a finished
 * one, stays on disk, out of every view. What a session parked is its
 * project's: it keeps no session current, and a project with something
 * parked shows though none of its sessions does.
 */
import { nearestFirst, type Project } from './project'
import { isOpen, snoozedAsks } from './replies'
import { compareText } from './text'
import type { Ask, Item, Parked, Reply, Session, StatusLine } from './types'

/** How long an idle session (no window, nothing waiting) stays in the views after its last update. */
export const CURRENT_MS = 7 * 24 * 60 * 60_000

/**
 * A session's asks still open, the oldest first, as `board --json` and
 * `watch` alike list them: waiting, on Lee or on a window to deliver Lee's
 * reply, or replied, Claude's to act on.
 */
export const openAsks = (session: Pick<Session, 'asks'>): Ask[] => session.asks.filter(isOpen)

/** A session in brief: what it is doing, and what it holds for Lee. */
export type SessionSummary = {
  id: string
  name: string
  summary: string
  /** The project's name. */
  project: string
  now: string[]
  next?: string
  isOpen: boolean
  /** Finished: out of every view, whatever it holds. */
  isFinished: boolean
  /** Asks waiting on Lee, those snoozed aside. */
  waiting: number
  /** Asks Lee snoozed, which wait on Lee again as they wake; none once the session is finished. */
  snoozed: number
  /**
   * Asks waiting as posted, none once the session is finished: those Lee's
   * reply is on its way to among them, which keep the session current as an
   * ask waiting on Lee does, and which Claude, not yet given the reply,
   * reads as waiting on Lee; and those snoozed, which keep it current too.
   */
  asked: number
  parked: number
  /** When it started. */
  created: number
  updatedAt: number
}

/** A session as views beyond its own draw it: in brief, with its open asks and what it parked. */
export type SessionBrief = SessionSummary & {
  /** Oldest first. */
  parkedItems: Parked[]
  /** The asks still open, oldest first. */
  asks: Ask[]
}

export type ProjectSummary = {
  key: string
  name: string
  /** Where the project lives, where that is known. */
  directory?: string
  /** Those with a window first, then the most recently updated. */
  sessions: SessionSummary[]
  /** How many sessions have a window. */
  open: number
  waiting: number
  snoozed: number
  /** Asks waiting as posted, as each session counts them: what keeps the project out of the folded line. */
  asked: number
  /** What is parked in the project, from every session filed under it, finished and idle ones included. */
  parked: number
  updatedAt: number
}

/** All projects: this project first, then the busiest; `folded`, those with nothing open, waiting or parked, most recent first. */
export type AllProjects = {
  projects: ProjectSummary[]
  folded: ProjectSummary[]
}

/** A change of status in a project's history, and the session it came from. */
export type ProjectStatusLine = StatusLine & { session: string }

/** A parked item of a project's, and the session that parked it: its id, and its name. */
export type ProjectParked = Parked & { session: string; name: string }

type Dated = { updatedAt: number }

const byRecency = (a: Dated, b: Dated) => b.updatedAt - a.updatedAt

const openFirst = (a: SessionSummary, b: SessionSummary) =>
  Number(b.isOpen) - Number(a.isOpen) || byRecency(a, b) || compareText(a.id, b.id)

const busiest = (a: ProjectSummary, b: ProjectSummary) =>
  b.waiting - a.waiting ||
  b.open - a.open ||
  b.parked - a.parked ||
  byRecency(a, b) ||
  compareText(a.name, b.name)

/** Whether a session or a project holds nothing that keeps it current but a window or its being recent: no ask waiting. */
export const isIdle = (counts: Pick<SessionSummary, 'asked'>) => counts.asked === 0

/** A project folded into All projects' one line: no window, idle, and nothing parked in it. */
const isFolded = (project: ProjectSummary) =>
  project.open === 0 && isIdle(project) && project.parked === 0

const total = (sessions: readonly SessionSummary[], count: (session: SessionSummary) => number) =>
  sessions.reduce((sum, session) => sum + count(session), 0)

/**
 * Whether a session shows in the views: not finished, and open, with an ask
 * waiting (on Lee, snoozed or not, or on a window to deliver Lee's answer),
 * or updated within `CURRENT_MS`.
 */
export const isCurrent = (session: SessionSummary, now: number) =>
  !session.isFinished &&
  (session.isOpen || !isIdle(session) || now - session.updatedAt <= CURRENT_MS)

/** The title of a session's item, by its id; undefined where the session has none. */
export const itemTitle = (session: Session, id: string) => session.items.get(id)?.title

export const summarise = (session: Session): SessionSummary => ({
  id: session.id,
  name: session.status.name,
  summary: session.status.summary,
  project: session.project,
  now: session.status.now,
  next: session.status.next,
  isOpen: session.isOpen,
  isFinished: session.finished !== undefined,
  waiting: session.waiting,
  snoozed: snoozedAsks(session).length,
  asked:
    session.finished === undefined ? session.asks.filter(ask => ask.state === 'waiting').length : 0,
  parked: session.parked.length,
  created: session.created,
  updatedAt: session.updatedAt,
})

/** The asks closed, those ignored aside, the newest closed first: what a session's Resolved lists. */
export const resolvedAsks = (session: Pick<Session, 'asks'>) =>
  session.asks
    .filter(ask => ask.state === 'closed')
    .sort((a, b) => (b.closedAt ?? b.at) - (a.closedAt ?? a.at))

export const brief = (session: Session): SessionBrief => ({
  ...summarise(session),
  parkedItems: session.parked,
  asks: openAsks(session),
})

/**
 * What is parked in a project, from every session filed under it: how many
 * items, and the latest time among the sessions holding them, as the time
 * rule leaves it, which dates a project none of whose sessions is current;
 * 0 where it is not known.
 */
export type Parking = { parked: number; updatedAt: number }

export const NOTHING_PARKED: Parking = { parked: 0, updatedAt: 0 }

/** What the sessions filed under a project, finished and idle ones included, hold parked. */
export const parkingOf = (sessions: readonly SessionSummary[]): Parking => {
  const holding = sessions.filter(session => session.parked > 0)

  return {
    parked: total(holding, session => session.parked),
    updatedAt: Math.max(0, ...holding.map(session => session.updatedAt)),
  }
}

/**
 * A project from its current sessions, named as its most recently updated
 * one names it, and what is parked in it: updated when its latest current
 * session was, else as what is parked dates it.
 */
export const summariseProject = (
  key: string,
  sessions: readonly SessionSummary[],
  parking: Parking = NOTHING_PARKED,
): ProjectSummary => {
  const summaries = [...sessions].sort(openFirst)
  const latest = [...sessions].sort(byRecency).at(0)

  return {
    key,
    name: latest?.project ?? key,
    sessions: summaries,
    open: summaries.filter(session => session.isOpen).length,
    waiting: total(summaries, session => session.waiting),
    snoozed: total(summaries, session => session.snoozed),
    asked: total(summaries, session => session.asked),
    parked: parking.parked,
    updatedAt: latest?.updatedAt ?? parking.updatedAt,
  }
}

/** The All projects view: `here`, the project this window works in, always first and never folded. */
export const allProjects = (projects: readonly ProjectSummary[], here?: string): AllProjects => {
  const others = projects.filter(project => project.key !== here)

  return {
    projects: [
      ...projects.filter(project => project.key === here),
      ...others.filter(project => !isFolded(project)).sort(busiest),
    ],
    folded: others.filter(isFolded).sort((a, b) => byRecency(a, b) || compareText(a.name, b.name)),
  }
}

/** A project as a front end reads it, and its sessions in brief. */
export type ProjectSessions = { project: Project; sessions: readonly SessionSummary[] }

/**
 * The projects as the start of a conversation and the CLI list them, each
 * with its current sessions, and counting what is parked in it from every
 * session: those whose directory holds the folder first, the nearest first,
 * then the busiest, and those with nothing open, waiting or parked last. A
 * project with no current sessions and nothing parked is left out, but never
 * one `kept` names.
 */
export const listedProjects = (
  read: readonly ProjectSessions[],
  folder: string,
  now: number,
  kept: readonly string[] = [],
): ProjectSummary[] => {
  const summaries = read.flatMap(({ project, sessions }) => {
    const current = sessions.filter(session => isCurrent(session, now))
    const parking = parkingOf(sessions)
    const { name, directory } = project

    return current.length > 0 || parking.parked > 0 || kept.includes(project.key)
      ? [{ ...summariseProject(project.key, current, parking), name, directory }]
      : []
  })
  const { projects, folded } = allProjects(summaries)

  return nearestFirst([...projects, ...folded], folder)
}

/** Every change of a session's status, each naming the session by its id. */
export const changedBy = (session: Pick<Session, 'id' | 'history'>): ProjectStatusLine[] =>
  session.history.map(line => ({ ...line, session: session.id }))

/** A project's history, from whichever of its sessions each change came from, the newest first. */
export const projectHistory = (lines: readonly ProjectStatusLine[]): ProjectStatusLine[] =>
  [...lines].sort((a, b) => b.at - a.at || compareText(a.session, b.session))

/** What a session parked, each item naming the session by its id and its name. */
export const parkedBy = (session: Pick<Session, 'id' | 'status' | 'parked'>): ProjectParked[] =>
  session.parked.map(parked => ({ ...parked, session: session.id, name: session.status.name }))

/** A project's parked items, from whichever of its sessions parked each, the oldest first. */
export const projectParked = (parked: readonly ProjectParked[]): ProjectParked[] =>
  [...parked].sort((a, b) => a.at - b.at || compareText(a.session, b.session))

/** Whether an item was parked and taken off Parked since: picked up by Lee, or closed by Claude. */
const isTakenOff = (item: Item): item is Parked => item.type === 'park' && item.state !== 'parked'

/** When an item taken off Parked was taken off. */
const takenAt = (parked: Parked) => parked.closedAt ?? parked.at

/** What was taken off a session's Parked, the newest taken off first. */
export const takenOff = (session: Pick<Session, 'items'>): Parked[] =>
  [...session.items.values()]
    .filter(isTakenOff)
    .sort((a, b) => takenAt(b) - takenAt(a) || compareText(a.id, b.id))

/** What was taken off a session's Parked, each item naming the session by its id and its name. */
export const takenOffBy = (session: Pick<Session, 'id' | 'status' | 'items'>): ProjectParked[] =>
  takenOff(session).map(parked => ({ ...parked, session: session.id, name: session.status.name }))

/** What was taken off a project's Parked, from whichever of its sessions parked each, the newest taken off first. */
export const projectTakenOff = (taken: readonly ProjectParked[]): ProjectParked[] =>
  [...taken].sort((a, b) => takenAt(b) - takenAt(a) || compareText(a.session, b.session))

/** A window's hold on a session, as its heartbeat there says: the window, when it attached, and the session, by its id and its name. */
export type Hold = { writer: string; attachedAt: number; session: string; name: string }

/** Every window's hold on a session, by the heartbeats it keeps, those of windows long gone among them. */
export const holdsOf = (session: Pick<Session, 'id' | 'status' | 'presence'>): Hold[] =>
  session.presence.map(({ writer, attachedAt }) => ({
    writer,
    attachedAt,
    session: session.id,
    name: session.status.name,
  }))

/**
 * The name of the session a pick-up went to: the window that wrote it held
 * one session as it did, so of those `holds` names, the one that window
 * attached to last by the pick-up's time. Undefined where none is known: a
 * window that joined the session again since rewrote its heartbeat there.
 */
export const pickedUpBy = (holds: readonly Hold[], { by, at }: Pick<Reply, 'by' | 'at'>) =>
  holds
    .filter(hold => hold.writer === by && hold.attachedAt <= at)
    .sort((a, b) => b.attachedAt - a.attachedAt)
    .at(0)?.name
