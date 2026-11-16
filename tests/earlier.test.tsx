import type { SitrepPane } from '../types'
import { expect, test, tier } from './kit'
import type { Body } from '../core'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { HOUR, MIN, T0, W2 } from './data'
import { choiceAsk, delivered, file, reply, resolve, yesAsk, type Line } from './lines'
import { HELD } from './filing'
import { heldItem, pane, sceneFrom, type Drawn } from './render'
import { ACROSS, DOCKED, postedId, world, type World } from './world'

tier('user')

/** Now, five hours after the asks were posted. */
const NOW = T0 + 5 * HOUR

/** Lines a second window on the session wrote, as of `hours` after the asks. */
const after = (hours: number, ...bodies: Body[]): Line[] =>
  bodies.map((body): Line => [T0 + hours * HOUR, body])

/**
 * This session's asks, closed an hour apart, through a second window on
 * the session: a review Lee approved, a decision Lee chose on, one Claude
 * resolved saying why, one Lee commented on that Claude then resolved; and
 * one Lee ignored.
 */
const CLOSED: readonly Line[] = [
  ...after(
    0,
    yesAsk('a1', 'Review round 1'),
    choiceAsk('a2', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
    yesAsk('a3', 'Run the apply', 'Done'),
    yesAsk('a4', 'Review round 2'),
    yesAsk('a5', 'Try the flow', 'It works'),
  ),
  ...after(1, reply('r1', 'a1', 'yes'), delivered('r1')),
  ...after(2, reply('r2', 'a2', 'choose', { option: 'Forever' }), delivered('r2')),
  ...after(3, resolve('a3', 'Ran it in the chat')),
  ...after(3, reply('r3', 'a4', 'comment', { note: 'Tighten the gaps' }), delivered('r3')),
  ...after(3, reply('r4', 'a5', 'ignore'), delivered('r4')),
  ...after(4, resolve('a4')),
]

/** The closed asks in a world: the second window's file written, the watch reading it, the board opened. */
async function closedAsks(w: World) {
  const { id, paths } = await w.begin()

  w.put(paths.log(W2), file(...CLOSED))
  await w.clock.advance(WATCH_MS)

  return { id, ui: await w.opened() }
}

/** The board drawn as the watch leaves it once the second window wrote `lines`, the pane as given. */
const drawnAfter = (lines: readonly Line[], shown: Partial<SitrepPane> = {}, now = NOW) =>
  pane(sceneFrom({ lines, writer: W2, pane: shown, now: now + WATCH_MS }))

/** RESOLVED shown in full. */
const IN_FULL = { resolvedInFull: HELD.id }

/** A closed ask opened, by the key its press selects. */
const opening = (id: string) => ({ selected: `resolved:${heldItem(id)}` })

/** The closed asks RESOLVED lists, by key, in the order drawn. */
const listed = async (ui: Drawn) =>
  (await ui.findAll({ type: 'Box' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith('closed:'))

test('RESOLVED counts the closed asks, ignored ones aside, the newest closed first, each a line with when it closed', async () => {
  const folded = drawnAfter(CLOSED)

  expect(await folded.find({ type: 'Text', text: '4 resolved' })).toBeDefined()
  expect(await listed(folded)).toEqual([
    `closed:${heldItem('a4')}`,
    `closed:${heldItem('a3')}`,
    `closed:${heldItem('a2')}`,
  ])

  const ui = drawnAfter(CLOSED, IN_FULL)
  const across = async (key: string) => rowsOf(await ui.find({ key }), ACROSS)

  expect(await listed(ui)).toEqual([
    `closed:${heldItem('a4')}`,
    `closed:${heldItem('a3')}`,
    `closed:${heldItem('a2')}`,
    `closed:${heldItem('a1')}`,
  ])
  expect(await across(`closed:${heldItem('a4')}`)).toEqual([
    '✓ Review round 2                                    1h',
  ])
  expect(await across(`closed:${heldItem('a3')}`)).toEqual([
    '✓ Run the apply                                     2h',
  ])
  expect(await across(`closed:${heldItem('a2')}`)).toEqual([
    '✓ Keep the ledger 400 days, or forever?             3h',
  ])
  expect(await across(`closed:${heldItem('a1')}`)).toEqual([
    '✓ Review round 1                                    4h',
  ])
})

test('a closed ask opens to how it closed, one branch from its tick with no age in it', async () => {
  const opened = async (ask: string, shown: Partial<SitrepPane> = {}) => {
    const ui = drawnAfter(CLOSED, { ...shown, ...opening(ask) })

    return rowsOf(await ui.find({ key: `closed:${heldItem(ask)}` }), ACROSS).slice(1)
  }

  expect(await opened('a4')).toEqual(['└ resolved by Claude'])
  expect(await opened('a3')).toEqual(['└ resolved by Claude: Ran it in the chat'])
  expect(await opened('a2')).toEqual(['└ → Forever'])
  expect(await opened('a1', IN_FULL)).toEqual(['└ → Approve'])
})

test('RESOLVED shows the latest 3 under a dim show all; shown in full, it lists every one under a dim show fewer', async () => {
  const toggle = async (ui: Drawn) => (await ui.find({ key: `earlier:${HELD.id}` }))?.props
  const folded = drawnAfter(CLOSED)
  const inFull = drawnAfter(CLOSED, IN_FULL)

  expect(await toggle(folded)).toMatchObject({ label: 'show all 4', plain: true, dimColor: true })
  expect(await folded.find({ type: 'Text', text: 'show all 4' })).toBeUndefined()
  expect(await listed(folded)).toHaveLength(3)

  expect(await toggle(inFull)).toMatchObject({ label: 'show fewer', dimColor: true })
  expect(await listed(inFull)).toHaveLength(4)
})

test('RESOLVED is a section of its own at the foot of the view, its heading green, drawn only once an ask has closed', async () => {
  const asked = after(0, yesAsk('a1', 'Review round 1'))
  const heading = async (ui: Drawn) => ui.find({ type: 'Text', text: 'RESOLVED' })

  expect(await heading(drawnAfter(asked))).toBeUndefined()

  const ui = drawnAfter([...asked, ...after(1, reply('r1', 'a1', 'yes'), delivered('r1'))])
  const rows = rowsOf(await ui.find({ type: 'Box' }), DOCKED.bodyColumns)

  expect((await heading(ui))?.props).toMatchObject({ color: C.ok, bold: true })
  expect(await ui.find({ type: 'Text', text: '1 resolved' })).toBeDefined()
  expect(
    await ui.find({ key: `earlier:${HELD.id}` }),
    'no more than 3, so nothing to show all',
  ).toBeUndefined()
  expect(rows.slice(-2), 'under NOTES, the last of the view').toEqual([
    expect.stringMatching(/^ RESOLVED ─+ 1 resolved$/),
    ' ✓ Review round 1                                    4h',
  ])
})

test('ASKS holds only what is open: no line of what was done earlier', async () => {
  const ui = drawnAfter(CLOSED)
  const texts = [
    ...(await ui.findAll({ type: 'Text' })),
    ...(await ui.findAll({ type: 'Button' })),
  ].map(each => each.text)

  expect(texts.filter(text => /done earlier/.test(text))).toEqual([])
  expect(await ui.find({ type: 'Text', text: 'Nothing waiting on you.' })).toBeDefined()
})

test('each closed ask is a green tick and a white title, its age grey; a long title keeps to one line until opened', async () => {
  const title =
    'Check every part of the help desk redesign, every area of it, against the brief and the notes'
  const lines = [
    ...after(0, yesAsk('a1', title)),
    ...after(4, reply('r1', 'a1', 'yes'), delivered('r1')),
  ]
  const ui = drawnAfter(lines)
  const press = async () => (await ui.find({ key: `resolved:${heldItem('a1')}` }))?.props
  const drawn = async (drawing: Drawn) =>
    rowsOf(await drawing.find({ key: `closed:${heldItem('a1')}` }), ACROSS)

  expect((await ui.find({ type: 'Text', text: '✓' }))?.props.color).toBe(C.ok)
  expect(await press()).toMatchObject({ plain: true, label: expect.stringMatching(/…$/) })
  expect((await press())?.dimColor).toBeUndefined()
  expect((await ui.find({ type: 'Text', text: '1h' }))?.props.color).toBe(C.grey)
  expect(await drawn(ui), 'closed, a line of its own, nothing hung').toEqual([
    '✓ Check every part of the help desk redesign, e…    1h',
  ])

  const opened = drawnAfter(lines, opening('a1'))

  expect(await drawn(opened)).toEqual([
    '✓ Check every part of the help desk redesign,       1h',
    '│ every area of it, against the brief and the',
    '│ notes',
    '└ → Approve',
  ])
  expect((await opened.find({ type: 'Text', text: '→ Approve' }))?.props.color).toBe(C.soft)
})

test('closing the board folds RESOLVED back to the latest 3', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const band = await w.band()

  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.resolvedInFull).toBe(id)
  expect(await listed(ui)).toHaveLength(4)

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })

  expect(w.state.pane?.resolvedInFull).toBeNull()
  expect(await listed(ui)).toHaveLength(3)
  expect(await ui.find({ key: `closed:${w.item('a1')}` })).toBeUndefined()
})

