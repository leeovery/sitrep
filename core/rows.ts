/**
 * A session's state across its windows, what it is doing, and the rows the
 * notch's panel, the strip, the menu and the SitRep window show of the
 * board, in their order, each in its section with its lines and its time
 * (see "A session's state" and "The rows" in DESIGN.md). The app draws them
 * as they come: what a surface shows is decided here.
 *
 * A row is a session, which shows once, in one row.
 * - A session needing Lee is a row in Needs you, with a line for each ask
 *   waiting on Lee and each live window stopped on a permission prompt or a
 *   question, the oldest first; dimmed while no window holds it.
 * - Else a session a window holds is a row of one line: working, where any
 *   of its windows is, else on its own work, both in Working; else your turn.
 * - A session no window holds, with nothing waiting, has none: the SitRep
 *   window shows it. Nor has a finished one.
 */
import { isFilled } from './entries'
import { isLive } from './presence'
import { directoryOf, type Project } from './project'
import { waitingOnLee } from './replies'
import { isPathSubject } from './subject'
import { compareText } from './text'
import type { Ask, Session, StateKind, ToolShown, WindowState, Work } from './types'

/**
 * Where a session stands: needing Lee, as when an ask waits (while no window
 * holds it, too) or a window is stopped on Lee; its window working; its
 * window's turn over, on its own work; waiting for Lee's message; no window
 * holding it; or finished.
 */
export type SessionState = 'needsYou' | 'working' | 'onItsWork' | 'yourTurn' | 'away' | 'finished'

/** What a row's line is: an ask, a window's permission prompt or question, or a session whose window works, is on its own work, or waits on Lee's message. */
export type RowKind = 'ask' | 'permission' | 'question' | 'working' | 'onItsWork' | 'yourTurn'

/** Where a row sits: needing Lee; its window working or on its own work; or waiting on Lee's message. */
export type Section = 'needsYou' | 'working' | 'yourTurn'

/**
 * A line's words, in parts: what leads it, which a working line shimmers;
 * what it acts on, set in mono where it is a command or a path, else
 * `subject`, plain; how many more there are, as a question's `+2`; and when
 * the wake it waits on is due, which the app words after the lead as it
 * counts down ("in 12m"): core writes nothing that changes with the clock.
 */
export type RowLine = { lead: string; mono?: string; subject?: string; more?: string; until?: number }

/** One of a row's lines: an ask or a window's stop waiting on Lee, or the state of the window the row's turn comes from. */
export type Line = {
  /** What it is, the same for as long as it stands: an ask's session and id, a stop's window and when it showed, else its session. */
  key: string
  is: RowKind
  ask?: string
  /** The window it comes from: a stop's, or the one working or waiting on Lee's message. */
  writer?: string
  /** What it says. */
  first: RowLine
  /** When it began, which the app counts from: an ask's posting or reopening, a stop's showing, the turn's end, or its start while working. */
  since: number
}

export type Row = {
  /** The session, which names the row. */
  session: string
  section: Section
  /** Needing Lee, with no window holding the session: dimmed, with no window to jump to. */
  isAway: boolean
  /** The key of the project the session is filed under. */
  project: string
  /** The session's name, which a Needs you row shows as its title. */
  name: string
  /** Its project's name, which a Needs you row shows under its title. */
  projectName: string
  /** The project's two letters, as the strip's mark shows them. */
  letters: string
  /** In Needs you, a line for each ask and stop waiting on Lee, the oldest first; else the one of its turn. */
  lines: Line[]
  /** Its project and session, `Switchboard · Dashboard redesign`, under a Working or Your turn row's line; an away row's says no window holds it. */
  second: string
  /** When it began: its oldest line's. */
  since: number
  /** On its own work, the soonest wake its window waits on, which orders it among the rest. */
  wakeAt?: number
}

