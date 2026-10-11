import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { C } from '../hooks/look'
import { rowsOf } from './drawn'
import { note, park, T0, W2, W4, yesAsk } from './support'
import { ELSEWHERE, INLINE, PROJECT, SESSION, toProject, WIDE, world } from './world'

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

/** The pane's rows as drawn, `cells` across where given, each with the column kept free on its left. */
const rows = async (ui: Board, cells?: number) => rowsOf(await ui.find({ type: 'Box' }), cells)

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

/** The blank row under the tab rule, then the view's title line, `cells` across. */
const underRule = async (ui: Board, cells = WIDE.bodyColumns) => {
  const [, , blank, title] = await rows(ui, cells)

  return { blank, title }
}

/** A view's title line `cells` across: its title and aside, and the way back at the right edge where there is one. */
const titleLine = (title: string, back = '', cells = WIDE.bodyColumns) =>
  ` ${title}${' '.repeat(cells - 2 - title.length - back.length)}${back}`.trimEnd()

/** The board's first row: the home tab, its glyph and this session's name, then All projects. */
const HOME_FIRST = /^ {2}⌂ Dashboard redesign {2}≡ All projects/

/** A place the board goes, reached from home as Lee reaches it, its title line, and its way back; none at home and on All projects. */
type Place = { name: string; reach: (ui: Board) => Promise<unknown>; title: string; back?: string }

const PLACES: readonly Place[] = [
  { name: 'home', reach: async () => undefined, title: 'Dashboard redesign · Switchboard' },
  {
    name: 'All projects',
    reach: ui => ui.press({ key: 'tab:all' }),
    title: 'All projects · 2 waiting on you',
  },
  {
    name: "this project's view",
    reach: ui => toProject(ui),
    title: 'Switchboard · 2 waiting on you',
    back: '← All projects',
  },
  {
    name: "another session's view",
    reach: onLedger,
    title: 'Request ledger · Switchboard',
    back: '← Switchboard',
  },
  {
    name: "another project's view",
    reach: ui => toProject(ui, ELSEWHERE.key),
    title: 'Goosemates · nothing waiting on you',
    back: '← All projects',
  },
  {
    name: "another project's session",
    reach: async ui => {
      await toProject(ui, ELSEWHERE.key)
      await ui.press({ key: `go:${GOOSEMATES}` })
    },
    title: 'Standing orders · Goosemates',
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

    expect(tabs, props.placement).toBe(
      `  ⌂ Dashboard redesign 1  ≡ All projects 2${props.placement === 'inline' ? ' [ ✕ close ]' : ''}`,
    )
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

test("inline, at phone width and wider, the tab row ends with the board's own wide close, the name cut to leave it room, the rule lined up under the tabs; pressing it closes the board", async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const band = await w.band()
  const all = ' ≡ All projects 2 '.length
  const close = '[ ✕ close ]'

  for (const [props, name] of [
    [{ ...INLINE, bodyColumns: 46 }, 'Dashboar…'],
    [{ ...WIDE, placement: 'inline' as const }, 'Dashboard redesign'],
  ] as const) {
    const ui = await w.opened(props)
    const width = props.bodyColumns - 2
    const first = ` ⌂ ${name} 1 `.length
    const spare = ' '.repeat(width - first - all - close.length)
    const rest = '─'.repeat(width - first - all)
    const at = `${props.bodyColumns}`

    for (const [way, rule] of [
      ['tab:session', ` ${'━'.repeat(first)}${'─'.repeat(all)}${rest}`],
      ['tab:all', ` ${'─'.repeat(first)}${'━'.repeat(all)}${rest}`],
    ] as const) {
      await ui.press({ key: way })

      const [tabs, under] = await rows(ui, props.bodyColumns)

      expect(tabs, `${at}, ${way}`).toBe(`  ⌂ ${name} 1  ≡ All projects 2${spare} ${close}`)
      expect(under, `${at}, ${way}: the close over plain rule`).toBe(rule)
      expect([...(tabs ?? '')].length, 'one row, to the edge').toBe(props.bodyColumns - 1)
    }

    expect(await band.find({ key: 'band:board', text: '✕ close' }), at).toBeDefined()
    await ui.press({ key: 'tabs:close' })
    expect(w.panes.has('sitrep'), at).toBe(false)
    expect(await band.find({ key: 'band:board', text: '▸ show board' }), at).toBeDefined()
    await ui.unmount()
  }
})

test('docked, the tabs have no close', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  for (const props of [WIDE, { ...WIDE, bodyColumns: 46 }]) {
    const ui = await w.opened(props)

    expect(await ui.find({ key: 'tabs:close' }), `${props.bodyColumns}`).toBeUndefined()
    expect((await rows(ui, props.bodyColumns))[0], `${props.bodyColumns}`).toMatch(
      /≡ All projects 2$/,
    )
    await ui.unmount()
  }
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

test("a blank row under the tab rule, then the view's title line, the way back one level up at its right end; home and All projects have none; docked and inline", async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)

    for (const { name, reach, title, back } of PLACES) {
      const scene = `${props.placement}, ${name}`

      await ui.press({ key: 'tab:session' })
      await reach(ui)
      expect(await underRule(ui), scene).toEqual({ blank: '', title: titleLine(title, back) })
      expect(await ui.find({ key: 'up', text: back }), scene).toEqual(
        back === undefined ? undefined : expect.anything(),
      )
      expect(await ui.find({ key: 'home' }), `${scene}: no ⌂ beside it`).toBeUndefined()
    }

    await ui.unmount()
  }
})

