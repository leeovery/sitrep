import { expect, test, tier } from 'claude-code/testing'
import type { Body } from '../core'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { ask, delivered, file, MIN, reply, resolve, T0, W2, type Line } from './support'
import { world } from './world'

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
        ask('a1', 'review', 'Review round 1'),
        ask('a2', 'decide', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
        ask('a3', 'do', 'Run the apply'),
        ask('a4', 'review', 'Review round 2'),
        ask('a5', 'try', 'Try the flow'),
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

test('DONE counts the closed asks, ignored ones aside, the newest closed first, each hung with how it closed', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)

  expect(await ui.find({ type: 'Text', text: '4 closed' })).toBeDefined()
  expect(await listed(ui)).toEqual(['closed:a4', 'closed:a3', 'closed:a2'])

  await ui.press({ key: `earlier:${id}` })

  expect(await listed(ui)).toEqual(['closed:a4', 'closed:a3', 'closed:a2', 'closed:a1'])
  expect(rowsOf(await ui.find({ key: 'closed:a4' }))).toEqual([
    '✓ Review round 2',
    '└ resolved by Claude · 1h ago',
  ])
  expect(rowsOf(await ui.find({ key: 'closed:a3' }))).toEqual([
    '✓ Run the apply',
    '└ resolved by Claude: Ran it in the chat · 2h ago',
  ])
  expect(rowsOf(await ui.find({ key: 'closed:a2' }))).toEqual([
    '✓ Keep the ledger 400 days, or forever?',
    '└ → Forever · 3h ago',
  ])
  expect(rowsOf(await ui.find({ key: 'closed:a1' }))).toEqual([
    '✓ Review round 1',
    '└ approved · 4h ago',
  ])
})

test('DONE shows the latest 3; show all opens it to every one, and show fewer closes it again', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const toggle = async () => (await ui.find({ key: `earlier:${id}` }))?.props

  expect(await toggle()).toMatchObject({ label: 'show all 4', plain: true })
  expect(await listed(ui)).toHaveLength(3)

  await ui.press({ key: `earlier:${id}` })
  expect(await toggle()).toMatchObject({ label: 'show fewer' })
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

  w.put(paths.log(W2), file(...after(0, ask('a1', 'review', 'Review round 1'))))
  await w.clock.advance(WATCH_MS)
  expect(await heading()).toBeUndefined()

  w.put(
    paths.log(W2),
    file(
      ...after(0, ask('a1', 'review', 'Review round 1')),
      ...after(1, reply('r1', 'a1', 'yes'), delivered('r1')),
    ),
  )
  await w.clock.advance(WATCH_MS)

  const rows = rowsOf(await ui.find({ type: 'Box' }))

  expect((await heading())?.props).toMatchObject({ color: C.ok, bold: true })
  expect(await ui.find({ type: 'Text', text: '1 closed' })).toBeDefined()
  expect(
    await ui.find({ key: `earlier:${id}` }),
    'no more than 3, so nothing to show all',
  ).toBeUndefined()
  expect(rows.slice(-3), 'under LOG, the last of the view').toEqual([
    expect.stringMatching(/^ DONE ─+ 1 closed$/),
    ' ✓ Review round 1',
    ' └ approved · 4h ago',
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

test('each closed ask is drawn faint, mark and title, its age grey, a long title kept to one line', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { paths } = await w.begin()
  const title =
    'Review the whole of the dashboard redesign, every area of it, against the brief and the notes'

  w.put(
    paths.log(W2),
    file(
      ...after(0, ask('a1', 'review', title)),
      ...after(4, reply('r1', 'a1', 'yes'), delivered('r1')),
    ),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()
  const [mark, shown] = (await ui.findAll({ type: 'Text' })).filter(
    each => each.text === '✓' || each.text === title,
  )

  expect(mark?.props.color).toBe(C.faint)
  expect(shown?.props).toMatchObject({ color: C.faint, wrap: 'truncate-end' })
  expect((await ui.find({ type: 'Text', text: '· 1h ago' }))?.props.color).toBe(C.grey)
  expect((await ui.find({ type: 'Text', text: 'approved' }))?.props.color).toBe(C.soft)
})

test('closing the board resets the history, as any selection', async ($, on) => {
  const w = world($, on, { now: NOW })
  const { id, ui } = await closedAsks(w)
  const band = await w.band()

  await ui.press({ key: `earlier:${id}` })
  expect(w.state.pane?.selected).toBe(`earlier:${id}`)

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })

  expect(w.state.pane?.selected).toBeNull()
  expect(await ui.find({ key: 'closed:a1' })).toBeUndefined()
})

test("an ask Lee commented on and Claude then resolved goes straight to DONE, never lingering as Lee's send", async ($, on) => {
  const w = world($, on, { now: T0 + 2 * MIN })
  const { paths } = await w.begin()

  w.put(
    paths.log(W2),
    file(
      [T0, ask('a1', 'review', 'Review round 1')],
      [T0 + MIN, reply('r1', 'a1', 'comment', { note: 'Tighten the gaps' })],
      [T0 + MIN, delivered('r1')],
      [T0 + 2 * MIN - 1_000, resolve('a1', 'Tightened them')],
    ),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.opened()

  expect(await ui.find({ key: 'pick:a1' })).toBeUndefined()
  expect(await ui.find({ key: 'sent:a1' })).toBeUndefined()
  expect(await ui.find({ key: 'closed:a1' })).toBeDefined()
})
