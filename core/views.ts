/**
 * What the board's views show, as data: a session in brief, a project with
 * its sessions, its asks, its log and what it parked, and every project,
 * the busiest first; and every project as the start of a conversation and
 * the CLI list them, those around the folder first.
 *
 * A session shows while it is current: open, holding something for Lee, or
 * updated lately, and not finished. An older idle one, or a finished
 * one, stays on disk, out of every view.
 */
import { nearestFirst, type Project } from './project'
import { isOpen, snoozedAsks } from './replies'
import { compareText } from './text'
import type { Ask, LogLine, Parked, Session } from './types'

/** How long an idle session (no window, nothing waiting or parked) stays in the views after its last update. */
export const CURRENT_MS = 7 * 24 * 60 * 60_000

/** How many of its latest log lines a brief carries: as many as any view of the board shows. */
export const BRIEF_LOG_LINES = 8

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
  updatedAt: number
}

/** A session as views beyond its own draw it: in brief, with its open asks, its latest log lines and what it parked. */
export type SessionBrief = SessionSummary & {
  /** Newest first. */
  log: LogLine[]
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
  parked: number
  updatedAt: number
}

/** All projects: this project first, then the busiest; `folded`, those with nothing open, waiting or parked, most recent first. */
export type AllProjects = {
  projects: ProjectSummary[]
  folded: ProjectSummary[]
}

/** A line of a project's log, and the session it came from. */
export type ProjectLogLine = LogLine & { session: string }

/** A parked item of a project's, and the session that parked it. */
export type ProjectParked = Parked & { session: string }

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

/** Whether a session or a project holds nothing that keeps it current but a window or its being recent: no ask waiting, nothing parked. */
export const isIdle = (counts: Pick<SessionSummary, 'asked' | 'parked'>) =>
  counts.asked === 0 && counts.parked === 0

/** A project folded into All projects' one line: no window, and idle. */
const isFolded = (project: ProjectSummary) => project.open === 0 && isIdle(project)

const total = (sessions: readonly SessionSummary[], count: (session: SessionSummary) => number) =>
  sessions.reduce((sum, session) => sum + count(session), 0)

/**
 * Whether a session shows in the views: not finished, and open, with an ask
 * waiting (on Lee, snoozed or not, or on a window to deliver Lee's answer),
 * holding something parked, or updated within `CURRENT_MS`.
 */
export const isCurrent = (session: SessionSummary, now: number) =>
  !session.isFinished &&
  (session.isOpen || !isIdle(session) || now - session.updatedAt <= CURRENT_MS)

/** The title of a session's item, by its id, as the views show it (a note's is its text); undefined where the session has none. */
export const itemTitle = (session: Session, id: string) => {
  const item = session.items.get(id)

  if (item === undefined) {
    return undefined
  }

  return item.type === 'note' ? item.text : item.title
}

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
  updatedAt: session.updatedAt,
})

/** The asks closed, those ignored aside, the newest closed first: what a session's Resolved lists. */
export const resolvedAsks = (session: Pick<Session, 'asks'>) =>
  session.asks
    .filter(ask => ask.state === 'closed')
    .sort((a, b) => (b.closedAt ?? b.at) - (a.closedAt ?? a.at))

export const brief = (session: Session): SessionBrief => ({
  ...summarise(session),
  log: session.log.slice(0, BRIEF_LOG_LINES),
  parkedItems: session.parked,
  asks: openAsks(session),
})

/** A project from its sessions, named as its most recently updated session names it. */
export const summariseProject = (
  key: string,
  sessions: readonly SessionSummary[],
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
    parked: total(summaries, session => session.parked),
    updatedAt: latest?.updatedAt ?? 0,
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
 * with its current sessions: those whose directory holds the folder first,
 * the nearest first, then the busiest, and those with nothing open, waiting
 * or parked last. A project with no current sessions is left out, but never
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
    const { name, directory } = project

    return current.length > 0 || kept.includes(project.key)
      ? [{ ...summariseProject(project.key, current), name, directory }]
      : []
  })
  const { projects, folded } = allProjects(summaries)

  return nearestFirst([...projects, ...folded], folder)
}

/** A project's log: every session's lines, newest first. */
export const projectLog = (sessions: readonly Pick<Session, 'id' | 'log'>[]): ProjectLogLine[] =>
  sessions
    .flatMap(session => session.log.map(line => ({ ...line, session: session.id })))
    .sort((a, b) => b.at - a.at || compareText(a.session, b.session))

/** What a project's sessions have parked, oldest first. */
export const projectParked = (sessions: readonly SessionBrief[]): ProjectParked[] =>
  sessions
    .flatMap(session => session.parkedItems.map(parked => ({ ...parked, session: session.id })))
    .sort((a, b) => a.at - b.at || compareText(a.session, b.session))
