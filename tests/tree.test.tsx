import { expect, test, tier } from 'claude-code/testing'
import { CURRENT_MS, projectOf, type WorkMeta } from '../core'
import { AROUND_MS } from '../hooks/around'
import { ask, MIN, note, park, status, T0, W2, W3, W4 } from './support'
import { ELSEWHERE, postedId, PROJECT, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const DAY = 24 * 60 * MIN

const PORTAL = projectOf('/Users/lee/Code/portal/.git')
const PIGEON = projectOf('/Users/lee/Code/pigeon/.git')
const DUSTY = projectOf('/Users/lee/Code/dusty/.git')

const REVIEW = { kind: 'review', title: 'Review Sessions & Runway, round 1' }

const LEDGER = 'sr-1edger'
const THEMES = 'sr-themes'
const ORDERS = 'sr-0rders'
const NOTES = 'sr-p1ge0n'

/** A work started by `by` in a project, `ago` before now. */
const meta = (id: string, name: string, project: string, by: string, ago = 0): WorkMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project,
  root: `/Users/lee/Code/${project}`,
  created: T0 - ago,
  by,
})

/**
 * The works around this session's, modelled on the spike's: another open
 * session of this project with an ask and something parked, and a closed
 * one; Goosemates open with an ask; Portal closed with something parked;
 * Pigeon closed and quiet, updated two days ago; Dusty quiet for longer
 * than a work stays current. Then this session starts its own and asks.
 */
