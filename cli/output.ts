/**
 * What the CLI prints of the projects and of a session: lines to
 * read, or JSON for tools such as the tmux indicator.
 *
 * The JSON is stable: every field is always there, a list empty and any
 * other value null where there is none, and `v`, the output's version,
 * moves only with a change a reader would trip on. So its fields keep the
 * names they had before a piece of work was called a session: `list`'s
 * projects hold `works`, and `board` gives its session as `work`.
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
  type ProjectSessions,
  type Session,
  type SessionSummary,
} from '../core'

/** The JSON's version, by command: `board`'s moved to 2 as its asks came to say what they want back, in place of their kind. */
const OUTPUT = { list: 1, board: 2 } as const

/** What `list` gives: the project the CLI runs in, if it runs in one, and the projects listed. */
export type Listing = { here?: Project; projects: ProjectSummary[] }

const json = (value: unknown) => JSON.stringify(value, null, 2)

/**
 * The projects as `list` gives them, every one or those `named` names, each
 * with its current sessions, as the start of a conversation lists them:
 * those whose directory holds the folder the CLI runs in first. `here` is
 * the nearest of those. A project with no current sessions is left out, but
 * never `here`, nor one named.
 */
export const listing = (
  read: readonly ProjectSessions[],
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

/** What a session holds that `list` tells: whether a window has it, and what waits and is parked. */
const factsOf = (session: SessionSummary) => [
  ...(session.isOpen ? ['open'] : []),
  ...(session.waiting > 0 ? [`${session.waiting} waiting`] : []),
  ...(session.parked > 0 ? [`${session.parked} parked`] : []),
]

const sessionLine = (session: SessionSummary) => {
  const facts = factsOf(session)

  return `  ${session.id}  ${session.name}${facts.length === 0 ? '' : ` (${facts.join(', ')})`}`
}

const projectLines = (project: ProjectSummary) => [
  project.name,
  ...(project.sessions.length === 0
    ? ['  no current sessions']
    : project.sessions.map(sessionLine)),
]

/** Each project's name, then its sessions, a line each: the id, the name, and what it holds. */
export const listText = (projects: readonly ProjectSummary[]) =>
  projects.length === 0
    ? 'No current sessions on the board.'
    : projects.flatMap(projectLines).join('\n')

const sessionJson = (session: SessionSummary) => ({
  id: session.id,
  name: session.name,
  summary: session.summary,
  now: session.now,
  next: session.next ?? null,
  isOpen: session.isOpen,
  waiting: session.waiting,
  parked: session.parked,
  updatedAt: session.updatedAt,
})

const projectJson = (project: ProjectSummary, onScreen: ReadonlySet<string>) => ({
  key: project.key,
  name: project.name,
  open: project.open,
  waiting: project.waiting,
  parked: project.parked,
  updatedAt: project.updatedAt,
  works: project.sessions.map(session => ({
    ...sessionJson(session),
    onScreen: onScreen.has(session.id),
  })),
})

/**
 * `list --json`: the project the CLI runs in, by its key, else null, and the
 * projects as `listing` gives them, each session saying whether a jump can
 * reach it.
 */
export const listJson = ({ here, projects }: Listing, onScreen: ReadonlySet<string>) =>
  json({
    v: OUTPUT.list,
    here: here?.key ?? null,
    projects: projects.map(project => projectJson(project, onScreen)),
  })

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

/** `board --json`: the session in brief, as `list` gives it, with its open asks, what it parked and its latest log lines. */
export const boardJson = (project: string, session: Session) => {
  const { log, parkedItems, asks, ...summary } = brief(session)

  return json({
    v: OUTPUT.board,
    project: { key: project, name: session.project },
    work: sessionJson(summary),
    asks: asks.map(askJson),
    parked: parkedItems.map(parkedJson),
    log: log.map(logJson),
  })
}
