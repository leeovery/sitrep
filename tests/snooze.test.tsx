/**
 * Snooze in the pane: an ask waiting on Lee snoozed from its buttons, asked
 * in place until when, and written into the window's own file in its
 * session, through the hold or read back and written whole; a snoozed ask
 * in ASKS after those waiting, quieted, with `wake now`; and an ask its
 * time wakes announced as a new one is, one Lee wakes not.
 */
import { expect, test, tier } from 'claude-code/testing'
import {
  HEARTBEAT_MS,
  LATER_MS,
  parseEntries,
  sessionPaths,
  snoozeAt,
  type SessionMeta,
} from '../core'
import { AROUND_MS } from '../hooks/around'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import type { SitrepAttachment } from '../types'
import { rowsOf } from './drawn'
import {
  CLI,
  delivered,
  file,
  META,
  MIN,
  note,
  reply,
  SENDER,
  SLOW,
  snooze,
  W1,
  W2,
  W3,
  wake,
  yesAsk,
} from './support'
import { CONVERSATION, postedId, PROJECT, PROMPT, ROOT, toProject, WIDE, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Board = Awaited<ReturnType<World['opened']>>

/** A time in local time, as Snooze works it out. */
const local = (year: number, month: number, day: number, hour: number, minute = 0) =>
  new Date(year, month - 1, day, hour, minute).getTime()

/** Friday 23 October 2026, 14:00, local time: when the world starts. */
const FRIDAY = local(2026, 10, 23, 14)

const CHIME = 'sounds/ask.aiff'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

const GO = { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' }

const LEDGER = { wants: 'yes', yes: 'Keep', title: 'Keep the ledger forever' }

const THEMES = 'sr-themes'

const THEMES_META: SessionMeta = {
  id: THEMES,
  name: 'Themes',
  summary: 'Themes, area by area',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: FRIDAY,
  by: W3,
}

/** Themes' file this window writes, as Lee snoozes its ask from the pane. */
const MINE = sessionPaths(ROOT, PROJECT.key, THEMES).log(W1)

/** The world at Friday 14:00. */
const fridayWorld = ($: Parameters<typeof world>[0], on: Parameters<typeof world>[1]) =>
  world($, on, { now: FRIDAY })

/** Long enough for a new ask's pulse to run out, ASKS' heading back on its counts. */
const REST_MS = 5_000

/**
 * A session begun with an ask posted, which the board opens as new, and a
 * moment on, its pulse run out: the folder's paths, the ask's id, and the
 * app's lines as it writes them, in the CLI's own file there, as Lee
 * snoozes and wakes from the app.
 */
async function asking(w: World) {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))

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
  w.elsewhere(THEMES_META).write(yesAsk('k4', 'Pick the dark palette', 'Done'))

  const { id } = await asking(w)
  const ui = await w.opened(WIDE)

  return { id, ui }
}

test("the pane's snooze writes one line through the hold into the window's own file, its time worked out at the press; a post after keeps it", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await asking(w)
  const ui = await w.pane()
  const pressedAt = w.clock.now()

  await snoozing(ui, w.item(id), 'tomorrow')
  await w.call('note', { text: 'Drew round 2' })

  expect(linesOf(w, paths.log(W1), 'snooze')).toMatchObject([
    { type: 'snooze', item: id, until: snoozeAt('tomorrow', pressedAt), at: pressedAt },
  ])
  expect(
    parseEntries(w.text(paths.log(W1)))
      .map(line => line.type)
      .slice(-3),
  ).toEqual(['ask', 'snooze', 'note'])
  expect(w.files.has(paths.letters(W1)), 'nothing goes to the inbox').toBe(false)
  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(local(2026, 10, 24, 9))
})

test("another session's snooze is read back and written whole into the window's own file there, and the board reads it again", async ($, on) => {
  const w = fridayWorld($, on)

  w.put(MINE, file([FRIDAY, note('n1', 'Looked in on the palette')]))

  const { ui } = await beside(w)
  const item = w.item('k4', THEMES)

  await toProject(ui)
  await ui.press({ key: `go:${THEMES}` })
  await ui.press({ key: `pick:${item}` })

  const pressedAt = w.clock.now()

  await snoozing(ui, item, 'later')

  expect(parseEntries(w.text(MINE)).map(({ seq, type }) => [seq, type])).toEqual([
    [1, 'note'],
    [2, 'snooze'],
  ])
  expect(parseEntries(w.text(MINE)).at(-1)).toMatchObject({
    item: 'k4',
    until: pressedAt + LATER_MS,
    at: pressedAt,
  })
  expect(w.files.has(sessionPaths(ROOT, PROJECT.key, THEMES).letters(W1))).toBe(false)
  expect(await ui.find({ type: 'Text', text: 'snoozed until 17:00' })).toBeDefined()
})

