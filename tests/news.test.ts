import { expect, test, tier } from './kit'
import { sessionPaths } from '../core'
import { TOAST_MS } from '../hooks/host'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { META, PROJECT, reviewRound, ROOT, T0, W1 } from './data'
import { choiceAsk, yesAsk } from './lines'
import { asked, CONVERSATION, world } from './world'

tier('user')

const PULSE_FRAME_MS = 150

const paths = sessionPaths(ROOT, PROJECT.key, META.id)

test("a new ask from another writer pulses, toasts for 10 seconds and opens, playing no sound, which is SitRep's; one there when the window attached does not", async ($, on) => {
  /** How long each new-ask toast stays, in the order shown. */
  const toastsMs: (number | undefined)[] = []

  // Registered before the world's own, so it is outermost and hears each toast on its way to the world.
  on('ui.toast', { text: /^● New ask: / }, ($, e, next) => (toastsMs.push(e.timeoutMs), next(e)))

  const w = world($, on)
  const elsewhere = w.writer(paths)

  w.seed(META)
  elsewhere(yesAsk('k1', 'Review round 1'))
  await $.session.start(CONVERSATION)
  await w.call('join', { session: META.id })

  expect(w.toasts).toEqual([])

  elsewhere(choiceAsk('k2', 'Keep the ledger forever?', ['Yes', 'No']))
  await w.clock.advance(WATCH_MS)

  expect(w.toasts).toEqual(['● New ask: Keep the ledger forever?'])
  expect(w.sounds, 'SitRep, the Mac app, plays it').toEqual([])
  expect(toastsMs, 'long enough to read through').toEqual([TOAST_MS])
  expect(w.state.pulse).toEqual({ asks: ['k2'], frames: 24 })

  const ui = await w.pane()

  expect(
    await ui.find({ key: `choose:${w.item('k2')}:0` }),
    'it opens on the board, its buttons out',
  ).toBeDefined()
  expect(
    await ui.find({ key: `yes:${w.item('k1')}` }),
    'the ask there before stays closed',
  ).toBeUndefined()
})

test('the ● pulses on the band, then rests', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('ask', reviewRound(1))

  const band = await w.band()

  await w.clock.advance(PULSE_FRAME_MS)
  expect(await band.find({ type: 'Text', text: '◉' })).toMatchObject({ props: { color: C.pulse } })

  await w.clock.advance(24 * PULSE_FRAME_MS)
  expect(w.state.pulse).toEqual({ asks: [], frames: 0 })
  expect(await band.find({ type: 'Text', text: '●' })).toMatchObject({ props: { color: C.ask } })
})

test("Claude's own ask is new to the window too", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })

  expect(w.toasts).toEqual(['● New ask: Run the production apply'])
  expect(w.state.pane?.selected).toBe(w.item(id))
})

test('asks landing together make one toast', async ($, on) => {
  const w = world($, on)
  const { paths: begun } = await w.begin()
  const elsewhere = w.writer(begun)

  elsewhere(yesAsk('k1', 'Review round 1'), yesAsk('k2', 'Try it at 80 columns', 'It works'))
  await w.clock.advance(WATCH_MS)

  expect(w.toasts).toEqual(['● 2 new asks, the latest: Try it at 80 columns'])
  expect(w.state.pulse?.asks).toEqual(['k1', 'k2'])
})

test('after a reload, the asks already there make no toast; the next one does', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const elsewhere = w.writer(paths)
  const kept: SitrepAttachment = {
    project: PROJECT.key,
    session: META.id,
    writer: W1,
    attachedAt: T0,
  }
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
  await $.session.start(CONVERSATION)

  expect(w.state.board?.asks.map(each => each.id)).toEqual(['k1'])
  expect(w.toasts).toEqual([])

  elsewhere(yesAsk('k2', 'Review round 2'))
  await w.clock.advance(WATCH_MS)

  expect(w.toasts).toEqual(['● New ask: Review round 2'])
})

test('an ask closed before the window first saw it is no news', async ($, on) => {
  const w = world($, on)
  const { paths: begun } = await w.begin()
  const elsewhere = w.writer(begun)

  elsewhere(yesAsk('k1', 'Review round 1'), { type: 'resolve', item: 'k1' })
  await w.clock.advance(WATCH_MS)

  expect(w.toasts).toEqual([])
})
