import type { RenderPropsOf } from 'claude-code'
import type { SitrepPlace } from '../types'
import { expect, test, tier } from './kit'
import { CURRENT_MS, sessionPaths, type Body, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { C, GLYPH } from '../hooks/look'
import { EVERY_PROJECT, itemKey, projectPlace } from '../hooks/places'
import { rowsOf } from './drawn'
import {
  changeKey,
  DAY,
  ELSEWHERE,
  HELD,
  LEDGER,
  meta,
  MIN,
  PARKED_BEFORE,
  PROJECT,
  REVIEW,
  ROOT,
  SHIFTS,
  T0,
  THEMES,
  W2,
  W3,
  W4,
} from './data'
import { askOf, choiceAsk, file, finish, park, status, yesAsk, type Line } from './lines'
import type { Neighbour } from './filing'
import { pane, sceneFrom, type Desk, type Drawn } from './render'
import { asked, DOCKED, postedId, toProject, WIDE, world, type Board, type World } from './world'

tier('user')

const FABRIKAM = { key: 'fabrikam-1a2b3c4d', name: 'Fabrikam' }
const TAILSPIN = { key: 'tailspin', name: 'Tailspin' }
const DUSTY = { key: 'dusty', name: 'Dusty' }

const NOTES = 'sr-n0tes0'

/**
 * The sessions around this session's, modelled on the spike's: another open
 * session of this project with an ask and something parked, and a closed
 * one; Contoso open with an ask; Fabrikam closed with something parked;
 * Tailspin closed and quiet, updated two days ago; Dusty quiet for longer
 * than a session stays current. This session asks.
 */
const NEIGHBOURHOOD: Desk = {
  lines: [[T0, askOf('k1', REVIEW)]],
  around: [
    {
      meta: LEDGER,
      lines: [
        [T0 - MIN, status(['Reading the brief'], LEDGER)],
        [T0, status(['Drawing the ledger schema'], LEDGER)],
        [T0, choiceAsk('k3', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever'])],
        [T0, park('p2', 'Export the ledger as CSV')],
      ],
      seenAt: T0,
    },
    { meta: { ...THEMES, created: T0 - DAY } },
    {
      meta: SHIFTS,
      project: ELSEWHERE.key,
      lines: [[T0, yesAsk('k5', 'Review the shift schedules')]],
      seenAt: T0,
    },
    {
      meta: meta('sr-0ff11e', 'Offline mode', W3, { project: 'fabrikam', created: T0 - 3 * DAY }),
      project: FABRIKAM.key,
      lines: [[T0, park('p1', 'Thumbnails in the picker')]],
    },
    {
      meta: meta(NOTES, 'Shared notes', W3, { project: 'tailspin', created: T0 - 2 * DAY }),
      project: TAILSPIN.key,
    },
    {
      meta: meta('sr-d0sty0', 'An old idea', W3, {
        project: 'dusty',
        created: T0 - (CURRENT_MS + DAY),
      }),
      project: DUSTY.key,
    },
  ],
}

/** The neighbourhood in a world: the sessions around written, then this session begun and asking. */
async function neighbourhood(w: World) {
  w.surround(NEIGHBOURHOOD.around)

  const { id } = await w.begin()

  return { id, posted: await asked(w, REVIEW) }
}

/** The neighbourhood drawn as `props`, the board looking at a place, with an item opened where one is named. */
const neighbourhoodAt = (
  place: SitrepPlace | null,
  props: RenderPropsOf['Pane'],
  selected: string | null = null,
) => pane(sceneFrom({ ...NEIGHBOURHOOD, pane: { place, selected } }), props)

/** The keys of the drawn buttons that start with `prefix`, in the order drawn. */
const keysOf = async (ui: Drawn, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith(prefix))

test('the board walks from this session to every project, down into a project and its sessions, and back up', async ($, on) => {
  const w = world($, on)
  const { posted } = await neighbourhood(w)
  const ui = await w.opened()

  expect(await ui.find({ key: `pick:${w.item(posted)}` })).toBeDefined()

  // All projects, then this project: the tabs stay, and the way back sits under them.
  await toProject(ui)
  expect(await ui.find({ key: 'tab:all' })).toBeDefined()
  expect(await ui.find({ key: 'up', text: '← All projects' })).toBeDefined()

  // Down into another session of it, and back up to the project, then to every project.
  await ui.press({ key: `go:${LEDGER.id}` })
  expect(await ui.find({ key: 'up', text: '← Northwind' })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
  await ui.press({ key: 'up' })
  expect(w.state.pane).toMatchObject({ place: { level: 'all' } })
  expect(await ui.find({ key: 'up' }), 'none on All projects').toBeUndefined()

  // Quiet ones fold away; down into another project's session and back up twice.
  expect(await ui.find({ key: `proj:${ELSEWHERE.key}` })).toBeDefined()
  expect(await ui.find({ key: `proj:${TAILSPIN.key}` })).toBeUndefined()
  expect(await ui.find({ key: `proj:${FABRIKAM.key}` })).toBeDefined()
  await ui.press({ key: `go:${SHIFTS.id}` })
  expect(await ui.find({ key: `pick:${SHIFTS.id}:k5` })).toBeDefined()
  expect(await ui.find({ key: 'up', text: '← Contoso' })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(await ui.find({ key: 'up', text: '← All projects' })).toBeDefined()

  // Home, from anywhere.
  await ui.press({ key: 'tab:session' })
  expect(await ui.find({ key: `pick:${w.item(posted)}` })).toBeDefined()
})

test('closed and opened again, the board is home, wherever it had gone', async ($, on) => {
  const w = world($, on)
  const { posted } = await neighbourhood(w)
  const ui = await w.opened()
  const band = await w.band()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  expect(w.state.pane).toMatchObject({
    place: { level: 'session', session: LEDGER.id },
    selected: `${LEDGER.id}:k3`,
  })

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })
  expect(w.state.pane).toMatchObject({ isOpen: true, place: null, selected: null })
  expect(await ui.find({ key: `pick:${w.item(posted)}` })).toBeDefined()
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
})

test('the board shows two tabs, home by its name and All projects, each with what waits there', async () => {
  const ui = neighbourhoodAt(null, WIDE)
  const counts = async (drawn: Drawn) =>
    Promise.all(
      ['tab:session:box', 'tab:all:box'].map(async key => rowsOf(await drawn.find({ key }))),
    )

  expect(await ui.find({ key: 'tab:session', text: 'Help desk redesign' })).toBeDefined()
  expect(await ui.find({ key: 'tab:all', text: 'All projects' })).toBeDefined()
  expect(await ui.find({ key: 'tab:project' })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /This session/ })).toBeUndefined()
  expect(await counts(ui), 'one waits here, three across every project').toEqual([
    [' ⌂ Help desk redesign 1'],
    [' ≡ All projects 3'],
  ])

  expect(await counts(neighbourhoodAt(EVERY_PROJECT, WIDE))).toEqual([
    [' ⌂ Help desk redesign 1'],
    [' ≡ All projects 3'],
  ])
})

test("another session's view is the session view: its status and its history, its asks with working buttons, what it parked", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  expect(await ui.find({ type: 'Text', text: 'Invoice ledger' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Drawing the ledger schema' })).toBeDefined()
  expect(
    (await ui.findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => ['Invoice ledger', 'ASKS', 'STATUS', 'PARKED'].includes(text)),
    'the same order as this session’s',
  ).toEqual(['Invoice ledger', 'ASKS', 'STATUS', 'PARKED'])
  await ui.press({ key: `history:${LEDGER.id}` })
  expect(
    await ui.find({
      key: `status:${changeKey(LEDGER.id, T0, W2)}`,
      text: 'now drawing the ledger schema',
    }),
  ).toBeDefined()
  expect(
    await ui.find({ key: `ppick:${LEDGER.id}:p2`, text: 'Export the ledger as CSV' }),
  ).toBeDefined()

  await ui.press({ key: `ppick:${LEDGER.id}:p2` })
  await ui.press({ key: `pickup:${LEDGER.id}:p2` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'p2', verdict: 'pickup' },
  ])
  await ui.press({ key: `undo:${LEDGER.id}:p2` })

  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `choose:${LEDGER.id}:k3:1` })
  expect(await ui.find({ type: 'Text', text: '→ Forever' })).toBeDefined()
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'k3', verdict: 'choose', option: 'Forever' },
  ])
})

