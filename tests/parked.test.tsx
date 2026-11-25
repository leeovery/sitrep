/**
 * PARKED folded to its first 3, as RESOLVED is (DESIGN.md, "Parked"): `show
 * all` lists every item, `show fewer` folds it again, and an item Lee is
 * acting on shows though folded, in its place.
 */
import type { SitrepPane } from '../types'
import { expect, test, tier } from './kit'
import {
  historyList,
  isCarriedAsShown,
  oldList,
  parkedList,
  pickedUpList,
  projectScope,
  resolvedList,
} from '../hooks/lists'
import { itemKey, projectPlace } from '../hooks/places'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { HELD, heldItem, LEDGER, MIN, PROJECT, T0, W2 } from './data'
import { file, park, reply, type Line } from './lines'
import { pane, sceneFrom, type Desk, type Drawn } from './render'
import { world } from './world'

tier('user')

const NOW = T0 + 10 * MIN

/** PARKED's list: the project's, which every view of it draws. */
const PARKED = parkedList(projectScope(PROJECT.key))

/** The press that shows every parked item, and fewer again. */
const TOGGLE = `all:${PARKED}`

/** Lines a minute apart, the first at T0. */
const minutely = (...lines: Line[1][]) => lines.map((body, i): Line => [T0 + i * MIN, body])

/** Items this session parked, `p1` onwards. */
const own = (count: number) =>
  minutely(...Array.from({ length: count }, (_, i) => park(`p${i + 1}`, `Own item ${i + 1}`)))

/** The ledger, another session of the project, with two items it parked before this session's. */
const AROUND: Desk['around'] = [
  {
    meta: LEDGER,
    lines: [
      [T0 - 2 * MIN, park('p1', 'Archive old invoices')],
      [T0 - MIN, park('p2', 'Rename the shift report')],
    ],
    seenAt: T0,
  },
]

const ledgerItem = (id: string) => itemKey(LEDGER.id, id)

/** The board drawn: this session's `count` items and the ledger's two, home unless told, the rest of the desk as given. */
const drawn = (count: number, desk: Desk = {}) =>
  pane(sceneFrom({ lines: own(count), around: AROUND, now: NOW, ...desk }))

/** What PARKED draws, by key, in order: its items, by their address, and its `from other sessions`. */
const listed = async (ui: Drawn) =>
  (await ui.findAll({ type: 'Box' }))
    .map(each => String(each.key ?? ''))
    .filter(key => key.startsWith('block:parked:'))
    .map(key => key.slice('block:parked:'.length))

const toggle = async (ui: Drawn) => (await ui.find({ key: TOGGLE }))?.props

const IN_FULL: Partial<SitrepPane> = { shown: { [PARKED]: 'all' } }

test("PARKED shows its first 3, the session's own first, under a dim show all counting every item; its heading counts every one", async () => {
  const ui = drawn(3)
  const rows = rowsOf(await ui.find({ type: 'Box' }))

  expect(await listed(ui)).toEqual([heldItem('p1'), heldItem('p2'), heldItem('p3')])
  expect(await toggle(ui)).toMatchObject({ label: 'show all 5', plain: true, dimColor: true })
  expect(rows.find(row => row.startsWith(' PARKED'))).toMatch(/ 5 to come back to$/)
})

test('shown in full, PARKED lists every item, from other sessions before the first another parked, under a dim show fewer', async () => {
  const ui = drawn(3, { pane: IN_FULL })

  expect(await listed(ui)).toEqual([
    heldItem('p1'),
    heldItem('p2'),
    heldItem('p3'),
    'others',
    ledgerItem('p1'),
    ledgerItem('p2'),
  ])
  expect(await toggle(ui)).toMatchObject({ label: 'show fewer', plain: true, dimColor: true })
})

test('folded, from other sessions shows only where an item after it shows', async () => {
  expect(await listed(drawn(2))).toEqual([
    heldItem('p1'),
    heldItem('p2'),
    'others',
    ledgerItem('p1'),
  ])
  expect(await listed(drawn(3)), 'none of the others shown').not.toContain('others')
})

