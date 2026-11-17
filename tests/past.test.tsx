import type { SitrepPane } from '../types'
import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { projectPlace } from '../hooks/places'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { HELD, heldItem, HOUR, LEDGER, MIN, PROJECT, T0, THEMES, W2 } from './data'
import { delivered, file, park, reply, resolve, status, type Line } from './lines'
import { pane, sceneFrom, type Drawn } from './render'
import { ACROSS, DOCKED, INLINE, world } from './world'

tier('user')

/** Now, an hour after the session started. */
const NOW = T0 + HOUR

/** This session's status, changed five times a minute apart. */
const CHANGES: readonly Line[] = [
  [T0, status(['Drawing round 1'], { next: 'Round 2' })],
  [T0 + MIN, status(['Drawing round 2'])],
  [T0 + 2 * MIN, status(['Drawing round 2', 'Writing the notes'])],
  [T0 + 3 * MIN, status(['Writing the notes'], { next: 'Ship it' })],
  [T0 + 4 * MIN, status(['Shipping'], { name: HELD.name })],
]

/** One item still parked, one Lee picked up with a note, one Claude closed saying why. */
const PARKED: readonly Line[] = [
  [T0, park('p1', 'A priority badge')],
  [T0, park('p2', 'Tidy the fixtures', { ref: 'notes: tidy.md' })],
  [T0 + 5 * MIN, reply('r1', 'p2', 'pickup', { note: 'Before the release' })],
  [T0 + 5 * MIN, delivered('r1')],
  [T0, park('p3', 'Drop the old flag')],
  [T0 + 6 * MIN, resolve('p3', 'Dropped it in the PR')],
]

/** The held session's view, drawn from `lines` with the pane as given. */
const drawn = (lines: readonly Line[], shown: Partial<SitrepPane> = {}, props = DOCKED) =>
  pane(sceneFrom({ lines, now: NOW, pane: shown }), props)

/** The rows a block draws, by its key, `cells` across. */
const rowsAt = async (ui: Drawn, key: string, cells = ACROSS) =>
  rowsOf(await ui.find({ key }), cells)

/** A list shown, its latest or every one, as the pane keeps it. */
const showing = (list: string, as: 'latest' | 'all' = 'latest'): Partial<SitrepPane> => ({
  shown: { [list]: as },
})

/** The press of a list of the board's past, by its key. */
const press = async (ui: Drawn, key: string) => (await ui.find({ key }))?.props

/** The keys of the blocks drawn whose key opens with `prefix`, in order. */
const keysOf = async (ui: Drawn, prefix: string) =>
  (await ui.findAll({ type: 'Box' }))
    .map(each => String(each.key ?? ''))
    .filter(key => key.startsWith(prefix))

/** The rows of each block drawn whose key opens with `prefix`, in order, `cells` across. */
const rowsUnder = async (ui: Drawn, prefix: string, cells = ACROSS) =>
  Promise.all((await keysOf(ui, prefix)).map(key => rowsAt(ui, key, cells)))

const HISTORY = `history:${HELD.id}`
const PICKED_UP = `pickedup:${HELD.id}`

test("STATUS's history is folded under the status as a dim press counting every change; shown, the latest 3 follow a hide history, the newest first, each with its age, with show all past them", async () => {
  const folded = drawn(CHANGES)

  expect(await press(folded, HISTORY)).toMatchObject({
    label: 'show history 5',
    plain: true,
    dimColor: true,
  })
  expect(await keysOf(folded, 'change:')).toEqual([])

  const shown = drawn(CHANGES, showing(HISTORY))

  expect(await press(shown, HISTORY)).toMatchObject({ label: 'hide history', dimColor: true })
  expect(await press(shown, `all:${HISTORY}`)).toMatchObject({
    label: 'show all 5',
    dimColor: true,
  })
  expect(await rowsUnder(shown, 'change:')).toEqual([
    ['• now shipping                                     56m'],
    ['• no longer drawing round 2                        57m'],
    ['• now also writing the notes                       58m'],
  ])
})

test('the history shown in full lists every change under show fewer', async () => {
  const ui = drawn(CHANGES, showing(HISTORY, 'all'))

  expect(await rowsUnder(ui, 'change:')).toEqual([
    ['• now shipping                                     56m'],
    ['• no longer drawing round 2                        57m'],
    ['• now also writing the notes                       58m'],
    ['• now drawing round 2                              59m'],
    ['• now drawing round 1                               1h'],
  ])
  expect(await press(ui, `all:${HISTORY}`)).toMatchObject({ label: 'show fewer' })
})

test('a history of 3 changes or fewer has no show all', async () => {
  const ui = drawn(CHANGES.slice(0, 3), showing(HISTORY))

  expect(await press(ui, HISTORY)).toMatchObject({ label: 'hide history' })
  expect(await keysOf(ui, 'change:')).toHaveLength(3)
  expect(await ui.find({ key: `all:${HISTORY}` })).toBeUndefined()
})