test("the project view lists its sessions, this one first, each with what it does and what waits; and no history of their status, each session's being under its own Status", async () => {
  const ui = neighbourhoodAt(projectPlace(PROJECT.key), DOCKED)

  expect(await keysOf(ui, 'go:')).toEqual([`go:${HELD.id}`, `go:${LEDGER.id}`, `go:${THEMES.id}`])
  expect(await ui.find({ type: 'Text', text: '2 of 3 open' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()

  const sessions = (await ui.findAll({ type: 'Box' })).filter(each => each.key?.startsWith('sess:'))

  expect(sessions.map(each => rowsOf(each))).toEqual([
    ['Help desk redesign ⌂ 1 waiting', '└ Redesign the help desk, page by page'],
    ['Invoice ledger 1 waiting', '└ Drawing the ledger schema'],
    ['Themes closed', '└ Themes, area by area'],
  ])

  const shown = pane(
    sceneFrom({
      ...NEIGHBOURHOOD,
      pane: {
        place: projectPlace(PROJECT.key),
        shown: { [`history:project:${PROJECT.key}`]: 'latest' },
      },
    }),
  )

  expect(await keysOf(ui, 'history:')).toEqual([])
  expect(await keysOf(shown, 'history:'), 'shown as a pane an older load saved').toEqual([])
  expect(await keysOf(shown, 'status:')).toEqual([])
})

test('All projects: this project first, then the busiest; the quiet fold into one line; an old idle session is gone', async () => {
  const ui = neighbourhoodAt(EVERY_PROJECT, DOCKED)

  expect(await keysOf(ui, 'proj:')).toEqual([
    `proj:${PROJECT.key}`,
    `proj:${ELSEWHERE.key}`,
    `proj:${FABRIKAM.key}`,
  ])
  expect(await keysOf(ui, 'go:')).toEqual([`go:${HELD.id}`, `go:${LEDGER.id}`, `go:${SHIFTS.id}`])
  expect(await ui.find({ type: 'Text', text: 'no sessions open · ◇ 1 parked' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: '1 more, with nothing going on: Tailspin' }),
  ).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /Dusty/ })).toBeUndefined()
})

