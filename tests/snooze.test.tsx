/**
 * Snooze in the pane: an ask waiting on Lee snoozes alone from its
 * buttons, asked in place until when, and written into the window's own
 * file in that session, through the hold or read back and written whole;
 * snoozed asks in ASKS after those waiting, quieted, with `wake now`, which
 * wakes the ask, or its session where the session's snooze holds it; an
 * ask its time wakes announced as a new one is, one Lee wakes not; and
 * Lee's own prompt in the window waking his snooze of the session it
 * holds, never an ask's own.
 */
import { expect, test, tier } from './kit'
import {
  HEARTBEAT_MS,
  IN_AN_HOUR_MS,
  parseEntries,
  sessionPaths,
  snoozeAt,
  SNOOZE_DEFAULTS,
  UNTIL_IT_MOVES,
} from '../core'
import { actionsOf } from '../hooks/actions'
import { AROUND_MS } from '../hooks/around'
import type { Host } from '../hooks/host'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment, SitrepPane } from '../types'
import { glyphColors, rowsOf } from './drawn'
import { slot } from './host'
import { CLI, CLOSES, GO, META, MIN, PROJECT, REVIEW, ROOT, SENDER, THEMES, W1, W2 } from './data'
import { delivered, file, park, reply, snooze, snoozeSession, wakeSession, yesAsk } from './lines'
import {
  asked,
  CONVERSATION,
  PROMPT,
  toProject,
  WIDE,
  world,
  type Board,
  type World,
} from './world'
import { LOCAL_ZONE, wallClock } from './zoned'

tier('user')

/**
 * A time in the Mac's own zone. The mod reads the clock across awaits,
 * after `inZone` has put the real `Date` back, so world tests run in the
 * Mac's own zone. Snooze's arithmetic in a named zone, London's change of
 * the clocks among it, is tested in snooze.test.ts and wakes.test.ts.
 */
const local = wallClock(LOCAL_ZONE)

/** Friday 23 October 2026, 14:00 in the Mac's zone: when the world starts. */
const FRIDAY = local(2026, 10, 23, 14)

/** An ask to keep the ledger. */
const KEEP_LEDGER = { wants: 'yes', yes: 'Keep', title: 'Keep the ledger forever' }

/** Themes' file this window writes, as Lee snoozes its ask from the pane. */
const MINE = sessionPaths(ROOT, PROJECT.key, THEMES.id).log(W1)

/** The world at Friday 14:00. */
const fridayWorld = ($: Parameters<typeof world>[0], on: Parameters<typeof world>[1]) =>
  world($, on, { now: FRIDAY })

/** Long enough for a new ask's pulse to run out, ASKS' heading back on its counts. */
const REST_MS = 5_000

/** How long Later today snoozes for by default. */
const DEFAULT_LATER_MS = SNOOZE_DEFAULTS.later.hours * IN_AN_HOUR_MS

/**
 * A session begun with an ask posted, which the board opens as new, and a
 * moment on, its pulse run out: the folder's paths, the ask's id, and the
 * app's lines as it writes them, in the CLI's own file there, as Lee
 * snoozes and wakes from the app.
 */
async function posted(w: World) {
  const { paths } = await w.begin()
  const id = await asked(w, REVIEW)

  await w.clock.advance(REST_MS)

  return { paths, id, app: w.writer(paths, CLI) }
}

/** Lee snoozes an opened ask from its buttons, choosing `when`. */
const snoozing = async (ui: Board, item: string, when: string) => {
  await ui.press({ key: `snooze:${item}` })
  await ui.press({ key: `snooze-${when}:${item}` })
}

/** The window's own file's lines of a kind. */
const linesOf = (w: World, path: string, type: string) =>
  parseEntries(w.text(path)).filter(line => line.type === type)

/** The keys of the drawn buttons that start with `prefix`, in the order drawn. */
const keysOf = async (ui: Board, prefix: string) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => each.key ?? '')
    .filter(key => key.startsWith(prefix))

/** Themes, with no window, its ask waiting; then this session begun with an ask, and the board opened. */
async function beside(w: World) {
  w.elsewhere({ ...THEMES, created: FRIDAY }).write(yesAsk('k4', 'Pick the dark palette', 'Done'))

  const { id } = await posted(w)
  const ui = await w.opened(WIDE)

  return { id, ui }
}

