/**
 * Snooze in the pane as the app's `snooze.json` sets it: the choices it
 * offers, in their order, those switched off left out, each waking at the
 * time set, and no snooze while none is; the defaults wherever the file
 * does not read, with nothing said of it; the file read again once it
 * changed, within a look, or where the last read failed or came too soon
 * after its time to trust; and settings a window holds read whole.
 */
import { expect, test, tier } from './kit'
import { IN_AN_HOUR_MS, parseEntries, SNOOZE_CHOICES, SNOOZE_DEFAULTS, snoozeFile } from '../core'
import { AROUND_MS } from '../hooks/around'
import { MIN, ROOT, W1 } from './data'
import { APP_FILE } from './choices'
import { asked, world, type Board, type World } from './world'
import { LOCAL_ZONE, wallClock } from './zoned'

tier('user')

/** A time in the Mac's own zone, as the mod reads the clock there. */
const local = wallClock(LOCAL_ZONE)

/** Friday 23 October 2026, 14:00 in the Mac's zone: when each world starts. */
const FRIDAY = local(2026, 10, 23, 14)

const FILE = snoozeFile(ROOT)

/** The choices the snooze question of the opened ask offers, in the order drawn, `cancel` as `no`. */
const offered = async (ui: Board, item: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith('snooze-') && key.endsWith(`:${item}`))
    .map(key => key.slice('snooze-'.length, -`:${item}`.length))

/** By default: every choice but This weekend, off, and Tonight before 18:00. */
const DEFAULT_OFFER = ['hour', 'later', 'tonight', 'tomorrow', 'week', 'no']

/** The world with `file` as the app wrote it, if any; a session begun, an ask posted, the board open, and a look taken. */
async function opening(w: World, file?: string) {
  if (file !== undefined) {
    w.put(FILE, file)
  }

  const { paths } = await w.begin()
  const id = await asked(w)
  const ui = await w.pane()
  const item = w.item(id)

  await w.clock.advance(AROUND_MS)

  return { paths, item, ui }
}

/** As `opening`, the ask's snooze asked. */
async function asking(w: World, file?: string) {
  const opened = await opening(w, file)

  await opened.ui.press({ key: `snooze:${opened.item}` })

  return opened
}

/** Each `until` the window's own file holds, in the order written. */
const untils = (w: World, path: string) =>
  parseEntries(w.text(path)).flatMap(line =>
    line.type === 'snoozeSession' ? [(line as { until?: number }).until] : [],
  )

test('the pane offers the choices the file switches on, in their order, those it switches off left out', async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { item, ui } = await asking(w, APP_FILE)

  expect(await offered(ui, item)).toEqual([
    'later',
    'tonight',
    'tomorrow',
    'weekend',
    'week',
    'no',
  ])
  expect(await ui.find({ key: `snooze-weekend:${item}`, text: 'this weekend' })).toBeDefined()
})

test('each choice wakes at the time the file sets: Later today an hour on, Tonight at 20:30, This weekend on Sunday at 10:00, Next week on Friday at 08:30', async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { paths, item, ui } = await asking(w, APP_FILE)
  const pressedAt = w.clock.now()

  for (const when of ['later', 'tonight', 'weekend', 'week']) {
    if (when !== 'later') {
      await ui.press({ key: `wake:${item}` })
      await ui.press({ key: `pick:${item}` })
      await ui.press({ key: `snooze:${item}` })
    }

    await ui.press({ key: `snooze-${when}:${item}` })
  }

  expect(untils(w, paths.log(W1))).toEqual([
    pressedAt + IN_AN_HOUR_MS,
    local(2026, 10, 23, 20, 30),
    local(2026, 10, 25, 10),
    local(2026, 10, 30, 8, 30),
  ])
})

test("with no file, or one that does not read, garbled or of a later version, the pane offers the defaults, and says nothing of it", async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { item, ui } = await asking(w)
  const toasts = w.toasts.length

  expect(await offered(ui, item), 'no file').toEqual(DEFAULT_OFFER)

  for (const [file, what] of [
    [APP_FILE.slice(0, 60), 'garbled'],
    [APP_FILE.replace('"v" : 1', '"v" : 2'), 'a later version'],
  ] as const) {
    w.put(FILE, file)
    await w.clock.advance(AROUND_MS)

    expect(await offered(ui, item), what).toEqual(DEFAULT_OFFER)
  }

  expect(w.toasts.slice(toasts)).toEqual([])
})

/** Two files of one size, one switching In an hour off, the other Next week. */
const NO_HOUR = '{"v":1,"hour":{"on":false}}'
const NO_WEEK = '{"v":1,"week":{"on":false}}'

