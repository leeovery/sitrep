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
import { isOpen } from './replies'
import { compareText } from './text'
import type { Ask, LogLine, Parked, Session } from './types'

/** How long an idle session (no window, nothing waiting or parked) stays in the views after its last update. */
export const CURRENT_MS = 7 * 24 * 60 * 60_000

/** How many of its latest log lines a brief carries: as many as any view of the board shows. */
export const BRIEF_LOG_LINES = 8

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
  waiting: number
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

const isIdle = (project: ProjectSummary) =>
  project.open === 0 && project.waiting === 0 && project.parked === 0

const total = (sessions: readonly SessionSummary[], count: (session: SessionSummary) => number) =>
  sessions.reduce((sum, session) => sum + count(session), 0)

/** Whether a session shows in the views: not finished, and open, waiting on Lee, holding something parked, or updated within `CURRENT_MS`. */
export const isCurrent = (session: SessionSummary, now: number) =>
  !session.isFinished &&
  (session.isOpen ||
    session.waiting > 0 ||
    session.parked > 0 ||
    now - session.updatedAt <= CURRENT_MS)

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
  parked: session.parked.length,
  updatedAt: session.updatedAt,
})

export const brief = (session: Session): SessionBrief => ({
  ...summarise(session),
  log: session.log.slice(0, BRIEF_LOG_LINES),
  parkedItems: session.parked,
  asks: session.asks.filter(isOpen),
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
      ...others.filter(project => !isIdle(project)).sort(busiest),
    ],
    folded: others.filter(isIdle).sort((a, b) => byRecency(a, b) || compareText(a.name, b.name)),
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