test("the pane's snooze writes one line through the hold into the window's own file, its time worked out at the press; a post after keeps it", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await posted(w)
  const ui = await w.pane()
  const pressedAt = w.clock.now()

  await snoozing(ui, w.item(id), 'tomorrow')
  await w.call('park', { title: 'Drew round 2' })

  expect(linesOf(w, paths.log(W1), 'snooze')).toMatchObject([
    {
      type: 'snooze',
      item: id,
      until: snoozeAt('tomorrow', pressedAt, SNOOZE_DEFAULTS),
      at: pressedAt,
    },
  ])
  expect(
    parseEntries(w.text(paths.log(W1)))
      .map(line => line.type)
      .slice(-3),
  ).toEqual(['ask', 'snooze', 'park'])
  expect(w.files.has(paths.letters(W1)), 'nothing goes to the inbox').toBe(false)
  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(local(2026, 10, 24, 9))
})

test("the pane's snooze of one of two asks puts off that ask alone, and no session's: the other waits on Lee still, unquieted, as does one landing after the board was drawn", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const go = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `snooze:${w.item(go)}` })
  app(yesAsk('k9', 'Try it at 80 columns', 'It works'))
  await ui.press({ key: `snooze-tomorrow:${w.item(go)}` })
  await w.clock.advance(REST_MS)

  expect(linesOf(w, paths.log(W1), 'snooze')).toMatchObject([
    { item: go, until: local(2026, 10, 24, 9) },
  ])
  expect(linesOf(w, paths.log(W1), 'snoozeSession')).toEqual([])
  expect(w.state.board?.asks.map(ask => [ask.id, ask.snoozedUntil])).toEqual([
    [id, undefined],
    [go, local(2026, 10, 24, 9)],
    ['k9', undefined],
  ])
  expect(w.state.board?.waiting).toBe(2)
  expect(await ui.find({ type: 'Text', text: '2 waiting · 1 snoozed' })).toBeDefined()
  expect(await keysOf(ui, 'wake:')).toEqual([`wake:${w.item(go)}`])
  expect((await ui.find({ key: `pick:${w.item(id)}` }))?.props.dimColor).toBeFalsy()
})

test("another session's snooze is read back and written whole into the window's own file there, and the board reads it again", async ($, on) => {
  const w = fridayWorld($, on)

  w.put(MINE, file([FRIDAY, park('n1', 'Looked in on the palette')]))

  const { ui } = await beside(w)
  const item = w.item('k4', THEMES.id)

  await toProject(ui)
  await ui.press({ key: `go:${THEMES.id}` })
  await ui.press({ key: `pick:${item}` })

  const pressedAt = w.clock.now()

  await snoozing(ui, item, 'later')

  expect(parseEntries(w.text(MINE)).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'park'],
    [2, 'snooze'],
  ])
  expect(parseEntries(w.text(MINE)).at(-1)).toMatchObject({
    until: pressedAt + DEFAULT_LATER_MS,
    at: pressedAt,
  })
  expect(w.files.has(sessionPaths(ROOT, PROJECT.key, THEMES.id).letters(W1))).toBe(false)
  expect(await ui.find({ type: 'Text', text: 'snoozed until 17:00' })).toBeDefined()
})

test("a project's Asks offers snooze on another session's ask drawn from its brief, and writes it there", async ($, on) => {
  const w = fridayWorld($, on)
  const { ui } = await beside(w)
  const item = w.item('k4', THEMES.id)

  await toProject(ui)
  await ui.press({ key: `pick:${item}` })
  await snoozing(ui, item, 'week')

  expect(linesOf(w, MINE, 'snooze')).toMatchObject([{ item: 'k4', until: local(2026, 10, 26, 9) }])
  expect(await ui.find({ type: 'Text', text: 'snoozed until next week' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /1 waiting · 1 snoozed/ })).toBeDefined()
})

test("wake now on an ask the session's snooze holds writes one wake line, the session's, and every ask of it waits on Lee again", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const go = await asked(w, GO)
  const ui = await w.pane()

  app(snoozeSession(FRIDAY + 3_600_000, id, go))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `wake:${w.item(go)}` })

  expect(linesOf(w, paths.log(W1), 'wakeSession')).toMatchObject([{ type: 'wakeSession' }])
  expect(w.state.board?.waiting).toBe(2)
  expect(await ui.find({ key: `wake:${w.item(id)}` })).toBeUndefined()
})

