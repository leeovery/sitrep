/**
 * What the board's views show, as data: a piece of work in brief, a project
 * with its works and its log, and every project, the busiest first.
 */
import { compareText } from './text'
import type { LogLine, Work } from './types'

/** A piece of work in brief: what it is doing, and what it holds for Lee. */
export type WorkSummary = {
  id: string
  name: string
  summary: string
  now: string[]
  next?: string
  isOpen: boolean
  waiting: number
  parked: number
  updatedAt: number
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

export const summarise = (work: Work): WorkSummary => ({
  id: work.id,
  name: work.status.name,
  summary: work.status.summary,
  now: work.status.now,
  next: work.status.next,
  isOpen: work.isOpen,
  waiting: work.waiting,
  parked: work.parked.length,
  updatedAt: work.updatedAt,
})

/** A project from its works, named as its most recently updated work names it. */
export const summariseProject = (key: string, works: readonly Work[]): ProjectSummary => {
  const summaries = works.map(summarise).sort(openFirst)
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
export const projectLog = (works: readonly Work[]): ProjectLogLine[] =>
  works
    .flatMap(work => work.log.map(line => ({ ...line, work: work.id })))
    .sort((a, b) => b.at - a.at || compareText(a.work, b.work))