test('a change opens to its detail, each line under its label; its mark is a faint dot', async () => {
  const change = heldItem(String(T0 + 2 * MIN))
  const ui = drawn(CHANGES, { ...showing(HISTORY), selected: `status:${change}` })

  expect(await rowsAt(ui, `change:${change}`)).toEqual([
    '• now also writing the notes                       58m',
    '├ Added: Writing the notes',
    '└ Still there: Drawing round 2',
  ])
  expect(
    (await ui.findAll({ type: 'Text', text: '•' })).map(each => each.props.color),
  ).toContain(C.faint)
})

test("PARKED's picked up is folded under what is parked as a dim press counting what was taken off it", async () => {
  const ui = drawn(PARKED)

  expect(await press(ui, PICKED_UP)).toMatchObject({
    label: 'show picked up 2',
    plain: true,
    dimColor: true,
  })
  expect(await keysOf(ui, 'taken:')).toEqual([])
  expect(await ui.find({ key: `ppick:${heldItem('p1')}` })).toBeDefined()
})

test("PARKED's picked up shown lists what was taken off, the newest first, each ticked green with its age: picked up by the session it went to, or closed by Claude", async () => {
  const ui = drawn(PARKED, showing(PICKED_UP))

  expect(await press(ui, PICKED_UP)).toMatchObject({ label: 'hide picked up', dimColor: true })
  expect(await rowsUnder(ui, 'taken:')).toEqual([
    ['✓ Drop the old flag · closed by Claude             54m'],
    ['✓ Tidy the fixtures · picked up by Help desk re…   55m'],
  ])
  expect(
    (await ui.findAll({ type: 'Text', text: '✓' })).map(each => each.props.color),
  ).toEqual([C.ok, C.ok])
})

test("an item taken off opens to Lee's note on the pick-up and its ref, or to Claude's reason for the close", async () => {
  const opened = async (id: string) =>
    rowsAt(
      drawn(PARKED, { ...showing(PICKED_UP), selected: `picked:${heldItem(id)}` }),
      `taken:${heldItem(id)}`,
    )

  expect(await opened('p2')).toEqual([
    '✓ Tidy the fixtures · picked up by Help desk       55m',
    '│ redesign',
    '├ Before the release',
    '└ see notes: tidy.md',
  ])
  expect(await opened('p3')).toEqual([
    '✓ Drop the old flag · closed by Claude             54m',
    '└ Dropped it in the PR',
  ])
})

test("picked up past the latest 3 shows them under show all, and every one shown in full", async () => {
  const more: Line[] = [
    ...PARKED,
    ...['p4', 'p5'].flatMap((id, i): Line[] => [
      [T0, park(id, `Item ${id}`)],
      [T0 + (10 + i) * MIN, resolve(id)],
    ]),
  ]
  const latest = drawn(more, showing(PICKED_UP))
  const all = drawn(more, showing(PICKED_UP, 'all'))

  expect(await press(latest, PICKED_UP)).toMatchObject({ label: 'hide picked up' })
  expect(await press(latest, `all:${PICKED_UP}`)).toMatchObject({ label: 'show all 4' })
  expect(await keysOf(latest, 'taken:')).toEqual([
    `taken:${heldItem('p5')}`,
    `taken:${heldItem('p4')}`,
    `taken:${heldItem('p3')}`,
  ])
  expect(await press(all, `all:${PICKED_UP}`)).toMatchObject({ label: 'show fewer' })
  expect(await keysOf(all, 'taken:')).toHaveLength(4)
})

test('PARKED is drawn while something was taken off though nothing is parked, saying nothing is to come back to; with neither it is not drawn', async () => {
  const taken = drawn(PARKED.filter(([, body]) => body.type !== 'park' || body.id !== 'p1'))

  expect(await taken.find({ type: 'Text', text: 'PARKED' })).toBeDefined()
  expect(await taken.find({ type: 'Text', text: 'nothing to come back to' })).toBeDefined()
  expect(await press(taken, PICKED_UP)).toMatchObject({ label: 'show picked up 2' })

  const neither = drawn(CHANGES)

  expect(await neither.find({ type: 'Text', text: 'PARKED' })).toBeUndefined()
  expect(await neither.find({ key: PICKED_UP })).toBeUndefined()
})

/** Two sessions beside this one: the ledger, held by its window, which picked up its own item; Themes, held by none, whose item was picked up by a window no session holds. */
const AROUND = [
  {
    meta: LEDGER,
    seenAt: T0,
    lines: [
      [T0 + 2 * MIN, status(['Reading the schema'], { name: LEDGER.name })],
      [T0, park('p1', 'Export as CSV')],
      [T0 + 7 * MIN, reply('r1', 'p1', 'pickup')],
      [T0 + 7 * MIN, delivered('r1')],
    ] satisfies Line[],
  },
  {
    meta: THEMES,
    lines: [
      [T0 + 3 * MIN, status(['Drawing the dark theme'], { name: THEMES.name })],
      [T0, park('p1', 'Pick the accent')],
      [T0 + 8 * MIN, reply('r1', 'p1', 'pickup')],
      [T0 + 8 * MIN, delivered('r1')],
    ] satisfies Line[],
  },
]

