import type { SitrepPlace } from '../types'
import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { EVERY_PROJECT, projectPlace } from '../hooks/places'
import { rowsOf } from './drawn'
import { ELSEWHERE, GO, HELD, keyed, LEDGER, PROJECT, PROJECT_KEY, SHIFTS, T0, W4 } from './data'
import { askOf, park, status, yesAsk } from './lines'
import type { Neighbour } from './filing'
import type { Element } from './matching'
import { pane, sceneFrom, type Desk, type Drawn } from './render'
import { INLINE, toProject, WIDE, world, type Board, type World } from './world'

tier('user')

/** The pane's rows as drawn, `cells` across where given, each with the column kept free on its left. */
const rows = async (ui: Drawn, cells?: number) => rowsOf(await ui.find({ type: 'Box' }), cells)

/** This session with one thing parked, and another session of its project with two. */
const PARKED_AROUND: Desk = {
  lines: [[T0, park('p1', 'A priority badge across all tabs')]],
  around: [
    {
      meta: LEDGER,
      lines: [
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0, park('p2', 'Archive old invoices')],
      ],
      seenAt: T0,
    },
  ],
}

/** PARKED_AROUND in a world: the ledger's files written, and this session begun and parking. */
async function parkedAround(w: World) {
  w.surround(PARKED_AROUND.around)
  await w.begin()
  await w.call('park', { title: 'A priority badge across all tabs' })
}

/** A session's view: one of this project's unless told. */
const sessionPlace = (session: string, project = PROJECT_KEY): SitrepPlace => ({
  level: 'session',
  project: keyed(project),
  session,
})

/** The board on the ledger's view: another session of this project. */
const ON_LEDGER = sessionPlace(LEDGER.id)

/** The board taken from home to a place as Lee takes it there: All projects, then the project, then the session; home, nowhere. */
const reach = async (ui: Board, place: SitrepPlace | null) => {
  if (place === null) {
    return
  }

  if (place.level === 'all') {
    await ui.press({ key: 'tab:all' })

    return
  }

  await toProject(ui, place.project)

  if (place.level === 'session') {
    await ui.press({ key: `go:${place.session}` })
  }
}

/** The tab row and the rule under it, as drawn. */
const header = async (ui: Drawn) => (await rows(ui)).slice(0, 2)

/** The way back's row under the tab rule, then the view's title line, `cells` across. */
const underRule = async (ui: Drawn, cells = WIDE.bodyColumns) => {
  const [, , back, title] = await rows(ui, cells)

  return { back, title }
}

/** The rows the header draws, `cells` across. */
const headerRows = async (ui: Drawn, cells: number) =>
  rowsOf(await ui.find({ key: 'header' }), cells).length

/** The board's first row: the home tab, its glyph and this session's name, then All projects. */
const HOME_FIRST = /^ {2}⌂ Help desk redesign {2}≡ All projects/

/** A place the board goes, null for home as the pane keeps it, its title line, and its way back; none at home and on All projects. */
type Place = { name: string; place: SitrepPlace | null; title: string; back?: string }

const PLACES: readonly Place[] = [
  { name: 'home', place: null, title: 'Help desk redesign · Northwind' },
  { name: 'All projects', place: EVERY_PROJECT, title: 'All projects · 2 waiting on you' },
  {
    name: "this project's view",
    place: projectPlace(PROJECT.key),
    title: 'Northwind · 2 waiting on you',
    back: '← All projects',
  },
  {
    name: "another session's view",
    place: ON_LEDGER,
    title: 'Invoice ledger · Northwind',
    back: '← Northwind',
  },
  {
    name: "another project's view",
    place: projectPlace(ELSEWHERE.key),
    title: 'Contoso · nothing waiting on you',
    back: '← All projects',
  },
  {
    name: "another project's session",
    place: sessionPlace(SHIFTS.id, ELSEWHERE.key),
    title: 'Shift schedules · Contoso',
    back: '← Contoso',
  },
]

/** This session asking, another of its project asking, and Contoso's session there to visit. */
const ASKS_AROUND: Desk = {
  lines: [[T0, askOf('k1', GO)]],
  around: [
    { meta: LEDGER, lines: [[T0, yesAsk('k3', 'Review the ledger schema')]], seenAt: T0 },
    { meta: SHIFTS, project: ELSEWHERE.key, seenAt: T0 },
  ],
}

/** ASKS_AROUND in a world: the sessions around written, and this session begun and asking. */
async function asksAround(w: World) {
  w.surround(ASKS_AROUND.around)
  await w.begin()
  await w.call('ask', GO)
}

/** The scene of a desk, its board looking at a place: home unless told. */
const lookingAt = (desk: Desk, place: SitrepPlace | null = null) =>
  sceneFrom({ ...desk, pane: { place } })

/** Where the board looks, as kept. */
const placeOf = (w: World) => w.state.pane?.place

