import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { C } from '../hooks/look'
import { rowsOf } from './drawn'
import { park, T0, W2, W4, yesAsk } from './support'
import { ELSEWHERE, INLINE, toProject, WIDE, world } from './world'

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

const GOOSEMATES = 'sr-0rders'

/** A session of another project, Goosemates. */
const GOOSEMATES_META: WorkMeta = {
  id: GOOSEMATES,
  name: 'Standing orders',
  summary: 'Standing orders, area by area',
  project: 'goosemates',
  root: '/Users/lee/Code/goosemates',
  created: T0,
  by: W4,
}

/** The pane's rows as drawn, each with the column kept free on its left. */
const rows = async (ui: Board) => rowsOf(await ui.find({ type: 'Box' }))

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
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER}` })
}

/** The tab row and the rule under it, as drawn. */
const header = async (ui: Board) => (await rows(ui)).slice(0, 2)

/** The board's first row at home: the home tab, its glyph alone, then All projects. */
const HOME_FIRST = /^ {2}⌂ {2}≡ All projects/

test('two tabs: home as its glyph and its count, All projects and its count; the current one lit, its rule running on to the edge', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER_META)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  ledger.beat()
  await w.begin()
  await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' })

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)
    const [tabs, rule] = await header(ui)
    const lit = '━'.repeat(' ⌂ 1 '.length)

    expect(tabs, props.placement).toBe('  ⌂ 1  ≡ All projects 2')
    expect(rule).toBe(` ${lit}${'─'.repeat(props.bodyColumns - 2 - lit.length)}`)
    expect((await ui.find({ key: 'tab:session' }))?.props.dimColor).toBe(false)
    expect((await ui.find({ key: 'tab:all' }))?.props.dimColor).toBe(true)
    expect(await ui.find({ key: 'parked' }), 'no parked count on the row').toBeUndefined()
    await ui.unmount()
  }

  const ui = await w.pane('terminal', WIDE)

  await ui.press({ key: 'tab:all' })
  expect((await ui.find({ key: 'tab:all' }))?.props.dimColor).toBe(false)
  expect((await ui.find({ type: 'Box', key: 'tab:all:box' }))?.props.backgroundColor).toBe(C.tab)
})

test('a project view, this one included, has the back row to All projects and home; another session, to its project', async ($, on) => {
  const w = world($, on)

  w.elsewhere(GOOSEMATES_META, ELSEWHERE.key).beat()
  await parkedAround(w)

  const ui = await w.opened(WIDE)

  await toProject(ui)

  const [row, rule] = await header(ui)

  expect(row, "this project's view").toBe(' ← All projects  ⌂')
  expect(rule).toBe(` ${'─'.repeat(WIDE.bodyColumns - 2)}`)
  expect(await ui.find({ key: 'tab:session' })).toBeUndefined()

  await ui.press({ key: `go:${LEDGER}` })
  expect((await header(ui))[0], 'another session').toBe(' ← Switchboard  ⌂')

  await ui.press({ key: 'home' })
  await ui.press({ key: 'tab:all' })
  await ui.press({ key: `proj:${ELSEWHERE.key}` })
  expect((await header(ui))[0], "another project's view").toBe(' ← All projects  ⌂')

  await ui.press({ key: `go:${GOOSEMATES}` })
  expect((await header(ui))[0], "another project's session").toBe(' ← Goosemates  ⌂')

  await ui.press({ key: 'home' })
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
  expect(await ui.find({ type: 'Button', text: /back to the board/ })).toBeUndefined()
})

test('docked, as inline, the tabs are the first row of the board: there is no collapse or expand', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
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
  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
})

test('a pane saved on the parked page by an older load opens as the board', async ($, on) => {
  const w = world($, on)
  const saved = { isOpen: false, place: null, view: 'parked', selected: null }
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
  expect(w.state.pane, 'the older load’s view is still there').toMatchObject({ view: 'parked' })

  const ui = await w.opened(WIDE)

  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
  expect(await ui.find({ type: 'Text', text: 'FOR YOU' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'PARKED' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^PARKED IN/ })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /back to the board/ })).toBeUndefined()
})

test('inline, nothing sits above the tabs: they are the first row of the board', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(INLINE)
  const [first] = await rows(ui)

  expect(first).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()

  await onLedger(ui)
  expect((await rows(ui))[0]).toMatch(/^ ← Switchboard/)
})