test("the project view's ASKS lists asks two sessions posted at the same moment by their sessions, whichever order the sessions are read in", async () => {
  const around: readonly Neighbour[] = [
    { meta: THEMES, lines: [[T0, yesAsk('k1', 'Approve the dark theme')]], seenAt: T0 },
    { meta: LEDGER, lines: [[T0, yesAsk('k3', 'Review the ledger schema')]], seenAt: T0 },
  ]
  const asked = (read: readonly Neighbour[]) =>
    keysOf(pane(sceneFrom({ around: read, pane: { place: projectPlace(PROJECT.key) } })), 'pick:')
  const ledgerFirst = [`pick:${itemKey(LEDGER.id, 'k3')}`, `pick:${itemKey(THEMES.id, 'k1')}`]

  expect(await asked(around)).toEqual(ledgerFirst)
  expect(await asked([...around].reverse())).toEqual(ledgerFirst)
})

test("the project view's ASKS holds every session's asks, the newest first, each naming its session and answered from there", async ($, on) => {
  const w = world($, on)
  const { posted } = await neighbourhood(w)
  const ui = await w.opened(WIDE)
  const rows = async () => rowsOf(await ui.find({ type: 'Box' }), WIDE.bodyColumns)

  await toProject(ui)
  expect(
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('pick:'))
      .map(each => [each.key, each.text]),
  ).toEqual([
    [`pick:${w.item(posted)}`, 'Help desk redesign: Review Tickets & Replies, round 1'],
    [`pick:${LEDGER.id}:k3`, 'Invoice ledger: Keep the ledger 400 days, or forever?'],
  ])
  expect(await ui.find({ type: 'Text', text: '2 waiting' })).toBeDefined()

  const listed = await rows()
  const at = listed.findIndex(row => row.startsWith(' ASKS'))

  expect(listed.slice(at + 1, at + 3), 'no blank row between asks').toEqual([
    expect.stringMatching(/^ ◆ Help desk redesign: Review Tickets & Replies, round 1 +now$/),
    expect.stringMatching(/^ ◆ Invoice ledger: Keep the ledger 400 days, or forever\? +now$/),
  ])

  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `choose:${LEDGER.id}:k3:1` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'k3', verdict: 'choose', option: 'Forever' },
  ])
  expect(await ui.find({ type: 'Text', text: '→ Forever' })).toBeDefined()
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
})

