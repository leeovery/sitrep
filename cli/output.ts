/**
 * What the CLI prints of the projects and of a session: lines to
 * read, or JSON for tools such as the tmux indicator; which sessions show on
 * screen; and the lines of `watch`, the board as every surface shows it, its
 * Snoozed rows apart from its rows, with the boards of the sessions the
 * SitRep app follows.
 *
 * The JSON is stable: every field is always there, a list empty and any
 * other value null where there is none, and `v`, the output's version,
 * moves only with a change a reader would trip on.
 */
import {
  answerOf,
  brief,
  compareText,
  inWords,
  isSameName,
  listedProjects,
  projectAround,
  replyState,
  resolvedAsks,
  snoozedUntilIn,
  type Ask,
  type Feed,
  type FeedProject,
  type FeedSession,
  type FeedWindow,
  type Line,
  type LogLine,
  type Parked,
  type Project,
  type ProjectSummary,
  type ProjectSessions,
  type Row,
  type RowLine,
  type Session,
  type SessionSummary,
  type SnoozedLine,
  type SnoozedRow,
  type WindowState,
  type Where,
} from '../core'
import type { OnScreen, Shown } from './screen'

/** The JSON's version, by command; why each stands where it does is DESIGN.md's ("One engine, two front ends"). */
const OUTPUT = { list: 2, board: 3, watch: 3, screen: 1 } as const

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

/** What a session holds that `list` tells: whether a window has it, and what waits, is snoozed and is parked. */
const factsOf = (session: SessionSummary) => [
  ...(session.isOpen ? ['open'] : []),
  ...(session.waiting > 0 ? [`${session.waiting} waiting`] : []),
  ...(session.snoozed > 0 ? [`${session.snoozed} snoozed`] : []),
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
  snoozed: session.snoozed,
  parked: session.parked,
  created: session.created,
  updatedAt: session.updatedAt,
})

const projectJson = (project: ProjectSummary) => ({
  key: project.key,
  name: project.name,
  open: project.open,
  waiting: project.waiting,
  snoozed: project.snoozed,
  parked: project.parked,
  updatedAt: project.updatedAt,
  sessions: project.sessions.map(sessionJson),
})

/** `list --json`: the project the CLI runs in, by its key, else null, and the projects as `listing` gives them. */
export const listJson = ({ here, projects }: Listing) =>
  json({ v: OUTPUT.list, here: here?.key ?? null, projects: projects.map(projectJson) })

/** Whether a jump could reach a session, as `screen --json` says it. */
const SCREEN_JSON = { 'on screen': 'on', 'off screen': 'off', unknown: 'unknown' } as const

/** Whether a jump could reach a session, in words. */
const SCREEN_WORDS = {
  'on screen': 'on screen',
  'off screen': 'not on screen',
  unknown: 'not known',
} as const

/** The sessions shown, by their ids. */
const byId = (shown: readonly Shown[]) =>
  [...shown].sort((a, b) => compareText(a.session.id, b.session.id))

/**
 * `screen --json`: each session a live window holds, by its id, saying
 * whether a jump could reach it, `on`, `off` or `unknown`; and what gave no
 * answer, by name.
 */
export const screenJson = ({ shown, unanswered }: OnScreen) =>
  json({
    v: OUTPUT.screen,
    sessions: byId(shown).map(({ session, is }) => ({ id: session.id, is: SCREEN_JSON[is] })),
    unanswered,
  })

/** Each session a live window holds, a line each: its id, its name and whether it is on screen; then what gave no answer. */
export const screenText = ({ shown, unanswered }: OnScreen) =>
  shown.length === 0
    ? 'No session is open in a window.'
    : [
        ...byId(shown).map(
          ({ session, is }) => `${session.id}  ${session.status.name}: ${SCREEN_WORDS[is]}`,
        ),
        ...(unanswered.length === 0 ? [] : [`${inWords(unanswered)} gave no answer.`]),
      ].join('\n')

/** Where Lee's reply to an ask stands, whether it is Lee's answer, which bars another, and its words as the board shows them on one row; null where `replyState` gives none. */
const replyJson = (ask: Ask) => {
  const state = replyState(ask)

  return state === undefined
    ? null
    : {
        is: state.is,
        isAnswer: state.isAnswer,
        words: answerOf(ask, state.reply),
        since: state.since,
      }
}

/** An ask of a session, as `board --json` and `watch` list it. */
const askJson = (session: SessionSummary, ask: Ask) => ({
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
  reply: replyJson(ask),
  snoozedUntil: snoozedUntilIn(session, ask) ?? null,
})

