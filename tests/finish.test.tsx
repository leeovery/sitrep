import type { RenderPropsOf } from 'claude-code'
import { expect, test, tier } from './kit'
import { parseEntries, sessionPaths } from '../core'
import { rowsOf } from './drawn'
import {
  ELSEWHERE,
  LEDGER,
  meta,
  MIN,
  PROJECT,
  REVIEW,
  ROOT,
  SHIFTS,
  T0,
  THEMES,
  W1,
  W3,
} from './data'
import { file, finish, note, park, yesAsk } from './lines'
import { toProject, WIDE, world, type Board, type World } from './world'

tier('user')

const LOBBY = 'sr-10bbyy'

/** Themes' file this window writes, as Lee finishes it from its view. */
const MINE = sessionPaths(ROOT, PROJECT.key, THEMES.id).log(W1)

/**
 * This session with an ask, beside three others of its project, each with
 * an ask: the ledger, open in another window; Themes, with no window; and
 * the lobby, already finished. Contoso's one session is finished too, its
 * ask still open. A minute on, Lee opens the board, drawn as `props` say.
 */
async function around(w: World, props?: RenderPropsOf['Pane']) {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  w.elsewhere(THEMES).write(yesAsk('k4', 'Pick the dark palette', 'Done'))
  w.elsewhere(meta(LOBBY, 'Lobby', W3)).write(
    yesAsk('k5', 'Check the lobby', 'Done'),
    finish('lee'),
  )
  w.elsewhere(SHIFTS, ELSEWHERE.key).write(
    yesAsk('k6', 'Review the shift schedules'),
    finish('claude', 'Shipped'),
  )

  const { id } = await w.begin()

  await w.call('ask', REVIEW)
  await w.clock.advance(MIN)
  ledger.beat()

  return { id, ui: await w.opened(props) }
}

/** The keys of the drawn buttons that start with `prefix`, in the order drawn. */
const keysOf = async (ui: Board, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith(prefix))

/** Lee goes from this session to another of its project. */
const visit = async (ui: Board, session: string) => {
  await toProject(ui)
  await ui.press({ key: `go:${session}` })
}

test(
  'a finished session drops out of the project and All projects, and its asks count nowhere',
  async ($, on) => {
    const w = world($, on)
    const { id, ui } = await around(w, WIDE)
    const band = await w.band()

    expect(await band.find({ key: 'band:elsewhere', text: '2 elsewhere' })).toBeDefined()

    await toProject(ui)
    expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER.id}`, `go:${THEMES.id}`])
    expect(await ui.find({ type: 'Text', text: '3 waiting on you' })).toBeDefined()

    await ui.press({ key: 'up' })
    expect(await keysOf(ui, 'proj:')).toEqual([`proj:${PROJECT.key}`])
    expect(await ui.find({ type: 'Text', text: '3 waiting on you' })).toBeDefined()
    expect(
      await ui.find({ type: 'Text', text: '3' }),
      'the All projects tab counts three',
    ).toBeDefined()
  },
)

test("the button to finish a session is drawn only in another session's view with no window", async ($, on) => {
  const w = world($, on)
  const { ui } = await around(w)

  expect(await keysOf(ui, 'finish:'), 'never in this session').toEqual([])

  await visit(ui, LEDGER.id)
  expect(await keysOf(ui, 'finish:'), 'never while a window has it').toEqual([])

  await ui.press({ key: 'up' })
  await ui.press({ key: `go:${THEMES.id}` })

  const button = await ui.find({ key: `finish:${THEMES.id}` })

  expect(button?.props).toMatchObject({ label: '✓ finish this session', plain: true })
  expect(button?.props.dimColor).toBeUndefined()

  const buttons = await keysOf(ui, '')

  expect(buttons.at(-1), 'at the foot of the view').toBe(`finish:${THEMES.id}`)
})

test('finishing a session asks first; cancel writes nothing', async ($, on) => {
  const w = world($, on)
  const { ui } = await around(w)

  await visit(ui, THEMES.id)
  await ui.press({ key: `finish:${THEMES.id}` })

  expect(
    await ui.find({ type: 'Text', text: 'Finish Themes? Its open asks stop counting.' }),
  ).toBeDefined()
  expect(await ui.find({ key: `finish-yes:${THEMES.id}`, text: 'yes, finish it' })).toBeDefined()
  expect(await ui.find({ key: `finish:${THEMES.id}` })).toBeUndefined()

  await ui.press({ key: `finish-no:${THEMES.id}` })

  expect(await ui.find({ key: `finish:${THEMES.id}` })).toBeDefined()
  expect(await ui.find({ key: `finish-yes:${THEMES.id}` })).toBeUndefined()
  expect(w.files.has(MINE)).toBe(false)
  expect(w.state.pane).toMatchObject({ place: { level: 'session', session: THEMES.id } })
})

test("yes writes the finish into the session's folder as this window's writer, and the board goes up to where it is gone", async ($, on) => {
  const w = world($, on)

  w.put(MINE, file([T0, note('n1', 'Looked in on the palette')]))

  const { id, ui } = await around(w)
  const inbox = sessionPaths(ROOT, PROJECT.key, THEMES.id).letters(W1)

  await visit(ui, THEMES.id)
  await ui.press({ key: `finish:${THEMES.id}` })
  await ui.press({ key: `finish-yes:${THEMES.id}` })

  expect(parseEntries(w.text(MINE)).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'note'],
    [2, 'finish'],
  ])
  expect(parseEntries(w.text(MINE)).at(-1)).toMatchObject({ who: 'lee', at: w.clock.now() })
  expect(w.files.has(inbox), 'nothing goes to its inbox').toBe(false)
  expect(w.state.pane).toMatchObject({ place: { level: 'project', project: PROJECT.key } })
  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER.id}`])
  expect(await ui.find({ type: 'Text', text: '2 waiting on you' })).toBeDefined()
})

test("Lee's finish hides nothing parked: the session's items stay in the project's Parked, by its name", async ($, on) => {
  const w = world($, on)

  w.put(MINE, file([T0, park('p7', 'Theme the lobby too')]))

  const { id, ui } = await around(w)

  await visit(ui, THEMES.id)
  expect(await ui.find({ key: `ppick:${THEMES.id}:p7`, text: 'Theme the lobby too' })).toBeDefined()

  await ui.press({ key: `finish:${THEMES.id}` })
  await ui.press({ key: `finish-yes:${THEMES.id}` })

  expect(await keysOf(ui, 'go:')).toEqual([`go:${id}`, `go:${LEDGER.id}`])
  expect(await ui.find({ type: 'Text', text: '1 to come back to' })).toBeDefined()
  expect(
    await ui.find({ key: `ppick:${THEMES.id}:p7`, text: 'Themes: Theme the lobby too' }),
  ).toBeDefined()
})

test('a session Claude finished counts nothing in its own window: the band and the tab say none waits', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })

  const band = await w.band()
  const ui = await w.opened(WIDE)

  expect(await band.find({ key: 'band:asks', text: '1 ask' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ Help desk redesign 1'])

  await w.call('finish', { reason: 'Shipped' })

  expect(await band.find({ key: 'band:asks', text: '0 asks' })).toBeDefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ Help desk redesign'])
})