const PROJECT_HISTORY = `history:project:${PROJECT.key}`
const PROJECT_PICKED_UP = `pickedup:project:${PROJECT.key}`

/** The project's view, this session and the two around it, the pane as given. */
const projectDrawn = (shown: Partial<SitrepPane> = {}, props = DOCKED) =>
  pane(
    sceneFrom({
      lines: [
        ...CHANGES.slice(0, 2),
        [T0, park('p2', 'Tidy the fixtures')],
        [T0 + 5 * MIN, reply('r1', 'p2', 'pickup')],
        [T0 + 5 * MIN, delivered('r1')],
      ],
      now: NOW,
      around: AROUND,
      pane: { place: projectPlace(PROJECT.key), ...shown },
    }),
    props,
  )

test("the project's view folds its sessions' history under SESSIONS and its picked up under PARKED, each press counting across its sessions", async () => {
  const ui = projectDrawn()

  expect(await press(ui, PROJECT_HISTORY)).toMatchObject({ label: 'show history 4' })
  expect(await press(ui, PROJECT_PICKED_UP)).toMatchObject({ label: 'show picked up 3' })
  expect(await keysOf(ui, 'change:')).toEqual([])
  expect(await keysOf(ui, 'taken:')).toEqual([])
})

/** Room for a project's longest row of the past whole. */
const ROOMY = 100

test("the project's view shown names each change's session, and each item's, picked up by the session holding the window that picked it up", async () => {
  for (const props of [DOCKED, INLINE].map(each => ({ ...each, bodyColumns: ROOMY }))) {
    const ui = projectDrawn(
      { shown: { [PROJECT_HISTORY]: 'all', [PROJECT_PICKED_UP]: 'latest' } },
      props,
    )
    const rows = async (prefix: string) =>
      (await rowsUnder(ui, prefix, ROOMY - 2)).map(each => each.map(row => row.replace(/ {2,}/g, ' ')))

    expect(await rows('change:'), props.placement).toEqual([
      ['• Themes: now drawing the dark theme 57m'],
      ['• Invoice ledger: now reading the schema 58m'],
      ['• Help desk redesign: now drawing round 2 59m'],
      ['• Help desk redesign: now drawing round 1 1h'],
    ])
    expect(await rows('taken:'), props.placement).toEqual([
      ['✓ Themes: Pick the accent · picked up 52m'],
      ['✓ Invoice ledger: Export as CSV · picked up by Invoice ledger 53m'],
      ['✓ Help desk redesign: Tidy the fixtures · picked up by Help desk redesign 55m'],
    ])
    expect(await press(ui, `all:${PROJECT_HISTORY}`)).toMatchObject({ label: 'show fewer' })
  }
})

test('at the narrowest width a test draws, a row of the past keeps to its line, its words cut short before its age', async () => {
  const ui = projectDrawn(
    { shown: { [PROJECT_HISTORY]: 'latest', [PROJECT_PICKED_UP]: 'latest' } },
    { ...DOCKED, bodyColumns: 42 },
  )
  const rows = (prefix: string) => rowsUnder(ui, prefix, 40)

  expect(await rows('change:')).toEqual([
    ['• Themes: now drawing the dark th…   57m'],
    ['• Invoice ledger: now reading the…   58m'],
    ['• Help desk redesign: now drawing…   59m'],
  ])
  expect(await rows('taken:')).toEqual([
    ['✓ Themes: Pick the accent · picke…   52m'],
    ['✓ Invoice ledger: Export as CSV ·…   53m'],
    ['✓ Help desk redesign: Tidy the fi…   55m'],
  ])
})

test('the presses show a list, every one of it, fewer again, and fold it away, an opened change it stops showing closed with it; closing the board folds every list', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, paths } = await w.begin()

  w.put(paths.log(W2), file(...CHANGES, ...PARKED))
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()
  const band = await w.band()
  const shownOf = () => w.state.pane?.shown ?? {}
  const history = `history:${id}`
  const oldest = `status:${w.item(String(T0))}`

  await ui.press({ key: history })
  expect(shownOf()[history]).toBe('latest')
  await ui.press({ key: `all:${history}` })
  expect(shownOf()[history]).toBe('all')
  await ui.press({ key: oldest })
  expect(await ui.find({ type: 'Text', text: 'Round 2' })).toBeDefined()

  await ui.press({ key: `all:${history}` })
  expect(shownOf()[history], 'show fewer leaves it shown').toBe('latest')
  expect(w.state.pane?.selected, 'the oldest change no longer shows').toBeNull()

  await ui.press({ key: `pickedup:${id}` })
  await ui.press({ key: `picked:${w.item('p2')}` })
  await ui.press({ key: history })
  expect(shownOf()[history]).toBeUndefined()
  expect(w.state.pane?.selected, 'what another list opened stays open').toBe(
    `picked:${w.item('p2')}`,
  )

  await ui.press({ key: `pickedup:${id}` })
  expect(w.state.pane?.selected).toBeNull()

  await ui.press({ key: history })
  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })
  expect(shownOf()).toEqual({})
  expect(await ui.find({ key: history })).toMatchObject({ props: { label: 'show history 5' } })
})