test('two tabs: home as its glyph, its name and its count, All projects and its count; the current one lit, its rule running on to the edge', async () => {
  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    const ui = pane(lookingAt(ASKS_AROUND), props)
    const [tabs, rule] = await header(ui)
    const lit = '━'.repeat(' ⌂ Help desk redesign 1 '.length)

    expect(tabs, props.placement).toBe(
      `  ⌂ Help desk redesign 1  ≡ All projects 2${props.placement === 'inline' ? ' [ ✕ close ]' : ''}`,
    )
    expect(rule).toBe(` ${lit}${'─'.repeat(props.bodyColumns - 2 - lit.length)}`)
    expect((await ui.find({ key: 'tab:session' }))?.props.dimColor).toBe(false)
    expect((await ui.find({ key: 'tab:all' }))?.props.dimColor).toBe(true)
    expect(await ui.find({ key: 'parked' }), 'no parked count on the row').toBeUndefined()
  }

  const ui = pane(lookingAt(ASKS_AROUND, EVERY_PROJECT), WIDE)

  expect((await ui.find({ key: 'tab:all' }))?.props.dimColor).toBe(false)
  expect((await ui.find({ type: 'Box', key: 'tab:all:box' }))?.props.backgroundColor).toBe(C.tab)
})

test('the two tabs are drawn the same in every place: the first lit at home, All projects lit anywhere else', async () => {
  const first = ' ⌂ Help desk redesign 1 '.length
  const all = ' ≡ All projects 2 '.length
  const rest = '─'.repeat(WIDE.bodyColumns - 2 - first - all)

  for (const { name, place } of PLACES) {
    const ui = pane(lookingAt(ASKS_AROUND, place), WIDE)
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

/** The colour of a tab's count of what waits there: the Text in its box that is a number. */
const countColour = async (ui: Drawn, tab: string) => {
  const box = await ui.find({ type: 'Box', key: `${tab}:box` })
  const count = (box?.children as Element[] | undefined)?.find(
    child => child.type === 'Text' && /^\d+$/.test(child.children?.join('') ?? ''),
  )

  if (count === undefined) {
    throw new Error(`${tab}: count not found`)
  }

  return count.props.color
}

test("each tab's count of what waits there is in the asks' colour while its tab is lit, and grey while it is not, in every place the board goes", async () => {
  for (const { name, place } of PLACES) {
    const ui = pane(lookingAt(ASKS_AROUND, place), WIDE)
    const [home, all] = name === 'home' ? [C.ask, C.grey] : [C.grey, C.ask]

    expect(await countColour(ui, 'tab:session'), name).toBe(home)
    expect(await countColour(ui, 'tab:all'), name).toBe(all)
  }
})

test("on a narrow board the first tab's name is cut short, and All projects keeps its full width", async () => {
  const desk: Desk = {
    lines: [
      [T0, status([], { name: 'Redesign the help desk, page by page', summary: HELD.summary })],
      [T0, askOf('k1', GO)],
    ],
  }
  const narrow = { ...WIDE, bodyColumns: 42 }
  const all = ' ≡ All projects 1 '.length
  const first = narrow.bodyColumns - 2 - all

  for (const [way, place, rule] of [
    ['tab:session', null, ` ${'━'.repeat(first)}${'─'.repeat(all)}`],
    ['tab:all', EVERY_PROJECT, ` ${'─'.repeat(first)}${'━'.repeat(all)}`],
  ] as const) {
    const ui = pane(lookingAt(desk, place), narrow)
    const cells = await Promise.all(
      ['tab:session:box', 'tab:all:box'].map(async key => (await ui.find({ key }))?.props.width),
    )

    expect(await header(ui), way).toEqual(['  ⌂ Redesign the he… 1  ≡ All projects 1', rule])
    expect(cells, 'the name takes what All projects leaves').toEqual([first, all])
  }

  const wide = pane(lookingAt(desk, EVERY_PROJECT), WIDE)

  expect((await header(wide))[0], 'wide, the whole name').toMatch(
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

test('docked, the tabs have no close', async () => {
  for (const props of [WIDE, { ...WIDE, bodyColumns: 46 }]) {
    const ui = pane(lookingAt(ASKS_AROUND), props)

    expect(await ui.find({ key: 'tabs:close' }), `${props.bodyColumns}`).toBeUndefined()
    expect((await rows(ui, props.bodyColumns))[0], `${props.bodyColumns}`).toMatch(
      /≡ All projects 2$/,
    )
  }
})

test('the first tab goes home from every place', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)
  const home = { level: 'session', project: PROJECT.key, session: w.state.attachment?.session }

  for (const { name, place } of PLACES.slice(1)) {
    await reach(ui, place)
    expect(placeOf(w), name).not.toEqual(home)
    await ui.press({ key: 'tab:session' })
    expect(placeOf(w), name).toEqual(home)
    expect(await ui.find({ key: 'up' }), name).toBeUndefined()
  }
})

test("under the tab rule, the way back one level up, dim, at the left of its row, then the view's title line; home and All projects leave that row blank; docked and inline", async () => {
  for (const props of [WIDE, { ...WIDE, placement: 'inline' as const }]) {
    for (const { name, place, title, back } of PLACES) {
      const ui = pane(lookingAt(ASKS_AROUND, place), props)
      const scene = `${props.placement}, ${name}`

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
  }
})

test('with no session held, the board is its one line: no tabs, and no blank row under them', async () => {
  for (const props of [WIDE, INLINE]) {
    expect(await rows(pane(undefined, props)), props.placement).toEqual([
      expect.stringMatching(/^ This window holds no session\./),
    ])
  }
})

test('back goes one level up: a session to its project, a project to All projects', async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)

  await reach(ui, sessionPlace(SHIFTS.id, ELSEWHERE.key))
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'project', project: ELSEWHERE.key })
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'all' })

  await reach(ui, ON_LEDGER)
  await ui.press({ key: 'up' })
  expect(placeOf(w)).toEqual({ level: 'project', project: PROJECT.key })
})

