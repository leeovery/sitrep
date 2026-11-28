/**
 * The moments the golden frames hold: round 1's worlds (design/paper/round1)
 * as core gives them, each at a size, in what the terminal answered, at a
 * fixed clock, in the state the panel reaches it in. Each is drawn through
 * `viewOf` and `draw`, as the panel draws.
 *
 * - The rows are made as core makes them and put in core's own order, so
 *   the board's order and counts are core's and the panel's, not round 1's.
 * - A session whose Claude ended is away on its row; one whose Claude runs
 *   where no terminal on this Mac shows it is away by `notHere`.
 * - Each is reached as the panel reaches it, at each size: its board read,
 *   then its keys pressed, both stepped as the panel steps them, then the
 *   clock run on, where it waits. A pick is answered from the board alone,
 *   as `reachOf` answers it: a fixture runs no command.
 * - A session given a place has a live window there.
 * - Each row of asks holds them on the board, in its project, so the view
 *   answers them: round 5's asks (design/paper/round5) where it drew them,
 *   else words asks of its lines' titles.
 * - The clock is London's: `check.ts` runs in its zone, so a Snoozed wake
 *   reads the same on any machine.
 */
import {
  headOf,
  inPanelOrder,
  inSnoozedOrder,
  type Ask,
  type Feed,
  type FeedProject,
  type FeedSession,
  type FeedWindow,
  type Row,
  type RowKind,
  type RowLine,
  type SnoozedKind,
  type SnoozedRow,
  type Where,
} from '../../core'
import { widthOf, type Size } from '../panel/cells'
import { draw, type Line } from '../panel/draw'
import type { Key } from '../panel/keys'
import { rgbOf, type Paint } from '../panel/paint'
import { reachOf } from '../panel/reach'
import { opening, step, type PanelState } from '../panel/state'
import { viewOf, type PanelView } from '../panel/view'

/** The board a fixture shows, and the sessions on it this Mac doesn't show. */
export type World = { feed: Feed; notHere: ReadonlySet<string> }

export type Fixture = {
  /** What the frame shows: `rest`, `busy`. */
  screen: string
  size: Size
  world: World
  paint: Paint
  now: number
  /** The lines new to Needs you on the board, first shown at `now`. */
  news: readonly string[]
  /** The keys pressed once the board is read. */
  keys: readonly Key[]
  /** How long the clock runs on once the keys are pressed, as the panel's ticks step it. */
  later: number
}

/** The zone the fixtures' clock reads in. */
export const ZONE = 'Europe/London'

const MINUTE_MS = 60_000

/** An hour, in the minutes a row's age is given in. */
const HOUR_MINUTES = 60

/** Wednesday 18 November 2026, 14:00 in London, which keeps UTC in November. */
const NOW = Date.UTC(2026, 10, 18, 14)

/** A day in November 2026 at 09:00 in London. */
const nineOn = (day: number) => Date.UTC(2026, 10, day, 9)

/** Nordfox's ink and ground, as the terminal answers them. */
const NORDFOX = { fg: rgbOf('#CDCECF'), bg: rgbOf('#2E3440') }

const COLOUR: Paint = { level: 'truecolor', ...NORDFOX }

const NO_COLOR: Paint = { level: 'none', ...NORDFOX }

const SIXTEEN: Paint = { level: '16', ...NORDFOX }

/** Each project's letters in its sessions' ids. */
const CODES: Record<string, string> = {
  Northwind: 'nw',
  Contoso: 'co',
  Fabrikam: 'fa',
  Tailspin: 'ts',
  Woodgrove: 'wg',
  Litware: 'lw',
  'Adventure Works': 'aw',
  'Trey Research': 'tr',
  Wingtip: 'wt',
}

let issued = 0

/** A session's id, its project's letters and a number no other session has. */
const idFor = (project: string) => `sr-${CODES[project] ?? 'xx'}${String(++issued).padStart(4, '0')}`

/** Where a session is away from: its Claude ended, or no terminal on this Mac shows it. */
type Away = 'ended' | 'elsewhere'

