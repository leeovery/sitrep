import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { rowsOf } from './drawn'
import { ELSEWHERE, GO, LEDGER, PROJECT, SHIFTS, T0, W4 } from './data'
import { note, park, yesAsk } from './lines'
import { CONVERSATION, INLINE, toProject, WIDE, world, type Board, type World } from './world'

tier('user')

/** The pane's rows as drawn, `cells` across where given, each with the column kept free on its left. */
const rows = async (ui: Board, cells?: number) => rowsOf(await ui.find({ type: 'Box' }), cells)

/** This session with one thing parked, and another session of its project with two. */
async function parkedAround(w: World) {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(park('p1', 'Export the ledger as CSV'), park('p2', 'Archive old invoices'))
  ledger.beat()
  await w.begin()
  await w.call('park', { title: 'A priority badge across all tabs' })
}

/** The board on the ledger's view: another session of this project. */
const onLedger = async (ui: Board) => {
  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
}

/** The tab row and the rule under it, as drawn. */
const header = async (ui: Board) => (await rows(ui)).slice(0, 2)

/** The way back's row under the tab rule, then the view's title line, `cells` across. */
const underRule = async (ui: Board, cells = WIDE.bodyColumns) => {
  const [, , back, title] = await rows(ui, cells)

  return { back, title }
}

/** The rows the header draws, `cells` across. */
const headerRows = async (ui: Board, cells: number) =>
  rowsOf(await ui.find({ key: 'header' }), cells).length

/** The board's first row: the home tab, its glyph and this session's name, then All projects. */
const HOME_FIRST = /^ {2}⌂ Help desk redesign {2}≡ All projects/

/** A place the board goes, reached from home as Lee reaches it, its title line, and its way back; none at home and on All projects. */
type Place = { name: string; reach: (ui: Board) => Promise<unknown>; title: string; back?: string }

const PLACES: readonly Place[] = [
  { name: 'home', reach: async () => undefined, title: 'Help desk redesign · Northwind' },
  {
    name: 'All projects',
    reach: ui => ui.press({ key: 'tab:all' }),
    title: 'All projects · 2 waiting on you',
  },
  {
    name: "this project's view",
    reach: ui => toProject(ui),
    title: 'Northwind · 2 waiting on you',
    back: '← All projects',
  },
  {
    name: "another session's view",
    reach: onLedger,
    title: 'Invoice ledger · Northwind',
    back: '← Northwind',
  },
  {
    name: "another project's view",
    reach: ui => toProject(ui, ELSEWHERE.key),
    title: 'Contoso · nothing waiting on you',
    back: '← All projects',
  },
  {
    name: "another project's session",
    reach: async ui => {
      await toProject(ui, ELSEWHERE.key)
      await ui.press({ key: `go:${SHIFTS.id}` })
    },
    title: 'Shift schedules · Contoso',
    back: '← Contoso',
  },
]

/** This session asking, another of its project asking, and Contoso's session there to visit. */
async function asksAround(w: World) {
  const ledger = w.elsewhere(LEDGER)

  w.elsewhere(SHIFTS, ELSEWHERE.key).beat()
  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  ledger.beat()
  await w.begin()
  await w.call('ask', GO)
}

/** Where the board looks, as kept. */
const placeOf = (w: World) => w.state.pane?.place

test('two tabs: home as its glyph, its name and its count, All projects and its count; the current one lit, its rule running on to the edge', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)
    const [tabs, rule] = await header(ui)
    const lit = '━'.repeat(' ⌂ Help desk redesign 1 '.length)

    expect(tabs, props.placement).toBe(
      `  ⌂ Help desk redesign 1  ≡ All projects 2${props.placement === 'inline' ? ' [ ✕ close ]' : ''}`,
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
  const first = ' ⌂ Help desk redesign 1 '.length
  const all = ' ≡ All projects 2 '.length
  const rest = '─'.repeat(WIDE.bodyColumns - 2 - first - all)

  for (const { name, reach } of PLACES) {
    await ui.press({ key: 'tab:session' })
    await reach(ui)

    const isHome = name === 'home'
    const [tabs, rule] = await header(ui)
    const lit = await ui.find({ type: 'Box', key: isHome ? 'tab:session:box' : 'tab:all:box' })

    expect(tabs, name).toBe('  ⌂ Help desk redesign 1  ≡ All projects 2')
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
  await w.call('status', { name: 'Redesign the help desk, page by page' })
  await w.call('ask', GO)

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
    expect(await header(ui), way).toEqual(['  ⌂ Redesign the he… 1  ≡ All projects 1', rule])
    expect(await cells(), 'the name takes what All projects leaves').toEqual([first, all])
  }

  await ui.redraw(WIDE)
  expect((await header(ui))[0], 'wide, the whole name').toMatch(
    /^ {2}⌂ Redesign the help desk, page by page 1 {2}≡ All projects 1$/,
  )
})