test('RESOLVED shown in full stays so while items open and close, in RESOLVED or elsewhere on the board; only its toggle folds it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const note = postedId(await w.call('note', { text: 'PR #82 merged' }))
  const toggle = async () => (await ui.find({ key: `earlier:${id}` }))?.props.label

  await ui.press({ key: `earlier:${id}` })

  for (const press of [
    `resolved:${w.item('a4')}`,
    `resolved:${w.item('a4')}`,
    `log:${w.item(note)}`,
  ]) {
    await ui.press({ key: press })
    expect(await listed(ui), press).toHaveLength(4)
    expect(await toggle(), press).toBe('show fewer')
  }

  await ui.press({ key: `earlier:${id}` })
  expect(await listed(ui)).toHaveLength(3)
  expect(await toggle()).toBe('show all 4')
})

test('a closed ask opens and closes by its own key, as any item, and closing the board closes it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { ui } = await closedAsks(w)
  const band = await w.band()
  const branch = async () => ui.find({ type: 'Text', text: 'resolved by Claude' })

  await ui.press({ key: `resolved:${w.item('a4')}` })
  expect(w.state.pane?.selected).toBe(`resolved:${w.item('a4')}`)
  expect(await branch()).toBeDefined()

  await ui.press({ key: `resolved:${w.item('a4')}` })
  expect(w.state.pane?.selected).toBeNull()
  expect(await branch()).toBeUndefined()

  await ui.press({ key: `resolved:${w.item('a4')}` })
  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })

  expect(w.state.pane?.selected).toBeNull()
  expect(await branch()).toBeUndefined()
})

