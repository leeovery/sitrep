/**
 * What the CLI prints of the projects and of a piece of work: lines to
 * read, or JSON for tools such as the tmux indicator.
 *
 * The JSON is stable: every field is always there, a list empty and any
 * other value null where there is none, and `v`, the output's version,
 * moves only with a change a reader would trip on.
 */
import {
  brief,
  isSameName,
  listedProjects,
  projectAround,
  type Ask,
  type LogLine,
  type Parked,
  type Project,
  type ProjectSummary,
  type ProjectWorks,
  type Work,
  type WorkSummary,
} from '../core'

/** The JSON's version, by command: `board`'s moved to 2 as its asks came to say what they want back, in place of their kind. */
const OUTPUT = { list: 1, board: 2 } as const

/** What `list` gives: the project the CLI runs in, if it runs in one, and the projects listed. */
export type Listing = { here?: Project; projects: ProjectSummary[] }

const json = (value: unknown) => JSON.stringify(value, null, 2)

/**
 * The projects as `list` gives them, every one or those `named` names,
 * each with its current works, as the start of a session lists them: those
 * whose directory holds the folder the CLI runs in first. `here` is the
 * nearest of those. A project with no current works is left out, but never
 * `here`, nor one named.
 */
export const listing = (
  read: readonly ProjectWorks[],
  cwd: string,
  now: number,
  named?: string,
): Listing => {
  const here = projectAround(
    read.map(({ project }) => project),
    cwd,
  )
  const chosen =
    named === undefined ? read : read.filter(({ project }) => isSameName(project.name, named))
  const kept = named === undefined ? [here] : chosen.map(({ project }) => project)
  const keys = kept.flatMap(project => (project === undefined ? [] : [project.key]))

  return { here, projects: listedProjects(chosen, cwd, now, keys) }
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
  projects.length === 0
    ? 'No current pieces of work on the board.'
    : projects.flatMap(projectLines).join('\n')

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

/** `list --json`: the project the CLI runs in, by its key, else null, and the projects as `listing` gives them. */
export const listJson = ({ here, projects }: Listing) =>
  json({ v: OUTPUT.list, here: here?.key ?? null, projects: projects.map(projectJson) })

const askJson = (ask: Ask) => ({
  id: ask.id,
  wants: ask.wants,
  yes: ask.wants === 'yes' ? (ask.yes ?? null) : null,
  title: ask.title,
  where: ask.where ?? null,
  options: ask.options ?? [],
  needs: ask.needs ?? null,
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
  const { log, parkedItems, asks, ...summary } = brief(work)

  return json({
    v: OUTPUT.board,
    project: { key: project, name: work.project },
    work: workJson(summary),
    asks: asks.map(askJson),
    parked: parkedItems.map(parkedJson),
    log: log.map(logJson),
  })
}