/** A session as a world holds it: its row in a section or in Snoozed, whether this Mac shows it, where its live window is, if it says, and the asks its row's lines are. */
type Seat = { row: Row; away?: Away; where?: Where; asks?: readonly Ask[] } | { snoozed: SnoozedRow }

const named = (name: string, project: string, isAway: boolean) => ({
  session: idFor(project),
  isAway,
  project: project.toLowerCase(),
  name,
  projectName: project,
  second: `${project} · ${name}`,
})

const SECTIONS = {
  ask: 'needsYou',
  permission: 'needsYou',
  question: 'needsYou',
  yourTurn: 'yourTurn',
  working: 'working',
  onItsWork: 'working',
} as const satisfies Record<RowKind, Row['section']>

/** How a row is made: its lines, and the words of each after the first where they differ; whether it is away, its wake, and where its window is. */
type Made = { count?: number; more?: readonly string[]; away?: Away; wakeAt?: number; where?: Where }

/** The window a stop or a turn comes from. */
const WRITER = 'w1'

/** A row's line, keyed as core keys it: an ask by its session and id, a window's stop by its window and when it showed, a turn by its session. */
const lineOf = (is: RowKind, session: string, at: number, first: RowLine, since: number): Row['lines'][number] => {
  switch (is) {
    case 'ask':
      return { key: `ask:${session}:k${at + 1}`, is, ask: `k${at + 1}`, first, since }
    case 'permission':
    case 'question':
      return { key: `stop:${session}:${WRITER}:${since}`, is, writer: WRITER, first, since }
    default:
      return { key: `turn:${session}`, is, writer: WRITER, first, since }
  }
}

/** A row of `count` lines saying `first`, or each its own of `more`, the newest `minutes` old, each older a minute before it. */
const seat = (is: RowKind, name: string, project: string, first: RowLine, minutes: number, made: Made = {}): Seat => {
  const { count = 1, away, wakeAt, where, more = [] } = made
  const since = NOW - minutes * MINUTE_MS
  const base = named(name, project, away === 'ended')
  const saying = (at: number): RowLine => {
    const lead = more[at - 1]

    return lead === undefined ? first : { lead }
  }
  const row: Row = {
    ...base,
    section: SECTIONS[is],
    lines: Array.from({ length: count }, (_, at) => lineOf(is, base.session, at, saying(at), since - at * MINUTE_MS)),
    since,
    ...(wakeAt === undefined ? {} : { wakeAt }),
  }

  return { row, ...(away === undefined ? {} : { away }), ...(where === undefined ? {} : { where }) }
}

/** A board ask a row of asks holds: its title, how many minutes ago it was asked, and what it wants. */
type Asking = { title: string; minutes: number } & (
  | { wants: 'yes'; yes: string }
  | { wants: 'choice'; options: readonly string[]; recommended?: string }
  | { wants: 'words' }
)

/** When an asking was asked. */
const askedAt = ({ minutes }: Asking) => NOW - minutes * MINUTE_MS

/** What an asking wants back, as the board's ask holds it: a yes's words, or a choice's options and Claude's pick. */
const wantedOf = (asking: Asking): Pick<Ask, 'yes' | 'options' | 'recommended'> => {
  switch (asking.wants) {
    case 'yes':
      return { yes: asking.yes }
    case 'choice':
      return { options: [...asking.options], ...(asking.recommended === undefined ? {} : { recommended: asking.recommended }) }
    case 'words':
      return {}
  }
}

/** The board's ask of an asking, `k1` the first, waiting on Lee since its line came. */
const boardAsk = (asking: Asking, at: number): Ask => ({
  type: 'ask',
  id: `k${at + 1}`,
  by: WRITER,
  at: askedAt(asking),
  openedAt: askedAt(asking),
  wants: asking.wants,
  title: asking.title,
  ...wantedOf(asking),
  state: 'waiting',
  replies: [],
})