test('folding RESOLVED back closes an opened ask it no longer shows; one it still shows stays open', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)

  await ui.press({ key: `earlier:${id}` })
  await ui.press({ key: `resolved:${w.item('a1')}` })
  expect(await listed(ui)).toHaveLength(4)
  expect(await ui.find({ type: 'Text', text: '→ Approve' })).toBeDefined()

  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.selected).toBeNull()
  expect(await listed(ui)).toHaveLength(3)

  await ui.press({ key: `earlier:${id}` })
  await ui.press({ key: `resolved:${w.item('a4')}` })
  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.selected).toBe(`resolved:${w.item('a4')}`)
  expect(await listed(ui)).toHaveLength(3)
  expect(await ui.find({ type: 'Text', text: 'resolved by Claude' })).toBeDefined()
})

test('a pane an older load saved, knowing nothing of RESOLVED shown in full, shows RESOLVED folded', async ($, on) => {
  const w = world($, on, { now: NOW })
  const saved = { isOpen: false, place: null, selected: null }
  let isWritten = false

  // What an older load left in $.state, read until this load first writes the pane over it.
  on('state.get', { plugin: 'sitrep', key: 'pane' }, ($, e, next) =>
    isWritten ? next(e) : { value: { value: saved, version: 0 } },
  )
  on('state.set', { plugin: 'sitrep', key: 'pane' }, ($, e, next) => {
    isWritten = true

    return next(e)
  })

  const { id, ui } = await closedAsks(w)

  expect(await listed(ui)).toHaveLength(3)
  expect((await ui.find({ key: `earlier:${id}` }))?.props.label).toBe('show all 4')

  await ui.press({ key: `earlier:${id}` })
  expect(await listed(ui)).toHaveLength(4)
})

test("an ask Lee commented on and Claude then resolved goes straight to RESOLVED, never lingering as Lee's send", async () => {
  const ui = drawnAfter(
    [
      [T0, yesAsk('a1', 'Review round 1')],
      [T0 + MIN, reply('r1', 'a1', 'comment', { note: 'Tighten the gaps' })],
      [T0 + MIN, delivered('r1')],
      [T0 + 2 * MIN - 1_000, resolve('a1', 'Tightened them')],
    ],
    {},
    T0 + 2 * MIN,
  )

  expect(await ui.find({ key: `pick:${heldItem('a1')}` })).toBeUndefined()
  expect(await ui.find({ key: 'sent:a1' })).toBeUndefined()
  expect(await ui.find({ key: `closed:${heldItem('a1')}` })).toBeDefined()
})
