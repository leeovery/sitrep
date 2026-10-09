import type { RenderPropsOf } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { rowsOf } from './drawn'
import { park, T0, W2 } from './support'
import { DOCKED, INLINE, WIDE, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Board = Awaited<ReturnType<World['pane']>>

const LEDGER = 'sr-1edger'

const LEDGER_META: WorkMeta = {
  id: LEDGER,
  name: 'Request ledger',
  summary: 'Request ledger, area by area',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W2,
}

/** A board of `columns` across, docked or inline. */
const sized = (columns: number, placement: 'dock' | 'inline' = 'dock'): RenderPropsOf['Pane'] => ({
  ...DOCKED,
  bodyColumns: columns,
  placement,
})

/** The pane's rows as drawn, each with the column kept free on its left. */
const rows = async (ui: Board) => rowsOf(await ui.find({ type: 'Box' }))

/** The row the parked count is drawn on. */
const parkedRow = async (ui: Board) => {
  const text = (await ui.find({ key: 'parked' }))?.text ?? 'no parked count'

  return (await rows(ui)).find(row => row.endsWith(text))
}

/** This session with one thing parked, and another session of its project with two. */
async function parkedAround(w: World) {
  const ledger = w.elsewhere(LEDGER_META)

  ledger.write(park('p1', 'Export the ledger as CSV'), park('p2', 'Archive old requests'))
  ledger.beat()
  await w.begin()
  await w.call('park', { title: 'A tmux indicator across sessions' })
}

/** The board on the ledger's view, off Lee's own path. */
const onLedger = async (ui: Board) => {
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
}

test('the parked count ends the tab row, right-aligned at its edge, docked and inline', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)
    const row = await parkedRow(ui)

    expect(row, props.placement).toMatch(
      /^ {2}⌂ This session {2}▤ Switchboard {2}≡ All projects +◇ 1 parked$/,
    )
    expect([...(row ?? '')].length, 'it ends at the edge').toBe(1 + props.bodyColumns - 2)
    await ui.unmount()
  }
})

test('where the word will not fit beside the full tabs, the count drops it first', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(DOCKED)

  expect(await ui.find({ key: 'tab:session', text: 'This session' })).toBeDefined()
  expect(await ui.find({ key: 'parked', text: '◇ 1' })).toBeDefined()
  expect([...((await parkedRow(ui)) ?? '')].length).toBe(DOCKED.bodyColumns - 1)
})

test('on a narrow board, where the tabs take their short labels, the count is only ◇ and its number', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const narrow = sized(40, 'inline')
  const ui = await w.opened(narrow)

  expect(await ui.find({ key: 'tab:session', text: 'Session' })).toBeDefined()
  expect(await ui.find({ key: 'tab:all', text: 'All' })).toBeDefined()
  expect(await ui.find({ key: 'parked', text: '◇ 1' })).toBeDefined()
  expect([...((await parkedRow(ui)) ?? '')].length).toBe(narrow.bodyColumns - 1)
})

test('off Lee’s own path the back row carries the count the same way, of what was parked where the board looks', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  await onLedger(ui)

  const row = await parkedRow(ui)

  expect(row).toMatch(/^ ← Switchboard {2}⌂ this session +◇ 2 parked$/)
  expect([...(row ?? '')].length).toBe(WIDE.bodyColumns - 1)

  await ui.press({ key: 'parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN REQUEST LEDGER' })).toBeDefined()
  await ui.press({ key: 'back' })
  await ui.unmount()

  const narrow = await w.pane('terminal', sized(40))

  expect((await parkedRow(narrow)) ?? '').toMatch(/^ ← Switchboard {2}⌂ this session +◇ 2$/)
})

test('docked, the row above the tabs holds only the collapse, at its right', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)
  const [first, gap, tabs] = await rows(ui)
  const toolbar = (await ui.findAll({ type: 'Box' })).find(box =>
    box.children.some(child => (child as { props?: { key?: string } }).props?.key === 'collapse'),
  )

  expect(first?.trim()).toBe('⇥ collapse')
  expect(toolbar?.props.justifyContent).toBe('flex-end')
  expect(toolbar?.children).toHaveLength(1)
  expect(gap).toBe('')
  expect(tabs).toMatch(/^ {2}⌂ This session/)
})

test('inline, nothing sits above the tabs: they are the first row of the board', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(INLINE)
  const [first] = await rows(ui)

  expect(first).toMatch(/^ {2}⌂ This session/)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()

  await onLedger(ui)
  expect((await rows(ui))[0]).toMatch(/^ ← Switchboard/)
})
