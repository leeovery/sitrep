import type { On } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
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

test('the band is counts on the right, each opening the board on what it counts', async ($, on) => {
  const w = world($, on)

  await busy(w)

  const ui = await w.band()
  expect(await ui.drawn()).toMatchObject({ props: { justifyContent: 'flex-end' } })
  expect(await ui.find({ key: 'band:for-you', text: '1 for you' })).toBeDefined()
  expect(await ui.find({ key: 'band:parked', text: '1 parked' })).toBeDefined()

  await ui.press({ key: 'band:parked' })
  expect(w.panes.get('sitrep')).toBe(true)

  const board = await w.pane()

  expect(await board.find({ type: 'Text', text: 'PARKED IN THIS SESSION' })).toBeDefined()

  await ui.press({ key: 'band:for-you' })
  expect(await board.find({ type: 'Text', text: 'FOR YOU' })).toBeDefined()
})

test('below 64 columns the words drop and the counts stay', async ($, on) => {
  const w = world($, on)

  await busy(w)

  const ui = await w.band('terminal', 50)

  expect(await ui.find({ key: 'band:for-you', text: '1' })).toBeDefined()
  expect(await ui.find({ key: 'band:parked', text: '1' })).toBeDefined()
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