/**
 * What a session is doing, as the line under its name says it: a window's
 * permission prompt or question, the one shown first; else the window its
 * turn row comes from, working or your turn; each worded as its row's first
 * line, since its state began. With no window holding it, away, since its
 * latest line.
 */
export type Doing = { is: StateKind | 'away'; line: RowLine; since: number }

/** The panel's head: how many lines need Lee, away ones among them, and how many sessions the rows hold. None needing Lee is all clear. */
export type Head = { needYou: number; sessions: number }

/** A live window on a session, and what it is doing. */
type Held = { writer: string; state: WindowState }

const STOPS: readonly StateKind[] = ['permission', 'question']

/**
 * The verb a working row leads with while a tool runs, by the tool's name,
 * its subject after it in mono. Any other tool leads with its name.
 */
const VERBS: ReadonlyMap<string, string> = new Map([
  ['Read', 'Reading'],
  ['Edit', 'Editing'],
  ['MultiEdit', 'Editing'],
  ['NotebookEdit', 'Editing'],
  ['Write', 'Writing'],
  ['Bash', 'Running'],
  ['Grep', 'Searching'],
  ['WebSearch', 'Searching'],
  ['Glob', 'Finding'],
  ['WebFetch', 'Fetching'],
  ['Skill', 'Using'],
  ['LSP', 'Checking'],
])

/** The tools that run a task of their own: a working row leads with its description. */
const TASKS: ReadonlySet<string> = new Set(['Agent', 'Task', 'Monitor'])

/** A question's row when its heartbeat gave no text for it. */
const SOME_QUESTION = 'Claude asks a question'

/** A permission prompt's row when its heartbeat gave no tool for it. */
const SOME_PERMISSION = 'A permission prompt'

/** An away ask's second line, in place of its project and session: there is no window to jump to. */
const AWAY_LINE = 'No window holds it. Carry it on in Claude.'

/** Whether a row needs Lee: its lines asks, permission prompts or questions. */
export const needsYou = (row: Row) => row.section === 'needsYou'

/** The live windows on a session; one on a version before heartbeats said its state reads as your turn since it attached. */
const heldBy = (session: Session, now: number): Held[] =>
  session.presence
    .filter(each => isLive(each, now))
    .map(each => ({
      writer: each.writer,
      state: each.state ?? { is: 'yourTurn', since: each.attachedAt },
    }))

const isStopped = (window: Held) => STOPS.includes(window.state.is)

const isWorking = (window: Held) => window.state.is === 'working'

const isOnItsWork = (window: Held) => window.state.is === 'onItsWork'

/** Of several windows, the one whose state began last: the one active last. */
const latest = (windows: readonly Held[]) =>
  [...windows]
    .sort((a, b) => b.state.since - a.state.since || compareText(a.writer, b.writer))
    .at(0)

/** Of several windows, the one whose state began first: as their rows sit, the stop shown first. */
const earliest = (windows: readonly Held[]) =>
  [...windows]
    .sort((a, b) => a.state.since - b.state.since || compareText(a.writer, b.writer))
    .at(0)

/** The window a session's turn row comes from: the one working whose turn began last, else the one on its own work whose turn ended last, else the one active last. */
const turnOf = (held: readonly Held[]) =>
  latest(held.filter(isWorking)) ?? latest(held.filter(isOnItsWork)) ?? latest(held)

/** Where a session stands at `now`, across its live windows: needing Lee wins, then working, then on its own work, then your turn. */
export const sessionState = (session: Session, now: number): SessionState => {
  if (session.finished !== undefined) {
    return 'finished'
  }

  const held = heldBy(session, now)

  if (session.waiting > 0 || held.some(isStopped)) {
    return 'needsYou'
  }

  if (held.length === 0) {
    return 'away'
  }

  if (held.some(isWorking)) {
    return 'working'
  }

  return held.some(isOnItsWork) ? 'onItsWork' : 'yourTurn'
}