test("wake now on an ask snoozed on its own writes one wake line, that ask's, and no session's: it waits on Lee again, another he snoozed sleeping on", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const go = await asked(w, GO)
  const ui = await w.pane()

  app(snooze(id, local(2026, 10, 24, 9)), snooze(go, local(2026, 10, 26, 9)))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `wake:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'wake')).toMatchObject([{ type: 'wake', item: id }])
  expect(linesOf(w, paths.log(W1), 'wakeSession')).toEqual([])
  expect(w.state.board?.waiting).toBe(1)
  expect(await keysOf(ui, 'wake:')).toEqual([`wake:${w.item(go)}`])
})

test('a snooze the check refuses writes nothing, and a toast says why: a comment of Lee\'s on its way to the ask since the board was drawn', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await posted(w)
  const ui = await w.pane()

  await ui.press({ key: `snooze:${w.item(id)}` })
  w.put(
    paths.letters(SENDER),
    file([w.clock.now(), reply('r1', id, 'comment', { note: 'Looks off' })]),
  )
  await ui.press({ key: `snooze-later:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'snooze')).toEqual([])
  expect(w.toasts.at(-1)).toBe('Not snoozed: your reply to it is on its way to Claude.')
})

test('a snooze into a session gone since the board was drawn writes nothing, and a toast says so', async ($, on) => {
  const w = fridayWorld($, on)
  const { ui } = await beside(w)
  const item = w.item('k4', THEMES.id)

  await toProject(ui)
  await ui.press({ key: `pick:${item}` })
  w.files.delete(sessionPaths(ROOT, PROJECT.key, THEMES.id).meta)
  await snoozing(ui, item, 'later')

  expect(w.files.has(MINE)).toBe(false)
  expect(w.toasts.at(-1)).toBe('Not snoozed: its session is no longer on the board.')
})

test('a wake the check refuses writes nothing, and a toast says why: woken from the app since the board was drawn', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const ui = await w.pane()

  app(snoozeSession(FRIDAY + 3_600_000, id))
  await w.clock.advance(WATCH_MS)
  app(wakeSession())
  await ui.press({ key: `wake:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'wakeSession')).toEqual([])
  expect(w.toasts.at(-1)).toBe('Not woken: it is not snoozed.')
})

test('a snoozed ask counts on neither the band nor the tabs, here or elsewhere', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, ui } = await beside(w)
  const band = await w.band()

  expect(await band.find({ key: 'band:asks' })).toMatchObject({ text: '1 ask' })
  expect(await band.find({ key: 'band:elsewhere', text: '1 elsewhere' })).toBeDefined()

  await snoozing(ui, w.item(id), 'later')
  await toProject(ui)
  await ui.press({ key: `pick:${w.item('k4', THEMES.id)}` })
  await snoozing(ui, w.item('k4', THEMES.id), 'later')

  expect(await band.find({ key: 'band:asks' })).toMatchObject({ text: '0 asks' })
  expect(await band.find({ key: 'band:elsewhere' }), 'none elsewhere').toBeUndefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ Help desk redesign'])
  expect(rowsOf(await ui.find({ key: 'tab:all:box' }))).toEqual([' ≡ All projects'])
})

test("ASKS draws a snoozed session's asks after those waiting, quieted, each hanging when it wakes with wake now; its heading says both counts", async ($, on) => {
  const w = fridayWorld($, on)

  w.elsewhere({ ...THEMES, created: FRIDAY }).write(yesAsk('k4', 'Pick the dark palette', 'Done'))

  const { id: review, app } = await posted(w)
  const ledger = await asked(w, KEEP_LEDGER)
  const ui = await w.opened(WIDE)

  app(snoozeSession(local(2026, 10, 24, 9), review, ledger))
  await w.clock.advance(REST_MS)
  await toProject(ui)

  expect(await keysOf(ui, 'pick:')).toEqual([
    `pick:${w.item('k4', THEMES.id)}`,
    `pick:${w.item(ledger)}`,
    `pick:${w.item(review)}`,
  ])
  expect(await ui.find({ type: 'Text', text: '1 waiting · 2 snoozed' })).toBeDefined()
  expect(await ui.findAll({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toEqual([
    expect.objectContaining({ props: expect.objectContaining({ color: C.grey }) }),
    expect.objectContaining({ props: expect.objectContaining({ color: C.grey }) }),
  ])
  expect((await ui.find({ key: `wake:${w.item(ledger)}` }))?.props).toMatchObject({
    label: 'wake now',
    plain: true,
    dimColor: true,
  })
  expect((await ui.find({ key: `pick:${w.item(ledger)}` }))?.props.dimColor).toBe(true)
  expect((await ui.find({ key: `pick:${w.item('k4', THEMES.id)}` }))?.props.dimColor).toBeFalsy()
  expect(rowsOf(await ui.find({ key: `ask:${w.item(ledger)}` }))[0]).toContain('Keep the ledger')

  const marks = async (id: string) => glyphColors(await ui.find({ key: `ask:${id}` }), '●')

  expect(await marks(w.item('k4', THEMES.id)), "the waiting ask's ●").toEqual([C.ask])
  expect(await marks(w.item(ledger)), "a snoozed ask's ●, quieted").toEqual([C.grey])
  expect(await marks(w.item(review)), "a snoozed ask's ●, quieted").toEqual([C.grey])
})

test('with nothing waiting, the heading still says what is snoozed', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const ui = await w.pane()

  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ type: 'Text', text: 'nothing waiting · 1 snoozed' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Nothing waiting on you.' })).toBeUndefined()
})

test('a waiting ask, opened, offers snooze among its buttons; a snoozed one, opened, offers its answers and no snooze', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  expect(await keysOf(ui, '')).toEqual(
    expect.arrayContaining([`yes:${item}`, `ignore:${item}`, `snooze:${item}`]),
  )
  expect((await ui.find({ key: `snooze:${item}` }))?.props).toMatchObject({
    label: 'snooze',
    dimColor: true,
  })

  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `yes:${item}` }), 'opened still, it answers').toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` })).toBeUndefined()
})