test("a session's project, named in its title line, is a dim press opening the project's view, as All projects' does: from home, and from another project's session", async ($, on) => {
  const w = world($, on)

  await asksAround(w)

  const ui = await w.opened(WIDE)

  expect(await ui.find({ key: `proj:${PROJECT.key}`, text: 'Northwind' })).toMatchObject({
    props: { plain: true, dimColor: true },
  })
  await ui.press({ key: `proj:${PROJECT.key}` })
  expect(placeOf(w)).toEqual(projectPlace(PROJECT.key))

  await reach(ui, sessionPlace(SHIFTS.id, ELSEWHERE.key))
  await ui.press({ key: `proj:${ELSEWHERE.key}` })
  expect(placeOf(w)).toEqual(projectPlace(ELSEWHERE.key))
})

/** Phone width, as Blink draws the board inline, and a docked board's. */
const NARROW = [
  { ...INLINE, bodyColumns: 46 },
  { ...WIDE, bodyColumns: 60 },
] as const

test('a long title cuts its aside first, then itself, at phone width and docked, to the whole line: the way back, on the row above, takes none of it', async () => {
  const named = (id: string, name: string): Neighbour => ({
    meta: { ...LEDGER, id, name },
    lines: [[T0, status(['Beginning'], { name, summary: LEDGER.summary })]],
    seenAt: T0,
  })
  const desk: Desk = {
    around: [
      named('sr-r0nd22', 'Invoice ledger, round 2 of the exports'),
      named('sr-w1d3rr', 'Invoice ledger, area by area, with its exports and its retention'),
    ],
  }
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
    for (const [i, id] of ['sr-r0nd22', 'sr-w1d3rr'].entries()) {
      const scene = `${props.bodyColumns}: ${id}`
      const shown = expected[props.bodyColumns][i] ?? ''
      const ui = pane(lookingAt(desk, sessionPlace(id)), props)

      expect(await underRule(ui, props.bodyColumns), scene).toEqual({
        back: ' ← Northwind',
        title: ` ${shown}`,
      })
      expect([...shown].length, `${scene}: no further than the edge`).toBeLessThanOrEqual(
        props.bodyColumns - 2,
      )
    }
  }
})

test('a way back longer than the line is cut short at its edge, and the title line keeps its whole width', async () => {
  const intake = 'intake'
  const desk: Desk = {
    around: [
      {
        meta: { ...SHIFTS, project: intake },
        project: intake,
        projectFile: {
          name: 'The Customer Intake Rebuild Programme, phase two of the three',
          directory: '/Users/me/Code/intake',
          created: T0,
          by: W4,
        },
        seenAt: T0,
      },
    ],
  }
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
    const ui = pane(lookingAt(desk, sessionPlace(SHIFTS.id, intake)), props)

    expect(await underRule(ui, props.bodyColumns), `${props.bodyColumns}`).toEqual(
      expected[props.bodyColumns],
    )
  }
})

test('docked, as inline, the tabs are the first row of the board: there is no collapse or expand', async () => {
  const ui = pane(lookingAt(PARKED_AROUND), WIDE)

  expect((await rows(ui))[0]).toMatch(HOME_FIRST)
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /collapse|expand/ })).toBeUndefined()

  const ledger = pane(lookingAt(PARKED_AROUND, ON_LEDGER), WIDE)

  expect((await rows(ledger))[0]).toMatch(HOME_FIRST)
  expect(await underRule(ledger)).toEqual({
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

test('inline, nothing sits above the tabs, and the header flows with the view: its first rows, the way back, then the view', async () => {
  const home = pane(lookingAt(PARKED_AROUND), INLINE)
  const [first] = await rows(home)

  expect(first).toMatch(HOME_FIRST)
  expect(await home.find({ key: 'collapse' })).toBeUndefined()

  const ui = pane(lookingAt(PARKED_AROUND, ON_LEDGER), INLINE)
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