/** A row of these asks, the newest first, each line its ask's title, aged as its ask. */
const asking = (name: string, project: string, asks: readonly Asking[], { away, where }: Made = {}): Seat => {
  const base = named(name, project, away === 'ended')
  const lines = asks.map((each, at) => lineOf('ask', base.session, at, { lead: each.title }, askedAt(each)))
  const row: Row = { ...base, section: 'needsYou', lines, since: lines[0]?.since ?? NOW }

  return { row, asks: asks.map(boardAsk), ...(away === undefined ? {} : { away }), ...(where === undefined ? {} : { where }) }
}

/** A row of `count` words asks titled `status`, or each its own of `more`, the newest `minutes` old, each older a minute before it. */
const ask = (name: string, project: string, status: string, minutes: number, { count = 1, more = [], ...made }: Made = {}) =>
  asking(
    name,
    project,
    Array.from({ length: count }, (_, at): Asking => ({ title: more[at - 1] ?? status, minutes: minutes + at, wants: 'words' })),
    made,
  )

const permission = (name: string, project: string, tool: string, what: string, minutes: number) =>
  seat('permission', name, project, { lead: `Allow ${tool}`, mono: what }, minutes)

const turn = (name: string, project: string, status: string, minutes: number, made?: Made) =>
  seat('yourTurn', name, project, { lead: status }, minutes, made)

const working = (name: string, project: string, status: string, minutes: number, made?: Made) =>
  seat('working', name, project, { lead: status }, minutes, made)

const own = (name: string, project: string, status: string, minutes: number) =>
  seat('onItsWork', name, project, { lead: status }, minutes)

/** On its own work, waiting on a wake due `minutes` from now. */
const waking = (name: string, project: string, inMinutes: number, minutes: number) => {
  const until = NOW + inMinutes * MINUTE_MS

  return seat('onItsWork', name, project, { lead: 'Wakes', until }, minutes, { wakeAt: until })
}

/** A session's row in Snoozed, of one line, waking at `wakesAt`. */
const snoozed = (is: SnoozedKind, name: string, project: string, status: string, wakesAt: number): Seat => {
  const base = named(name, project, false)

  return {
    snoozed: {
      ...base,
      lines: [
        {
          key: is === 'ask' ? `ask:${base.session}:k1` : `turn:${base.session}`,
          ...(is === 'ask' ? { ask: 'k1' } : {}),
          is,
          first: { lead: status },
          since: NOW - 3 * HOUR_MINUTES * MINUTE_MS,
          wakesAt,
        },
      ],
      wakesAt,
    },
  }
}

/** A row's session as its project lists it on the board, with the asks its lines are. */
const feedSessionOf = ({ session, name, projectName, since }: Row, asks: readonly Ask[]): FeedSession => ({
  id: session,
  name,
  summary: '',
  project: projectName,
  now: [],
  isOpen: true,
  isFinished: false,
  waiting: asks.length,
  snoozed: 0,
  asked: asks.length,
  parked: 0,
  created: since,
  updatedAt: since,
  state: 'needsYou',
  since,
  doing: { is: 'away', line: { lead: name }, since },
  asks: [...asks],
  parkedItems: [],
})

/** The project of a row of asks, holding its session alone. */
const projectOf = (row: Row, asks: readonly Ask[]): FeedProject => ({
  key: row.project,
  name: row.projectName,
  sessions: [feedSessionOf(row, asks)],
  open: 1,
  waiting: asks.length,
  snoozed: 0,
  asked: asks.length,
  parked: 0,
  updatedAt: row.since,
})

/** The live window of a session given a place, the first a jump tries, attached as its row's line came. */
const windowOf = (row: Row, where: Where): FeedWindow => ({
  writer: WRITER,
  session: row.session,
  name: row.name,
  project: row.projectName,
  needsReload: false,
  where,
  attachedAt: row.since,
  jumpOrder: 0,
})