test("inline, at phone width and wider, the tab row ends with the board's own wide close, the name cut to leave it room, the rule lined up under the tabs; pressing it closes the board", async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const band = await w.band()
  const all = ' ≡ All projects 2 '.length
  const close = '[ ✕ close ]'

  for (const [props, name] of [
    [{ ...INLINE, bodyColumns: 46 }, 'Help des…'],
    [{ ...WIDE, placement: 'inline' as const }, 'Help desk redesign'],
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
  const home = { level: 'session', project: PROJECT.key, session: w.state.attachment?.session }

  for (const { name, reach } of PLACES.slice(1)) {
    await reach(ui)
    expect(placeOf(w), name).not.toEqual(home)
    await ui.press({ key: 'tab:session' })
    expect(placeOf(w), name).toEqual(home)
    expect(await ui.find({ key: 'up' }), name).toBeUndefined()
  }
})

test("under the tab rule, the way back one level up, dim, at the left of its row, then the view's title line; home and All projects leave that row blank; docked and inline", async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = await w.opened(props)

    for (const { name, reach, title, back } of PLACES) {
      const scene = `${props.placement}, ${name}`

      await ui.press({ key: 'tab:session' })
      await reach(ui)
      expect(await underRule(ui), scene).toEqual({
        back: back === undefined ? '' : ` ${back}`,
        title: ` ${title}`,
      })
      expect((await ui.find({ key: 'up', text: back }))?.props.dimColor, scene).toBe(
        back === undefined ? undefined : true,
      )
      expect(await headerRows(ui, props.bodyColumns), `${scene}: the header's rows`).toBe(3)
      expect(await ui.find({ key: 'home' }), `${scene}: no ⌂ beside it`).toBeUndefined()
    }

    await ui.unmount()
  }
})

test('with no session held, the board is its one line: no tabs, and no blank row under them', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)

  for (const props of [WIDE, INLINE]) {
    const ui = await w.pane('terminal', props)

    expect(await rows(ui), props.placement).toEqual([
      expect.stringMatching(/^ This window holds no session\./),
    ])
    await ui.unmount()
  }
})

test('back goes one level up: a session to its project, a project to All projects', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)

  await toProject(ui, ELSEWHERE.key)
  await ui.press({ key: `go:${SHIFTS.id}` })
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

test('a long title cuts its aside first, then itself, at phone width and docked, to the whole line: the way back, on the row above, takes none of it', async ($, on) => {
  const w = world($, on)
  const named = (id: string, name: string) => {
    const session = w.elsewhere({ ...LEDGER, id, name })

    session.write(note('n1', 'Began'))
    session.beat()
  }

  named('sr-r0nd22', 'Invoice ledger, round 2 of the exports')
  named('sr-w1d3rr', 'Invoice ledger, area by area, with its exports and its retention')
  await w.begin()

  const expected = {
    46: [
      'Invoice ledger, round 2 of the exports · No…',
      'Invoice ledger, area by area, with its expo…',
    ],
    60: [
      'Invoice ledger, round 2 of the exports · Northwind',
      'Invoice ledger, area by area, with its exports and its re…',
    ],
  }

  for (const props of NARROW) {
    const ui = await w.opened(props)

    for (const [i, id] of ['sr-r0nd22', 'sr-w1d3rr'].entries()) {
      const scene = `${props.bodyColumns}: ${id}`
      const shown = expected[props.bodyColumns][i] ?? ''

      await toProject(ui)
      await ui.press({ key: `go:${id}` })
      expect(await underRule(ui, props.bodyColumns), scene).toEqual({
        back: ' ← Northwind',
        title: ` ${shown}`,
      })
      expect([...shown].length, `${scene}: no further than the edge`).toBeLessThanOrEqual(
        props.bodyColumns - 2,
      )
    }

    await ui.unmount()
  }
})

test('a way back longer than the line is cut short at its edge, and the title line keeps its whole width', async ($, on) => {
  const w = world($, on)
  const intake = 'intake'

  w.project(intake, {
    name: 'The Customer Intake Rebuild Programme, phase two of the three',
    directory: '/Users/me/Code/intake',
    created: T0,
    by: W4,
  })
  w.elsewhere({ ...SHIFTS, project: intake }, intake).beat()
  await w.begin()

  const expected = {
    46: {
      back: ' ← The Customer Intake Rebuild Programme, ph…',
      title: ' Shift schedules · The Customer Intake Rebui…',
    },
    60: {
      back: ' ← The Customer Intake Rebuild Programme, phase two of the…',
      title: ' Shift schedules · The Customer Intake Rebuild Programme, …',
    },
  }

  for (const props of NARROW) {
    const ui = await w.opened(props)

    await toProject(ui, intake)
    await ui.press({ key: `go:${SHIFTS.id}` })
    expect(await underRule(ui, props.bodyColumns), `${props.bodyColumns}`).toEqual(
      expected[props.bodyColumns],
    )
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
  expect(await underRule(ui)).toEqual({
    back: ' ← Northwind',
    title: ' Invoice ledger · Northwind',
  })
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
  expect(await ui.find({ type: 'Text', text: 'ASKS' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'PARKED' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^PARKED IN/ })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /back to the board/ })).toBeUndefined()
})

test('inline, nothing sits above the tabs, and the header flows with the view: its first rows, the way back, then the view', async ($, on) => {
  const w = world($, on)

  await parkedAround(w)

  const ui = await w.opened(INLINE)
  const [first] = await rows(ui)

  expect(first).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()

  await onLedger(ui)

  const [tabs, , back, view] = await rows(ui, INLINE.bodyColumns)
  const [board] = await ui.findAll({ type: 'Box' })

  expect(tabs).toMatch(HOME_FIRST)
  expect(back).toBe(' ← Northwind')
  expect(view).toBe(' Invoice ledger · Northwind')
  expect(board?.props.height, 'not held to the window').toBeUndefined()
  expect((await ui.findAll({ type: 'Box' })).some(box => box.props.overflow === 'hidden')).toBe(
    false,
  )
})
