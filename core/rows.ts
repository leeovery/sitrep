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
 *   question, the newest first; dimmed while no window holds it.
 * - Else a session a window holds is a row of one line: working, where any
 *   of its windows is, else on its own work, both in Working; else your turn.
 *   Your turn's section follows Needs you's, since it waits on Lee too;
 *   Working's follows it.
 * - A session no window holds, with nothing waiting, has none: the SitRep
 *   window shows it. Nor has a finished one.
 *
 * A session Lee snoozed needs Lee in none of them: its asks and its turn
 * are its row in Snoozed, apart from the rows, while the snooze holds. Its
 * windows' stops are theirs, and stay in Needs you; a session working is in
 * Working, its asks asleep in Snoozed beside it.
 */
import { isFilled } from './entries'
import { isLive } from './presence'
import { directoryOf, type Project } from './project'
import { snoozedAsks, snoozedUntilOf, waitingOnLee, type SnoozedAsk } from './replies'
import { isPathSubject } from './subject'
import { compareText } from './text'
import {
  UNTIL_IT_MOVES,
  type Ask,
  type Session,
  type StateKind,
  type ToolShown,
  type WindowState,
  type Work,
} from './types'

/**
 * Where a session stands: needing Lee, as when an ask waits (while no window
 * holds it, too) or a window is stopped on Lee; its window working; its
 * window's turn over, on its own work; waiting for Lee's message; no window
 * holding it; or finished.
 */
export type SessionState = 'needsYou' | 'working' | 'onItsWork' | 'yourTurn' | 'away' | 'finished'

/** What a row's line is: an ask, a window's permission prompt or question, or a session whose window works, is on its own work, or waits on Lee's message. */
export type RowKind = 'ask' | 'permission' | 'question' | 'working' | 'onItsWork' | 'yourTurn'

/** Where a row sits: needing Lee; waiting on Lee's message; or its window working or on its own work. */
export type Section = 'needsYou' | 'yourTurn' | 'working'

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
  /** An ask's, when the snooze it woke from ran out: what makes it new to a watch that showed it asleep. Core's alone, never printed. */
  woke?: number
}

/** What names a session's row, wherever it sits: the session, its project, and whether a window holds it. */
type Named = {
  /** The session, which names the row. */
  session: string
  /** Needing Lee or in Snoozed, with no window holding the session: dimmed, with no window to jump to. */
  isAway: boolean
  /** The key of the project the session is filed under. */
  project: string
  /** The session's name, which a Needs you row shows as its title. */
  name: string
  /** Its project's name, which a Needs you row shows under its title. */
  projectName: string
  /** The project's two letters, as the strip's mark shows them. */
  letters: string
  /** Its project and session, `Northwind · Help desk redesign`, under a Working or Your turn row's line; an away row's says no window holds it. */
  second: string
}

export type Row = Named & {
  section: Section
  /** In Needs you, a line for each ask and stop waiting on Lee, the newest first; else the one of its turn. */
  lines: Line[]
  /** The instant its time counts from, which orders it in its section: its newest line's. */
  since: number
  /** On its own work, the soonest wake its window waits on, which orders it among the rest. */
  wakeAt?: number
}

/** What a Snoozed row's line is: an ask snoozed, or the session's turn. */
export type SnoozedKind = 'ask' | 'yourTurn'

/** One of a Snoozed row's lines: an ask snoozed, by the key it has in Needs you, or the turn, by the key it has as a turn's row; and when it wakes. */
export type SnoozedLine = {
  key: string
  is: SnoozedKind
  /** The ask, by its id; none on a turn. */
  ask?: string
  first: RowLine
  /** An ask's posting or reopening, as in Needs you; a turn's end, as a turn's row counts from. */
  since: number
  /** None on a turn an old line snoozed until it moves. */
  wakesAt?: number
}

/**
 * A session's row in Snoozed, named as its Needs you row is: a line for each
 * ask snoozed, and its turn's where it stands at Lee's turn; and when the
 * soonest wakes, none for a turn an old line snoozed until it moves.
 */
export type SnoozedRow = Named & { lines: SnoozedLine[]; wakesAt?: number }

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
 * where it has two (SitRep SR, BlueYonder BY), else its first two letters or
 * digits (Northwind No, contoso co).
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

/** An ask's key, the same in Needs you and Snoozed. */
const askKey = (session: Session, ask: Ask) => `ask:${session.id}:${ask.id}`