/**
 * A project's two letters, as the strip's marks show them: its capitals
 * where it has two (SitRep SR, DocMan DM), else its first two letters or
 * digits (Switchboard Sw, agntc ag).
 */
export const lettersOf = (name: string) => {
  const capitals = name.match(/\p{Lu}/gu) ?? []
  const letters = capitals.length >= 2 ? capitals : (name.match(/[\p{L}\p{N}]/gu) ?? [])

  return letters.slice(0, 2).join('')
}

/** A tool's subject as a row shows it: a file's path from the project's directory, where it lies under it. */
const subjectOf = ({ name, subject }: ToolShown, project: Project) => {
  const under = project.directory === undefined ? undefined : `${directoryOf(project.directory)}/`

  return subject !== undefined &&
    under !== undefined &&
    isPathSubject(name) &&
    subject.startsWith(under)
    ? subject.slice(under.length)
    : subject
}

/** What a session's board says it is doing: what is under way first, else its summary, else its name. */
const boardLine = (session: Session): RowLine => ({
  lead: [session.status.now[0], session.status.summary, session.status.name].find(isFilled) ?? '',
})

/** A running tool's line: its verb and its subject, a task's description, or any other tool's name. */
const toolLine = (tool: ToolShown, project: Project): RowLine => {
  const verb = VERBS.get(tool.name)

  if (verb !== undefined) {
    return { lead: verb, mono: subjectOf(tool, project) }
  }

  return { lead: TASKS.has(tool.name) ? (tool.subject ?? tool.name) : tool.name }
}

/**
 * What a window on its own work waits on, as its line says it, the first of
 * these it has: its agents, by their count or the one's description; a
 * workflow, by its name; a shell, its command in mono; a monitor; any other
 * task; and, with nothing else, its soonest wake, which the app counts down
 * to after the lead.
 */
const workLine = ({ agents, workflows, shells, monitors, others, wakes }: Work): RowLine => {
  if (agents !== undefined) {
    return {
      lead: 'Waiting on',
      subject: agents.count === 1 ? agents.first : `${agents.count} agents`,
    }
  }

  if (workflows !== undefined) {
    return { lead: 'Running', subject: workflows.first }
  }

  if (shells !== undefined) {
    return { lead: 'Running', mono: shells.first }
  }

  if (monitors !== undefined) {
    return { lead: 'Watching', subject: monitors.first }
  }

  if (others !== undefined) {
    return { lead: 'Waiting on', subject: others.first }
  }

  return { lead: 'Wakes', ...(wakes?.at === undefined ? {} : { until: wakes.at }) }
}

/** What a window's state shows as its row's first line. */
const stateLine = (state: WindowState, session: Session, project: Project): RowLine => {
  const { tool, question, work } = state

  switch (state.is) {
    case 'permission':
      return tool === undefined
        ? { lead: SOME_PERMISSION }
        : { lead: `Allow ${tool.name}`, mono: subjectOf(tool, project) }
    case 'question':
      return {
        lead: question?.text ?? SOME_QUESTION,
        more: question !== undefined && question.count > 1 ? `+${question.count - 1}` : undefined,
      }
    case 'working':
      return tool === undefined ? boardLine(session) : toolLine(tool, project)
    case 'onItsWork':
      return work === undefined ? boardLine(session) : workLine(work)
    case 'yourTurn':
      return boardLine(session)
  }
}

const askLine = (session: Session, ask: Ask): Line => ({
  key: `ask:${session.id}:${ask.id}`,
  is: 'ask',
  ask: ask.id,
  first: { lead: ask.title },
  since: ask.openedAt,
})

/** Lines, the oldest first. */
const byAge = (a: Line, b: Line) => a.since - b.since || compareText(a.key, b.key)

/**
 * A session's row at `now`: in Needs you, its asks waiting on Lee and its
 * windows stopped on Lee; else one line for its windows working, on their own
 * work or waiting on Lee's message. None for a session no window holds with
 * nothing waiting, nor for a finished one.
 */
