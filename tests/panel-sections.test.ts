import { expect, test } from './kit'
import {
  panelSections,
  type Feed,
  type Row,
  type RowKind,
  type SnoozedKind,
  type SnoozedRow,
} from '../core'
import { MIN, T0 } from './data'

const SECTIONS: Record<RowKind, Row['section']> = {
  ask: 'needsYou',
  permission: 'needsYou',
  question: 'needsYou',
  working: 'working',
  onItsWork: 'working',
  yourTurn: 'yourTurn',
}

/** A session's row of `lines` lines of the kind given, the newest at `since`; the rest made up. */
const row = (session: string, is: RowKind, since = T0, { lines = 1, isAway = false } = {}): Row => ({
  session,
  section: SECTIONS[is],
  isAway,
  project: 'northwind',
  name: session,
  projectName: 'Northwind',
  letters: 'No',
  second: `Northwind · ${session}`,
  lines: Array.from({ length: lines }, (_, at) => ({
    key: `${is}:${session}:${at}`,
    is,
    first: { lead: session },
    since: since - at * MIN,
  })),
  since,
})

/** A session's row in Snoozed, of lines of the kinds given. */
const snoozed = (session: string, kinds: SnoozedKind[], isAway = false): SnoozedRow => ({
  session,
  isAway,
  project: 'northwind',
  name: session,
  projectName: 'Northwind',
  letters: 'No',
  second: `Northwind · ${session}`,
  lines: kinds.map((is, at) => ({ key: `${is}:${session}:${at}`, is, first: { lead: session }, since: T0 })),
})

/** A feed of these rows, in the order core gives them. */
const feedOf = (rows: Row[], asleep: SnoozedRow[] = []): Feed => ({
  head: { needYou: 0, sessions: rows.length },
  rows,
  snoozed: asleep,
  projects: [],
  windows: [],
})

const NONE: ReadonlySet<string> = new Set()

/** Litware with one ask and Tailspin with three; two at your turn; one working and one on its own work. */
const BOARD = [
  row('litware', 'ask'),
  row('tailspin', 'question', T0, { lines: 3 }),
  row('wingtip', 'yourTurn'),
  row('fabrikam', 'yourTurn'),
  row('doc', 'working'),
  row('boot', 'onItsWork'),
]

/** Tailspin's two asks asleep, beside its row in Needs you. */
const ASLEEP = snoozed('tailspin', ['ask', 'ask'])

const sessionsOf = (sections: ReturnType<typeof panelSections>) =>
  sections.map(({ kind, rows }) => [kind, rows.map(each => each.session)])

test("Needs you holds its asks then its Stopped, each those this Mac shows before the away ones, in core's order; a session this Mac doesn't show leads the away ones", () => {
  const rows = [
    row('newAsk', 'ask', T0 + 6 * MIN),
    row('heldAsk', 'permission', T0 + 5 * MIN),
    row('oldAsk', 'ask', T0 + 4 * MIN),
    row('awayAsk', 'ask', T0 + 9 * MIN, { isAway: true }),
    row('newTurn', 'yourTurn', T0 + 8 * MIN),
    row('heldTurn', 'yourTurn', T0 + 7 * MIN),
    row('oldTurn', 'yourTurn', T0 + MIN),
    row('doc', 'working', T0 + 2 * MIN),
    row('boot', 'onItsWork', T0 + 3 * MIN),
  ]
  const sections = panelSections(feedOf(rows), new Set(['heldAsk', 'heldTurn']))

  expect(sessionsOf(sections)).toEqual([
    [
      'needsYou',
      ['newAsk', 'oldAsk', 'heldAsk', 'awayAsk', 'newTurn', 'oldTurn', 'heldTurn'],
    ],
    ['working', ['doc', 'boot']],
  ])
  expect(sections[0]?.rows.filter(each => each.isAway).map(each => each.session)).toEqual([
    'heldAsk',
    'awayAsk',
    'heldTurn',
  ])
})

test("with every session shown, Needs you keeps core's order, asks before Stopped", () => {
  expect(sessionsOf(panelSections(feedOf(BOARD), NONE))).toEqual([
    ['needsYou', ['litware', 'tailspin', 'wingtip', 'fabrikam']],
    ['working', ['doc', 'boot']],
  ])
})

test("Working keeps core's order, working then on its own work", () => {
  const rows = [row('later', 'working'), row('sooner', 'working'), row('waking', 'onItsWork')]

  expect(sessionsOf(panelSections(feedOf(rows), NONE))).toEqual([
    ['working', ['later', 'sooner', 'waking']],
  ])
})

test("Snoozed is last, in core's order, a session there beside its row in another section, and away where this Mac doesn't show it", () => {
  const asleep = [snoozed('fabrikam', ['yourTurn']), ASLEEP, snoozed('contoso', ['ask'], true)]
  const sections = panelSections(feedOf(BOARD, asleep), new Set(['fabrikam']))

  expect(sessionsOf(sections).at(-1)).toEqual(['snoozed', ['fabrikam', 'tailspin', 'contoso']])
  expect(sections.at(-1)?.rows.map(each => each.isAway)).toEqual([true, false, true])
  expect(sections[0]?.rows.map(each => each.session)).toContain('tailspin')
})

test('Needs you counts its asks, the lines of its ask rows, and its Stopped, its rows, apart, the asks first', () => {
  expect(panelSections(feedOf(BOARD), NONE).map(each => each.counts)).toEqual([
    [
      { value: 4, need: 'ask' },
      { value: 2, need: 'turn' },
    ],
    [{ value: 2 }],
  ])
})

test('each of Needs you\'s counts shows only above zero', () => {
  const asks = BOARD.filter(each => each.section === 'needsYou')
  const stopped = BOARD.filter(each => each.section === 'yourTurn')

  expect(panelSections(feedOf(asks), NONE)[0]?.counts).toEqual([{ value: 4, need: 'ask' }])
  expect(panelSections(feedOf(stopped), NONE)[0]?.counts).toEqual([{ value: 2, need: 'turn' }])
})

test('Snoozed counts its lines, the asks asleep and the turns put off', () => {
  const asleep = [ASLEEP, snoozed('fabrikam', ['ask', 'yourTurn']), snoozed('contoso', ['yourTurn'])]

  expect(panelSections(feedOf([], asleep), NONE)).toEqual([
    { kind: 'snoozed', rows: asleep, counts: [{ value: 5 }] },
  ])
})

test('an empty section is left out, and an empty board has none', () => {
  const noneWaiting = BOARD.filter(each => each.section === 'working')

  expect(sessionsOf(panelSections(feedOf(noneWaiting, [ASLEEP]), NONE))).toEqual([
    ['working', ['doc', 'boot']],
    ['snoozed', ['tailspin']],
  ])
  expect(panelSections(feedOf([]), NONE)).toEqual([])
})

test('the feed itself is left as it was', () => {
  const feed = feedOf(BOARD, [ASLEEP])

  panelSections(feed, new Set(['litware', 'tailspin']))

  expect([...feed.rows, ...feed.snoozed].some(each => each.isAway)).toBe(false)
})