const askLine = (session: Session, ask: Ask): Line => ({
  key: askKey(session, ask),
  is: 'ask',
  ask: ask.id,
  first: { lead: ask.title },
  since: ask.openedAt,
  ...(ask.wokeAt === undefined ? {} : { woke: ask.wokeAt }),
})

/** What names a session's row in `project`, its second line saying so where it is away. */
const namedRow = (project: Project, session: Session, isAway: boolean): Named => {
  const name = session.status.name

  return {
    session: session.id,
    isAway,
    project: project.key,
    name,
    projectName: project.name,
    letters: lettersOf(project.name),
    second: isAway ? AWAY_LINE : `${project.name} · ${name}`,
  }
}

/** Lines, the newest first. */
const byRecency = (a: Line, b: Line) => b.since - a.since || compareText(a.key, b.key)

/**
 * A session's row at `now`: in Needs you, its asks waiting on Lee and its
 * windows stopped on Lee; else one line for its windows working, on their own
 * work or waiting on Lee's message. None for a session no window holds with
 * nothing waiting, nor for a finished one, nor for a turn Lee put off while
 * the snooze holds, which is in Snoozed.
 */
export const rowOf = (project: Project, session: Session, now: number): Row | undefined => {
  if (session.finished !== undefined) {
    return undefined
  }

  const held = heldBy(session, now)
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
  ].sort(byRecency)
  const [newest] = needs

  if (newest !== undefined) {
    return {
      ...namedRow(project, session, held.length === 0),
      section: 'needsYou',
      lines: needs,
      since: newest.since,
    }
  }

  const turn = turnOf(held)

  if (turn === undefined || snoozedTurnOf(session, now) !== undefined) {
    return undefined
  }

  const wakeAt = turn.state.work?.wakes?.at

  return {
    ...namedRow(project, session, false),
    section: turn.state.is === 'yourTurn' ? 'yourTurn' : 'working',
    lines: [windowLine(`turn:${session.id}`, turn)],
    since: turn.state.since,
    ...(wakeAt === undefined ? {} : { wakeAt }),
  }
}

type Waking = { wakesAt?: number }

/** A snooze's time as a line or row says it: none until it moves. */
const wakingAt = (until: number): Waking => (until === UNTIL_IT_MOVES ? {} : { wakesAt: until })

const snoozedLine = (session: Session, ask: SnoozedAsk): SnoozedLine => ({
  key: askKey(session, ask),
  is: 'ask',
  ask: ask.id,
  first: { lead: ask.title },
  since: ask.openedAt,
  ...wakingAt(ask.snoozedUntil),
})

/** When a Snoozed line or row wakes; one snoozed until it moves, after any time. */
const wakingOf = ({ wakesAt }: Waking) => wakesAt ?? UNTIL_IT_MOVES

/** The sooner to wake first, those snoozed until they move last. */
const bySooner = (a: Waking, b: Waking) =>
  wakingOf(a) === wakingOf(b) ? 0 : wakingOf(a) - wakingOf(b)

/** Snoozed lines, the soonest to wake first, then the oldest. */
const bySleep = (a: SnoozedLine, b: SnoozedLine) =>
  bySooner(a, b) || a.since - b.since || compareText(a.key, b.key)

/** When it wakes, none for one snoozed until it moves: of several snoozes holding, the latest; undefined where none holds. */
const latestWaking = (wakings: readonly (Waking | undefined)[]): Waking | undefined =>
  wakings
    .filter(waking => waking !== undefined)
    .reduce<Waking | undefined>(
      (last, waking) => (last === undefined || wakingOf(waking) > wakingOf(last) ? waking : last),
      undefined,
    )

/**
 * When the turn a session stands at your turn on ended, at `now`, across its
 * windows: its turn row's time, the one whose turn ended last. None while it
 * stands anywhere else: needing Lee, working, on its own work, away or
 * finished.
 */
export const turnEndOf = (session: Session, now: number) =>
  sessionState(session, now) === 'yourTurn' ? turnOf(heldBy(session, now))?.state.since : undefined

/**
 * An old line's snooze of a session's turn, read as it always was, while it
 * holds at `now` on the turn that ended at `end`: no later than the turn it
 * names, and its time, if it has one, still to come. So any turn ending
 * later, a window's next or one joining, ends it.
 */
const oldTurnSnooze = (session: Session, end: number, now: number): Waking | undefined => {
  const snooze = session.turnSnooze

  if (snooze === undefined || end > snooze.turn) {
    return undefined
  }

  if (snooze.until === undefined) {
    return {}
  }

  return now < snooze.until ? { wakesAt: snooze.until } : undefined
}

