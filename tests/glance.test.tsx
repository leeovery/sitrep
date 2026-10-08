import { expect, test, tier } from 'claude-code/testing'
import { INLINE, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

/** A work with something under way, an ask waiting, and a note logged, drawn as the docked board. */
async function underWay(w: World) {
  await w.begin()
  await w.call('status', { now: ['Drawing Usage, round 2'], next: 'Usage, round 3' })

  const ask = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))
  const note = postedId(await w.call('note', { text: 'PR #82 merged', detail: ['6 files'] }))
  const ui = await w.pane()

  await ui.press({ key: `pick:${ask}` })

  return { ask, note, ui }
}

test('collapse turns the board into the glance: its counts on one row, what is under way, what waits, the latest log', async ($, on) => {
  const w = world($, on)
  const { ui } = await underWay(w)

  await ui.press({ key: 'collapse' })

  expect(w.state.pane?.mode).toBe('glance')
  expect(await ui.find({ key: 'glance:for-you', text: '1' })).toBeDefined()
  expect(await ui.find({ key: 'glance:parked', text: '0' })).toBeDefined()
  expect(await ui.find({ key: 'expand', text: '⇤ expand' })).toBeDefined()
  expect(await ui.find({ text: 'Drawing Usage, round 2' })).toBeDefined()
  expect(await ui.find({ text: 'next: Usage, round 3' })).toBeDefined()
  expect(await ui.find({ text: 'Review round 1' })).toBeDefined()
  expect(await ui.find({ text: 'PR #82 merged' })).toBeDefined()
  expect(await ui.find({ key: 'collapse' })).toBeUndefined()
})

test('every line of the glance opens the full board on what was clicked', async ($, on) => {
  const w = world($, on)
  const { ask, note, ui } = await underWay(w)

  await ui.press({ key: 'collapse' })
  await ui.press({ key: `open:gask:${ask}` })
  expect(w.state.pane?.mode).toBe('full')
  expect(await ui.find({ key: `yes:${ask}` })).toBeDefined()

  await ui.press({ key: 'collapse' })
  await ui.press({ key: `open:glog:${note}` })
  expect(await ui.find({ type: 'Text', text: '6 files' })).toBeDefined()

  await ui.press({ key: 'collapse' })
  await ui.press({ key: 'glance:parked' })
  expect(await ui.find({ type: 'Text', text: 'PARKED IN THIS SESSION' })).toBeDefined()
})

test('expand opens the full board again, as it was', async ($, on) => {
  const w = world($, on)
  const { ui } = await underWay(w)

  await ui.press({ key: 'collapse' })
  await ui.press({ key: 'expand' })

  expect(await ui.find({ type: 'Text', text: 'FOR YOU' })).toBeDefined()
  expect(await ui.find({ key: 'collapse', text: '⇥ collapse' })).toBeDefined()
})

test('the glance offers what waits in Ready to send, and opens the board on it', async ($, on) => {
  const w = world($, on)
  const { ask, ui } = await underWay(w)

  await ui.press({ key: `pick:${ask}` })
  await ui.press({ key: `yes:${ask}` })
  await ui.press({ key: 'collapse' })
  expect(await ui.find({ key: 'glance:ready', text: '✓ 1 reply ready to send' })).toBeDefined()

  await ui.press({ key: 'glance:ready' })
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test('an inline board has no collapse', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.pane('terminal', INLINE)

  expect(await ui.find({ key: 'collapse' })).toBeUndefined()
})