test("a project's Asks offers snooze on another session's ask drawn from its brief, and writes it there", async ($, on) => {
  const w = fridayWorld($, on)
  const { ui } = await beside(w)
  const item = w.item('k4', THEMES)

  await toProject(ui)
  await ui.press({ key: `pick:${item}` })
  await snoozing(ui, item, 'week')

  expect(linesOf(w, MINE, 'snooze')).toMatchObject([{ item: 'k4', until: local(2026, 10, 26, 9) }])
  expect(await ui.find({ type: 'Text', text: 'snoozed until Mon 09:00' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /1 waiting · 1 snoozed/ })).toBeDefined()
})

test('wake now writes one wake line, and the ask waits on Lee again', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await asking(w)
  const ui = await w.pane()

  app(snooze(id, FRIDAY + 3_600_000))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `wake:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'wake')).toMatchObject([{ type: 'wake', item: id }])
  expect(w.state.board?.waiting).toBe(1)
  expect(await ui.find({ key: `wake:${w.item(id)}` })).toBeUndefined()
})

test('a snooze the check refuses writes nothing, and a toast says why: a reply of Lee’s on its way since the board was drawn', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await asking(w)
  const ui = await w.pane()

  await ui.press({ key: `snooze:${w.item(id)}` })
  w.put(paths.letters(SENDER), file([FRIDAY, reply('r1', id, 'yes')]))
  await ui.press({ key: `snooze-later:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'snooze')).toEqual([])
  expect(w.toasts.at(-1)).toBe(
    `Not snoozed: Lee's reply to ${id} is on its way: it waits on Lee no more.`,
  )
})

test('a snooze into a session gone since the board was drawn writes nothing, and a toast says so', async ($, on) => {
  const w = fridayWorld($, on)
  const { ui } = await beside(w)
  const item = w.item('k4', THEMES)

  await toProject(ui)
  await ui.press({ key: `pick:${item}` })
  w.files.delete(sessionPaths(ROOT, PROJECT.key, THEMES).meta)
  await snoozing(ui, item, 'later')

  expect(w.files.has(MINE)).toBe(false)
  expect(w.toasts.at(-1)).toBe('Not snoozed: its session is no longer on the board.')
})

test('a wake the check refuses writes nothing, and a toast says why: woken from the app since the board was drawn', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await asking(w)
  const ui = await w.pane()

  app(snooze(id, FRIDAY + 3_600_000))
  await w.clock.advance(WATCH_MS)
  app(wake(id))
  await ui.press({ key: `wake:${w.item(id)}` })

  expect(linesOf(w, paths.log(W1), 'wake')).toEqual([])
  expect(w.toasts.at(-1)).toBe(`Not woken: ${id} is not snoozed.`)
})

test('a snoozed ask counts on neither the band nor the tabs, here or elsewhere', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, ui } = await beside(w)
  const band = await w.band()

  expect(await band.find({ key: 'band:asks', text: '1 ask' })).toBeDefined()
  expect(await band.find({ key: 'band:elsewhere', text: '1 elsewhere' })).toBeDefined()

  await snoozing(ui, w.item(id), 'later')
  await toProject(ui)
  await ui.press({ key: `pick:${w.item('k4', THEMES)}` })
  await snoozing(ui, w.item('k4', THEMES), 'later')

  expect(await band.find({ key: 'band:asks', text: '0 asks' })).toBeDefined()
  expect(await band.find({ key: 'band:elsewhere' }), 'none elsewhere').toBeUndefined()
  expect(rowsOf(await ui.find({ key: 'tab:session:box' }))).toEqual([' ⌂ Dashboard redesign'])
  expect(rowsOf(await ui.find({ key: 'tab:all:box' }))).toEqual([' ≡ All projects'])
})