test("the project view's PARKED holds every session's parked items, the oldest first, each naming its session; there is no RESOLVED", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)
  await w.clock.advance(MIN)

  const tmux = postedId(await w.call('park', { title: 'A priority badge across all tabs' }))
  const done = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the apply' })

  await w.call('resolve', { item: done, reason: 'Ran it in the chat' })

  const ui = await w.opened(WIDE)
  const headings = async () =>
    (await ui.findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => ['SESSIONS', 'ASKS', 'PARKED', 'RESOLVED'].includes(text))

  expect(
    await ui.find({ type: 'Text', text: 'RESOLVED' }),
    'this session has its RESOLVED',
  ).toBeDefined()

  await toProject(ui)
  expect(await headings()).toEqual(['SESSIONS', 'ASKS', 'PARKED'])
  expect(await ui.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('ppick:'))
      .map(each => [each.key, each.text]),
  ).toEqual([
    [`ppick:${LEDGER.id}:p2`, 'Invoice ledger: Export the ledger as CSV'],
    [`ppick:${w.item(tmux)}`, 'Help desk redesign: A priority badge across all tabs'],
  ])

  await ui.press({ key: `ppick:${LEDGER.id}:p2` })
  await ui.press({ key: `pickup:${LEDGER.id}:p2` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'p2', verdict: 'pickup' },
  ])

  await ui.press({ key: 'up' })
  expect(
    await ui.find({ type: 'Text', text: 'PARKED' }),
    'All projects is the tree alone',
  ).toBeUndefined()
})

/** The parked items' buttons drawn, each with its text, in the order drawn. */
const parkedButtons = async (ui: Board) =>
  (await ui.findAll({ type: 'Button' }))
    .filter(each => each.key?.startsWith('ppick:'))
    .map(each => [each.key, each.text])

/** A session started by `by` in a project, its lines `ago` before now: idle, past the views. */
const longIdle = (w: World, session: SessionMeta, project: string, ...bodies: Body[]) => {
  const { paths } = w.elsewhere(session, project)

  w.put(paths.log(session.by), file(...bodies.map((body): Line => [session.created, body])))
}

