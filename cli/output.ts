/**
 * What the CLI prints of the projects and of a session: lines to
 * read, or JSON for tools such as the tmux indicator; and the lines of
 * `watch`, the board as every surface shows it, for the SitRep app.
 *
 * The JSON is stable: every field is always there, a list empty and any
 * other value null where there is none, and `v`, the output's version,
 * moves only with a change a reader would trip on. So its fields keep the
 * names they had before a piece of work was called a session: `list`'s
 * projects hold `works`, and `board` gives its session as `work`. `watch`,
 * newer than the words, says sessions.
 */
import {
  answerOf,
  answerState,
  brief,
  closingReply,
  isSameName,
  listedProjects,
  projectAround,
  resolvedAsks,
  type Ask,
  type Feed,
  type FeedProject,
  type FeedSession,
  type FeedWindow,
  type LogLine,
  type Parked,
  type Project,
  type ProjectSummary,
  type ProjectSessions,
  type Row,
  type RowLine,
  type Session,
  type SessionSummary,
  type WindowState,
  type Where,
} from '../core'

/**
 * The JSON's version, by command: `board`'s moved to 2 as its asks came to
 * say what they want back, in place of their kind. Fields added since, as
 * each ask's answer and `board`'s resolved asks, move none: a reader passes
 * over a field it does not know.
 */
const OUTPUT = { list: 1, board: 2, watch: 1 } as const

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

/** Where Lee's answer to an ask stands, and its words as the board shows them on one row; null with none on its way and none that closed it. */
const answerJson = (ask: Ask) => {
  const answer = answerState(ask)

  return answer === undefined
    ? null
    : { is: answer.is, words: answerOf(ask, answer.reply), since: answer.since }
}

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
  answer: answerJson(ask),
})

/** A resolved ask: as an open one is, with when it closed and, where Claude's resolve closed it, why. */
const resolvedJson = (ask: Ask) => ({
  ...askJson(ask),
  closedAt: ask.closedAt ?? null,
  reason: closingReply(ask) === undefined ? (ask.reason ?? null) : null,
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

/** `board --json`: the session in brief, as `list` gives it, with its open asks, what it parked, its latest log lines, and its resolved asks, the newest closed first. */
export const boardJson = (project: string, session: Session) => {
  const { log, parkedItems, asks, ...summary } = brief(session)

  return json({
    v: OUTPUT.board,
    project: { key: project, name: session.project },
    work: sessionJson(summary),
    asks: asks.map(askJson),
    parked: parkedItems.map(parkedJson),
    log: log.map(logJson),
    resolved: resolvedAsks(session).map(resolvedJson),
  })
}

const lineJson = (line: RowLine) => ({
  lead: line.lead,
  mono: line.mono ?? null,
  more: line.more ?? null,
})

const rowJson = (row: Row) => ({
  key: row.key,
  is: row.is,
  isAway: row.isAway,
  session: row.session,
  project: row.project,
  letters: row.letters,
  ask: row.ask ?? null,
  writer: row.writer ?? null,
  first: lineJson(row.first),
  second: row.second,
  since: row.since,
})

const feedSessionJson = (session: FeedSession) => ({
  ...sessionJson(session),
  state: session.state,
  since: session.since,
  asks: session.asks.map(askJson),
})

const feedProjectJson = (project: FeedProject) => ({
  key: project.key,
  name: project.name,
  directory: project.directory ?? null,
  open: project.open,
  waiting: project.waiting,
  parked: project.parked,
  updatedAt: project.updatedAt,
  sessions: project.sessions.map(feedSessionJson),
})

const whereJson = (where: Where | undefined) =>
  where === undefined
    ? null
    : {
        device: where.device ?? null,
        terminal: where.terminal ?? null,
        tmux:
          where.tmux === undefined ? null : { socket: where.tmux.socket, pane: where.tmux.pane },
      }

const stateJson = (state: WindowState | undefined) =>
  state === undefined
    ? null
    : {
        is: state.is,
        since: state.since,
        tool:
          state.tool === undefined
            ? null
            : { name: state.tool.name, subject: state.tool.subject ?? null },
        question:
          state.question === undefined
            ? null
            : { text: state.question.text, count: state.question.count },
      }

const windowJson = (window: FeedWindow) => ({
  writer: window.writer,
  session: window.session,
  name: window.name,
  project: window.project,
  version: window.version ?? null,
  needsReload: window.needsReload,
  where: whereJson(window.where),
  state: stateJson(window.state),
  attachedAt: window.attachedAt,
})

/** The board a watch line shows: all of it but the line's own time, what is new and what changed. */
const feedFields = (feed: Feed, version: string | undefined) => ({
  version: version ?? null,
  head: { needYou: feed.head.needYou, sessions: feed.head.sessions },
  rows: feed.rows.map(rowJson),
  projects: feed.projects.map(feedProjectJson),
  windows: feed.windows.map(windowJson),
})

/** What tells one watch line from the last, its own time aside: the board it shows, as text. `version` is the CLI's own. */
export const feedText = (feed: Feed, version: string | undefined) =>
  JSON.stringify(feedFields(feed, version))

/**
 * A line of `watch`, on one line: the board at `at`, the keys of the rows
 * new since the last line, and the ids of the sessions whose `board --json`
 * has changed since then.
 */
export const watchLine = (
  feed: Feed,
  version: string | undefined,
  at: number,
  news: readonly string[],
  changed: readonly string[],
) => JSON.stringify({ v: OUTPUT.watch, at, ...feedFields(feed, version), new: news, changed })
