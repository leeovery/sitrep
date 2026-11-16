import type { ClientSurface, JsonValue, RenderPropsOf, RenderViewport } from 'claude-code'
import { expect, test, tier, type Mounted } from './kit'
import { bandLast, besideBand } from '../hooks/draw/band'
import Placement from '../hooks/draw/placement'
import { rowsOf } from './drawn'
import { reviewRound } from './data'
import {
  asked,
  BAND,
  CONVERSATION,
  DOCKED,
  INLINE,
  postedId,
  SURFACES,
  world,
  type World,
} from './world'

tier('user')

type Surface = (typeof SURFACES)[number]

/** What the engine draws above the prompt with no plugin drawing there, as if it drew a line of its own. */
const engineBand = (w: World) => w.drawAbovePrompt(({ Text }) => <Text>the engine band</Text>)

/** Another plugin's row above the prompt, beside sitrep's band; it keeps the rows it was given. */
function gateBand(w: World) {
  const given: number[] = []

  w.drawAbovePrompt(({ Text }, props) => {
    given.push(props.maxRows)

    return <Text>a gate row</Text>
  })

  return given
}

/** The board drawn on a surface as Claude Code seated it there: its placement `Client` posts that as it draws. */
const seated = (w: World, surface: Surface, props: RenderPropsOf['Pane']) => w.pane(surface, props)

/** The board's own button on the band, as drawn, and whether it is dimmed. */
const boardButton = async (ui: Pick<Mounted, 'find'>) => {
  const button = await ui.find({ key: 'band:board' })

  return { rows: rowsOf(button), isDim: button?.props.dimColor === true }
}

/** A session begun with an ask waiting and an item parked. */
async function busy(w: World) {
  await w.begin()

  return {
    ask: await asked(w, reviewRound(1)),
    parked: postedId(await w.call('park', { title: 'A priority badge' })),
  }
}

test('the band counts what waits on Lee and offers the board, on each surface', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await asked(w, reviewRound(1))

  for (const surface of SURFACES) {
    const ui = await w.band(surface)

    expect(await ui.find({ key: 'band:asks' }), surface).toMatchObject({ text: '1 ask' })
    expect(await ui.find({ key: 'band:board' }), surface).toMatchObject({ text: '▸ show board' })
    expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
    await ui.unmount()
  }
})

test('with no session held, the band draws nothing of its own', async ($, on) => {
  const w = world($, on)

  engineBand(w)
  await $.session.start(CONVERSATION)

  const ui = await w.band()

  expect(await ui.find({ text: 'the engine band' })).toBeDefined()
  expect(await ui.find({ key: 'band:board' })).toBeUndefined()
})

test('what another plugin draws above the prompt stays, above the band, in the rows the band leaves it', async ($, on) => {
  const w = world($, on)
  const given = gateBand(w)

  await w.begin()

  for (const surface of SURFACES) {
    const ui = await w.band(surface)
    const rows = rowsOf(await ui.find({ type: 'Box' }))

    expect(rows[0]).toBe('a gate row')
    expect(rows.at(-1)).toContain('▸ show board')
    expect(await ui.find({ key: 'band:asks', text: '0 asks' })).toBeDefined()
    await ui.unmount()
  }

  expect(new Set(given)).toEqual(new Set([BAND.maxRows - 1]))
})

test("from Claude Code 2.1.323, what a plugin draws in the band's own row stays above the band, in the rows the band leaves it", async ($, on) => {
  const w = world($, on)
  const given: number[] = []

  on('ui.render', { component: 'AbovePrompt', plugin: 'sitrep' }, ($, e) => {
    const { Text } = $.ui.resolve(e)

    given.push(e.props.maxRows)

    return <Text>a gate row</Text>
  })
  await w.begin()

  const rows = rowsOf(await (await w.band()).find({ type: 'Box' }))

  expect(rows[0]).toBe('a gate row')
  expect(rows.at(-1)).toContain('▸ show board')
  expect(new Set(given)).toEqual(new Set([BAND.maxRows - 1]))
})

test('while the band draws nothing of its own, another plugin keeps every row above the prompt', async ($, on) => {
  const w = world($, on)
  const given = gateBand(w)

  await $.session.start(CONVERSATION)
  await (await w.band()).unmount()

  await w.begin()
  await $.ui.mount({
    plugin: 'sitrep',
    surface: 'terminal',
    component: 'AbovePrompt',
    props: { ...BAND, hasSurvey: true },
  })

  expect(new Set(given)).toEqual(new Set([BAND.maxRows]))
})