test("the project view's PARKED holds a finished session's items and an idle one's past the views, each by its session's name, and counts them all; a session's view holds them too, its own first, unnamed, and counts them all", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  longIdle(
    w,
    { ...THEMES, created: T0 - (CURRENT_MS + DAY) },
    PROJECT.key,
    park('p1', 'Theme the lobby too'),
  )
  ledger.write(park('p2', 'Export the ledger as CSV'), finish('claude', 'Shipped'))

  const { id } = await w.begin()

  await w.clock.advance(MIN)

  const tmux = postedId(await w.call('park', { title: 'A priority badge across all tabs' }))
  const ui = await w.opened(WIDE)

  expect(await ui.find({ type: 'Text', text: '3 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    [`ppick:${w.item(tmux)}`, 'A priority badge across all tabs'],
    [`ppick:${THEMES.id}:p1`, 'Themes: Theme the lobby too'],
    [`ppick:${LEDGER.id}:p2`, 'Invoice ledger: Export the ledger as CSV'],
  ])

  await toProject(ui)
  expect(await keysOf(ui, 'go:'), 'neither session is current').toEqual([`go:${id}`])
  expect(await ui.find({ type: 'Text', text: '3 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    [`ppick:${THEMES.id}:p1`, 'Themes: Theme the lobby too'],
    [`ppick:${LEDGER.id}:p2`, 'Invoice ledger: Export the ledger as CSV'],
    [`ppick:${w.item(tmux)}`, 'Help desk redesign: A priority badge across all tabs'],
  ])

  await ui.press({ key: `ppick:${LEDGER.id}:p2` })
  expect(await ui.find({ key: `pickup:${LEDGER.id}:p2` })).toBeDefined()
  expect(await ui.find({ key: `comment:${LEDGER.id}:p2` })).toBeDefined()
})

test("a finished session's files as a build before parked items were the project's left them: its items show in the project's PARKED by its name, and no look rewrites a byte", async ($, on) => {
  const w = world($, on)
  const paths = sessionPaths(ROOT, PROJECT.key, PARKED_BEFORE.id)
  const filesThere = () =>
    [...w.files].flatMap(([path, { text }]) => (path.startsWith(paths.dir) ? [[path, text]] : []))

  w.put(paths.meta, PARKED_BEFORE.meta)
  w.put(paths.log(PARKED_BEFORE.writer), PARKED_BEFORE.log)

  const before = filesThere()

  await w.begin()

  const ui = await w.opened(WIDE)

  await toProject(ui)
  expect(await ui.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    [`ppick:${PARKED_BEFORE.id}:p1`, 'Invoice ledger: Export the ledger as CSV'],
    [`ppick:${PARKED_BEFORE.id}:p2`, 'Invoice ledger: Archive old invoices'],
  ])

  await w.clock.advance(4 * AROUND_MS)
  expect(filesThere()).toEqual(before)
})