test("a project's view folds its PARKED the same, the oldest first, each naming its session", async () => {
  const ui = drawn(3, { pane: { place: projectPlace(PROJECT.key) } })

  expect(await listed(ui)).toEqual([ledgerItem('p1'), ledgerItem('p2'), heldItem('p1')])
  expect(await toggle(ui)).toMatchObject({ label: 'show all 5' })
})

test('PARKED of 3 items or fewer has no show all', async () => {
  const ui = pane(sceneFrom({ lines: own(3), now: NOW }))

  expect(await listed(ui)).toHaveLength(3)
  expect(await toggle(ui)).toBeUndefined()
})

/** What Lee is acting on past the fold, the ledger's second item: as the desk holds it. */
const ACTING_ON: Record<string, Desk> = {
  open: { pane: { selected: ledgerItem('p2') } },
  'asking to drop it': { pane: { selected: `drop:${ledgerItem('p2')}` } },
  'in answering': {
    answering: {
      project: PROJECT.key,
      session: LEDGER.id,
      item: 'p2',
      as: 'pickup',
      title: 'Rename the shift report',
      surface: 'terminal',
    },
  },
  'its pick-up queued in Ready to send': {
    queue: [{ project: PROJECT.key, session: LEDGER.id, item: 'p2', verdict: 'pickup' }],
  },
}

for (const [acting, desk] of Object.entries(ACTING_ON)) {
  test(`folded, an item past the first 3 shows in its place while ${acting}, from other sessions before it`, async () => {
    expect(await listed(drawn(3, desk))).toEqual([
      heldItem('p1'),
      heldItem('p2'),
      heldItem('p3'),
      'others',
      ledgerItem('p2'),
    ])
  })
}

test('folded, an item past the first 3 shows in its place while its pick-up is on its way', async () => {
  const lines = [...own(5), [T0 + 6 * MIN, reply('r1', 'p5', 'pickup')] satisfies Line]
  const ui = pane(sceneFrom({ lines, now: NOW }))

  expect(await listed(ui)).toEqual([heldItem('p1'), heldItem('p2'), heldItem('p3'), heldItem('p5')])
  expect(await toggle(ui)).toMatchObject({ label: 'show all 5' })
})

test('show fewer keeps an item opened past the first 3 open and shown; closed, it folds away; closing the board folds PARKED', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { paths } = await w.begin()

  w.put(paths.log(W2), file(...own(5)))
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()
  const band = await w.band()
  const fifth = w.item('p5')
  const shownItems = async () => (await listed(ui)).filter(key => key !== 'others')

  await ui.press({ key: TOGGLE })
  expect(w.state.pane?.shown?.[PARKED]).toBe('all')
  await ui.press({ key: `ppick:${fifth}` })

  await ui.press({ key: TOGGLE })
  expect(w.state.pane?.shown?.[PARKED]).toBeUndefined()
  expect(w.state.pane?.selected, 'what Lee is acting on stays open').toBe(fifth)
  expect(await shownItems()).toEqual([w.item('p1'), w.item('p2'), w.item('p3'), fifth])

  await ui.press({ key: `ppick:${fifth}` })
  expect(await shownItems()).toHaveLength(3)

  await ui.press({ key: TOGGLE })
  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })
  expect(w.state.pane?.shown?.[PARKED]).toBeUndefined()
  expect(await shownItems()).toHaveLength(3)
  expect(await toggle(ui)).toMatchObject({ label: 'show all 5' })
})

test("PARKED's press reads no look again: the look carries every parked item; only picked up and old sessions are carried as shown", () => {
  const project = projectScope(PROJECT.key)

  expect(isCarriedAsShown(pickedUpList(project))).toBe(true)
  expect(isCarriedAsShown(oldList(project))).toBe(true)
  expect(isCarriedAsShown(parkedList(project))).toBe(false)
  expect(isCarriedAsShown(historyList(HELD.id))).toBe(false)
  expect(isCarriedAsShown(resolvedList(HELD.id))).toBe(false)
})