/** A resolved ask: as an open one is, with when it closed, and Claude's reason, where Claude gave one as it resolved the ask. */
const resolvedJson = (session: SessionSummary, ask: Ask) => ({
  ...askJson(session, ask),
  closedAt: ask.closedAt ?? null,
  reason: ask.reason ?? null,
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

/** A session's board, as `board --json` prints it and `watch` carries it: the session in brief, as `list` gives it, with its open asks, what it parked, its latest log lines, and its resolved asks, the newest closed first. */
export const boardFields = (project: string, session: Session) => {
  const { log, parkedItems, asks, ...summary } = brief(session)

  return {
    v: OUTPUT.board,
    project: { key: project, name: session.project },
    session: sessionJson(summary),
    asks: asks.map(ask => askJson(summary, ask)),
    parked: parkedItems.map(parkedJson),
    log: log.map(logJson),
    resolved: resolvedAsks(session).map(ask => resolvedJson(summary, ask)),
  }
}

export type BoardFields = ReturnType<typeof boardFields>

/** A session's board as `watch` holds it: its fields, and their text, which tells it from another. */
export type HeldBoard = { fields: BoardFields; text: string }

export const heldBoard = (project: string, session: Session): HeldBoard => {
  const fields = boardFields(project, session)

  return { fields, text: JSON.stringify(fields) }
}

/** `board --json`: the session's board. */
export const boardJson = (project: string, session: Session) => json(boardFields(project, session))

const lineJson = (line: RowLine) => ({
  lead: line.lead,
  mono: line.mono ?? null,
  subject: line.subject ?? null,
  more: line.more ?? null,
  until: line.until ?? null,
})

const rowLineJson = (line: Line) => ({
  key: line.key,
  is: line.is,
  ask: line.ask ?? null,
  writer: line.writer ?? null,
  first: lineJson(line.first),
  since: line.since,
})

const rowJson = (row: Row) => ({
  session: row.session,
  section: row.section,
  isAway: row.isAway,
  project: row.project,
  name: row.name,
  projectName: row.projectName,
  letters: row.letters,
  lines: row.lines.map(rowLineJson),
  second: row.second,
  since: row.since,
})

const feedSessionJson = (session: FeedSession) => ({
  ...sessionJson(session),
  state: session.state,
  since: session.since,
  doing: {
    is: session.doing.is,
    line: lineJson(session.doing.line),
    since: session.doing.since,
  },
  asks: session.asks.map(ask => askJson(session, ask)),
  parkedItems: session.parkedItems.map(parkedJson),
})

const snoozedLineJson = (line: SnoozedLine) => ({
  key: line.key,
  is: line.is,
  ask: line.ask ?? null,
  first: lineJson(line.first),
  since: line.since,
  wakesAt: line.wakesAt ?? null,
})

const snoozedRowJson = (row: SnoozedRow) => ({
  session: row.session,
  isAway: row.isAway,
  project: row.project,
  name: row.name,
  projectName: row.projectName,
  letters: row.letters,
  lines: row.lines.map(snoozedLineJson),
  second: row.second,
  wakesAt: row.wakesAt ?? null,
})

const feedProjectJson = (project: FeedProject) => ({
  key: project.key,
  name: project.name,
  directory: project.directory ?? null,
  open: project.open,
  waiting: project.waiting,
  snoozed: project.snoozed,
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

/** The board a watch line shows: all of it but the line's own time, what is new and the boards it carries. */
const feedFields = (feed: Feed, version: string | undefined) => ({
  version: version ?? null,
  head: { needYou: feed.head.needYou, sessions: feed.head.sessions },
  rows: feed.rows.map(rowJson),
  snoozed: feed.snoozed.map(snoozedRowJson),
  projects: feed.projects.map(feedProjectJson),
  windows: feed.windows.map(windowJson),
})

/** What tells one watch line from the last, its own time aside: the board it shows, as text. `version` is the CLI's own. */
export const feedText = (feed: Feed, version: string | undefined) =>
  JSON.stringify(feedFields(feed, version))

/**
 * A line of `watch`, on one line: the board at `at`, the keys of the lines
 * needing Lee new since the last line, and, by session id, the board of
 * each session followed that is new to the set or changed since it was last
 * printed, null for one the watch finds none of.
 */
export const watchLine = (
  feed: Feed,
  version: string | undefined,
  at: number,
  news: readonly string[],
  boards: Readonly<Record<string, BoardFields | null>>,
) => JSON.stringify({ v: OUTPUT.watch, at, ...feedFields(feed, version), new: news, boards })
