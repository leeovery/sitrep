import { expect, test, tier } from 'claude-code/testing'
import type { Body } from '../core'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import {
  choiceAsk,
  delivered,
  file,
  MIN,
  reply,
  resolve,
  T0,
  W2,
  yesAsk,
  type Line,
} from './support'
import { ACROSS, DOCKED, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const HOUR = 60 * MIN

/** Now, five hours after the asks were posted. */
const NOW = T0 + 5 * HOUR

/** Lines a second window on the work wrote, as of `hours` after the asks. */
const after = (hours: number, ...bodies: Body[]): Line[] =>
  bodies.map((body): Line => [T0 + hours * HOUR, body])

/**
 * This session's asks, closed an hour apart, through a second window on
 * the work: a review Lee approved, a decision Lee chose on, one Claude
 * resolved saying why, one Lee commented on that Claude then resolved; and
 * one Lee ignored.
 */
async function closedAsks(w: World) {
  const { id, paths } = await w.begin()

  w.put(
    paths.log(W2),
    file(
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
    ),
  )
  await w.clock.advance(WATCH_MS)

  return { id, ui: await w.opened() }
}

/** The closed asks DONE lists, by key, in the order drawn. */
const listed = async (ui: Awaited<ReturnType<World['opened']>>) =>
  (await ui.findAll({ type: 'Box' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith('closed:'))

test('DONE counts the closed asks, ignored ones aside, the newest closed first, each a line with when it closed', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const across = async (key: string) => rowsOf(await ui.find({ key }), ACROSS)

  expect(await ui.find({ type: 'Text', text: '4 closed' })).toBeDefined()
  expect(await listed(ui)).toEqual([
    `closed:${w.item('a4')}`,
    `closed:${w.item('a3')}`,
    `closed:${w.item('a2')}`,
  ])

  await ui.press({ key: `earlier:${id}` })

  expect(await listed(ui)).toEqual([
    `closed:${w.item('a4')}`,
    `closed:${w.item('a3')}`,
    `closed:${w.item('a2')}`,
    `closed:${w.item('a1')}`,
  ])
  expect(await across(`closed:${w.item('a4')}`)).toEqual([
    '✓ Review round 2                                    1h',
  ])
  expect(await across(`closed:${w.item('a3')}`)).toEqual([
    '✓ Run the apply                                     2h',
  ])
  expect(await across(`closed:${w.item('a2')}`)).toEqual([
    '✓ Keep the ledger 400 days, or forever?             3h',
  ])
  expect(await across(`closed:${w.item('a1')}`)).toEqual([
    '✓ Review round 1                                    4h',
  ])
})

test('a closed ask opens to how it closed, one branch from its tick with no age in it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const opened = async (ask: string) => {
    await ui.press({ key: `done:${w.item(ask)}` })

    return rowsOf(await ui.find({ key: `closed:${w.item(ask)}` }), ACROSS).slice(1)
  }

  expect(await opened('a4')).toEqual(['└ resolved by Claude'])
  expect(await opened('a3')).toEqual(['└ resolved by Claude: Ran it in the chat'])
  expect(await opened('a2')).toEqual(['└ → Forever'])

  await ui.press({ key: `earlier:${id}` })
  expect(await opened('a1')).toEqual(['└ → Approve'])
})

test('DONE shows the latest 3; show all opens it to every one, and show fewer closes it again, the toggle dim', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const toggle = async () => (await ui.find({ key: `earlier:${id}` }))?.props

  expect(await toggle()).toMatchObject({ label: 'show all 4', plain: true, dimColor: true })
  expect(await ui.find({ type: 'Text', text: 'show all 4' })).toBeUndefined()
  expect(await listed(ui)).toHaveLength(3)

  await ui.press({ key: `earlier:${id}` })
  expect(await toggle()).toMatchObject({ label: 'show fewer', dimColor: true })
  expect(await listed(ui)).toHaveLength(4)

  await ui.press({ key: `earlier:${id}` })
  expect(await toggle()).toMatchObject({ label: 'show all 4' })
  expect(await listed(ui)).toHaveLength(3)
})

test('DONE is a section of its own at the foot of the view, its heading green, drawn only once an ask has closed', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, paths } = await w.begin()
  const ui = await w.opened()
  const heading = async () => ui.find({ type: 'Text', text: 'DONE' })

  w.put(paths.log(W2), file(...after(0, yesAsk('a1', 'Review round 1'))))
  await w.clock.advance(WATCH_MS)
  expect(await heading()).toBeUndefined()

  w.put(
    paths.log(W2),
    file(
      ...after(0, yesAsk('a1', 'Review round 1')),
      ...after(1, reply('r1', 'a1', 'yes'), delivered('r1')),
    ),
  )
  await w.clock.advance(WATCH_MS)

  const rows = rowsOf(await ui.find({ type: 'Box' }), DOCKED.bodyColumns)

  expect((await heading())?.props).toMatchObject({ color: C.ok, bold: true })
  expect(await ui.find({ type: 'Text', text: '1 closed' })).toBeDefined()
  expect(
    await ui.find({ key: `earlier:${id}` }),
    'no more than 3, so nothing to show all',
  ).toBeUndefined()
  expect(rows.slice(-2), 'under LOG, the last of the view').toEqual([
    expect.stringMatching(/^ DONE ─+ 1 closed$/),
    ' ✓ Review round 1                                    4h',
  ])
})

