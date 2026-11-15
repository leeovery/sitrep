import { expect, test, tier } from './kit'
import { CURRENT_MS, sessionPaths, type Body, type SessionMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { C, GLYPH } from '../hooks/look'
import { rowsOf } from './drawn'
import {
  choiceAsk,
  file,
  finish,
  MIN,
  note,
  park,
  PARKED_BEFORE,
  status,
  T0,
  W2,
  W3,
  W4,
  yesAsk,
  type Line,
} from './support'
import { ELSEWHERE, postedId, PROJECT, ROOT, toProject, WIDE, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const DAY = 24 * 60 * MIN

const PORTAL = { key: 'portal-1a2b3c4d', name: 'Portal' }
const PIGEON = { key: 'pigeon', name: 'Pigeon' }
const DUSTY = { key: 'dusty', name: 'Dusty' }

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

const LEDGER = 'sr-1edger'
const THEMES = 'sr-themes'
const ORDERS = 'sr-0rders'
const NOTES = 'sr-p1ge0n'

/** A session started by `by` in a project, `ago` before now. */
const meta = (id: string, name: string, project: string, by: string, ago = 0): SessionMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project,
  root: `/Users/lee/Code/${project}`,
  created: T0 - ago,
  by,
})

/**
 * The sessions around this session's, modelled on the spike's: another open
 * session of this project with an ask and something parked, and a closed
 * one; Goosemates open with an ask; Portal closed with something parked;
 * Pigeon closed and quiet, updated two days ago; Dusty quiet for longer
 * than a session stays current. Then this session starts its own and asks.
 */
async function neighbourhood(w: World) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))
  const orders = w.elsewhere(meta(ORDERS, 'Standing orders', 'goosemates', W4), ELSEWHERE.key)

  ledger.write(
    status(['Drawing the ledger schema'], {
      name: 'Request ledger',
      summary: 'Request ledger, area by area',
    }),
    choiceAsk('k3', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
    park('p2', 'Export the ledger as CSV'),
    note('n3', 'Wrote the schema'),
  )
  ledger.beat()
  w.elsewhere(meta(THEMES, 'Themes', 'switchboard', W3, DAY))
  orders.write(yesAsk('k5', 'Review the standing orders'))
  orders.beat()
  w.elsewhere(meta('sr-p0rta1', 'Agent-aware Portal', 'portal', W3, 3 * DAY), PORTAL.key).write(
    park('p1', 'Thumbnails in the picker'),
  )
  w.elsewhere(meta(NOTES, 'Space-aware notes', 'pigeon', W3, 2 * DAY), PIGEON.key)
  w.elsewhere(meta('sr-d0sty0', 'An old idea', 'dusty', W3, CURRENT_MS + DAY), DUSTY.key)

  const { id } = await w.begin()

  return { id, asked: postedId(await w.call('ask', REVIEW)) }
}

/** The keys of the drawn buttons that start with `prefix`, in the order drawn. */
const keysOf = async (ui: Awaited<ReturnType<World['pane']>>, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith(prefix))

test('the board walks from this session to every project, down into a project and its sessions, and back up', async ($, on) => {
  const w = world($, on)
  const { asked } = await neighbourhood(w)
  const ui = await w.opened()

  expect(await ui.find({ key: `pick:${w.item(asked)}` })).toBeDefined()

  // All projects, then this project: the tabs stay, and the way back sits under them.
  await toProject(ui)
  expect(await ui.find({ key: 'tab:all' })).toBeDefined()
  expect(await ui.find({ key: 'up', text: '← All projects' })).toBeDefined()

  // Down into another session of it, and back up to the project, then to every project.
  await ui.press({ key: `go:${LEDGER}` })
  expect(await ui.find({ key: 'up', text: '← Switchboard' })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
  await ui.press({ key: 'up' })
  expect(w.state.pane).toMatchObject({ place: { level: 'all' } })
  expect(await ui.find({ key: 'up' }), 'none on All projects').toBeUndefined()

  // Quiet ones fold away; down into another project's session and back up twice.
  expect(await ui.find({ key: `proj:${ELSEWHERE.key}` })).toBeDefined()
  expect(await ui.find({ key: `proj:${PIGEON.key}` })).toBeUndefined()
  expect(await ui.find({ key: `proj:${PORTAL.key}` })).toBeDefined()
  await ui.press({ key: `go:${ORDERS}` })
  expect(await ui.find({ key: `pick:${ORDERS}:k5` })).toBeDefined()
  expect(await ui.find({ key: 'up', text: '← Goosemates' })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(await ui.find({ key: 'up', text: '← All projects' })).toBeDefined()

  // Home, from anywhere.
  await ui.press({ key: 'tab:session' })
  expect(await ui.find({ key: `pick:${w.item(asked)}` })).toBeDefined()
})

test('closed and opened again, the board is home, wherever it had gone', async ($, on) => {
  const w = world($, on)
  const { asked } = await neighbourhood(w)
  const ui = await w.opened()
  const band = await w.band()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: `pick:${LEDGER}:k3` })
  expect(w.state.pane).toMatchObject({
    place: { level: 'session', session: LEDGER },
    selected: `${LEDGER}:k3`,
  })

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })
  expect(w.state.pane).toMatchObject({ isOpen: true, place: null, selected: null })
  expect(await ui.find({ key: `pick:${w.item(asked)}` })).toBeDefined()
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
})

