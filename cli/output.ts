/**
 * What the CLI prints of the projects and of a piece of work: lines to
 * read, or JSON for tools such as the tmux indicator.
 *
 * The JSON is stable: every field is always there, a list empty and any
 * other value null where there is none, and `v`, the output's version,
 * moves only with a change a reader would trip on.
 */
import {
  allProjects,
  brief,
  isCurrent,
  isOpen,
  summarise,
  summariseProject,
  type Ask,
  type LogLine,
  type Parked,
  type Project,
  type ProjectSummary,
  type Work,
  type WorkSummary,
} from '../core'

/** The JSON's version. */
const OUTPUT = 1

/** A project's works, as read. */
export type ProjectRead = { key: string; works: readonly Work[] }

const json = (value: unknown) => JSON.stringify(value, null, 2)

/**
 * The projects as `list` gives them, each with its current works: `here`
 * first, named as its folder is, then the busiest, and those with nothing
 * open, waiting or parked last. A project with no current works is left
 * out, but never `here`.
 */
export const listed = (read: readonly ProjectRead[], here: Project, now: number) => {
  const summaries = read.flatMap(({ key, works }) => {
    const current = works.map(summarise).filter(work => isCurrent(work, now))
    const summary = summariseProject(key, current)

    if (key === here.key) {
      return [{ ...summary, name: here.name }]
    }

    return current.length === 0 ? [] : [summary]
  })
  const { projects, folded } = allProjects(summaries, here.key)

  return [...projects, ...folded]
}

/** What a work holds that `list` tells: whether a window has it, and what waits and is parked. */
const factsOf = (work: WorkSummary) => [
  ...(work.isOpen ? ['open'] : []),
  ...(work.waiting > 0 ? [`${work.waiting} waiting`] : []),
  ...(work.parked > 0 ? [`${work.parked} parked`] : []),
]

const workLine = (work: WorkSummary) => {
  const facts = factsOf(work)

  return `  ${work.id}  ${work.name}${facts.length === 0 ? '' : ` (${facts.join(', ')})`}`
}

const projectLines = (project: ProjectSummary) => [
  project.name,
  ...(project.works.length === 0 ? ['  no current pieces of work'] : project.works.map(workLine)),
]

/** Each project's name, then its works, a line each: the id, the name, and what it holds. */
export const listText = (projects: readonly ProjectSummary[]) =>
  projects.flatMap(projectLines).join('\n')

const workJson = (work: WorkSummary) => ({
  id: work.id,
  name: work.name,
  summary: work.summary,
  now: work.now,
  next: work.next ?? null,
  isOpen: work.isOpen,
  waiting: work.waiting,
  parked: work.parked,
  updatedAt: work.updatedAt,
})

const projectJson = (project: ProjectSummary) => ({
  key: project.key,
  name: project.name,
  open: project.open,
  waiting: project.waiting,
  parked: project.parked,
  updatedAt: project.updatedAt,
  works: project.works.map(workJson),
})

/** `list --json`: the project the CLI runs in, by its key, and the projects as `listed` gives them. */
export const listJson = (projects: readonly ProjectSummary[], here: Project) =>
  json({ v: OUTPUT, here: here.key, projects: projects.map(projectJson) })

const askJson = (ask: Ask) => ({
  id: ask.id,
  kind: ask.kind,
  title: ask.title,
  where: ask.where ?? null,
  options: ask.options ?? [],
  ref: ask.ref ?? null,
  state: ask.state,
  at: ask.at,
})

const parkedJson = (parked: Parked) => ({
  id: parked.id,
  title: parked.title,
  where: parked.where ?? null,
  ref: parked.ref ?? null,
  at: parked.at,
})

const logJson = (line: LogLine) => ({
  kind: line.kind,
  id: line.id ?? null,
  text: line.text,
  detail: line.detail,
  ref: line.ref ?? null,
  by: line.by,
  at: line.at,
})

/** `board --json`: the work in brief, as `list` gives it, with its open asks, what it parked and its latest log lines. */
export const boardJson = (project: string, work: Work) => {
  const { log, parkedItems, ...summary } = brief(work)

  return json({
    v: OUTPUT,
    project: { key: project, name: work.project },
    work: workJson(summary),
    asks: work.asks.filter(isOpen).map(askJson),
    parked: parkedItems.map(parkedJson),
    log: log.map(logJson),
  })
}
