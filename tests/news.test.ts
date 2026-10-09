import { expect, test, tier } from 'claude-code/testing'
import { workPaths } from '../core'
import { TOAST_MS } from '../hooks/host'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { choiceAsk, META, T0, W1, yesAsk } from './support'
import { postedId, PROJECT, ROOT, SESSION, world } from './world'

tier('user')

const CHIME = 'sounds/ask.aiff'

const PULSE_FRAME_MS = 150

const paths = workPaths(ROOT, PROJECT.key, META.id)

test('a new ask from another writer pulses, toasts for 10 seconds, chimes and opens; one there when the window attached does not', async ($, on) => {
  const w = world($, on)
  const elsewhere = w.writer(paths)

  w.seed(META)
  elsewhere(yesAsk('k1', 'Review round 1'))
  await $.session.start(SESSION)
  await w.call('join', { work: META.id })

  expect(w.sounds).toEqual([])
  expect(w.toasts).toEqual([])

  elsewhere(choiceAsk('k2', 'Keep the ledger forever?', ['Yes', 'No']))
  await w.clock.advance(WATCH_MS)

  expect(w.sounds).toEqual([CHIME])
  expect(w.toasts).toEqual(['◆ For you: Keep the ledger forever?'])
  expect(w.toastsMs, 'long enough to read through').toEqual([TOAST_MS])
  expect(w.state.pulse).toEqual({ asks: ['k2'], frames: 24 })

  const ui = await w.pane()

  expect(
    await ui.find({ key: 'choose:k2:0' }),
    'it opens on the board, its buttons out',
  ).toBeDefined()
  expect(await ui.find({ key: 'yes:k1' }), 'the ask there before stays closed').toBeUndefined()
})

test('the ◆ pulses on the band, then rests', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })

  const band = await w.band()

  await w.clock.advance(PULSE_FRAME_MS)
  expect(await band.find({ type: 'Text', text: '◈' })).toMatchObject({ props: { color: C.pulse } })

  await w.clock.advance(24 * PULSE_FRAME_MS)
  expect(w.state.pulse).toEqual({ asks: [], frames: 0 })
  expect(await band.find({ type: 'Text', text: '◆' })).toMatchObject({ props: { color: C.ask } })
})

test("Claude's own ask is new to the window too", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run the production apply' }),
  )

  expect(w.sounds).toEqual([CHIME])
  expect(w.toasts).toEqual(['◆ For you: Run the production apply'])
  expect(w.state.pane?.selected).toBe(id)
})

test('asks landing together make one toast and one chime', async ($, on) => {
  const w = world($, on)
  const { paths: begun } = await w.begin()
  const elsewhere = w.writer(begun)

  elsewhere(yesAsk('k1', 'Review round 1'), yesAsk('k2', 'Try it at 80 columns', 'It works'))
  await w.clock.advance(WATCH_MS)

  expect(w.sounds).toEqual([CHIME])
  expect(w.toasts).toEqual(['◆ 2 for you, the latest: Try it at 80 columns'])
  expect(w.state.pulse?.asks).toEqual(['k1', 'k2'])
})

test('after a reload, the asks already there make no chime; the next one does', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const elsewhere = w.writer(paths)
  const kept: SitrepAttachment = { project: PROJECT.key, work: META.id, writer: W1, attachedAt: T0 }
  let isReloaded = false

  on('state.get', { plugin: 'sitrep', key: 'attachment' }, ($, e, next) => {
    if (isReloaded) {
      return next(e)
    }

    isReloaded = true

    return { value: { value: kept, version: 1 } }
  })

  w.seed(META)
  elsewhere(yesAsk('k1', 'Review round 1'))
  await $.session.start(SESSION)

  expect(w.state.board?.asks.map(each => each.id)).toEqual(['k1'])
  expect(w.sounds).toEqual([])

  elsewhere(yesAsk('k2', 'Review round 2'))
  await w.clock.advance(WATCH_MS)

  expect(w.sounds).toEqual([CHIME])
})

test('an ask closed before the window first saw it is no news', async ($, on) => {
  const w = world($, on)
  const { paths: begun } = await w.begin()
  const elsewhere = w.writer(begun)

  elsewhere(yesAsk('k1', 'Review round 1'), { type: 'resolve', item: 'k1' })
  await w.clock.advance(WATCH_MS)

  expect(w.sounds).toEqual([])
})
