import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, workPaths, type WorkMeta } from '../core'
import { rowsOf } from './drawn'
import { ask, file, finish, MIN, note, T0, W1, W2, W3, W4 } from './support'
import { ELSEWHERE, PROJECT, ROOT, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Board = Awaited<ReturnType<World['opened']>>

const LEDGER = 'sr-1edger'
const THEMES = 'sr-themes'
const LOBBY = 'sr-10bbyy'
const ORDERS = 'sr-0rders'

const meta = (id: string, name: string, by: string, project = 'switchboard'): WorkMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project,
  root: `/Users/lee/Code/${project}`,
  created: T0,
  by,
})

/** Themes' file this window writes, as Lee marks it done from its view. */
const MINE = workPaths(ROOT, PROJECT.key, THEMES).log(W1)

/**
 * This session with an ask, beside three others of its project, each with
 * an ask: the ledger, open in another window; Themes, with no window; and
 * the lobby, already marked done. Goosemates' one work is done too, its ask
 * still open. A minute on, Lee opens the board.
 */
async function around(w: World) {
  const ledger = w.elsewhere(meta(LEDGER, 'Request ledger', W2))

  ledger.write(ask('k3', 'review', 'Review the ledger schema'))
  w.elsewhere(meta(THEMES, 'Themes', W3)).write(ask('k4', 'do', 'Pick the dark palette'))
  w.elsewhere(meta(LOBBY, 'Lobby', W3)).write(ask('k5', 'do', 'Check the lobby'), finish('lee'))
  w.elsewhere(meta(ORDERS, 'Standing orders', W4, 'goosemates'), ELSEWHERE.key).write(
    ask('k6', 'review', 'Review the standing orders'),
    finish('claude', 'Shipped'),
  )

  const { id } = await w.begin()

  await w.call('ask', { kind: 'review', title: 'Review Sessions & Runway, round 1' })
  await w.clock.advance(MIN)
  ledger.beat()

  return { id, ui: await w.opened() }
}

/** The keys of the drawn buttons that start with `prefix`, in the order drawn. */
const keysOf = async (ui: Board, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith(prefix))

/** Lee goes from this session to another of its project. */
const visit = async (ui: Board, work: string) => {
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${work}` })
}

test('a finished work drops out of the project and All projects, and its asks count nowhere', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await around(w)
  const band = await w.band()

  expect(await band.find({ key: 'band:elsewhere', text: '2 in other sessions' })).toBeDefined()
  expect(await ui.find({ key: 'tab:session', text: 'This session' })).toBeDefined()

  await ui.press({ key: 'tab:project' })
  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER}`, `go:${THEMES}`])
  expect(await ui.find({ type: 'Text', text: '3 waiting on you' })).toBeDefined()

  await ui.press({ key: 'tab:all' })
  expect(await keysOf(ui, 'proj:')).toEqual([`proj:${PROJECT.key}`])
  expect(await ui.find({ type: 'Text', text: '3 waiting on you' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: '3' }),
    'the All projects tab counts three',
  ).toBeDefined()
})

test("the button to mark a work done is drawn only in another session's view with no window", async ($, on) => {
  const w = world($, on)
  const { ui } = await around(w)

  expect(await keysOf(ui, 'finish:'), 'never in this session').toEqual([])

  await visit(ui, LEDGER)
  expect(await keysOf(ui, 'finish:'), 'never while a window has it').toEqual([])

  await ui.press({ key: 'up' })
  await ui.press({ key: `go:${THEMES}` })

  const button = await ui.find({ key: `finish:${THEMES}` })

  expect(button?.props).toMatchObject({ label: '✓ mark this work done', plain: true })
  expect(button?.props.dimColor).toBeUndefined()

  const buttons = await keysOf(ui, '')

  expect(buttons.at(-1), 'at the foot of the view').toBe(`finish:${THEMES}`)
})

test('marking a work done asks first; cancel writes nothing', async ($, on) => {
  const w = world($, on)
  const { ui } = await around(w)

  await visit(ui, THEMES)
  await ui.press({ key: `finish:${THEMES}` })

  expect(
    await ui.find({ type: 'Text', text: 'Mark Themes done? Its open asks stop counting.' }),
  ).toBeDefined()
  expect(await ui.find({ key: `finish-yes:${THEMES}`, text: 'yes, mark it done' })).toBeDefined()
  expect(await ui.find({ key: `finish:${THEMES}` })).toBeUndefined()

  await ui.press({ key: `finish-no:${THEMES}` })

  expect(await ui.find({ key: `finish:${THEMES}` })).toBeDefined()
  expect(await ui.find({ key: `finish-yes:${THEMES}` })).toBeUndefined()
  expect(w.files.has(MINE)).toBe(false)
  expect(w.state.pane).toMatchObject({ place: { level: 'session', work: THEMES } })
})

test("yes writes the finish into the work's folder as this window's writer, and the board goes up to where it is gone", async ($, on) => {
  const w = world($, on)

  w.put(MINE, file([T0, note('n1', 'Looked in on the palette')]))

  const { id, ui } = await around(w)
  const inbox = workPaths(ROOT, PROJECT.key, THEMES).letters(W1)

  await visit(ui, THEMES)
  await ui.press({ key: `finish:${THEMES}` })
  await ui.press({ key: `finish-yes:${THEMES}` })

  expect(parseEntries(w.text(MINE)).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'note'],
    [2, 'finish'],
  ])
  expect(parseEntries(w.text(MINE)).at(-1)).toMatchObject({ who: 'lee', at: w.clock.now() })
  expect(w.files.has(inbox), 'nothing goes to its inbox').toBe(false)
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER}`])
  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()
})

test('a work Claude finished counts nothing in its own window: the band and the tab say none waits', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('ask', { kind: 'review', title: 'Review round 1' })

  const band = await w.band()
  const ui = await w.opened()

  expect(await band.find({ key: 'band:for-you', text: '1 for you' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ This session 1'])

  await w.call('finish', { reason: 'Shipped' })

  expect(await band.find({ key: 'band:for-you', text: '0 for you' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ This session'])
})
