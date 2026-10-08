/**
 * What the board's views show, as data: a piece of work in brief, a project
 * with its works, its log and what it parked, and every project, the busiest
 * first.
 *
 * A work shows while it is current: open, holding something for Lee, or
 * updated lately, and not marked done. An older idle one, or a finished
 * one, stays on disk, out of every view.
 */
import { compareText } from './text'
import type { LogLine, Parked, Work } from './types'

/** How long an idle work (no window, nothing waiting or parked) stays in the views after its last update. */
export const CURRENT_MS = 7 * 24 * 60 * 60_000

/** How many of its latest log lines a brief carries: as many as any view of the board shows. */
export const BRIEF_LOG_LINES = 8

/** A piece of work in brief: what it is doing, and what it holds for Lee. */
export type WorkSummary = {
  id: string
  name: string
  summary: string
  /** The project's name. */
  project: string
  now: string[]
  next?: string
  isOpen: boolean
  /** Marked done: out of every view, whatever it holds. */
  isFinished: boolean
  waiting: number
  parked: number
  updatedAt: number
}

/** A piece of work as views beyond its own draw it: in brief, with its latest log lines and what it parked. */
export type WorkBrief = WorkSummary & {
  /** Newest first. */
  log: LogLine[]
  /** Oldest first. */
  parkedItems: Parked[]
}

export type ProjectSummary = {
  key: string
  name: string
  /** Those with a window first, then the most recently updated. */
  works: WorkSummary[]
  /** How many works have a window. */
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

/** A line of a project's log, and the work it came from. */
export type ProjectLogLine = LogLine & { work: string }

/** A parked item of a project's, and the work that parked it. */
export type ProjectParked = Parked & { work: string }

type Dated = { updatedAt: number }

const byRecency = (a: Dated, b: Dated) => b.updatedAt - a.updatedAt

const openFirst = (a: WorkSummary, b: WorkSummary) =>
  Number(b.isOpen) - Number(a.isOpen) || byRecency(a, b) || compareText(a.id, b.id)

const busiest = (a: ProjectSummary, b: ProjectSummary) =>
  b.waiting - a.waiting ||
  b.open - a.open ||
  b.parked - a.parked ||
  byRecency(a, b) ||
  compareText(a.name, b.name)

const isIdle = (project: ProjectSummary) =>
  project.open === 0 && project.waiting === 0 && project.parked === 0

const total = (works: readonly WorkSummary[], count: (work: WorkSummary) => number) =>
  works.reduce((sum, work) => sum + count(work), 0)

/** Whether a work shows in the views: not finished, and open, waiting on Lee, holding something parked, or updated within `CURRENT_MS`. */
export const isCurrent = (work: WorkSummary, now: number) =>
  !work.isFinished &&
  (work.isOpen || work.waiting > 0 || work.parked > 0 || now - work.updatedAt <= CURRENT_MS)

export const summarise = (work: Work): WorkSummary => ({
  id: work.id,
  name: work.status.name,
  summary: work.status.summary,
  project: work.project,
  now: work.status.now,
  next: work.status.next,
  isOpen: work.isOpen,
  isFinished: work.finished !== undefined,
  waiting: work.waiting,
  parked: work.parked.length,
  updatedAt: work.updatedAt,
})

export const brief = (work: Work): WorkBrief => ({
  ...summarise(work),
  log: work.log.slice(0, BRIEF_LOG_LINES),
  parkedItems: work.parked,
})

/** A project from its works, named as its most recently updated work names it. */
export const summariseProject = (key: string, works: readonly WorkSummary[]): ProjectSummary => {
  const summaries = [...works].sort(openFirst)
  const latest = [...works].sort(byRecency).at(0)

  return {
    key,
    name: latest?.project ?? key,
    works: summaries,
    open: summaries.filter(work => work.isOpen).length,
    waiting: total(summaries, work => work.waiting),
    parked: total(summaries, work => work.parked),
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

/** A project's log: every work's lines, newest first. */
export const projectLog = (works: readonly Pick<Work, 'id' | 'log'>[]): ProjectLogLine[] =>
  works
    .flatMap(work => work.log.map(line => ({ ...line, work: work.id })))
    .sort((a, b) => b.at - a.at || compareText(a.work, b.work))

/** What a project's works have parked, oldest first. */
export const projectParked = (works: readonly WorkBrief[]): ProjectParked[] =>
  works
    .flatMap(work => work.parkedItems.map(parked => ({ ...parked, work: work.id })))
    .sort((a, b) => a.at - b.at || compareText(a.work, b.work))