/** The world of these sessions, as core gives its board. */
const worldOf = (seats: readonly Seat[]): World => {
  const rows = inPanelOrder(seats.flatMap(each => ('row' in each ? [each.row] : [])))

  return {
    feed: {
      head: headOf(rows),
      rows,
      snoozed: inSnoozedOrder(seats.flatMap(each => ('snoozed' in each ? [each.snoozed] : []))),
      projects: seats.flatMap(each => ('asks' in each && each.asks !== undefined ? [projectOf(each.row, each.asks)] : [])),
      windows: seats.flatMap(each => ('where' in each && each.where !== undefined ? [windowOf(each.row, each.where)] : [])),
    },
    notHere: new Set(seats.flatMap(each => ('row' in each && each.away === 'elsewhere' ? [each.row.session] : []))),
  }
}

/** A Ghostty window in no multiplexer, whose Claude a pick can't reach. */
const IN_GHOSTTY: Where = { device: '/dev/ttys004', terminal: 'ghostty' }

/** Round 5's asks: Help desk redesign's choice and words ask, Shift schedules' yes, and Email templates' choice. */
const THREAD: Asking = {
  title: 'Thread replies, or keep them flat?',
  minutes: 4,
  wants: 'choice',
  options: ['Flat', 'Threaded', 'Flat, with a quote of the one it answers'],
  recommended: 'Threaded',
}

const OFFICE: Asking = { title: 'Which office moves to the new desk first?', minutes: 12, wants: 'words' }

const ROTA: Asking = { title: 'Approve the rota for the first week of December', minutes: 26, wants: 'yes', yes: 'Approve' }

const PLAIN_TEXT: Asking = {
  title: 'Keep the plain-text versions?',
  minutes: 2 * HOUR_MINUTES,
  wants: 'choice',
  options: ['Keep them', 'Drop them'],
}

const REST: readonly Seat[] = [
  permission('Data import', 'Litware', 'Bash', 'psql -f import.sql', 1),
  asking('Help desk redesign', 'Northwind', [THREAD, OFFICE]),
  asking('Shift schedules', 'Contoso', [ROTA]),
  asking('Email templates', 'Fabrikam', [PLAIN_TEXT], { away: 'ended' }),
  turn('Release notes', 'Tailspin', 'Drafted the 2.4 release notes', 31, { where: IN_GHOSTTY }),
  turn('Warehouse map', 'Litware', 'Mapped the ground floor', HOUR_MINUTES, { away: 'elsewhere' }),
  working('Mobile app', 'Woodgrove', 'Running npm test', 6),
  working('Invoice ledger', 'Northwind', 'Exporting the ledger as CSV', 2),
  own('Catalog sync', 'Fabrikam', 'Waiting on 2 agents', 15),
  snoozed('ask', 'Onboarding flow', 'Contoso', 'Pick the onboarding steps', nineOn(19)),
  snoozed('yourTurn', 'Pricing page', 'Litware', 'Drafted three price tiers', nineOn(23)),
]

/** The docs page's still: only the placeholder names the docs may use, and a row of each kind the page names. */
const DOCS: readonly Seat[] = [
  asking('Help desk redesign', 'Northwind', [THREAD, OFFICE]),
  ask('Data import', 'Litware', 'Keep the old CSV columns?', 2 * HOUR_MINUTES, { away: 'ended' }),
  turn('Shift schedules', 'Contoso', 'Drafted the new rota', 31),
  working('Mobile app', 'Woodgrove', 'Running npm test', 6),
  own('Invoice ledger', 'Fabrikam', 'Waiting on 2 agents', 15),
  snoozed('ask', 'Onboarding flow', 'Tailspin', 'Pick the onboarding steps', nineOn(19)),
]

const NEW_ASK = ask('Room bookings', 'Woodgrove', 'Can a room be booked twice?', 0)