/** A session's turn Lee put off: when it ended, and when it wakes, none for one until it moves. */
export type SnoozedTurn = Waking & { end: number }

/**
 * A session's turn Lee put off at `now`: it stands at your turn while his
 * snooze of the session holds, on whatever turn, since a turn ending alone
 * never wakes it; while an old line's snooze of that turn holds; or while
 * his snoozes of asks, each its own, hold every ask waiting on him. Of
 * several, it wakes as the latest does.
 */
export const snoozedTurnOf = (session: Session, now: number): SnoozedTurn | undefined => {
  const end = turnEndOf(session, now)

  if (end === undefined) {
    return undefined
  }

  const until = snoozedUntilOf(session, now)
  const waking = latestWaking([
    until === undefined ? undefined : wakingAt(until),
    oldTurnSnooze(session, end, now),
    session.turnWithAsks === undefined ? undefined : { wakesAt: session.turnWithAsks },
  ])

  return waking === undefined ? undefined : { ...waking, end }
}

/**
 * Whether Lee's snooze of a session holds at `now`, or an old line's of its
 * turn: what his own prompt in its window wakes. His snooze of one ask is
 * none of it: he put that one off alone, working on the rest.
 */
export const isSessionAsleepAt = (session: Session, now: number) => {
  const end = turnEndOf(session, now)

  return (
    snoozedUntilOf(session, now) !== undefined ||
    (end !== undefined && oldTurnSnooze(session, end, now) !== undefined)
  )
}

/** A turn put off, as its line in Snoozed: keyed as its turn's row is, saying what Claude left Lee as that row does, since the turn's end. */
const snoozedTurnLine = (session: Session, { end, wakesAt }: SnoozedTurn): SnoozedLine => ({
  key: `turn:${session.id}`,
  is: 'yourTurn',
  first: boardLine(session),
  since: end,
  ...(wakesAt === undefined ? {} : { wakesAt }),
})

/**
 * A session's row in Snoozed at `now`, beside any row it has: a line for
 * each ask snoozed and one for its turn put off, the soonest to wake first,
 * then the oldest; dimmed while no window holds it, as in Needs you. It
 * wakes as its soonest line does. None with nothing put off, so none for a
 * finished session.
 */
export const snoozedRowOf = (
  project: Project,
  session: Session,
  now: number,
): SnoozedRow | undefined => {
  const turn = snoozedTurnOf(session, now)
  const lines = [
    ...snoozedAsks(session).map(ask => snoozedLine(session, ask)),
    ...(turn === undefined ? [] : [snoozedTurnLine(session, turn)]),
  ].sort(bySleep)
  const [soonest] = lines

  return soonest === undefined
    ? undefined
    : {
        ...namedRow(project, session, heldBy(session, now).length === 0),
        lines,
        ...(soonest.wakesAt === undefined ? {} : { wakesAt: soonest.wakesAt }),
      }
}

/** A row's oldest line's time: how long it has waited, in Needs you or Snoozed. */
export const oldestOf = (row: { lines: readonly { since: number }[] }) =>
  Math.min(...row.lines.map(line => line.since))

/** Snoozed's rows, the soonest to wake first, those snoozed until they move last, then the oldest. */
export const inSnoozedOrder = (rows: readonly SnoozedRow[]) =>
  [...rows].sort(
    (a, b) => bySooner(a, b) || oldestOf(a) - oldestOf(b) || compareText(a.session, b.session),
  )

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

/** A row's group, in the panel's order: needing Lee, an away session's after; your turn; working, on its own work at its end. */
const groupOf = (row: Row) => {
  switch (row.section) {
    case 'needsYou':
      return row.isAway ? 1 : 0
    case 'yourTurn':
      return 2
    case 'working':
      return isOwnWork(row) ? 4 : 3
  }
}

/** On its own work, a row waiting on a wake before one that is not, the sooner first. */
const byWake = (a: Row, b: Row) =>
  a.wakeAt === undefined || b.wakeAt === undefined
    ? Number(a.wakeAt === undefined) - Number(b.wakeAt === undefined)
    : a.wakeAt - b.wakeAt

/**
 * Needs you's rows newest first, by their newest lines, and your turn's;
 * on its own work's soonest to wake first, then oldest first; working's the
 * longest running first.
 */
const bySince = (a: Row, b: Row) => {
  if (a.section !== 'working') {
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