test('the board shows two tabs, home by its name and All projects, each with what waits there', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened(WIDE)
  const counts = async () =>
    Promise.all(['tab:session:box', 'tab:all:box'].map(async key => rowsOf(await ui.find({ key }))))

  expect(await ui.find({ key: 'tab:session', text: 'Dashboard redesign' })).toBeDefined()
  expect(await ui.find({ key: 'tab:all', text: 'All projects' })).toBeDefined()
  expect(await ui.find({ key: 'tab:project' })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /This session/ })).toBeUndefined()
  expect(await counts(), 'one waits here, three across every project').toEqual([
    [' ⌂ Dashboard redesign 1'],
    [' ≡ All projects 3'],
  ])

  await ui.press({ key: 'tab:all' })
  expect(await counts()).toEqual([[' ⌂ Dashboard redesign 1'], [' ≡ All projects 3']])
})

test("another session's view is the session view: its status, its asks with working buttons, its notes", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER}` })
  expect(await ui.find({ type: 'Text', text: 'Request ledger' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Drawing the ledger schema' })).toBeDefined()
  expect(
    (await ui.findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => ['Request ledger', 'ASKS', 'STATUS', 'NOTES', 'PARKED'].includes(text)),
    'the same order as this session’s',
  ).toEqual(['Request ledger', 'ASKS', 'STATUS', 'NOTES', 'PARKED'])
  expect(await ui.find({ key: `log:${LEDGER}:n3`, text: 'Wrote the schema' })).toBeDefined()
  expect(
    await ui.find({ key: `ppick:${LEDGER}:p2`, text: 'Export the ledger as CSV' }),
  ).toBeDefined()

  await ui.press({ key: `ppick:${LEDGER}:p2` })
  await ui.press({ key: `pickup:${LEDGER}:p2` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER, item: 'p2', verdict: 'pickup' },
  ])
  await ui.press({ key: `undo:${LEDGER}:p2` })

  await ui.press({ key: `pick:${LEDGER}:k3` })
  await ui.press({ key: `choose:${LEDGER}:k3:1` })
  expect(await ui.find({ type: 'Text', text: '→ Forever' })).toBeDefined()
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER, item: 'k3', verdict: 'choose', option: 'Forever' },
  ])
})

test("the project view lists its sessions, this one first, each with what it does and what waits; and the project's notes", async ($, on) => {
  const w = world($, on)
  const { id } = await neighbourhood(w)
  const ui = await w.opened()

  await toProject(ui)

  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER}`, `go:${THEMES}`])
  expect(await ui.find({ type: 'Text', text: '2 of 3 open' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Drawing the ledger schema' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '1 waiting' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'closed' })).toBeDefined()
  expect(
    await ui.find({ key: `log:${LEDGER}:n3`, text: 'Request ledger: Wrote the schema' }),
  ).toBeDefined()

  await ui.press({ key: `log:${LEDGER}:n3` })
  expect(await ui.find({ type: 'Text', text: 'nothing more was recorded' })).toBeDefined()
})

test('All projects: this project first, then the busiest; the quiet fold into one line; an old idle session is gone', async ($, on) => {
  const w = world($, on)
  const { id } = await neighbourhood(w)

  const ui = await w.opened()

  await ui.press({ key: 'tab:all' })

  expect(await keysOf(ui, 'proj:')).toEqual([
    `proj:${PROJECT.key}`,
    `proj:${ELSEWHERE.key}`,
    `proj:${PORTAL.key}`,
  ])
  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER}`, `go:${ORDERS}`])
  expect(await ui.find({ type: 'Text', text: 'no sessions open · ◇ 1 parked' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: '1 more, with nothing going on: Pigeon' }),
  ).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /Dusty/ })).toBeUndefined()
})

test("the project view's ASKS holds every session's asks, the newest first, each naming its session and answered from there", async ($, on) => {
  const w = world($, on)
  const { asked } = await neighbourhood(w)
  const ui = await w.opened(WIDE)
  const rows = async () => rowsOf(await ui.find({ type: 'Box' }), WIDE.bodyColumns)

  await toProject(ui)
  expect(
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('pick:'))
      .map(each => [each.key, each.text]),
  ).toEqual([
    [`pick:${w.item(asked)}`, 'Dashboard redesign: Review Sessions & Runway, round 1'],
    [`pick:${LEDGER}:k3`, 'Request ledger: Keep the ledger 400 days, or forever?'],
  ])
  expect(await ui.find({ type: 'Text', text: '2 waiting' })).toBeDefined()

  const listed = await rows()
  const at = listed.findIndex(row => row.startsWith(' ASKS'))

  expect(listed.slice(at + 1, at + 3), 'no blank row between asks').toEqual([
    expect.stringMatching(/^ ◆ Dashboard redesign: Review Sessions & Runway, round 1 +now$/),
    expect.stringMatching(/^ ◆ Request ledger: Keep the ledger 400 days, or forever\? +now$/),
  ])

  await ui.press({ key: `pick:${LEDGER}:k3` })
  await ui.press({ key: `choose:${LEDGER}:k3:1` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER, item: 'k3', verdict: 'choose', option: 'Forever' },
  ])
  expect(await ui.find({ type: 'Text', text: '→ Forever' })).toBeDefined()
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
})

test("the project view's PARKED holds every session's parked items, the oldest first, each naming its session; there is no RESOLVED", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)
  await w.clock.advance(MIN)

  const tmux = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))
  const done = postedId(await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run the apply' }))

  await w.call('resolve', { item: done, reason: 'Ran it in the chat' })

  const ui = await w.opened(WIDE)
  const headings = async () =>
    (await ui.findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => ['SESSIONS', 'ASKS', 'NOTES', 'PARKED', 'RESOLVED'].includes(text))

  expect(
    await ui.find({ type: 'Text', text: 'RESOLVED' }),
    'this session has its RESOLVED',
  ).toBeDefined()

  await toProject(ui)
  expect(await headings()).toEqual(['SESSIONS', 'ASKS', 'NOTES', 'PARKED'])
  expect(await ui.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('ppick:'))
      .map(each => [each.key, each.text]),
  ).toEqual([
    [`ppick:${LEDGER}:p2`, 'Request ledger: Export the ledger as CSV'],
    [`ppick:${w.item(tmux)}`, 'Dashboard redesign: A tmux indicator across sessions'],
  ])

  await ui.press({ key: `ppick:${LEDGER}:p2` })
  await ui.press({ key: `pickup:${LEDGER}:p2` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER, item: 'p2', verdict: 'pickup' },
  ])

  await ui.press({ key: 'up' })
  expect(
    await ui.find({ type: 'Text', text: 'PARKED' }),
    'All projects is the tree alone',
  ).toBeUndefined()
})

/** The parked items' buttons drawn, each with its text, in the order drawn. */
const parkedButtons = async (ui: Awaited<ReturnType<World['pane']>>) =>
  (await ui.findAll({ type: 'Button' }))
    .filter(each => each.key?.startsWith('ppick:'))
    .map(each => [each.key, each.text])

/** A session started by `by` in a project, its lines `ago` before now: idle, past the views. */
const longIdle = (w: World, meta: SessionMeta, project: string, ...bodies: Body[]) => {
  const { paths } = w.elsewhere(meta, project)

  w.put(paths.log(meta.by), file(...bodies.map((body): Line => [meta.created, body])))
}

test("the project view's PARKED holds a finished session's items and an idle one's past the views, each by its session's name, and counts them all; a session's view holds its own", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))

  longIdle(
    w,
    meta(THEMES, 'Themes', 'switchboard', W3, CURRENT_MS + DAY),
    PROJECT.key,
    park('p1', 'Theme the lobby too'),
  )
  ledger.write(park('p2', 'Export the ledger as CSV'), finish('claude', 'Shipped'))

  const { id } = await w.begin()

  await w.clock.advance(MIN)

  const tmux = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))
  const ui = await w.opened(WIDE)

  expect(await ui.find({ type: 'Text', text: '1 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    [`ppick:${w.item(tmux)}`, 'A tmux indicator across sessions'],
  ])

  await toProject(ui)
  expect(await keysOf(ui, 'go:'), 'neither session is current').toEqual([`go:${id}`])
  expect(await ui.find({ type: 'Text', text: '3 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    [`ppick:${THEMES}:p1`, 'Themes: Theme the lobby too'],
    [`ppick:${LEDGER}:p2`, 'Request ledger: Export the ledger as CSV'],
    [`ppick:${w.item(tmux)}`, 'Dashboard redesign: A tmux indicator across sessions'],
  ])

  await ui.press({ key: `ppick:${LEDGER}:p2` })
  expect(await ui.find({ key: `pickup:${LEDGER}:p2` })).toBeDefined()
  expect(await ui.find({ key: `comment:${LEDGER}:p2` })).toBeDefined()
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
    [`ppick:${PARKED_BEFORE.id}:p1`, 'Request ledger: Export the ledger as CSV'],
    [`ppick:${PARKED_BEFORE.id}:p2`, 'Request ledger: Archive old requests'],
  ])

  await w.clock.advance(4 * AROUND_MS)
  expect(filesThere()).toEqual(before)
})

test('All projects keeps a project whose sessions are finished or idle past the views while something is parked in it, unfolded and counting it; its view says no sessions open, and its items show without pick-up buttons in a window of another project', async ($, on) => {
  const w = world($, on)
  const portal = w.elsewhere(meta('sr-p0rta1', 'Agent-aware Portal', 'portal', W3), PORTAL.key)

  portal.write(park('p1', 'Thumbnails in the picker'), finish('lee'))
  longIdle(
    w,
    meta('sr-p0rta2', 'Portal on zmx', 'portal', W4, CURRENT_MS + DAY),
    PORTAL.key,
    park('p1', 'Resume the zmx sessions'),
  )
  longIdle(w, meta('sr-d0sty0', 'An old idea', 'dusty', W3, CURRENT_MS + DAY), DUSTY.key)
  await w.begin()

  const ui = await w.opened(WIDE)

  await ui.press({ key: 'tab:all' })
  expect(await keysOf(ui, 'proj:')).toEqual([`proj:${PROJECT.key}`, `proj:${PORTAL.key}`])
  expect(await ui.find({ type: 'Text', text: 'no sessions open · ◇ 2 parked' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /more, with nothing going on/ })).toBeUndefined()

  await ui.press({ key: `proj:${PORTAL.key}` })
  expect(await ui.find({ type: 'Text', text: 'no sessions open' }), 'SESSIONS').toBeDefined()
  expect(await ui.find({ type: 'Text', text: /of 0 open/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(await parkedButtons(ui)).toEqual([
    ['ppick:sr-p0rta2:p1', 'Portal on zmx: Resume the zmx sessions'],
    ['ppick:sr-p0rta1:p1', 'Agent-aware Portal: Thumbnails in the picker'],
  ])

  await ui.press({ key: 'ppick:sr-p0rta1:p1' })
  expect(w.state.pane).toMatchObject({ selected: 'sr-p0rta1:p1' })
  expect(await keysOf(ui, 'pickup:'), 'no pick-up from another project').toEqual([])
  expect(await keysOf(ui, 'comment:')).toEqual([])
})

test('the band counts what waits in every other session, in every project, and opens All projects on it', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const band = await w.band()

  expect(await band.find({ key: 'band:asks', text: '1 ask' })).toBeDefined()
  expect(
    await band.find({ key: 'band:elsewhere', text: '2 elsewhere' }),
    "the ledger's ask and Goosemates'",
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
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))
  const orders = w.elsewhere(meta(ORDERS, 'Standing orders', 'goosemates', W4), ELSEWHERE.key)

  ledger.beat()
  orders.beat()
  await w.begin()

  const band = await w.band()

  expect(await band.find({ key: 'band:elsewhere' })).toBeUndefined()

  ledger.write(yesAsk('k3', 'Run the ledger migration', 'Done'))
  orders.write(yesAsk('k5', 'Review the standing orders'))
  ledger.beat()
  orders.beat()
  await w.clock.advance(AROUND_MS)
  expect(await band.find({ key: 'band:elsewhere', text: '2 elsewhere' })).toBeDefined()
  expect(w.state.others, 'nothing is read in full with the board closed').toEqual([])
  expect(
    w.state.projects?.map(project => project.key).sort(),
    'every project is read, the board closed',
  ).toEqual([ELSEWHERE.key, PROJECT.key])
})

test("the project view's sessions and All projects' trees hang from faint glyphs", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened(WIDE)
  const colours = async (text: string) => [
    ...new Set((await ui.findAll({ type: 'Text', text })).map(each => each.props.color)),
  ]

  await toProject(ui)
  expect(await colours(GLYPH.last)).toEqual([C.faint])

  await ui.press({ key: 'up' })
  expect(await colours(GLYPH.branch)).toEqual([C.faint])
  expect(await colours(GLYPH.last)).toEqual([C.faint])
})

test('what the sessions around hold is put in $.state only when a look finds it changed', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))

  await w.begin()

  const before = w.writes.projects

  await w.clock.advance(3 * AROUND_MS)
  expect(w.writes.projects, 'nothing changed, so nothing is put').toBe(before)

  ledger.write(note('n3', 'Wrote the schema'))
  await w.clock.advance(AROUND_MS)
  expect(w.writes.projects).toBe((before ?? 0) + 1)
  expect(w.state.projects?.[0]?.sessions[0]?.log.map(line => line.text)).toEqual([
    'Wrote the schema',
  ])
})
