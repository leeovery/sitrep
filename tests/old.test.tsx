import type { SitrepPane, SitrepProject } from '../types'
import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { projectPlace } from '../hooks/places'
import { rowsOf } from './drawn'
import { DAY, HELD, HOUR, LEDGER, meta, PROJECT, T0, W3 } from './data'
import type { Neighbour } from './filing'
import { finish, park, status, type Line } from './lines'
import { pane, sceneFrom, type Drawn } from './render'
import { ACROSS, toProject, world, type World } from './world'

tier('user')

/** Ten days on from the start: every session begun then has gone quiet, but those touched since. */
const NOW = T0 + 10 * DAY

/** Old sessions of Northwind's: one Claude finished a day ago, and three quiet past their 7 days. */
const SHIPPED = meta('sr-5h1pp3', 'Export to CSV', W3)
const SETTINGS = meta('sr-5ett1n', 'Settings tab', W3)
const SCHEMA = meta('sr-5chema', 'Ledger schema, first pass', W3)
const ARCHIVE = meta('sr-arch1v', 'Invoice archive', W3)

/** Its old sessions beside the ledger, still current, its status changed an hour ago. */
const AROUND: readonly Neighbour[] = [
  {
    meta: SCHEMA,
    lines: [[NOW - 9 * DAY, status(['Drawing the schema'], SCHEMA)]],
  },
  {
    meta: SHIPPED,
    lines: [
      [NOW - 2 * DAY, status(['Shipping the export'], SHIPPED)],
      [NOW - DAY, finish('claude', 'Shipped')],
    ],
  },
  {
    meta: ARCHIVE,
    lines: [[T0, status(['Archiving last year'], ARCHIVE)]],
  },
  {
    meta: SETTINGS,
    lines: [[NOW - 8 * DAY, status([], { name: SETTINGS.name, next: 'Tidy the copy' })]],
  },
  {
    meta: LEDGER,
    lines: [[NOW - HOUR, status(['Reading the brief'], LEDGER)]],
  },
]

const OLD = `old:project:${PROJECT.key}`

/** The scene of the project's view, its old sessions around it, the pane as given. */
const projectScene = (shown: Partial<SitrepPane> = {}) =>
  sceneFrom({ now: NOW, around: AROUND, pane: { place: projectPlace(PROJECT.key), ...shown } })

/** The project's view, the old sessions list shown as asked, none for folded. */
const projectDrawn = (showing?: 'latest' | 'all') =>
  pane(projectScene(showing === undefined ? {} : { shown: { [OLD]: showing } }))

/** The keys of the old sessions' rows drawn, in order. */
const endedKeys = async (ui: Drawn) =>
  (await ui.findAll({ type: 'Box' }))
    .map(each => String(each.key ?? ''))
    .filter(key => key.startsWith('ended:'))

/** The rows of each old session drawn, at the docked board's width. */
const endedRows = async (ui: Drawn) =>
  Promise.all((await endedKeys(ui)).map(async key => rowsOf(await ui.find({ key }), ACROSS)))

test("the project's view folds its old sessions under SESSIONS as a dim press counting every session not current, the finished and the quiet; the current never among them", async () => {
  const ui = projectDrawn()

  expect((await ui.find({ key: OLD }))?.props).toMatchObject({
    label: 'show old sessions 4',
    plain: true,
    dimColor: true,
  })
  expect(await endedKeys(ui)).toEqual([])
  expect(await ui.find({ key: `go:${LEDGER.id}` }), 'the ledger among the current').toBeDefined()
})

test('shown, the latest 3 old sessions follow hide old sessions, the latest ended first, each its name, dim, how long ago it ended, as `finished 1d` where it was finished, else `idle 8d`, and what it was last doing, faint, under it; show all past them', async () => {
  const ui = projectDrawn('latest')

  expect((await ui.find({ key: OLD }))?.props).toMatchObject({ label: 'hide old sessions' })
  expect(await endedRows(ui)).toEqual([
    ['Export to CSV                              finished 1d', '└ Shipping the export'],
    ['Settings tab                                   idle 8d', '└ next: Tidy the copy'],
    ['Ledger schema, first pass                      idle 9d', '└ Drawing the schema'],
  ])
  expect((await ui.find({ key: `all:${OLD}` }))?.props).toMatchObject({
    label: 'show all 4',
    dimColor: true,
  })
  expect((await ui.find({ key: `go:${SHIPPED.id}` }))?.props.dimColor).toBe(true)
  expect((await ui.find({ type: 'Text', text: 'Shipping the export' }))?.props.color).toBe(C.faint)
})

test('shown in full, every old session is listed under show fewer, the ledger, current, never', async () => {
  const ui = projectDrawn('all')

  expect(await endedKeys(ui)).toEqual([
    `ended:${SHIPPED.id}`,
    `ended:${SETTINGS.id}`,
    `ended:${SCHEMA.id}`,
    `ended:${ARCHIVE.id}`,
  ])
  expect((await ui.find({ key: `all:${OLD}` }))?.props).toMatchObject({ label: 'show fewer' })
})