test('All projects keeps a project whose sessions are finished or idle past the views while something is parked in it, unfolded and counting it; its view says no sessions open, and its items show without pick-up buttons in a window of another project, the drop alone offered', async ($, on) => {
  const w = world($, on)
  const offline = w.elsewhere(
    meta('sr-0ff11e', 'Offline mode', W3, { project: 'fabrikam' }),
    FABRIKAM.key,
  )

  offline.write(park('p1', 'Thumbnails in the picker'), finish('lee'))
  longIdle(
    w,
    meta('sr-5ync00', 'Offline sync', W4, {
      project: 'fabrikam',
      created: T0 - (CURRENT_MS + DAY),
    }),
    FABRIKAM.key,
    park('p1', 'Resume the paused uploads'),
  )
  longIdle(
    w,
    meta('sr-d0sty0', 'An old idea', W3, { project: 'dusty', created: T0 - (CURRENT_MS + DAY) }),
    DUSTY.key,
  )
  await w.begin()

  const ui = await w.opened(WIDE)

  await ui.press({ key: 'tab:all' })
  expect(await keysOf(ui, 'proj:')).toEqual([`proj:${PROJECT.key}`, `proj:${FABRIKAM.key}`])
  expect(await ui.find({ type: 'Text', text: 'no sessions open · ◇ 2 parked' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /more, with nothing going on/ })).toBeUndefined()

  await ui.press({ key: `proj:${FABRIKAM.key}` })
  expect(await ui.find({ type: 'Text', text: 'no sessions open' }), 'SESSIONS').toBeDefined()
  expect(await ui.find({ type: 'Text', text: /of 0 open/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    ['ppick:sr-5ync00:p1', 'Offline sync: Resume the paused uploads'],
    ['ppick:sr-0ff11e:p1', 'Offline mode: Thumbnails in the picker'],
  ])

  await ui.press({ key: 'ppick:sr-0ff11e:p1' })
  expect(w.state.pane).toMatchObject({ selected: 'sr-0ff11e:p1' })
  expect(await keysOf(ui, 'pickup:'), 'no pick-up from another project').toEqual([])
  expect(await keysOf(ui, 'comment:')).toEqual([])
  expect(await keysOf(ui, 'drop:'), 'the drop, which goes to no Claude').toEqual([
    'drop:sr-0ff11e:p1',
  ])
  expect(
    (await ui.find({ key: 'drop:sr-0ff11e:p1' }))?.props.dimColor,
    'the only press, so not dim',
  ).toBeFalsy()
})

test('the band counts what waits in every other session, in every project, and opens All projects on it', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const band = await w.band()

  expect(await band.find({ key: 'band:asks' })).toMatchObject({ text: '1 ask' })
  expect(
    await band.find({ key: 'band:elsewhere', text: '2 elsewhere' }),
    "the ledger's ask and Contoso's",
  ).toBeDefined()

  await band.press({ key: 'band:elsewhere' })
  expect(w.panes.get('sitrep')).toBe(true)
  expect(w.state.pane).toMatchObject({ place: { level: 'all' } })

  const board = await w.pane()

  expect(await board.find({ key: `proj:${ELSEWHERE.key}` })).toBeDefined()
  expect(await board.find({ key: 'tab:all' })).toMatchObject({ props: { dimColor: false } })

  const narrow = await w.band('terminal', 50)

  expect(await narrow.find({ key: 'band:elsewhere', text: '+2' })).toBeDefined()
})

test("a new ask in another session, in this project or another, reaches the band's count at the slower pace, the board closed", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)
  const shifts = w.elsewhere(SHIFTS, ELSEWHERE.key)

  ledger.beat()
  shifts.beat()
  await w.begin()

  const band = await w.band()

  expect(await band.find({ key: 'band:elsewhere' })).toBeUndefined()

  ledger.write(yesAsk('k3', 'Run the ledger migration', 'Done'))
  shifts.write(yesAsk('k5', 'Review the shift schedules'))
  ledger.beat()
  shifts.beat()
  await w.clock.advance(AROUND_MS)
  expect(await band.find({ key: 'band:elsewhere', text: '2 elsewhere' })).toBeDefined()
  expect(w.state.others, 'nothing is read in full with the board closed').toEqual([])
  expect(
    w.state.projects?.map(project => project.key).sort(),
    'every project is read, the board closed',
  ).toEqual([ELSEWHERE.key, PROJECT.key])
})

test("the project view's sessions and All projects' trees hang from faint glyphs", async () => {
  const colours = async (ui: Drawn, text: string) => [
    ...new Set((await ui.findAll({ type: 'Text', text })).map(each => each.props.color)),
  ]
  const project = neighbourhoodAt(projectPlace(PROJECT.key), WIDE)
  const all = neighbourhoodAt(EVERY_PROJECT, WIDE)

  expect(await colours(project, GLYPH.last)).toEqual([C.faint])
  expect(await colours(all, GLYPH.branch)).toEqual([C.faint])
  expect(await colours(all, GLYPH.last)).toEqual([C.faint])
})

test('what the sessions around hold is put in $.state only when a look finds it changed', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  await w.begin()

  const before = w.writes.projects

  await w.clock.advance(3 * AROUND_MS)
  expect(w.writes.projects, 'nothing changed, so nothing is put').toBe(before)

  ledger.write(status(['Writing the schema'], LEDGER))
  await w.clock.advance(AROUND_MS)
  expect(w.writes.projects).toBe((before ?? 0) + 1)
  expect(w.state.projects?.[0]?.sessions[0]?.now).toEqual(['Writing the schema'])
})