export const rowOf = (project: Project, session: Session, now: number): Row | undefined => {
  if (session.finished !== undefined) {
    return undefined
  }

  const held = heldBy(session, now)
  const shared = {
    session: session.id,
    project: project.key,
    name: session.status.name,
    projectName: project.name,
    letters: lettersOf(project.name),
  }
  const second = `${shared.projectName} · ${shared.name}`
  const windowLine = (key: string, { writer, state }: Held): Line => ({
    key,
    is: state.is,
    writer,
    first: stateLine(state, session, project),
    since: state.since,
  })
  const needs = [
    ...waitingOnLee(session).map(ask => askLine(session, ask)),
    ...held
      .filter(isStopped)
      .map(each => windowLine(`stop:${session.id}:${each.writer}:${each.state.since}`, each)),
  ].sort(byAge)
  const [oldest] = needs

  if (oldest !== undefined) {
    const isAway = held.length === 0

    return {
      ...shared,
      section: 'needsYou',
      isAway,
      lines: needs,
      second: isAway ? AWAY_LINE : second,
      since: oldest.since,
    }
  }

  const turn = turnOf(held)

  if (turn === undefined) {
    return undefined
  }

  const wakeAt = turn.state.work?.wakes?.at

  return {
    ...shared,
    section: turn.state.is === 'yourTurn' ? 'yourTurn' : 'working',
    isAway: false,
    lines: [windowLine(`turn:${session.id}`, turn)],
    second,
    since: turn.state.since,
    ...(wakeAt === undefined ? {} : { wakeAt }),
  }
}

/** What a session is doing at `now`, across its live windows (`Doing`). */
export const doingOf = (project: Project, session: Session, now: number): Doing => {
  const held = heldBy(session, now)
  const window = earliest(held.filter(isStopped)) ?? turnOf(held)

  return window === undefined
    ? { is: 'away', line: { lead: AWAY_LINE }, since: session.updatedAt }
    : {
        is: window.state.is,
        line: stateLine(window.state, session, project),
        since: window.state.since,
      }
}

/** Whether a row in Working is on its own work, not working. */
const isOwnWork = (row: Row) => row.lines[0]?.is === 'onItsWork'

/** A row's group, in the panel's order: needing Lee, an away session's after; working, on its own work at its end; your turn. */
const groupOf = (row: Row) => {
  switch (row.section) {
    case 'needsYou':
      return row.isAway ? 1 : 0
    case 'working':
      return isOwnWork(row) ? 3 : 2
    case 'yourTurn':
      return 4
  }
}

/** On its own work, a row waiting on a wake before one that is not, the sooner first. */
const byWake = (a: Row, b: Row) =>
  a.wakeAt === undefined || b.wakeAt === undefined
    ? Number(a.wakeAt === undefined) - Number(b.wakeAt === undefined)
    : a.wakeAt - b.wakeAt

/**
 * Your turn's rows newest first; on its own work's soonest to wake first,
 * then oldest first; every other group's oldest first, so Needs you's by its
 * oldest line, and working's the longest running first.
 */
const bySince = (a: Row, b: Row) => {
  if (a.section === 'yourTurn') {
    return b.since - a.since
  }

  return (isOwnWork(a) ? byWake(a, b) : 0) || a.since - b.since
}

/** Rows in the panel's order (see "The rows" in DESIGN.md). */
export const inPanelOrder = (rows: readonly Row[]) =>
  [...rows].sort(
    (a, b) => groupOf(a) - groupOf(b) || bySince(a, b) || compareText(a.session, b.session),
  )

/** The head: the lines needing Lee, and the rows. */
export const headOf = (rows: readonly Row[]): Head => ({
  needYou: rows.filter(needsYou).reduce((count, row) => count + row.lines.length, 0),
  sessions: rows.length,
})