const BUSY: readonly Seat[] = [
  permission('Data import', 'Litware', 'Bash', 'psql -f import.sql', 1),
  asking('Help desk redesign', 'Northwind', [THREAD, OFFICE]),
  ask('Room bookings', 'Adventure Works', 'Can a room be booked twice?', 9),
  asking('Shift schedules', 'Contoso', [ROTA]),
  ask('Expense claims', 'Trey Research', 'Which receipts need a scan?', 40, { count: 3 }),
  permission('Tax rates', 'Wingtip', 'Edit', 'src/tax/rates.ts', 52),
  asking('Email templates', 'Fabrikam', [PLAIN_TEXT], { away: 'ended' }),
  ask('Gift cards', 'Tailspin', 'Should a card expire?', 3 * HOUR_MINUTES, { away: 'ended' }),
  turn('Release notes', 'Tailspin', 'Drafted the 2.4 release notes', 31),
  turn('Search index', 'Wingtip', 'Rebuilt the index; 3 fields left', HOUR_MINUTES),
  turn('Staff directory', 'Contoso', 'Added the new starters', 2 * HOUR_MINUTES),
  turn('Warehouse map', 'Litware', 'Mapped the ground floor', HOUR_MINUTES, { away: 'elsewhere' }),
  working('Payroll export', 'Contoso', 'Writing payroll.csv', 22),
  working('Stock levels', 'Wingtip', 'Reading src/stock/levels.ts', 12),
  working('Delivery slots', 'Northwind', 'Running the slot planner', 9, { away: 'elsewhere' }),
  working('Mobile app', 'Woodgrove', 'Running npm test', 6),
  working('Route planner', 'Trey Research', 'Searching for route costs', 5),
  working('Sales dashboard', 'Adventure Works', 'Editing src/charts/sales.tsx', 4),
  working('Loyalty points', 'Woodgrove', 'Reading the points ledger', 3),
  working('Invoice ledger', 'Northwind', 'Exporting the ledger as CSV', 2),
  working('Login page', 'Adventure Works', 'Editing src/login/form.tsx', 1),
  working('Error alerts', 'Trey Research', 'Fetching the alert rules', 1),
  waking('Report builder', 'Fabrikam', 12, HOUR_MINUTES),
  own('Audit log', 'Tailspin', 'Watching the nightly export', 48),
  own('Catalog sync', 'Fabrikam', 'Waiting on 2 agents', 15),
  own('Booking reminders', 'Litware', 'Running the reminder job', 8),
  snoozed('ask', 'Onboarding flow', 'Contoso', 'Pick the onboarding steps', nineOn(19)),
  snoozed('ask', 'Survey results', 'Woodgrove', 'Keep the free-text answers?', nineOn(21)),
  snoozed('yourTurn', 'Holiday calendar', 'Northwind', 'Added the bank holidays', nineOn(22)),
  snoozed('yourTurn', 'Pricing page', 'Litware', 'Drafted three price tiers', nineOn(23)),
]

const AT_REST = worldOf(REST)

const ARRIVED = worldOf([NEW_ASK, ...REST])

const CROWDED = worldOf(BUSY)

const QUIET = worldOf([])

const FOR_DOCS = worldOf(DOCS)

/** The docs world with a row the narrow width cuts short, of a long name and three of Claude Code's questions, which ⏎ expands: a row of asks the view answers opens them. */
const LONG_NAME = 'Help desk redesign for the support team in every regional office'

const LONG_QUESTIONS = seat('question', LONG_NAME, 'Northwind', { lead: 'Thread replies, or keep them flat?' }, 4, {
  count: 3,
  more: ['Keep the old ticket numbers once the new desk goes live?', 'Which office moves first?'],
})

const EXPANDING = worldOf([LONG_QUESTIONS, ...DOCS.slice(1)])

/** The world read into the panel's first state, as an 80×24 terminal opens it. */
const readIn = (world: World) =>
  step(opening({ width: 80, height: 24 }, NOW, world.notHere), { board: world.feed, news: [], now: NOW }).state

/** The world's rows as the panel words them, Snoozed's among them. */
const rowsOf = (world: World) =>
  viewOf(world.feed, readIn(world), NOW, world.notHere).sections.flatMap(section => section.rows)