/** A plugin's settled row above the prompt, its name its text. */
const row = (plugin: string): RenderPropsOf['AbovePromptList']['rows'][number] => ({
  plugin,
  tree: { type: 'Text', props: {}, children: [plugin] },
})

test("the band's row goes to the foot, on the prompt, and the others keep their order", () => {
  const stacked = bandLast([row('sitrep'), row('gates'), row('ticker')])

  expect(stacked.map(({ plugin }) => plugin)).toEqual(['gates', 'ticker', 'sitrep'])
})

test("from Claude Code 2.1.323, the rows above the prompt are stacked with the band's at the foot", async ($, on) => {
  world($, on)

  const ui = await $.ui.mount({
    plugin: 'sitrep',
    surface: 'terminal',
    component: 'AbovePromptList',
    props: { ...BAND, rows: [row('sitrep'), row('gates'), row('ticker')] },
  })

  expect(rowsOf(await ui.find({ type: 'Box' }))).toEqual(['gates', 'ticker', 'sitrep'])
})

test("another plugin's row is given the rows the band leaves only while the band shows, and the band's own row, or one named for no plugin, never", () => {
  const SURVEY = { ...BAND, hasSurvey: true }
  const LEFT = BAND.maxRows - 1

  expect(besideBand('gates', BAND, true).maxRows, 'another plugin, the band shown').toBe(LEFT)
  expect(besideBand('gates', BAND, false).maxRows, 'no session held').toBe(BAND.maxRows)
  expect(besideBand('gates', SURVEY, true).maxRows, 'a survey holding the band').toBe(BAND.maxRows)
  expect(besideBand('sitrep', BAND, true).maxRows, "the band's own row").toBe(BAND.maxRows)
  expect(besideBand(undefined, BAND, true).maxRows, 'a row named for no plugin').toBe(BAND.maxRows)
  expect(besideBand('gates', BAND, true)).toEqual({ ...BAND, maxRows: LEFT })
})

test('the band shows or hides the board, and its label follows', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.band()

  await ui.press({ key: 'band:board' })
  expect(w.panes.get('sitrep')).toBe(true)
  expect(await ui.find({ key: 'band:board', text: 'hide board' })).toBeDefined()

  await ui.press({ key: 'band:board' })
  expect(w.panes.has('sitrep')).toBe(false)
  expect(await ui.find({ key: 'band:board', text: '▸ show board' })).toBeDefined()
})

test('the band is counts on the right, each opening the board on what it counts, and never counts what was parked', async ($, on) => {
  const w = world($, on)

  await busy(w)

  const ui = await w.band()
  expect(await ui.drawn()).toMatchObject({ props: { justifyContent: 'flex-end' } })
  expect(await ui.find({ key: 'band:asks', text: '1 ask' })).toBeDefined()
  expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '◇' })).toBeUndefined()
  expect(await ui.find({ text: /parked/ })).toBeUndefined()

  await ui.press({ key: 'band:asks' })
  expect(w.panes.get('sitrep')).toBe(true)

  const board = await w.pane()

  expect(await board.find({ type: 'Text', text: 'ASKS' })).toBeDefined()
  expect(w.state.pane).toMatchObject({ place: null })
})

test('below 64 columns the words drop and the counts stay', async ($, on) => {
  const w = world($, on)

  await busy(w)

  const ui = await w.band('terminal', 50)

  expect(await ui.find({ key: 'band:asks' }), 'the count alone').toMatchObject({ text: '1' })
  expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
  expect(await ui.find({ key: 'band:board' })).toMatchObject({ text: '▸ show board' })
})

test('a board Claude Code would not draw is closed again, and a toast says why', async ($, on) => {
  const w = world($, on)

  await w.begin()
  w.unplacePanes('the terminal is 90 columns wide, under 110')

  const ui = await w.band()

  await ui.press({ key: 'band:board' })
  expect(w.panes.has('sitrep')).toBe(false)
  expect(w.toasts).toContain(
    "Claude Code didn't draw the board: the terminal is 90 columns wide, under 110",
  )
  expect(await ui.find({ key: 'band:board', text: '▸ show board' })).toBeDefined()
})

test('/sitrep opens the board, printing nothing', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)

  const output = await $.command.run({
    command: 'sitrep',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: true, columns: 120 },
  })

  expect(w.commands).toEqual(['sitrep'])
  expect(w.panes.get('sitrep')).toBe(true)
  expect(output.text).toBeUndefined()
})

test('after a reload, the band says what the engine has of the board', async ($, on) => {
  const w = world($, on)

  await w.begin()
  w.panes.set('sitrep', true)
  await $.session.start(CONVERSATION)

  const ui = await w.band()

  expect(await ui.find({ key: 'band:board', text: 'hide board' })).toBeDefined()
})