test('For you holds only what is open: no line of what was done earlier', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { ui } = await closedAsks(w)
  const texts = [
    ...(await ui.findAll({ type: 'Text' })),
    ...(await ui.findAll({ type: 'Button' })),
  ].map(each => each.text)

  expect(texts.filter(text => /done earlier/.test(text))).toEqual([])
  expect(await ui.find({ type: 'Text', text: 'Nothing waiting on you.' })).toBeDefined()
})

test('each closed ask is a green tick and a white title, its age grey; a long title keeps to one line until opened', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { paths } = await w.begin()
  const title =
    'Review the whole of the dashboard redesign, every area of it, against the brief and the notes'

  w.put(
    paths.log(W2),
    file(...after(0, yesAsk('a1', title)), ...after(4, reply('r1', 'a1', 'yes'), delivered('r1'))),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()
  const press = async () => (await ui.find({ key: `done:${w.item('a1')}` }))?.props
  const drawn = async () => rowsOf(await ui.find({ key: `closed:${w.item('a1')}` }), ACROSS)

  expect((await ui.find({ type: 'Text', text: '✓' }))?.props.color).toBe(C.ok)
  expect(await press()).toMatchObject({ plain: true, label: expect.stringMatching(/…$/) })
  expect((await press())?.dimColor).toBeUndefined()
  expect((await ui.find({ type: 'Text', text: '1h' }))?.props.color).toBe(C.grey)
  expect(await drawn(), 'closed, a line of its own, nothing hung').toEqual([
    '✓ Review the whole of the dashboard redesign, e…    1h',
  ])

  await ui.press({ key: `done:${w.item('a1')}` })
  expect(await drawn()).toEqual([
    '✓ Review the whole of the dashboard redesign,       1h',
    '│ every area of it, against the brief and the',
    '│ notes',
    '└ → Approve',
  ])
  expect((await ui.find({ type: 'Text', text: '→ Approve' }))?.props.color).toBe(C.soft)
})

test('closing the board folds DONE back to the latest 3', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const band = await w.band()

  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.doneInFull).toBe(id)
  expect(await listed(ui)).toHaveLength(4)

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })

  expect(w.state.pane?.doneInFull).toBeNull()
  expect(await listed(ui)).toHaveLength(3)
  expect(await ui.find({ key: `closed:${w.item('a1')}` })).toBeUndefined()
})

test('DONE shown in full stays so while items open and close, in DONE or elsewhere on the board; only its toggle folds it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const note = postedId(await w.call('note', { text: 'PR #82 merged' }))
  const toggle = async () => (await ui.find({ key: `earlier:${id}` }))?.props.label

  await ui.press({ key: `earlier:${id}` })

  for (const press of [`done:${w.item('a4')}`, `done:${w.item('a4')}`, `log:${w.item(note)}`]) {
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

  await ui.press({ key: `done:${w.item('a4')}` })
  expect(w.state.pane?.selected).toBe(`done:${w.item('a4')}`)
  expect(await branch()).toBeDefined()

  await ui.press({ key: `done:${w.item('a4')}` })
  expect(w.state.pane?.selected).toBeNull()
  expect(await branch()).toBeUndefined()

  await ui.press({ key: `done:${w.item('a4')}` })
  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })

  expect(w.state.pane?.selected).toBeNull()
  expect(await branch()).toBeUndefined()
})

test('folding DONE back closes an opened ask it no longer shows; one it still shows stays open', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)

  await ui.press({ key: `earlier:${id}` })
  await ui.press({ key: `done:${w.item('a1')}` })
  expect(await listed(ui)).toHaveLength(4)
  expect(await ui.find({ type: 'Text', text: '→ Approve' })).toBeDefined()

  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.selected).toBeNull()
  expect(await listed(ui)).toHaveLength(3)

  await ui.press({ key: `earlier:${id}` })
  await ui.press({ key: `done:${w.item('a4')}` })
  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.selected).toBe(`done:${w.item('a4')}`)
  expect(await listed(ui)).toHaveLength(3)
  expect(await ui.find({ type: 'Text', text: 'resolved by Claude' })).toBeDefined()
})

test('a pane an older load saved, knowing nothing of DONE shown in full, shows DONE folded', async ($, on) => {
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

test("an ask Lee commented on and Claude then resolved goes straight to DONE, never lingering as Lee's send", async ($, on) => {
  const w = world($, on, { now: T0 + 2 * MIN })
  const { paths } = await w.begin()

  w.put(
    paths.log(W2),
    file(
      [T0, yesAsk('a1', 'Review round 1')],
      [T0 + MIN, reply('r1', 'a1', 'comment', { note: 'Tighten the gaps' })],
      [T0 + MIN, delivered('r1')],
      [T0 + 2 * MIN - 1_000, resolve('a1', 'Tightened them')],
    ),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()

  expect(await ui.find({ key: `pick:${w.item('a1')}` })).toBeUndefined()
  expect(await ui.find({ key: 'sent:a1' })).toBeUndefined()
  expect(await ui.find({ key: `closed:${w.item('a1')}` })).toBeDefined()
})