/** Every name, project and status line the worlds' rows show: those a frame may cut. */
export const NAMES: readonly string[] = [
  ...new Set(
    [AT_REST, ARRIVED, CROWDED, FOR_DOCS, EXPANDING].flatMap(world =>
      rowsOf(world).flatMap(row => [row.name, row.project, row.status.text]),
    ),
  ),
].sort()

/** The session's row in the world, named so. */
const rowNamed = (world: World, name: string) => {
  const row = world.feed.rows.find(each => each.name === name)

  if (row === undefined) {
    throw new Error(`no session named ${name}`)
  }

  return row
}

/** The key of the session's newest line. */
const newestLine = (world: World, name: string) => rowNamed(world, name).lines[0]?.key ?? ''

const DOWN: Key = { kind: 'down' }

const ENTER: Key = { kind: 'enter' }

const OPEN: Key = { kind: 'open' }

const SNOOZE: Key = { kind: 'snooze' }

const END: Key = { kind: 'end' }

const SNOOZED: Key = { kind: 'snoozed' }

const RIGHT: Key = { kind: 'right' }

/** The second answer's digit: Flat, of Help desk redesign's choice. */
const TWO: Key = { kind: 'digit', n: 2 }

/** How far round 5 drew an answer held: 0.3 of its two seconds, its ring at `◑`. */
const HELD_FOR = 600

/** The keys that put the band on the session named so, from none: `↓` onto the first row, the top one in view, then a `↓` a row. */
const downTo = (world: World, name: string): Key[] => {
  const state = readIn(world)
  const rows = viewOf(world.feed, state, NOW, world.notHere)
    .sections.filter(section => section.isOpen)
    .flatMap(section => section.rows)
  const at = rows.findIndex(row => row.name === name)

  if (at === -1) {
    throw new Error(`no row named ${name} in view`)
  }

  return Array.from({ length: at + 1 }, () => DOWN)
}

/** A screen: its world, its paint, the lines new on its board and the keys pressed, at each of its sizes. */
type Screen = {
  world: World
  paint?: Paint
  news?: readonly string[]
  keys?: readonly Key[]
  later?: number
  sizes: readonly (readonly [width: number, height: number])[]
}

const SCREENS: Record<string, Screen> = {
  rest: { world: AT_REST, sizes: [[39, 27], [69, 46], [73, 36]] },
  picked: { world: AT_REST, keys: downTo(AT_REST, 'Help desk redesign'), sizes: [[39, 27], [69, 46], [73, 36]] },
  unfolded: { world: AT_REST, keys: [SNOOZED], sizes: [[39, 27], [69, 46]] },
  busy: {
    world: CROWDED,
    keys: downTo(CROWDED, 'Invoice ledger'),
    sizes: [[39, 27], [69, 46], [73, 36], [73, 15], [24, 8]],
  },
  arriving: { world: ARRIVED, news: [newestLine(ARRIVED, 'Room bookings')], sizes: [[39, 27], [69, 46]] },
  unreachable: { world: AT_REST, keys: [...downTo(AT_REST, 'Release notes'), OPEN], sizes: [[39, 27], [69, 46]] },
  quiet: { world: QUIET, sizes: [[39, 27], [69, 46]] },
  wide: { world: AT_REST, keys: downTo(AT_REST, 'Help desk redesign'), sizes: [[114, 45], [173, 53]] },
  nocolor: {
    world: AT_REST,
    paint: NO_COLOR,
    keys: [...downTo(AT_REST, 'Help desk redesign'), SNOOZED],
    sizes: [[39, 27]],
  },
  sixteen: { world: AT_REST, paint: SIXTEEN, keys: downTo(AT_REST, 'Help desk redesign'), sizes: [[39, 27]] },
  narrow: { world: AT_REST, sizes: [[30, 27]] },
  small: { world: AT_REST, sizes: [[23, 10]] },
  docs: { world: FOR_DOCS, sizes: [[73, 18]] },
  expanded: { world: EXPANDING, keys: [...downTo(EXPANDING, LONG_NAME), ENTER], sizes: [[52, 27], [114, 45]] },
  snoozing: { world: FOR_DOCS, keys: [...downTo(FOR_DOCS, 'Help desk redesign'), SNOOZE], sizes: [[52, 27], [114, 45]] },
  waking: { world: FOR_DOCS, keys: [SNOOZED, END], sizes: [[52, 27]] },
  asks: {
    world: AT_REST,
    keys: [...downTo(AT_REST, 'Help desk redesign'), ENTER],
    sizes: [[39, 27], [69, 46], [73, 36], [114, 45], [173, 53], [30, 27]],
  },
  words: { world: AT_REST, keys: [...downTo(AT_REST, 'Help desk redesign'), ENTER, RIGHT], sizes: [[39, 27], [69, 46]] },
  yes: { world: AT_REST, keys: [...downTo(AT_REST, 'Shift schedules'), ENTER], sizes: [[39, 27], [69, 46]] },
  sending: { world: AT_REST, keys: [...downTo(AT_REST, 'Help desk redesign'), ENTER, TWO], later: HELD_FOR, sizes: [[39, 27], [69, 46]] },
  prompt: { world: AT_REST, keys: downTo(AT_REST, 'Data import'), sizes: [[39, 27]] },
  busyasks: { world: CROWDED, keys: [...downTo(CROWDED, 'Help desk redesign'), ENTER], sizes: [[39, 27], [73, 15]] },
  nocolorasks: { world: AT_REST, paint: NO_COLOR, keys: [...downTo(AT_REST, 'Help desk redesign'), ENTER], sizes: [[39, 27]] },
}

