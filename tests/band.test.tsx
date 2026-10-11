import type { On, RenderViewport } from 'claude-code'
import { expect, test, tier, type Mounted } from 'claude-code/testing'
import { rowsOf } from './drawn'
import { postedId, SESSION, SURFACES, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** What the engine draws above the prompt with no plugin drawing there. */
function engineBand(on: On) {
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>the engine band</Text>
  })
}

/** The phone: Blink over mosh, fullscreen, too narrow to dock the board. */
const PHONE: RenderViewport = { columns: 50, rows: 40, isFullscreen: true }

/** The narrowest fullscreen screen Claude Code docks the board on. */
const DOCKING: RenderViewport = { columns: 110, rows: 40, isFullscreen: true }

/** The board's own button on the band, as drawn, and whether it is dimmed. */
const boardButton = async (ui: Pick<Mounted, 'find'>) => {
  const button = await ui.find({ key: 'band:board' })

  return { rows: rowsOf(button), isDim: button?.props.dimColor === true }
}

/** A work begun with an ask waiting and an item parked. */
async function busy(w: World) {
  await w.begin()

  return {
    ask: postedId(await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })),
    parked: postedId(await w.call('park', { title: 'A tmux indicator' })),
  }
}

test('the band counts what waits on Lee and offers the board, on each surface', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const surface of SURFACES) {
    const ui = await w.band(surface)

    expect(await ui.find({ key: 'band:for-you', text: '0 for you' })).toBeDefined()
    expect(await ui.find({ key: 'band:board', text: '▸ show board' })).toBeDefined()
    expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
    await ui.unmount()
  }
})

test('with no work held, the band draws nothing of its own', async ($, on) => {
  const w = world($, on)

  engineBand(on)
  await $.session.start(SESSION)

  const ui = await w.band()

  expect(await ui.find({ text: 'the engine band' })).toBeDefined()
  expect(await ui.find({ key: 'band:board' })).toBeUndefined()
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
  expect(await ui.find({ key: 'band:for-you', text: '1 for you' })).toBeDefined()
  expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '◇' })).toBeUndefined()
  expect(await ui.find({ text: /parked/ })).toBeUndefined()

  await ui.press({ key: 'band:for-you' })
  expect(w.panes.get('sitrep')).toBe(true)

  const board = await w.pane()

  expect(await board.find({ type: 'Text', text: 'FOR YOU' })).toBeDefined()
  expect(w.state.pane).toMatchObject({ place: null })
})

test('below 64 columns the words drop and the counts stay', async ($, on) => {
  const w = world($, on)

  await busy(w)

  const ui = await w.band('terminal', 50)

  expect(await ui.find({ key: 'band:for-you', text: '1' })).toBeDefined()
  expect(await ui.find({ key: 'band:parked' })).toBeUndefined()
  expect(await ui.find({ key: 'band:board', text: '▸ show board' })).toBeDefined()
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

  await $.session.start(SESSION)

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
  await $.session.start(SESSION)

  const ui = await w.band()

  expect(await ui.find({ key: 'band:board', text: 'hide board' })).toBeDefined()
})

test('on the phone, an open board gets a wide ✕ close on the band, its words kept, and pressing it closes the board', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const surface of SURFACES) {
    const ui = await w.band(surface, PHONE.columns, PHONE)

    await ui.press({ key: 'band:board' })
    expect(await boardButton(ui)).toEqual({ rows: ['[ ✕ close ]'], isDim: false })

    await ui.press({ key: 'band:board' })
    expect(w.panes.has('sitrep')).toBe(false)
    expect((await boardButton(ui)).rows).toEqual(['▸ show board'])
    await ui.unmount()
  }
})

test('docked, an open board gets the dim hide board, as before', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.band('terminal', DOCKING.columns, DOCKING)

  await ui.press({ key: 'band:board' })
  expect(await boardButton(ui)).toEqual({ rows: ['hide board'], isDim: true })
})

test('a closed board gets ▸ show board, docked or inline', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const viewport of [PHONE, DOCKING]) {
    const ui = await w.band('terminal', viewport.columns, viewport)

    expect(await boardButton(ui)).toEqual({ rows: ['▸ show board'], isDim: false })
    await ui.unmount()
  }
})

test('off fullscreen at any width, or fullscreen a column short of docking, the board sits inline: its button is the wide close', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const inline: RenderViewport[] = [
    { columns: 200, rows: 40, isFullscreen: false },
    { ...DOCKING, columns: DOCKING.columns - 1 },
  ]

  for (const viewport of inline) {
    const ui = await w.band('terminal', viewport.columns, viewport)

    await ui.press({ key: 'band:board' })
    expect((await boardButton(ui)).rows).toEqual(['[ ✕ close ]'])
    await ui.press({ key: 'band:board' })
    await ui.unmount()
  }
})