test('ASKS draws a snoozed ask after those waiting, quieted, hanging when it wakes with wake now; its heading says both counts', async ($, on) => {
  const w = fridayWorld($, on)
  const { id: review, app } = await asking(w)
  const go = postedId(await w.call('ask', GO))
  const ledger = postedId(await w.call('ask', LEDGER))
  const ui = await w.pane()

  app(snooze(ledger, local(2026, 10, 24, 9)))
  await w.clock.advance(REST_MS)

  expect(await keysOf(ui, 'pick:')).toEqual([
    `pick:${w.item(go)}`,
    `pick:${w.item(review)}`,
    `pick:${w.item(ledger)}`,
  ])
  expect(await ui.find({ type: 'Text', text: '2 waiting · 1 snoozed' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toMatchObject({
    props: { color: C.grey },
  })
  expect((await ui.find({ key: `wake:${w.item(ledger)}` }))?.props).toMatchObject({
    label: 'wake now',
    plain: true,
    dimColor: true,
  })
  expect((await ui.find({ key: `pick:${w.item(ledger)}` }))?.props.dimColor).toBe(true)
  expect((await ui.find({ key: `pick:${w.item(go)}` }))?.props.dimColor).toBeFalsy()
  expect(rowsOf(await ui.find({ key: `ask:${w.item(ledger)}` }))[0]).toStartWith(
    '◆ Keep the ledger',
  )

  const marks = (await ui.findAll({ type: 'Text', text: '◆' })).map(each => each.props.color)

  expect(marks.at(-1), "the snoozed ask's ◆, quieted").toBe(C.grey)
})

test('with nothing waiting, the heading still says what is snoozed', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const ui = await w.pane()

  app(snooze(id, local(2026, 10, 24, 9)))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ type: 'Text', text: 'nothing waiting · 1 snoozed' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Nothing waiting on you.' })).toBeUndefined()
})

test('a waiting ask, opened, offers snooze among its buttons; a snoozed one, opened, offers its answers and no snooze', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const ui = await w.pane()
  const item = w.item(id)

  expect(await keysOf(ui, '')).toEqual(
    expect.arrayContaining([`yes:${item}`, `ignore:${item}`, `snooze:${item}`]),
  )
  expect((await ui.find({ key: `snooze:${item}` }))?.props).toMatchObject({
    label: 'snooze',
    dimColor: true,
  })

  app(snooze(id, local(2026, 10, 24, 9)))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `yes:${item}` }), 'opened still, it answers').toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` })).toBeUndefined()
})

test('snooze asks in place until when: later today, tomorrow and next week each write their time; the ask closes, quieted under those waiting', async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id: first } = await asking(w)
  const second = postedId(await w.call('ask', GO))
  const third = postedId(await w.call('ask', LEDGER))
  const ui = await w.pane()

  await w.clock.advance(REST_MS)

  const pressedAt = w.clock.now()

  await ui.press({ key: `snooze:${w.item(third)}` })

  expect(
    await ui.find({ type: 'Text', text: 'Snooze it? It stops counting until it wakes.' }),
  ).toBeDefined()
  expect(
    await ui.find({ key: `yes:${w.item(third)}` }),
    'the question in place of its buttons',
  ).toBeUndefined()
  expect(await ui.find({ key: `snooze-later:${w.item(third)}`, text: 'later today' })).toBeDefined()
  expect(await ui.find({ key: `snooze-tomorrow:${w.item(third)}`, text: 'tomorrow' })).toBeDefined()
  expect(await ui.find({ key: `snooze-week:${w.item(third)}`, text: 'next week' })).toBeDefined()
  expect(await ui.find({ key: `snooze-no:${w.item(third)}`, text: 'cancel' })).toBeDefined()

  await ui.press({ key: `snooze-later:${w.item(third)}` })

  expect(w.state.pane?.selected, 'the ask closes').toBeNull()

  await ui.press({ key: `pick:${w.item(second)}` })
  await snoozing(ui, w.item(second), 'tomorrow')
  await ui.press({ key: `pick:${w.item(first)}` })
  await snoozing(ui, w.item(first), 'week')

  expect(linesOf(w, paths.log(W1), 'snooze')).toMatchObject([
    { item: third, until: pressedAt + LATER_MS },
    { item: second, until: local(2026, 10, 24, 9) },
    { item: first, until: local(2026, 10, 26, 9) },
  ])
  expect(await ui.find({ type: 'Text', text: 'nothing waiting · 3 snoozed' })).toBeDefined()
  expect(await keysOf(ui, 'pick:'), 'the soonest to wake first').toEqual([
    `pick:${w.item(third)}`,
    `pick:${w.item(second)}`,
    `pick:${w.item(first)}`,
  ])
})

test("snooze's cancel goes back to the ask's buttons, and writes nothing", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await asking(w)
  const ui = await w.pane()
  const item = w.item(id)

  await ui.press({ key: `snooze:${item}` })
  await ui.press({ key: `snooze-no:${item}` })

  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()
  expect(await ui.find({ key: `snooze-later:${item}` })).toBeUndefined()
  expect(w.state.pane?.selected).toBe(item)
  expect(linesOf(w, paths.log(W1), 'snooze')).toEqual([])
})

test('the soonest to wake comes first among the snoozed, whenever each was posted', async ($, on) => {
  const w = fridayWorld($, on)
  const { id: review, app } = await asking(w)
  const go = postedId(await w.call('ask', GO))
  const ui = await w.pane()

  // The newer ask wakes later: newest first would put it first.
  app(snooze(review, local(2026, 10, 24, 9)), snooze(go, local(2026, 10, 26, 9)))
  await w.clock.advance(REST_MS)

  expect(await keysOf(ui, 'pick:')).toEqual([`pick:${w.item(review)}`, `pick:${w.item(go)}`])
})

test("a project's Asks lists this session's snoozed ask after another session's older waiting one", async ($, on) => {
  const w = fridayWorld($, on)

  w.elsewhere(THEMES_META).write(yesAsk('k4', 'Pick the dark palette', 'Done'))
  await w.clock.advance(MIN)

  const { id, app } = await asking(w)
  const ui = await w.opened(WIDE)

  app(snooze(id, local(2026, 10, 24, 9)))
  await w.clock.advance(WATCH_MS)
  await toProject(ui)

  expect(await keysOf(ui, 'pick:')).toEqual([`pick:${w.item('k4', THEMES)}`, `pick:${w.item(id)}`])
})

test("no snooze on an ask waiting on Claude: Lee's comment on its way, or Claude given it", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id } = await asking(w)
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
  const { id } = await asking(w)
  const ui = await w.pane()
  const item = w.item(id)

  await w.call('finish', { reason: 'Shipped' })
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()
  expect(await ui.find({ key: `snooze:${item}` })).toBeUndefined()
})

test("Snooze's question gives way to the ask's answers once the app snoozes it, and one press of the title closes it", async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const ui = await w.pane()
  const item = w.item(id)

  await ui.press({ key: `snooze:${item}` })
  app(snooze(id, local(2026, 10, 24, 9)))
  await w.clock.advance(WATCH_MS)

  expect(await ui.find({ key: `snooze-later:${item}` })).toBeUndefined()
  expect(await ui.find({ key: `yes:${item}` })).toBeDefined()

  await ui.press({ key: `pick:${item}` })

  expect(w.state.pane?.selected).toBeNull()
})

test("one press of the title closes the ask from Snooze's question", async ($, on) => {
  const w = fridayWorld($, on)
  const { id } = await asking(w)
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
  const { id, app } = await asking(w)
  const ui = await w.pane()
  const item = w.item(id)

  app(snooze(id, local(2026, 10, 24, 9)))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `yes:${item}` })

  expect(await ui.find({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toBeDefined()

  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    'From the board:\n- Review Sessions & Runway, round 1 → Approve',
  )
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(await ui.find({ type: 'Text', text: 'snoozed until tomorrow 09:00' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /snoozed/ })).toBeUndefined()
})

test('an ask its time wakes is announced as a new one is: the ◆ pulses, a toast, the chime, and it opens', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const ui = await w.pane()

  await ui.press({ key: `pick:${w.item(id)}` })
  app(snooze(id, w.clock.now() + 2 * WATCH_MS))
  await w.clock.advance(WATCH_MS)

  const sounds = w.sounds.length

  expect(w.state.pane?.selected).toBeNull()

  await w.clock.advance(2 * WATCH_MS)

  expect(w.sounds.slice(sounds)).toEqual([CHIME])
  expect(w.toasts.at(-1)).toBe('◆ Back from snooze: Review Sessions & Runway, round 1')
  expect(w.state.pulse).toMatchObject({ asks: [id] })
  expect(w.state.pane?.selected).toBe(w.item(id))
  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeDefined()
})

test(
  'a woken ask is announced once: what changes the board after says nothing more of it',
  SLOW,
  async ($, on) => {
    const w = fridayWorld($, on)
    const { id, app } = await asking(w)
    const back = '◆ Back from snooze: Review Sessions & Runway, round 1'

    await w.pane()
    app(snooze(id, w.clock.now() + 2 * WATCH_MS))
    await w.clock.advance(3 * WATCH_MS)

    const toasts = w.toasts.length

    await w.call('note', { text: 'Drew round 2' })
    app(yesAsk('k9', 'Try it at 80 columns', 'It works'))
    await w.clock.advance(HEARTBEAT_MS + 5_000)

    expect(w.toasts.filter(toast => toast === back)).toEqual([back])
    expect(w.toasts.slice(toasts)).toEqual(['◆ New ask: Try it at 80 columns'])
  },
)

test('asks their time wakes together make one toast, naming the latest, and one chime', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const go = postedId(await w.call('ask', GO))
  const until = w.clock.now() + 2 * WATCH_MS

  app(snooze(id, until), snooze(go, until))
  await w.clock.advance(WATCH_MS)

  const sounds = w.sounds.length

  await w.clock.advance(2 * WATCH_MS)

  expect(w.sounds.slice(sounds)).toEqual([CHIME])
  expect(w.toasts.at(-1)).toBe('◆ 2 back from snooze, the latest: Give the go for stage 3')
  expect(w.state.pulse?.asks).toEqual([id, go])
  expect(w.state.pane?.selected).toBe(w.item(go))
})

test("an ask landing as another wakes makes one toast, the new ask's, and one chime; both pulse, and the new one opens", async ($, on) => {
  const w = fridayWorld($, on)
  const { paths, id, app } = await asking(w)
  const elsewhere = w.writer(paths, W2)

  // Asleep at the look within the first advance, woken by the next: the one the new ask lands at.
  app(snooze(id, w.clock.now() + WATCH_MS + 1))
  await w.clock.advance(WATCH_MS)

  const sounds = w.sounds.length

  elsewhere(yesAsk('k9', 'Try it at 80 columns', 'It works'))
  await w.clock.advance(WATCH_MS)

  expect(w.sounds.slice(sounds)).toEqual([CHIME])
  expect(w.toasts.at(-1)).toBe('◆ New ask: Try it at 80 columns')
  expect(w.state.pulse?.asks).toEqual([id, 'k9'])
  expect(w.state.pane?.selected).toBe(w.item('k9'))
})

test('an ask Lee wakes, from the pane or the app, is not announced', async ($, on) => {
  const w = fridayWorld($, on)
  const { id, app } = await asking(w)
  const go = postedId(await w.call('ask', GO))
  const ui = await w.pane()
  const until = local(2026, 10, 24, 9)

  app(snooze(id, until), snooze(go, until))
  await w.clock.advance(WATCH_MS)

  const [sounds, toasts] = [w.sounds.length, w.toasts.length]

  await ui.press({ key: `wake:${w.item(id)}` })
  app(wake(go))
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.waiting).toBe(2)
  expect(w.sounds.length).toBe(sounds)
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

  elsewhere(yesAsk('k1', 'Review round 1'), snooze('k1', FRIDAY + 2 * WATCH_MS))
  await $.session.start(CONVERSATION)
  await w.clock.advance(WATCH_MS)

  expect(w.state.board?.asks[0]?.snoozedUntil).toBe(FRIDAY + 2 * WATCH_MS)
  expect(w.sounds).toEqual([])

  await w.clock.advance(2 * WATCH_MS)

  expect(w.sounds).toEqual([CHIME])
  expect(w.toasts).toEqual(['◆ Back from snooze: Review round 1'])
})

test('a reload over an ask already woken announces nothing for it', async ($, on) => {
  const w = fridayWorld($, on)
  const elsewhere = reloading(w, on)

  elsewhere(yesAsk('k1', 'Review round 1'), snooze('k1', FRIDAY - 1_000))
  await $.session.start(CONVERSATION)
  await w.clock.advance(3 * WATCH_MS)

  expect(w.state.board?.asks[0]?.wokeAt).toBe(FRIDAY - 1_000)
  expect(w.sounds).toEqual([])
  expect(w.toasts).toEqual([])
})

test("a pane snooze rides to Claude as a change to the board in its next prompt's context, and submits no turn", async ($, on) => {
  const w = fridayWorld($, on)
  const { id } = await asking(w)
  const ui = await w.pane()

  await snoozing(ui, w.item(id), 'week')
  await w.clock.advance(AROUND_MS)

  expect(w.submitted, 'no turn').toEqual([])

  const context = (await $.prompt.submit(PROMPT)).context

  expect(context?.[0]).toStartWith('The sitrep board changed since you last saw it. It now reads:')
  expect(context?.[0]).toContain(
    `- ${id} wants a yes (Approve), snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Review Sessions & Runway, round 1`,
  )
  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})