async function neighbourhood(w: World) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))
  const orders = w.elsewhere(meta(ORDERS, 'Standing orders', 'goosemates', W4), ELSEWHERE.key)

  ledger.write(
    status(['Drawing the ledger schema'], {
      name: 'Request ledger',
      summary: 'Request ledger, area by area',
    }),
    ask('k3', 'decide', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
    park('p2', 'Export the ledger as CSV'),
    note('n3', 'Wrote the schema'),
  )
  ledger.beat()
  w.elsewhere(meta(THEMES, 'Themes', 'switchboard', W3, DAY))
  orders.write(ask('k5', 'review', 'Review the standing orders'))
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

test('the board walks up from this session to its project and every project, and back down', async ($, on) => {
  const w = world($, on)
  const { asked } = await neighbourhood(w)
  const ui = await w.opened()

  expect(await ui.find({ key: `pick:${asked}` })).toBeDefined()

  // Up to the project: its sessions; down into another one, where the tabs give way to a step back.
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
  expect(await ui.find({ key: 'pick:k3' })).toBeDefined()
  expect(await ui.find({ key: 'tab:session' })).toBeUndefined()
  expect(await ui.find({ key: 'up', text: /← Switchboard/ })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(await ui.find({ key: 'tab:project' })).toBeDefined()

  // Up to every project; quiet ones fold away; down into another project's session and back up twice.
  await ui.press({ key: 'tab:all' })
  expect(await ui.find({ key: `proj:${ELSEWHERE.key}` })).toBeDefined()
  expect(await ui.find({ key: `proj:${PIGEON.key}` })).toBeUndefined()
  expect(await ui.find({ key: `proj:${PORTAL.key}` })).toBeDefined()
  await ui.press({ key: `go:${ORDERS}` })
  expect(await ui.find({ key: 'pick:k5' })).toBeDefined()
  expect(await ui.find({ key: 'up', text: /← Goosemates/ })).toBeDefined()
  await ui.press({ key: 'up' })
  expect(await ui.find({ key: 'up', text: /← All projects/ })).toBeDefined()

  // Home, from anywhere.
  await ui.press({ key: 'home' })
  expect(await ui.find({ key: `pick:${asked}` })).toBeDefined()
})

test('closed and opened again, the board is home, wherever it had gone', async ($, on) => {
  const w = world($, on)
  const { asked } = await neighbourhood(w)
  const ui = await w.opened()
  const band = await w.band()

  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
  await ui.press({ key: 'pick:k3' })
  expect(w.state.pane).toMatchObject({ place: { level: 'session', work: LEDGER }, selected: 'k3' })

  await band.press({ key: 'band:board' })
  await band.press({ key: 'band:board' })
  expect(w.state.pane).toMatchObject({ isOpen: true, place: null, view: 'board', selected: null })
  expect(await ui.find({ key: `pick:${asked}` })).toBeDefined()
  expect(await ui.find({ key: 'tab:session' })).toBeDefined()
})

test('on its own path the board shows three tabs, each with what waits there', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened()

  expect(await ui.find({ key: 'tab:session', text: 'This session' })).toBeDefined()
  expect(await ui.find({ key: 'tab:project', text: 'Switchboard' })).toBeDefined()
  expect(await ui.find({ key: 'tab:all', text: 'All projects' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '2' }), 'two wait in this project').toBeDefined()

  await ui.press({ key: 'tab:all' })
  expect(
    await ui.find({ type: 'Text', text: '3' }),
    'three wait across every project',
  ).toBeDefined()
})

test("another session's view is the session view: its status, its asks with working buttons, its log", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened()

  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER}` })
  expect(await ui.find({ type: 'Text', text: 'Request ledger' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Drawing the ledger schema' })).toBeDefined()
  expect(await ui.find({ key: 'log:n3', text: 'Wrote the schema' })).toBeDefined()

  await ui.press({ key: 'pick:k3' })
  await ui.press({ key: 'choose:k3:1' })
  expect(await ui.find({ type: 'Text', text: '→ Forever' })).toBeDefined()
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, work: LEDGER, item: 'k3', verdict: 'choose', option: 'Forever' },
  ])
})

test("the project view lists its sessions, this one first, each with what it does and what waits; and the project's log", async ($, on) => {
  const w = world($, on)
  const { id } = await neighbourhood(w)
  const ui = await w.opened()

  await ui.press({ key: 'tab:project' })

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

test('All projects: this project first, then the busiest; the quiet fold into one line; an old idle work is gone', async ($, on) => {
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

test('parked is scoped to where the board looks: this session, its project, every project', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)
  await w.clock.advance(MIN)
  await w.call('park', { title: 'A tmux indicator across sessions' })

  const ui = await w.opened()
  const parkedHere = async () =>
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key?.startsWith('ppick:'))
      .map(each => each.text)

  await ui.press({ key: 'parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN THIS SESSION' })).toBeDefined()
  expect(await parkedHere()).toEqual(['A tmux indicator across sessions'])

  await ui.press({ key: 'back' })
  await ui.press({ key: 'tab:project' })
  expect(await ui.find({ key: 'parked', text: '◇ 2 parked' })).toBeDefined()
  await ui.press({ key: 'parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN SWITCHBOARD' })).toBeDefined()
  expect(await parkedHere()).toEqual([
    'Export the ledger as CSV',
    'A tmux indicator across sessions',
  ])

  await ui.press({ key: 'ppick:p2' })
  expect(await ui.find({ type: 'Text', text: 'raised in Request ledger' })).toBeDefined()
  await ui.press({ key: 'pickup:p2' })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, work: LEDGER, item: 'p2', verdict: 'pickup' },
  ])

  await ui.press({ key: 'back' })
  await ui.press({ key: 'tab:all' })
  await ui.press({ key: 'parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN ALL PROJECTS' })).toBeDefined()
  expect(await parkedHere()).toHaveLength(3)
})

test("the band counts what waits in the project's other sessions, and opens the project view on it", async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const band = await w.band()

  expect(await band.find({ key: 'band:for-you', text: '1 for you' })).toBeDefined()
  expect(await band.find({ key: 'band:elsewhere', text: '1 in other sessions' })).toBeDefined()

  await band.press({ key: 'band:elsewhere' })
  expect(w.panes.get('sitrep')).toBe(true)

  const board = await w.pane()

  expect(await board.find({ key: `go:${LEDGER}` })).toBeDefined()
  expect(await board.find({ key: 'tab:project' })).toMatchObject({ props: { dimColor: false } })

  const narrow = await w.band('terminal', 50)

  expect(await narrow.find({ key: 'band:elsewhere', text: '+1' })).toBeDefined()
})

test("a new ask in another session reaches the band's count at the slower pace, the board closed", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))

  ledger.beat()
  await w.begin()

  const band = await w.band()

  expect(await band.find({ key: 'band:elsewhere' })).toBeUndefined()

  ledger.write(ask('k3', 'do', 'Run the ledger migration'))
  ledger.beat()
  await w.clock.advance(AROUND_MS)
  expect(await band.find({ key: 'band:elsewhere', text: '1 in other sessions' })).toBeDefined()
  expect(w.state.others, 'nothing is read in full with the board closed').toEqual([])
  expect(
    w.state.projects?.map(project => project.key),
    'only this project is read with the board closed',
  ).toEqual([PROJECT.key])
})

test('the glance lists the project’s sessions, an open one opening its view', async ($, on) => {
  const w = world($, on)

  await neighbourhood(w)

  const ui = await w.opened()

  await ui.press({ key: 'collapse' })
  expect(await ui.find({ type: 'Text', text: 'SESSIONS' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Themes' })).toMatchObject({ type: 'Text' })

  await ui.press({ key: `open:gsession:${LEDGER}` })
  expect(w.state.pane?.mode).toBe('full')
  expect(await ui.find({ key: 'pick:k3' })).toBeDefined()
  expect(await ui.find({ key: 'up', text: /← Switchboard/ })).toBeDefined()
})

test('what the works around hold is put in $.state only when a look finds it changed', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', 'switchboard', W2))

  await w.begin()

  const before = w.writes.projects

  await w.clock.advance(3 * AROUND_MS)
  expect(w.writes.projects, 'nothing changed, so nothing is put').toBe(before)

  ledger.write(note('n3', 'Wrote the schema'))
  await w.clock.advance(AROUND_MS)
  expect(w.writes.projects).toBe((before ?? 0) + 1)
  expect(w.state.projects?.[0]?.works[0]?.log.map(line => line.text)).toEqual(['Wrote the schema'])
})