test('the old sessions sit under the current ones after a blank row, with none between them', async () => {
  const rows = rowsOf(await projectDrawn('latest').find({ type: 'Box' }))
  const from = rows.findIndex(row => row.startsWith(' SESSIONS'))
  const to = rows.findIndex((row, i) => i > from && row.startsWith(' ASKS'))

  expect(rows.slice(from + 1, to).map(row => row.replace(/ {2,}/g, ' '))).toEqual([
    ' Help desk redesign ⌂',
    ' └ Redesign the help desk, page by page',
    '',
    ' Invoice ledger closed',
    ' └ Reading the brief',
    '',
    ' hide old sessions',
    ' Export to CSV finished 1d',
    ' └ Shipping the export',
    ' Settings tab idle 8d',
    ' └ next: Tidy the copy',
    ' Ledger schema, first pass idle 9d',
    ' └ Drawing the schema',
    ' show all 4',
    '',
  ])
})

test("an old session's row is closed whatever window still holds it: one finished while its window stays draws dim, its line faint", async () => {
  const notes = meta('sr-n0tes0', 'Release notes', W3)
  const scene = await sceneFrom({
    now: NOW,
    around: [
      {
        meta: notes,
        lines: [
          [NOW - HOUR, status(['Writing the notes'], notes)],
          [NOW - HOUR, finish('claude')],
        ],
        seenAt: NOW,
      },
    ],
    pane: { place: projectPlace(PROJECT.key), shown: { [OLD]: 'latest' } },
  })
  const ui = pane(scene)
  const old = scene?.projects.find(each => each.key === PROJECT.key)?.old?.entries

  expect(
    old?.map(each => [each.id, each.isOpen]),
    'a window holds it',
  ).toEqual([[notes.id, true]])
  expect((await ui.find({ key: `go:${notes.id}` }))?.props.dimColor).toBe(true)
  expect((await ui.find({ type: 'Text', text: 'Writing the notes' }))?.props.color).toBe(C.faint)
})

test("a look from before the window took up its session, which read that session as one around, gives the project's view no old sessions until the next", async () => {
  const scene = await projectScene()
  const ui = pane(
    scene && {
      ...scene,
      projects: scene.projects.map(project =>
        project.key === PROJECT.key
          ? { ...project, names: { ...project.names, [HELD.id]: HELD.name } }
          : project,
      ),
    },
  )

  expect(await ui.find({ key: OLD })).toBeUndefined()
})

test("what a build from before 17 November 2026 carried draws without throwing: the project's view without old sessions, its history left undrawn, and a session's view its project's Parked without a picked up", async () => {
  const lines: Line[] = [[T0, park('p1', 'A priority badge')]]
  const older = (project: SitrepProject) => {
    const { old: _old, takenOff: _takenOff, ...kept } = project

    return { ...kept, history: { entries: [], count: 12 } }
  }
  const drawnAs = async (place: SitrepPane['place']) => {
    const scene = await sceneFrom({
      lines,
      now: NOW,
      around: [...AROUND, { meta: LEDGER, lines: [[NOW - HOUR, park('p2', 'Export as CSV')]] }],
      pane: { place, shown: { [`history:project:${PROJECT.key}`]: 'all' } },
    })

    return pane(scene && { ...scene, projects: scene.projects.map(older) })
  }
  const project = await drawnAs(projectPlace(PROJECT.key))
  const home = await drawnAs(null)

  expect(await project.drawn()).toBeDefined()
  expect(await project.find({ key: OLD })).toBeUndefined()
  expect(await project.find({ key: `history:project:${PROJECT.key}` })).toBeUndefined()
  expect(await project.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()

  expect(await home.drawn()).toBeDefined()
  expect(await home.find({ type: 'Text', text: '2 to come back to' })).toBeDefined()
  expect(await home.find({ key: `pickedup:project:${PROJECT.key}` })).toBeUndefined()
})

/** Finished sessions of Northwind's, four of them, each finished as it was written. */
const FINISHED = [SHIPPED, SETTINGS, SCHEMA, ARCHIVE]

/** How many old sessions `$.state` carries for Northwind, and how many there are. */
const oldCarried = (w: World) => {
  const old = w.state.projects?.find(each => each.key === PROJECT.key)?.old

  return old && [old.entries.length, old.count]
}

test("a look carries a project's old sessions only while its view shows, the latest 3 and the count, every one only while they are shown in full; a row's name opens that session's view", async ($, on) => {
  const w = world($, on)

  for (const each of FINISHED) {
    w.elsewhere(each).write(status(['Wrapping up'], each), finish('claude'))
  }

  await w.begin()

  const ui = await w.opened()

  expect(oldCarried(w), 'home').toBeUndefined()

  await toProject(ui)
  expect(oldCarried(w), 'its view').toEqual([3, 4])

  await ui.press({ key: OLD })
  await ui.press({ key: `all:${OLD}` })
  expect(oldCarried(w), 'shown in full').toEqual([4, 4])

  await ui.press({ key: `go:${ARCHIVE.id}` })
  expect(w.state.pane?.place).toEqual({
    level: 'session',
    project: PROJECT.key,
    session: ARCHIVE.id,
  })
  expect(await ui.find({ type: 'Text', text: 'Invoice archive' })).toBeDefined()
  expect(oldCarried(w), "a session's view").toBeUndefined()
})