test('with no work held, the board is its one line: no tabs, and no blank row under them', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  for (const props of [WIDE, INLINE]) {
    const ui = await w.pane('terminal', props)

    expect(await rows(ui), props.placement).toEqual([
      expect.stringMatching(/^ This window holds no piece of work\./),
    ])
    await ui.unmount()
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

/** Phone width, as Blink draws the board inline, and a docked board's. */
const NARROW = [
  { ...INLINE, bodyColumns: 46 },
  { ...WIDE, bodyColumns: 60 },
] as const

test('a long title cuts its aside first, then itself, at phone width and docked: the way back stays whole at the right edge, the line one row', async ($, on) => {
  const w = world($, on)
  const named = (id: string, name: string) => {
    const work = w.elsewhere({ ...LEDGER_META, id, name })

    work.write(note('n1', 'Began'))
    work.beat()
  }

  named('sr-r0nd22', 'Request ledger, round 2')
  named('sr-w1d3rr', 'Request ledger, area by area, with its exports and retention')
  await w.begin()

  const expected = {
    46: ['Request ledger, round 2 · Swi…', 'Request ledger, area by area,…'],
    60: ['Request ledger, round 2 · Switchboard', 'Request ledger, area by area, with its expo…'],
  }

  for (const props of NARROW) {
    const ui = await w.opened(props)

    for (const [i, id] of ['sr-r0nd22', 'sr-w1d3rr'].entries()) {
      await toProject(ui)
      await ui.press({ key: `go:${id}` })

      const { title } = await underRule(ui, props.bodyColumns)

      expect(title, `${props.bodyColumns}: ${id}`).toBe(
        titleLine(expected[props.bodyColumns][i] ?? '', '← Switchboard', props.bodyColumns),
      )
      expect([...(title ?? '')].length, 'to the edge, and no further').toBe(props.bodyColumns - 1)
      expect(await ui.find({ key: 'up', text: '← Switchboard' }), 'whole').toBeDefined()
    }

    await ui.unmount()
  }
})

test('a way back longer than half the line is cut short to half, so the title keeps the rest', async ($, on) => {
  const w = world($, on)
  const portal = 'portal'

  w.project(portal, {
    name: 'The Customer Portal Rebuild Programme',
    directory: '/Users/lee/Code/portal',
    created: T0,
    by: W4,
  })
  w.elsewhere({ ...GOOSEMATES_META, project: portal }, portal).beat()
  await w.begin()

  const expected = {
    46: ' Standing orders · Th… ← The Customer Portal…',
    60: ' Standing orders · The Custo… ← The Customer Portal Rebuil…',
  }

  for (const props of NARROW) {
    const ui = await w.opened(props)

    await toProject(ui, portal)
    await ui.press({ key: `go:${GOOSEMATES}` })
    expect((await underRule(ui, props.bodyColumns)).title).toBe(expected[props.bodyColumns])
    await ui.unmount()
  }
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
  expect((await underRule(ui)).title).toBe(
    titleLine('Request ledger · Switchboard', '← Switchboard'),
  )
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

test('inline, nothing sits above the tabs, and the header flows with the view: its first rows, a blank row, then the view', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(INLINE)
  const [first] = await rows(ui)

  expect(first).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()

  await onLedger(ui)

  const [tabs, , blank, view] = await rows(ui, INLINE.bodyColumns)
  const [board] = await ui.findAll({ type: 'Box' })

  expect(tabs).toMatch(HOME_FIRST)
  expect(blank).toBe('')
  expect(view).toBe(titleLine('Request ledger · Switchboard', '← Switchboard', INLINE.bodyColumns))
  expect(board?.props.height, 'not held to the window').toBeUndefined()
  expect((await ui.findAll({ type: 'Box' })).some(box => box.props.overflow === 'hidden')).toBe(
    false,
  )
})
