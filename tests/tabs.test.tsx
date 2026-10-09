import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { C } from '../hooks/look'
import { rowsOf } from './drawn'
import { park, T0, W2, W4, yesAsk } from './support'
import { ELSEWHERE, INLINE, PROJECT, toProject, WIDE, world } from './world'

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

/** The board on the ledger's view: another session of this project. */
const onLedger = async (ui: Board) => {
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER}` })
}

/** The tab row and the rule under it, as drawn. */
const header = async (ui: Board) => (await rows(ui)).slice(0, 2)

/** The row under the tab rule: the back row where there is one, else the view's first line. */
const underRule = async (ui: Board) => (await rows(ui))[2]

/** The board's first row: the home tab, its glyph and this session's name, then All projects. */
const HOME_FIRST = /^ {2}⌂ Dashboard redesign {2}≡ All projects/

/** A place the board goes, reached from home as Lee reaches it, and its back row; none at home and on All projects. */
type Place = { name: string; reach: (ui: Board) => Promise<unknown>; back?: string }

const PLACES: readonly Place[] = [
  { name: 'home', reach: async () => undefined },
  { name: 'All projects', reach: ui => ui.press({ key: 'tab:all' }) },
  { name: "this project's view", reach: ui => toProject(ui), back: '← All projects' },
  { name: "another session's view", reach: onLedger, back: '← Switchboard' },
  {
    name: "another project's view",
    reach: ui => toProject(ui, ELSEWHERE.key),
    back: '← All projects',
  },
  {
    name: "another project's session",
    reach: async ui => {
      await toProject(ui, ELSEWHERE.key)
      await ui.press({ key: `go:${GOOSEMATES}` })
    },
    back: '← Goosemates',
  },
]

/** This session asking, another of its project asking, and Goosemates' session there to visit. */
async function asksAround(w: World) {
  const ledger = w.elsewhere(LEDGER_META)

  w.elsewhere(GOOSEMATES_META, ELSEWHERE.key).beat()
  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  ledger.beat()
  await w.begin()
  await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' })
}

/** Where the board looks, as kept. */
const placeOf = (w: World) => w.state.pane?.place

test('two tabs: home as its glyph, its name and its count, All projects and its count; the current one lit, its rule running on to the edge', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)
    const [tabs, rule] = await header(ui)
    const lit = '━'.repeat(' ⌂ Dashboard redesign 1 '.length)

    expect(tabs, props.placement).toBe('  ⌂ Dashboard redesign 1  ≡ All projects 2')
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

test('the two tabs are drawn the same in every place: the first lit at home, All projects lit anywhere else', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)
  const first = ' ⌂ Dashboard redesign 1 '.length
  const all = ' ≡ All projects 2 '.length
  const rest = '─'.repeat(WIDE.bodyColumns - 2 - first - all)

  for (const { name, reach } of PLACES) {
    await ui.press({ key: 'tab:session' })
    await reach(ui)

    const isHome = name === 'home'
    const [tabs, rule] = await header(ui)
    const lit = await ui.find({ type: 'Box', key: isHome ? 'tab:session:box' : 'tab:all:box' })

    expect(tabs, name).toBe('  ⌂ Dashboard redesign 1  ≡ All projects 2')
    expect(rule, name).toBe(
      isHome
        ? ` ${'━'.repeat(first)}${'─'.repeat(all)}${rest}`
        : ` ${'─'.repeat(first)}${'━'.repeat(all)}${rest}`,
    )
    expect((await ui.find({ key: 'tab:session' }))?.props.dimColor, name).toBe(!isHome)
    expect((await ui.find({ key: 'tab:all' }))?.props.dimColor, name).toBe(isHome)
    expect(lit?.props.backgroundColor, name).toBe(C.tab)
  }
})

test("on a narrow board the first tab's name is cut short, and All projects keeps its full width", async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('status', { name: 'Redesign the dashboard, area by area' })
  await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' })

  const narrow = { ...WIDE, bodyColumns: 42 }
  const ui = await w.opened(narrow)
  const all = ' ≡ All projects 1 '.length
  const first = narrow.bodyColumns - 2 - all
  const cells = async () =>
    Promise.all(
      ['tab:session:box', 'tab:all:box'].map(async key => (await ui.find({ key }))?.props.width),
    )

  for (const [way, rule] of [
    ['tab:session', ` ${'━'.repeat(first)}${'─'.repeat(all)}`],
    ['tab:all', ` ${'─'.repeat(first)}${'━'.repeat(all)}`],
  ] as const) {
    await ui.press({ key: way })
    expect(await header(ui), way).toEqual(['  ⌂ Redesign the da… 1  ≡ All projects 1', rule])
    expect(await cells(), 'the name takes what All projects leaves').toEqual([first, all])
  }

  await ui.redraw(WIDE)
  expect((await header(ui))[0], 'wide, the whole name').toMatch(
    /^ {2}⌂ Redesign the dashboard, area by area 1 {2}≡ All projects 1$/,
  )
})

test('the first tab goes home from every place', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)
  const home = { level: 'session', project: PROJECT.key, work: w.state.attachment?.work }

  for (const { name, reach } of PLACES.slice(1)) {
    await reach(ui)
    expect(placeOf(w), name).not.toEqual(home)
    await ui.press({ key: 'tab:session' })
    expect(placeOf(w), name).toEqual(home)
    expect(await ui.find({ key: 'up' }), name).toBeUndefined()
  }
})

test('the back row sits under the tab rule one level up, in every view but home and All projects', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)

  for (const { name, reach, back } of PLACES) {
    await ui.press({ key: 'tab:session' })
    await reach(ui)

    if (back === undefined) {
      expect(await ui.find({ key: 'up' }), name).toBeUndefined()
      expect(await underRule(ui), `${name}: its first line under the rule`).not.toMatch(/←/)
    } else {
      expect(await underRule(ui), name).toBe(` ${back}`)
      expect(await ui.find({ key: 'up', text: back }), name).toBeDefined()
    }

    expect(await ui.find({ key: 'home' }), `${name}: no ⌂ beside it`).toBeUndefined()
  }
})

test('back goes one level up: a session to its project, a project to All projects', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${GOOSEMATES}` })
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'project', project: ELSEWHERE.key })
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'all' })

  await onLedger(ui)
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'project', project: PROJECT.key })
})

test('docked, as inline, the tabs are the first row of the board: there is no collapse or expand', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(WIDE)

  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /collapse|expand/ })).toBeUndefined()

  await onLedger(ui)
  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
  expect(await underRule(ui)).toBe(' ← Switchboard')
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

test('inline, nothing sits above the tabs, and the header flows with the view: its first rows, the view right under', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(INLINE)
  const [first] = await rows(ui)

  expect(first).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()

  await onLedger(ui)

  const [tabs, , back, view] = await rows(ui)
  const [board] = await ui.findAll({ type: 'Box' })

  expect(tabs).toMatch(HOME_FIRST)
  expect(back).toBe(' ← Switchboard')
  expect(view).toMatch(/^ Request ledger/)
  expect(board?.props.height, 'not held to the window').toBeUndefined()
  expect((await ui.findAll({ type: 'Box' })).some(box => box.props.overflow === 'hidden')).toBe(
    false,
  )
})