test('drawn inline, an open board gets a wide ✕ close on the band, its words kept, and pressing it closes the board', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const surface of SURFACES) {
    const ui = await w.band(surface, 50)

    await ui.press({ key: 'band:board' })
    await seated(w, surface, INLINE)
    expect(await boardButton(ui)).toEqual({ rows: ['[ ✕ close ]'], isDim: false })

    await ui.press({ key: 'band:board' })
    expect(w.panes.has('sitrep')).toBe(false)
    expect((await boardButton(ui)).rows).toEqual(['▸ show board'])
    await ui.unmount()
  }
})

test('drawn docked, an open board gets the dim hide board, though the conversation beside it is under 110 columns', async ($, on) => {
  const w = world($, on)

  await w.begin()

  // A 160-column terminal, as it measured live with the board docked: the conversation's columns.
  const beside: RenderViewport = { columns: 98, rows: 40, isFullscreen: true }
  const ui = await w.band('terminal', beside.columns, beside)

  await ui.press({ key: 'band:board' })
  await seated(w, 'terminal', DOCKED)
  expect(await boardButton(ui)).toEqual({ rows: ['hide board'], isDim: true })
})

test("where the board sits is each surface's own: an inline board on one leaves the band on another its hide board", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const terminal = await w.band('terminal')
  const desktop = await w.band('desktop')

  await terminal.press({ key: 'band:board' })
  await seated(w, 'terminal', INLINE)
  await seated(w, 'desktop', DOCKED)
  expect((await boardButton(terminal)).rows).toEqual(['[ ✕ close ]'])
  expect((await boardButton(desktop)).rows).toEqual(['hide board'])
})

test('a closed board gets ▸ show board wherever it sat, and opened again after it sat inline, the wide ✕ close from the start', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.band()

  for (const props of [DOCKED, INLINE]) {
    await ui.press({ key: 'band:board' })
    const board = await seated(w, 'terminal', props)

    await ui.press({ key: 'band:board' })
    await board.unmount()
    expect(await boardButton(ui), props.placement).toEqual({
      rows: ['▸ show board'],
      isDim: false,
    })
  }

  await ui.press({ key: 'band:board' })
  expect(await boardButton(ui)).toEqual({ rows: ['[ ✕ close ]'], isDim: false })
})

test('a press its hook fails is answered, the failure in the debug log, nothing opened', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.band()

  w.refuseOpens('no room for the board')

  expect(await ui.press({ key: 'band:board' })).toEqual({ element: 'band:board' })
  expect(w.logs).toEqual([
    'sitrep: pressing band:board failed: throw: $.ui.open: no room for the board',
  ])
  expect(w.panes.has('sitrep')).toBe(false)
})

test('a placement message with bad data changes nothing', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.band()

  await ui.press({ key: 'band:board' })

  const board = await seated(w, 'terminal', INLINE)
  const writes = w.writes.pane

  const bad: JsonValue[] = [
    { placement: 'floating' },
    { placement: 3 },
    { placement: null },
    {},
    'dock',
    null,
  ]

  for (const data of bad) {
    await board.post(data, { in: 'placement' })
  }

  expect(w.writes.pane).toBe(writes)
  expect(w.state.pane?.placement).toEqual({ terminal: 'inline' })
  expect((await boardButton(ui)).rows).toEqual(['[ ✕ close ]'])
})

test('the board saying again where it sits writes nothing', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const board = await seated(w, 'terminal', DOCKED)
  const writes = w.writes.pane

  await board.post({ placement: 'dock' }, { in: 'placement' })
  expect(w.writes.pane).toBe(writes)
})

/** Where Claude Code seated the board, as its props say. */
type Seat = RenderPropsOf['Pane']['placement']

/** The placement module as a surface calls it, drawn at each placement in turn: what it posts, its state kept from call to call. */
const drawnAt = () => {
  const posts: JsonValue[] = []
  let state: { placement: Seat } | undefined

  return {
    posts,
    at: (placement: Seat) =>
      Placement({ placement }, {
        get state() {
          return state
        },
        setState: (next: { placement: Seat }) => {
          state = next
        },
        post: (data: JsonValue) => posts.push(data),
        elements: { Box: () => ({ type: 'Box' }) },
      } as unknown as ClientSurface<{ placement: Seat }>),
  }
}

test('the placement module posts where the board was drawn, and again only when that changes', () => {
  const { posts, at } = drawnAt()

  at('dock')
  at('dock')
  at('inline')
  at('inline')
  at('dock')
  expect(posts).toEqual([{ placement: 'dock' }, { placement: 'inline' }, { placement: 'dock' }])
})