export const FIXTURES: readonly Fixture[] = Object.entries(SCREENS).flatMap(([screen, { world, paint = COLOUR, news = [], keys = [], later = 0, sizes }]) =>
  sizes.map(([width, height]) => ({ screen, size: { width, height }, world, paint, now: NOW, news, keys, later })),
)

/** The fixture's frame's name: `panel-rest-39x27`. */
export const frameName = ({ screen, size }: Fixture) => `panel-${screen}-${size.width}x${size.height}`

/** The state after a key, a pick it asks for answered from the world's board alone. */
const pressedIn =
  ({ feed }: World) =>
  (state: PanelState, key: Key): PanelState => {
    const { state: next, open } = step(state, { key })
    const reach = open === undefined ? undefined : reachOf(open, feed)

    if (reach !== undefined && 'resume' in reach) {
      throw new Error(`a fixture runs no resume command, as ${reach.resume.name}'s would be`)
    }

    return reach === undefined ? next : step(next, { opened: reach.answer }).state
  }

/** The fixture's state at a size: its board read, then its keys pressed, as the panel steps them, then the clock run on, where it waits. */
export const stateAt = ({ world, now, news, keys, later }: Fixture, size: Size): PanelState => {
  const pressed = keys.reduce(pressedIn(world), step(opening(size, now, world.notHere), { board: world.feed, news, now }).state)

  return later === 0 ? pressed : step(pressed, { tick: now + later }).state
}

/** The fixture's view at a size, as the panel reaches it there. */
export const viewAt = (fixture: Fixture, size: Size): PanelView => {
  const state = stateAt(fixture, size)

  return viewOf(state.feed, state, state.now, state.notHere)
}

/** The fixture drawn, as the panel draws it, at its size or another. */
export const drawn = (fixture: Fixture, at: Size = fixture.size): Line[] => draw(viewAt(fixture, at), at, fixture.paint)

/** How drawn lines fail to fit a size: other than one a row, or a line wider than the columns. */
export const misfitsOf = (lines: readonly Line[], size: Size): string[] => [
  ...(lines.length === size.height ? [] : [`${lines.length} lines drawn for ${size.height} rows`]),
  ...lines.flatMap((line, at) => {
    const cells = widthOf(line.map(run => run.text).join(''))

    return cells <= size.width ? [] : [`line ${at + 1} drawn ${cells} cells wide for ${size.width} columns`]
  }),
]