test('snooze asks in place until when, and snoozes that ask alone: it is quieted and closed, the others waiting on; in an hour, later today, tonight, tomorrow and next week, in that order, each write their time', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id: first } = await posted(w)
  const second = await asked(w, GO)
  const third = await asked(w, KEEP_LEDGER)
  const ui = await w.pane()
  const item = w.item(third)

  await w.clock.advance(REST_MS)

  const pressedAt = w.clock.now()

  await ui.press({ key: `snooze:${item}` })

  expect(
    await ui.find({ type: 'Text', text: 'Snooze it? It stops counting until it wakes.' }),
  ).toBeDefined()
  expect(await ui.find({ key: `yes:${item}` }), 'the question in place of its buttons').toBeUndefined()
  expect(await keysOf(ui, 'snooze-')).toEqual(
    ['hour', 'later', 'tonight', 'tomorrow', 'week', 'no'].map(when => `snooze-${when}:${item}`),
  )
  expect(await ui.find({ key: `snooze-hour:${item}`, text: 'in an hour' })).toBeDefined()
  expect(await ui.find({ key: `snooze-later:${item}`, text: 'later today' })).toBeDefined()
  expect(await ui.find({ key: `snooze-tonight:${item}`, text: 'tonight' })).toBeDefined()
  expect(await ui.find({ key: `snooze-tomorrow:${item}`, text: 'tomorrow' })).toBeDefined()
  expect(await ui.find({ key: `snooze-week:${item}`, text: 'next week' })).toBeDefined()
  expect(await ui.find({ key: `snooze-no:${item}`, text: 'cancel' })).toBeDefined()

  await ui.press({ key: `snooze-later:${item}` })

  expect(w.state.pane?.selected, 'the ask closes').toBeNull()
  expect(await ui.find({ type: 'Text', text: '2 waiting · 1 snoozed' })).toBeDefined()
  expect(await keysOf(ui, 'wake:')).toEqual([`wake:${item}`])

  for (const when of ['hour', 'tonight', 'tomorrow', 'week'] as const) {
    await ui.press({ key: `wake:${item}` })
    await ui.press({ key: `pick:${item}` })
    await snoozing(ui, item, when)
  }

  expect(linesOf(w, paths.log(W1), 'snooze')).toMatchObject(
    [
      pressedAt + DEFAULT_LATER_MS,
      pressedAt + IN_AN_HOUR_MS,
      local(2026, 10, 23, 18),
      local(2026, 10, 24, 9),
      local(2026, 10, 26, 9),
    ].map(until => ({ item: third, until })),
  )
  expect(linesOf(w, paths.log(W1), 'wake')).toHaveLength(4)
  expect(linesOf(w, paths.log(W1), 'snoozeSession')).toEqual([])
  expect(w.state.board?.asks.filter(ask => ask.snoozedUntil === undefined).map(ask => ask.id)).toEqual(
    [first, second],
  )
})

