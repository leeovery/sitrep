import type { RenderPropsOf } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { C } from '../hooks/look'
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

/** The rule under the lit parked count: under its label (`◇ 1 parked`, `◇ 2 parked`) and the column before it. */
const LIT_RULE = '━'.repeat(11)

/** The tab row and the rule under it, as drawn. */
const header = async (ui: Board) => (await rows(ui)).slice(0, 2)

/** The parked count's cells, lit: the background its tab colour, the label not dimmed. */
const litCount = async (ui: Board) => {
  const box = await ui.find({ type: 'Box', key: 'parked:box' })
  const count = await ui.find({ key: 'parked' })

  return { background: box?.props.backgroundColor, isDim: count?.props.dimColor }
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

test('docked, as inline, the tabs are the first row of the board: there is no collapse or expand', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  expect((await rows(ui))[0]).toMatch(/^ {2}⌂ This session/)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /collapse|expand/ })).toBeUndefined()

  await onLedger(ui)
  expect((await rows(ui))[0]).toMatch(/^ ← Switchboard/)
})

test('a pane saved as the glance by an older load opens as the board', async ($, on) => {
  const w = world($, on)
  const saved = {
    isOpen: false,
    mode: 'glance',
    place: null,
    view: 'board',
    selected: null,
    commenting: null,
  }
  let isWritten = false

  // What an older load left in $.state, read until this load first writes the pane over it.
  on('state.get', { plugin: 'sitrep', key: 'pane' }, ($, e, next) =>
    isWritten ? next(e) : { value: { value: saved, version: 0 } },
  )
  on('state.set', { plugin: 'sitrep', key: 'pane' }, ($, e, next) => {
    isWritten = true

    return next(e)
  })

  await parkedAround(w)
  expect(w.state.pane).toMatchObject({ mode: 'glance' })

  const ui = await w.opened(WIDE)

  expect(w.state.pane).toMatchObject({ isOpen: true })
  expect((await rows(ui))[0]).toMatch(/^ {2}⌂ This session/)
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
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

test('the parked page keeps the tab row, the parked count lit as the current tab, the way back first under it', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  expect(await litCount(ui)).toEqual({ background: undefined, isDim: true })

  await ui.press({ key: 'parked' })

  const [tabs, rule, back, heading] = await rows(ui)

  expect(tabs).toMatch(/^ {2}⌂ This session {2}▤ Switchboard {2}≡ All projects +◇ 1 parked$/)
  expect(rule).toBe(` ${'─'.repeat(WIDE.bodyColumns - 2 - LIT_RULE.length)}${LIT_RULE}`)
  expect(back).toBe(' ← back to the board')
  expect(heading).toMatch(/^ PARKED IN THIS SESSION ─+ 1$/)
  expect(await litCount(ui)).toEqual({ background: C.tab, isDim: false })
  expect(
    (await ui.findAll({ type: 'Text', text: /━/ })).map(each => [each.text, each.props.color]),
  ).toEqual([[LIT_RULE, C.parked]])

  for (const tab of ['tab:session', 'tab:project', 'tab:all']) {
    expect((await ui.find({ key: tab }))?.props.dimColor, tab).toBe(true)
    expect((await ui.find({ type: 'Box', key: `${tab}:box` }))?.props.backgroundColor, tab).toBe(
      undefined,
    )
  }
})

test('off Lee’s own path the parked page keeps the back row, its count lit the same way', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  await onLedger(ui)
  await ui.press({ key: 'parked' })

  const [row, rule, back, heading] = await rows(ui)

  expect(row).toMatch(/^ ← Switchboard {2}⌂ this session +◇ 2 parked$/)
  expect(rule).toBe(` ${'─'.repeat(WIDE.bodyColumns - 2 - LIT_RULE.length)}${LIT_RULE}`)
  expect(back).toBe(' ← back to the board')
  expect(heading).toMatch(/^ PARKED IN REQUEST LEDGER ─+ 2$/)
  expect(await litCount(ui)).toEqual({ background: C.tab, isDim: false })
})

test('pressing the lit parked count goes back to the board view of the same place', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  await ui.press({ key: 'tab:project' })

  const board = await header(ui)

  await ui.press({ key: 'parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN SWITCHBOARD' })).toBeDefined()

  await ui.press({ key: 'parked' })
  expect(w.state.pane).toMatchObject({ view: 'board', place: { level: 'project' } })
  expect(await ui.find({ type: 'Text', text: /^PARKED IN/ })).toBeUndefined()
  expect(await header(ui)).toEqual(board)
  expect(await litCount(ui)).toEqual({ background: undefined, isDim: true })
})

test('on the parked page the tabs and the back row work as usual, keeping the parked view, scoped to where they go', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)
  const parkedHere = async () =>
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('ppick:'))
      .map(each => each.text)

  await ui.press({ key: 'parked' })
  expect(await parkedHere()).toEqual(['A tmux indicator across sessions'])

  await ui.press({ key: 'tab:project' })
  expect(w.state.pane?.view).toBe('parked')
  expect(await ui.find({ type: 'Text', text: 'PARKED IN SWITCHBOARD' })).toBeDefined()
  expect(await parkedHere()).toHaveLength(3)

  await ui.press({ key: 'tab:all' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN ALL PROJECTS' })).toBeDefined()

  await ui.press({ key: 'parked' })
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: 'parked' })
  expect(await parkedHere()).toEqual(['Export the ledger as CSV', 'Archive old requests'])

  await ui.press({ key: 'up' })
  expect(w.state.pane).toMatchObject({ view: 'parked', place: { level: 'project' } })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN SWITCHBOARD' })).toBeDefined()

  await ui.press({ key: 'parked' })
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: 'parked' })
  await ui.press({ key: 'home' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN THIS SESSION' })).toBeDefined()
  expect(await parkedHere()).toEqual(['A tmux indicator across sessions'])
})
