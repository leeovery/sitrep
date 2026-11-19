import { expect, test } from './kit'
import { countdown, NEW_MS, viewOf, type PanelRow, type ViewState } from '../cli/panel/view'
import {
  type Feed,
  type Row,
  type RowKind,
  type RowLine,
  type SnoozedKind,
  type SnoozedRow,
} from '../core'
import { DAY, HOUR, MIN, T0 } from './data'
import { inZone, LONDON, wallClock } from './zoned'

const NOW = T0 + DAY

const SECTIONS: Record<RowKind, Row['section']> = {
  ask: 'needsYou',
  permission: 'needsYou',
  question: 'needsYou',
  working: 'working',
  onItsWork: 'working',
  yourTurn: 'yourTurn',
}

type Made = { name?: string; project?: string; lines?: number; since?: number; isAway?: boolean }

/** Help desk redesign's row in Northwind: `lines` lines of the kind given, the newest first, saying `first`. */
const row = (
  is: RowKind,
  first: RowLine = { lead: 'Review the help desk' },
  { name = 'Help desk redesign', project = 'Northwind', lines = 1, since = NOW - 12 * MIN, isAway = false }: Made = {},
): Row => ({
  session: 'sr-nw0001',
  section: SECTIONS[is],
  isAway,
  project: 'northwind',
  name,
  projectName: project,
  letters: 'No',
  second: `${project} · ${name}`,
  lines: Array.from({ length: lines }, (_, at) => ({
    key: `${is}:sr-nw0001:${at}`,
    is,
    first,
    since: since - at * MIN,
  })),
  since,
})

/** Shift schedules' row in Snoozed, of lines of the kinds given, waking at `wakesAt`. */
const snoozed = (kinds: SnoozedKind[], wakesAt?: number): SnoozedRow => ({
  session: 'sr-co0002',
  isAway: false,
  project: 'contoso',
  name: 'Shift schedules',
  projectName: 'Contoso',
  letters: 'Co',
  second: 'Contoso · Shift schedules',
  lines: kinds.map((is, at) => ({
    key: `${is === 'ask' ? 'ask' : 'turn'}:sr-co0002:${at}`,
    is,
    first: { lead: 'Approve the rota' },
    since: T0,
  })),
  ...(wakesAt === undefined ? {} : { wakesAt }),
})

const feedOf = (rows: Row[], asleep: SnoozedRow[] = []): Feed => ({
  head: { needYou: 0, sessions: rows.length },
  rows,
  snoozed: asleep,
  projects: [],
  windows: [],
})

const STATE: ViewState = { top: 0, isSnoozedOpen: false, board: 'read', arrivals: new Map() }

const NONE: ReadonlySet<string> = new Set()

/** The rows of a view of these, in its order. */
const rowsOf = (feed: Feed, { state = STATE, now = NOW, notHere = NONE } = {}): PanelRow[] =>
  viewOf(feed, state, now, notHere).sections.flatMap(each => each.rows)

/** The one row a view of this one shows. */
const only = (made: Row | SnoozedRow, options: Parameters<typeof rowsOf>[1] = {}) => {
  const [shown] = rowsOf('section' in made ? feedOf([made]) : feedOf([], [made]), options)

  return shown
}

test('a status line joins its lead and what it acts on with a space, a permission prompt with a colon', () => {
  expect(only(row('working', { lead: 'Running', mono: 'npm test' }))?.status).toEqual({
    text: 'Running npm test',
  })
  expect(only(row('onItsWork', { lead: 'Waiting on', subject: '3 agents' }))?.status).toEqual({
    text: 'Waiting on 3 agents',
  })
  expect(only(row('permission', { lead: 'Allow Bash', mono: 'psql -f import.sql' }))?.status).toEqual({
    text: 'Allow Bash: psql -f import.sql',
  })
  expect(only(row('permission', { lead: 'A permission prompt' }))?.status).toEqual({
    text: 'A permission prompt',
  })
})

test("a question's +2 comes apart from its words, as a number", () => {
  expect(only(row('question', { lead: 'Which layout?', more: '+2' }))?.status).toEqual({
    text: 'Which layout?',
    more: 2,
  })
})

test('a wake counts down to its time: Wakes in 12m, Wakes now once due, Wakes alone with no time', () => {
  const wake = (until?: number) =>
    only(row('onItsWork', { lead: 'Wakes', ...(until === undefined ? {} : { until }) }))?.status.text

  expect([wake(NOW + 12 * MIN), wake(NOW), wake()]).toEqual(['Wakes in 12m', 'Wakes now', 'Wakes'])
})

test("a countdown reads as the app's: up to the whole minute, then in whole units, now once due", () => {
  const left = [720_000, 690_000, 660_001, 660_000, 30_000, 1, 0, -5_000, 5_400_000, 90_000_000]

  expect(left.map(each => countdown(NOW + each, NOW))).toEqual([
    'in 12m',
    'in 12m',
    'in 12m',
    'in 11m',
    'in 1m',
    'in 1m',
    'now',
    'now',
    'in 1h',
    'in 1d',
  ])
})