/** A minute before 18:00 on Friday 23 October 2026, in the Mac's zone. */
const EVENING = local(2026, 10, 23, 17, 59)

test('from 18:00 Snooze offers no tonight, its time gone; the rest stand, in their order', async ($, on) => {
  const w = world($, on, { now: EVENING })
  const { id } = await posted(w)
  const item = w.item(id)
  const ui = await w.pane()

  await ui.press({ key: `snooze:${item}` })
  expect(await keysOf(ui, 'snooze-'), '17:59').toContain(`snooze-tonight:${item}`)
  await w.clock.set(local(2026, 10, 23, 18))

  expect(await keysOf(ui, 'snooze-'), '18:00').toEqual(
    ['hour', 'later', 'tomorrow', 'week', 'no'].map(when => `snooze-${when}:${item}`),
  )
})

/**
 * Tonight pressed on a question drawn before 18:00, the press read at
 * 18:00:30. The pane draws for the time alone only every half minute, so a
 * question can stand past 18:00; the kit draws it afresh as its clock moves,
 * so the press is the act's alone, on a host answering only what a refusal
 * asks of it: what it toasts, or else what it logs failing, and the pane,
 * whose question stays open, drawn with what is offered now (above).
 */
test('tonight drawn before 18:00 and pressed after snoozes nothing, a toast saying so, the question kept open', async () => {
  const pane = slot<SitrepPane>({
    isOpen: true,
    place: null,
    selected: 'snooze:ask',
    shown: {},
    heldShown: null,
    placement: {},
  })
  const said = Promise.withResolvers<string>()
  const host = {
    clock: { now: async () => local(2026, 10, 23, 18) + 30_000 },
    state: { pane, snooze: slot(SNOOZE_DEFAULTS) },
    ui: { toast: said.resolve },
    log: (text: string) => said.resolve(`logged: ${text}`),
  } as unknown as Host

  actionsOf(host).snooze({ project: PROJECT.key, session: THEMES.id, item: 'k4' }, 'tonight')

  expect(await said.promise).toBe('Not snoozed: 18:00 has come already.')
  expect((await pane.read()).selected).toBe('snooze:ask')
})

test("snooze's cancel goes back to the ask's buttons, and writes nothing", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  await ui.press({ key: `snooze:${item}` })
  await ui.press({ key: `snooze-no:${item}` })

  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()
  expect(await ui.find({ key: `snooze-later:${item}` })).toBeUndefined()
  expect(w.state.pane?.selected).toBe(item)
  expect(linesOf(w, paths.log(W1), 'snooze')).toEqual([])
})

test("the soonest to wake comes first among the snoozed in a project's Asks, whenever each was posted", async ($, on) => {
  const w = fridayWorld($, on)

  // Themes' ask is the older, and wakes sooner: newest first would put it last.
  w.elsewhere({ ...THEMES, created: FRIDAY }).write(
    yesAsk('k4', 'Pick the dark palette', 'Done'),
    snoozeSession(local(2026, 10, 24, 9), 'k4'),
  )

  const { id, app } = await posted(w)
  const ui = await w.opened(WIDE)

  app(snoozeSession(local(2026, 10, 26, 9), id))
  await w.clock.advance(REST_MS)
  await toProject(ui)

  expect(await keysOf(ui, 'pick:')).toEqual([
    `pick:${w.item('k4', THEMES.id)}`,
    `pick:${w.item(id)}`,
  ])
})

test("a project's Asks lists this session's snoozed ask after another session's older waiting one", async ($, on) => {
  const w = fridayWorld($, on)

  w.elsewhere({ ...THEMES, created: FRIDAY }).write(yesAsk('k4', 'Pick the dark palette', 'Done'))
  await w.clock.advance(MIN)

  const { id, app } = await posted(w)
  const ui = await w.opened(WIDE)

  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)
  await toProject(ui)

  expect(await keysOf(ui, 'pick:')).toEqual([
    `pick:${w.item('k4', THEMES.id)}`,
    `pick:${w.item(id)}`,
  ])
})