test('the file is read again once its time or size moved, within a look, the question drawn again with what it offers; one changed in place with neither moved is not read again', async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { item, ui } = await asking(w, NO_HOUR)
  const { mtimeMs } = w.files.get(FILE) ?? { mtimeMs: 0 }

  expect(NO_HOUR.length).toBe(NO_WEEK.length)
  expect(await offered(ui, item)).toEqual(['later', 'tonight', 'tomorrow', 'week', 'no'])

  w.files.set(FILE, { text: NO_WEEK, mtimeMs })
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'neither moved').toEqual(['later', 'tonight', 'tomorrow', 'week', 'no'])

  w.put(FILE, NO_WEEK)
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'its time moved').toEqual(['hour', 'later', 'tonight', 'tomorrow', 'no'])

  w.files.delete(FILE)
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'gone').toEqual(DEFAULT_OFFER)
})

test('a press works out its time from the file as it stands at the press: Tonight moved to 21:00 since the question was drawn wakes at 21:00', async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { paths, item, ui } = await asking(w)

  w.put(FILE, '{"v":1,"tonight":{"on":true,"at":"21:00"}}')
  await w.clock.advance(AROUND_MS)
  await ui.press({ key: `snooze-tonight:${item}` })

  expect(untils(w, paths.log(W1))).toEqual([local(2026, 10, 23, 21)])
})

test('a read of the file that failed is tried again at the next look, though its size and time stand as they were', async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { item, ui } = await asking(w)

  w.put(FILE, NO_HOUR)

  const file = w.files.get(FILE) ?? { text: '', mtimeMs: 0 }

  w.after('list', ROOT, () => void w.files.delete(FILE))
  w.after('read', FILE, () => void w.files.set(FILE, file))
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'the read failed').toEqual(DEFAULT_OFFER)

  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'read again').toEqual(['later', 'tonight', 'tomorrow', 'week', 'no'])
})

test("a read within two seconds of the file's time is not trusted: a rewrite of the same size and time is read at the next look, and once read later than that, it is trusted", async ($, on) => {
  const w = world($, on, { now: FRIDAY })
  const { item, ui } = await asking(w)
  const mtimeMs = w.clock.now() + AROUND_MS - 1000

  w.files.set(FILE, { text: NO_HOUR, mtimeMs })
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'read a second after its time').toEqual([
    'later',
    'tonight',
    'tomorrow',
    'week',
    'no',
  ])

  w.files.set(FILE, { text: NO_WEEK, mtimeMs })
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'read again').toEqual(['hour', 'later', 'tonight', 'tomorrow', 'no'])

  w.files.set(FILE, { text: NO_HOUR, mtimeMs })
  await w.clock.advance(AROUND_MS)
  expect(await offered(ui, item), 'trusted').toEqual(['hour', 'later', 'tonight', 'tomorrow', 'no'])
})

test('while no choice is offered the ask offers no snooze: late on a Sunday with only Tonight and This weekend on, until Monday offers This weekend again; and with every choice off', async ($, on) => {
  const w = world($, on, { now: local(2026, 10, 25, 23, 50) })
  const { item, ui } = await opening(
    w,
    '{"v":1,"hour":{"on":false},"later":{"on":false},"tomorrow":{"on":false},"weekend":{"on":true},"week":{"on":false}}',
  )
  const button = () => ui.find({ key: `snooze:${item}` })

  expect(await button(), 'Sunday night').toBeUndefined()

  await w.clock.advance(10 * MIN)
  expect(await button(), 'Monday').toBeDefined()

  w.put(FILE, `{"v":1,${SNOOZE_CHOICES.map(choice => `"${choice}":{"on":false}`).join(',')}}`)
  await w.clock.advance(AROUND_MS)
  expect(await button(), 'every choice off').toBeUndefined()
})

test('settings a window holds without a choice, as a build before it was added stored them, are drawn and snoozed with its defaults: This weekend off, Tonight at 18:00', async ($, on) => {
  const { weekend, tonight, ...stored } = { ...SNOOZE_DEFAULTS, hour: { isOn: false } }
  const w = world($, on, { now: FRIDAY })

  w.holdSnoozeAs(stored)

  const { paths, item, ui } = await asking(w)

  expect(w.state.snooze).toEqual(stored)
  expect([weekend, tonight]).toEqual([SNOOZE_DEFAULTS.weekend, SNOOZE_DEFAULTS.tonight])
  expect(await offered(ui, item)).toEqual(['later', 'tonight', 'tomorrow', 'week', 'no'])

  await ui.press({ key: `snooze-tonight:${item}` })
  expect(untils(w, paths.log(W1))).toEqual([local(2026, 10, 23, 18)])
})