test('a row in Needs you or Working reads its time as ago gives it, from its newest line', () => {
  const times = [
    row('ask', undefined, { since: NOW - 30_000 }),
    row('yourTurn', undefined, { since: NOW - 12 * MIN }),
    row('working', undefined, { since: NOW - 2 * HOUR }),
    row('onItsWork', undefined, { since: NOW - 3 * DAY }),
  ]

  expect(times.map(each => only(each)?.time)).toEqual(['now', '12m', '2h', '3d'])
  expect(only(row('ask', undefined, { lines: 3, since: NOW - 5 * MIN }))?.time).toBe('5m')
})

test('a row in Snoozed reads when it wakes, as wakeWords says it, or until it moves', () => {
  const local = wallClock(LONDON)
  const now = local(2026, 11, 19, 10)
  const at = (wakesAt?: number) =>
    inZone(LONDON, () => only(snoozed(['ask'], wakesAt), { state: { ...STATE, isSnoozedOpen: true }, now })?.time)

  expect([at(local(2026, 11, 19, 14)), at(local(2026, 11, 20, 9)), at(local(2026, 11, 21, 9)), at()]).toEqual([
    '14:00',
    'tomorrow 09:00',
    'Sat 09:00',
    'until it moves',
  ])
})

test("each row's mark says what it is: an ask, Stopped, working or on its own work; in Snoozed, its state's", () => {
  const marks = rowsOf(
    feedOf(
      [row('question'), row('yourTurn'), row('working'), row('onItsWork')],
      [snoozed(['ask', 'yourTurn']), snoozed(['yourTurn'])],
    ),
  ).map(each => [each.mark, each.isSnoozed])

  expect(marks).toEqual([
    ['ask', false],
    ['turn', false],
    ['working', false],
    ['onItsWork', false],
    ['ask', true],
    ['turn', true],
  ])
})

test("a row is away where no window holds its session or this Mac doesn't show it, here otherwise", () => {
  expect(only(row('ask'))?.isAway).toBe(false)
  expect(only(row('ask', undefined, { isAway: true }))?.isAway).toBe(true)
  expect(only(row('yourTurn'), { notHere: new Set(['sr-nw0001']) })?.isAway).toBe(true)
  expect(only(snoozed(['ask']), { notHere: new Set(['sr-co0002']) })?.isAway).toBe(true)
})

test('a row with more than one line counts them beside its name; one of one line has no count', () => {
  expect(only(row('ask', undefined, { lines: 3 }))).toMatchObject({ name: 'Help desk redesign', count: 3 })
  expect(only(row('ask'))).not.toHaveProperty('count')
  expect(only(snoozed(['ask', 'ask']))?.count).toBe(2)
})

test("a row shows its session's name and its project's", () => {
  expect(only(row('working', undefined, { name: 'Invoice ledger', project: 'Fabrikam' }))).toMatchObject({
    session: 'sr-nw0001',
    name: 'Invoice ledger',
    project: 'Fabrikam',
  })
})

test('a line new to Needs you makes its row new for two seconds from the first view that showed it', () => {
  const arrived = (at: number) => ({ ...STATE, arrivals: new Map([['ask:sr-nw0001:1', at]]) })
  const isNew = (now: number, made = row('ask', undefined, { lines: 2 })) =>
    only(made, { state: arrived(NOW), now })?.isNew

  expect([isNew(NOW), isNew(NOW + NEW_MS - 1), isNew(NOW + NEW_MS)]).toEqual([true, true, false])
  expect(only(row('ask', undefined, { lines: 2 }))?.isNew).toBe(false)
  expect(NEW_MS).toBe(2_000)
})

test("a row in Snoozed is never new, though it shares an ask's key", () => {
  const state = { ...STATE, isSnoozedOpen: true, arrivals: new Map([['ask:sr-co0002:0', NOW]]) }

  expect(only(snoozed(['ask']), { state })?.isNew).toBe(false)
})

test('shown text has its control characters dropped and comes on one line', () => {
  const shown = only(
    row(
      'permission',
      { lead: 'Allow\u0007 Bash', mono: 'psql\u001b[2J -f\nimport.sql\u009b' },
      { name: 'Help\u001b[31m desk\r\nredesign\u007f', project: '\tNorthwind\u0085' },
    ),
  )

  expect(shown).toMatchObject({
    name: 'Help[31m desk redesign',
    project: 'Northwind',
    status: { text: 'Allow Bash: psql[2J -f import.sql' },
  })
})

test('Snoozed is open as the state says, Needs you and Working always', () => {
  const feed = feedOf([row('ask'), row('working')], [snoozed(['ask'])])
  const opened = (isSnoozedOpen: boolean) =>
    viewOf(feed, { ...STATE, isSnoozedOpen }, NOW, NONE).sections.map(each => [each.kind, each.isOpen])

  expect(opened(false)).toEqual([
    ['needsYou', true],
    ['working', true],
    ['snoozed', false],
  ])
  expect(opened(true).at(-1)).toEqual(['snoozed', true])
})

test("the view carries the state's band, scroll, answer and board, and the sections' counts", () => {
  const state: ViewState = { ...STATE, band: 'sr-nw0001', top: 3, answer: 'Opened', board: 'stale' }
  const view = viewOf(feedOf([row('ask', undefined, { lines: 2 })]), state, NOW, NONE)

  expect(view).toMatchObject({ band: 'sr-nw0001', top: 3, answer: 'Opened', board: 'stale' })
  expect(view.sections[0]?.counts).toEqual([{ value: 2, need: 'ask' }])
  expect(viewOf(feedOf([]), STATE, NOW, NONE)).toEqual({ sections: [], top: 0, board: 'read' })
})