test("no snooze on an ask waiting on Claude: Lee's comment on its way, or Claude given it", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  w.put(
    paths.letters(SENDER),
    file([w.clock.now(), reply('r1', id, 'comment', { note: 'Looks off' })]),
  )
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `yes:${item}` }), 'a comment bars no answer').toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` }), 'on its way').toBeUndefined()

  w.files.delete(paths.letters(SENDER))
  w.writer(paths)(reply('r1', id, 'comment', { note: 'Looks off' }), delivered('r1'))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.asks[0]?.state).toBe('replied')
  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` }), 'Claude has it').toBeUndefined()
})

test('no snooze in a session Claude finished, where nothing waits on Lee; its answers stay', async ($, on) => {
  const w = fridayWorld($, on)
  const { id } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  await w.call('finish', { reason: 'Shipped' })
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` })).toBeUndefined()
})

test("Snooze's question gives way to the ask's answers once the app snoozes it, and one press of the title closes it", async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  await ui.press({ key: `snooze:${item}` })
  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `snooze-later:${item}` })).toBeUndefined()
  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()

  await ui.press({ key: `pick:${item}` })

  expect(w.state.pane?.selected).toBeNull()
})

test("one press of the title closes the ask from Snooze's question", async ($, on) => {
  const w = fridayWorld($, on)
  const { id } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  await ui.press({ key: `snooze:${item}` })
  await ui.press({ key: `pick:${item}` })

  expect(w.state.pane?.selected).toBeNull()
  expect(await ui.find({ key: `snooze-later:${item}` })).toBeUndefined()
  expect(await ui.find({ key: `yes:${item}` })).toBeUndefined()
})

test('answering a snoozed ask answers it: the reply sent takes it out of Snoozed, and delivered it closes', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const ui = await w.pane()
  const item = w.item(id)

  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `yes:${item}` })

  expect(await ui.find({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toBeDefined()

  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  )
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(await ui.find({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /snoozed/ })).toBeUndefined()
})

test('an ask its time wakes is announced as a new one is: the ● pulses, a toast, and it opens, playing no sound, which is SitRep\'s', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const ui = await w.pane()

  await ui.press({ key: `pick:${w.item(id)}` })
  app(snoozeSession(w.clock.now() + 2 * WATCH_MS, id))
  await w.clock.advance(WATCH_MS)

  expect(w.state.pane?.selected).toBeNull()

  await w.clock.advance(2 * WATCH_MS)

  expect(w.toasts.at(-1)).toBe('● Back from snooze: Review Tickets & Replies, round 1')
  expect(w.sounds, 'SitRep, the Mac app, plays it').toEqual([])
  expect(w.state.pulse).toMatchObject({ asks: [id] })
  expect(w.state.pane?.selected).toBe(w.item(id))
  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeDefined()
})

test('an ask snoozed on its own wakes at its time, announced as a new one is, and waits on Lee again', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const until = w.clock.now() + 2 * WATCH_MS

  await w.pane()
  app(snooze(id, until))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(until)

  await w.clock.advance(2 * WATCH_MS)

  expect(w.toasts.at(-1)).toBe('● Back from snooze: Review Tickets & Replies, round 1')
  expect(w.state.board?.asks[0]).toMatchObject({ wokeAt: until })
  expect(w.state.board?.waiting).toBe(1)
})

test('a woken ask is announced once: what changes the board after says nothing more of it', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const back = '● Back from snooze: Review Tickets & Replies, round 1'

  await w.pane()
  app(snoozeSession(w.clock.now() + 2 * WATCH_MS, id))
  await w.clock.advance(3 * WATCH_MS)

  const toasts = w.toasts.length

  await w.call('park', { title: 'Drew round 2' })
  app(yesAsk('k9', 'Try it at 80 columns', 'It works'))
  await w.clock.advance(HEARTBEAT_MS + 5_000)

  expect(w.toasts.filter(toast => toast === back)).toEqual([back])
  expect(w.toasts.slice(toasts)).toEqual(['● New ask: Try it at 80 columns'])
})

test('asks their time wakes together make one toast, naming the latest', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const go = await asked(w, GO)
  const until = w.clock.now() + 2 * WATCH_MS

  app(snoozeSession(until, id, go))
  await w.clock.advance(WATCH_MS)
  await w.clock.advance(2 * WATCH_MS)

  expect(w.toasts.at(-1)).toBe('● 2 back from snooze, the latest: Give the ok for phase 3')
  expect(w.state.pulse?.asks).toEqual([id, go])
  expect(w.state.pane?.selected).toBe(w.item(go))
})

test("an ask landing as another wakes makes one toast, the new ask's; both pulse, and the new one opens", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const elsewhere = w.writer(paths, W2)

  // Asleep at the look within the first advance, woken by the next: the one the new ask lands at,
  // posted once the snooze ran out, so it wakes nothing early.
  app(snoozeSession(w.clock.now() + WATCH_MS + 1, id))
  await w.clock.advance(WATCH_MS)

  const toasts = w.toasts.length

  await w.clock.advance(1)
  elsewhere(yesAsk('k9', 'Try it at 80 columns', 'It works'))
  await w.clock.advance(WATCH_MS - 1)

  expect(w.toasts.length, 'one toast').toBe(toasts + 1)
  expect(w.toasts.at(-1)).toBe('● New ask: Try it at 80 columns')
  expect(w.state.pulse?.asks).toEqual([id, 'k9'])
  expect(w.state.pane?.selected).toBe(w.item('k9'))
})

test('an ask Lee wakes, from the pane or the app, is not announced', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await posted(w)
  const go = await asked(w, GO)
  const ui = await w.pane()
  const until = local(2026, 10, 24, 9)

  app(snoozeSession(until, id, go))
  await w.clock.advance(WATCH_MS)

  const toasts = w.toasts.length

  await ui.press({ key: `wake:${w.item(id)}` })
  app(wakeSession())
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.waiting).toBe(2)
  expect(w.toasts.length).toBe(toasts)
})

/** A reload over a session whose window holds it: the hold kept in `$.state` read back at the session's start. */
const reloading = (w: World, on: Parameters<typeof world>[1]) => {
  const kept: SitrepAttachment = {
    project: PROJECT.key,
    session: META.id,
    writer: W1,
    attachedAt: FRIDAY - 60_000,
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

  return w.writer(sessionPaths(ROOT, PROJECT.key, META.id))
}

test('a reload over an ask asleep announces nothing for it; its time waking it after is announced', async ($, on) => {
  const w = fridayWorld($, on)
  const elsewhere = reloading(w, on)

  elsewhere(yesAsk('k1', 'Review round 1'), snoozeSession(FRIDAY + 2 * WATCH_MS, 'k1'))
  await $.session.start(CONVERSATION)
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(FRIDAY + 2 * WATCH_MS)
  expect(w.toasts).toEqual([])

  await w.clock.advance(2 * WATCH_MS)

  expect(w.toasts).toEqual(['● Back from snooze: Review round 1'])
})

test('a reload over an ask already woken announces nothing for it', async ($, on) => {
  const w = fridayWorld($, on)
  const elsewhere = reloading(w, on)

  elsewhere(yesAsk('k1', 'Review round 1'), snoozeSession(FRIDAY - 1_000, 'k1'))
  await $.session.start(CONVERSATION)
  await w.clock.advance(3 * WATCH_MS)

  expect(w.state.board?.asks[0]?.wokeAt).toBe(FRIDAY - 1_000)
  expect(w.toasts).toEqual([])
})

/** A turn that starts without Lee: a background task's ending, as Claude Code submits it. */
const TASK_DONE = { ...PROMPT, text: 'Task done.', origin: { kind: 'task-notification' as const } }

test("a pane snooze rides to Claude as a change to the board in the context of the next turn not Lee's own, and submits no turn", async ($, on) => {
  const w = fridayWorld($, on)
  const { id } = await posted(w)
  const ui = await w.pane()

  await snoozing(ui, w.item(id), 'week')
  await w.clock.advance(AROUND_MS)

  expect(w.submitted, 'no turn').toEqual([])

  const context = (await $.prompt.submit(TASK_DONE)).context

  expect(context?.[0]).toStartWith('The sitrep board changed since you last saw it. It now reads:')
  expect(context?.[0]).toContain(
    `- ${id} wants a yes (Approve), snoozed by the user until Mon 26 Oct 09:00 (leave it until then): Review Tickets & Replies, round 1`,
  )
  expect((await $.prompt.submit(TASK_DONE)).context).toBeUndefined()
})

test("Lee's own prompt in the window wakes the session it holds while his snooze of it holds: one wake line through the hold, before the prompt takes the board's change; a turn that starts without him wakes nothing", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const ui = await w.pane()

  app(snoozeSession(local(2026, 10, 26, 9), id))
  await w.clock.advance(AROUND_MS)
  await $.prompt.submit(TASK_DONE)

  expect(linesOf(w, paths.log(W1), 'wakeSession'), 'a task ending').toEqual([])
  expect(w.state.board?.waiting).toBe(0)

  const context = (await $.prompt.submit(PROMPT)).context

  expect(linesOf(w, paths.log(W1), 'wakeSession')).toHaveLength(1)
  expect(w.state.board?.waiting).toBe(1)
  expect(context?.[0]).toContain(
    `- ${id} wants a yes (Approve), waiting on the user: Review Tickets & Replies, round 1`,
  )
  expect(await ui.find({ type: 'Text', text: /snoozed/ })).toBeUndefined()

  await $.prompt.submit(PROMPT)

  expect(linesOf(w, paths.log(W1), 'wakeSession'), 'nothing snoozed, nothing written').toHaveLength(
    1,
  )

  app(snoozeSession(w.clock.now() + 1_000, id))
  await w.clock.advance(WATCH_MS)
  await $.prompt.submit(PROMPT)

  expect(linesOf(w, paths.log(W1), 'wakeSession'), 'a snooze run out').toHaveLength(1)
})

test("Lee's own prompt in the window leaves an ask he snoozed on its own asleep, its turn with it: he put that one off, and writes nothing", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await posted(w)
  const ui = await w.pane()

  await snoozing(ui, w.item(id), 'week')
  await w.clock.advance(AROUND_MS)
  await $.prompt.submit(PROMPT)
  await w.clock.advance(WATCH_MS)

  expect(linesOf(w, paths.log(W1), 'wakeSession')).toEqual([])
  expect(linesOf(w, paths.log(W1), 'wake')).toEqual([])
  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(local(2026, 10, 26, 9))
  expect(await ui.find({ type: 'Text', text: 'snoozed until next week' })).toBeDefined()
})

test("Lee's prompt from the Remote Control bridge wakes it as one typed does; snoozed and woken before Claude saw either, his prompt carries no change", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)

  await w.pane()
  app(snoozeSession(FRIDAY + DEFAULT_LATER_MS, id))
  await w.clock.advance(1_000)

  const { context } = await $.prompt.submit({ ...PROMPT, origin: { kind: 'bridge' } })

  expect(linesOf(w, paths.log(W1), 'wakeSession')).toHaveLength(1)
  expect(w.state.board?.waiting).toBe(1)
  expect(context).toBeUndefined()
})

test("a snooze until it moves, the ask's Claude still working, wakes as the window's turn ends, by its Stop or its end; one with a time sleeps through, and a subagent's turn ending wakes neither", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await posted(w)
  const woken = () => linesOf(w, paths.log(W1), 'wakeSession')

  await w.turnStarts('Carry on with stage 2.')
  app(snoozeSession(local(2026, 10, 24, 9), id))
  await w.clock.advance(WATCH_MS)
  await w.turnEnds()

  expect(woken(), 'one with a time').toEqual([])
  expect(w.state.board?.waiting).toBe(0)

  await w.turnStarts('Carry on with stage 3.')
  app(snoozeSession(undefined, id))
  await w.clock.advance(WATCH_MS)
  await w.turnEnds({ agentId: 'a1' })

  expect(woken(), "a subagent's").toEqual([])
  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(UNTIL_IT_MOVES)

  await w.stops({})

  expect(woken()).toHaveLength(1)
  expect(w.state.board?.waiting).toBe(1)

  await w.turnEnds()

  expect(woken(), 'nothing more to wake').toHaveLength(1)

  await w.turnStarts('Carry on with stage 4.')
  app(snoozeSession(undefined, id))
  await w.clock.advance(WATCH_MS)
  await w.turnEnds()

  expect(woken(), 'its end alone').toHaveLength(2)
})
