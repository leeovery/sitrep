import { expect, test } from './kit'
import type { Size } from '../cli/panel/cells'
import { draw, text } from '../cli/panel/draw'
import type { Key, Press } from '../cli/panel/keys'
import { layoutOf } from '../cli/panel/layout'
import { opening, step, type PanelEvent, type PanelState } from '../cli/panel/state'
import { viewOf } from '../cli/panel/view'
import type { Ask, Feed, Row, RowKind } from '../core'
import { boardAsk, boardRow, feedOfRows, MIN, snoozedRow, T0 } from './data'

/**
 * A row's asks, opened under it: Help desk redesign asking a choice and a
 * words ask beside a permission prompt, Shift schedules asking a yes, Data
 * import at a prompt alone, Release notes at your turn, Mobile app working,
 * and Onboarding flow in Snoozed.
 */
const NOW = T0 + 60 * MIN

const SIZE: Size = { width: 39, height: 30 }

const [ASKING, YES, PROMPT, TURN, WORKING, ASLEEP] = ['sr-nw0001', 'sr-co0002', 'sr-lw0003', 'sr-ts0004', 'sr-wg0005', 'sr-fa0006'] as const

const THREAD = boardAsk('k1', 'Thread replies, or keep them flat?', { wants: 'choice', options: ['Flat', 'Threaded'], recommended: 'Threaded' }, NOW - 4 * MIN)

const OFFICE = boardAsk('k2', 'Which office moves first?', { wants: 'words' }, NOW - 12 * MIN)

const ROTA = boardAsk('k1', 'Approve the rota', { wants: 'yes', yes: 'Approve' }, NOW - 26 * MIN)

/** A row's line: an ask's naming its id and timed as it was asked, a window's stop timed at `since`. */
const lineOf = (session: string, is: RowKind, index: number, ask?: Ask, since = NOW - 30 * MIN): Row['lines'][number] => ({
  key: `${is}:${session}:${ask?.id ?? index}`,
  is,
  ...(ask === undefined ? {} : { ask: ask.id }),
  first: { lead: ask?.title ?? 'Allow Bash' },
  since: ask?.openedAt ?? since,
})

/** Help desk redesign's row of these asks, the newest first, and its window's permission prompt. */
const askingRow = (asks: readonly Ask[]): Row => ({
  ...boardRow(ASKING, 'ask', { name: 'Help desk redesign', since: asks[0]?.openedAt ?? NOW }),
  lines: [...asks.map((ask, at) => lineOf(ASKING, 'ask', at, ask)), lineOf(ASKING, 'permission', asks.length)],
})

const OTHERS: Row[] = [
  { ...boardRow(YES, 'ask', { name: 'Shift schedules', since: ROTA.openedAt }), lines: [lineOf(YES, 'ask', 0, ROTA)] },
  boardRow(PROMPT, 'permission', { name: 'Data import', since: NOW - 30 * MIN }),
  boardRow(TURN, 'yourTurn', { name: 'Release notes', since: NOW - 31 * MIN }),
  boardRow(WORKING, 'working', { name: 'Mobile app', since: NOW - 6 * MIN }),
]

/** The board with Help desk redesign asking these, or its row as given, and every other row. */
const board = (asks: readonly Ask[] = [THREAD, OFFICE], row: Row | undefined = askingRow(asks)): Feed =>
  feedOfRows(
    [...(row === undefined ? [] : [row]), ...OTHERS],
    [snoozedRow(ASLEEP, ['ask'], { name: 'Onboarding flow' })],
    { [ASKING]: asks, [YES]: [ROTA] },
  )

const press = (kind: Press): Key => ({ kind }) as Key

const [DOWN, UP, LEFT, RIGHT, ENTER, ESC, Z, S, O] = (['down', 'up', 'left', 'right', 'enter', 'esc', 'snooze', 'snoozed', 'open'] as const).map(press) as [
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
]

const tap = (y: number, x = 5): Key => ({ kind: 'tap', x, y })

const read = (feed: Feed = board(), size: Size = SIZE): PanelState => step(opening(size, NOW), { board: feed, news: [], now: NOW }).state

const stepped = (state: PanelState, ...events: PanelEvent[]) => events.reduce<PanelState>((sofar, event) => step(sofar, event).state, state)

const pressed = (state: PanelState, ...keys: Key[]) => stepped(state, ...keys.map(key => ({ key })))

/** The band on the row at `index` among the open rows, from none. */
const onRow = (state: PanelState, index: number) => pressed(state, ...Array.from({ length: index + 1 }, () => DOWN))

/** The board read, the band on Help desk redesign, and its asks open. */
const open = (feed: Feed = board(), size: Size = SIZE) => pressed(onRow(read(feed, size), 0), ENTER)

const boarded = (state: PanelState, feed: Feed) => stepped(state, { board: feed, news: [], now: NOW })

const viewIn = (state: PanelState) => viewOf(state.feed, state, state.now, state.notHere)

const layoutIn = (state: PanelState) => layoutOf(viewIn(state), state.size)

/** The frame's glyphs, a string a row, as the state draws it without colour. */
const frameOf = (state: PanelState) => text(draw(viewIn(state), state.size, { level: 'none' })).split('\n').slice(0, -1)

/** Where the band is, and the asks open, if any. */
const shown = (state: PanelState) => [state.band, state.opened]

/** The terminal row of the first line of the row `key`. */
const yOf = (state: PanelState, key: string) => layoutIn(state).rows.find(each => each.key === key)?.y ?? -1

/** The terminal row of the frame's first line holding `words`. */
const lineWith = (state: PanelState, words: string) => frameOf(state).findIndex(line => line.includes(words))

test("⏎ on a row with asks the view answers opens them under it, at the first, the band staying on the row; ⏎ again closes them", () => {
  const opened = open()

  expect([opened.band, opened.opened, opened.expanded]).toEqual([ASKING, { row: ASKING, ask: 'k1' }, undefined])
  expect(pressed(opened, ENTER).opened).toBeUndefined()
  expect(pressed(opened, ENTER).band).toBe(ASKING)
})

test("a tap on the band's row opens its asks as ⏎ does; a tap on another row puts the band there and opens nothing", () => {
  const banded = onRow(read(), 0)

  expect(pressed(banded, tap(yOf(banded, ASKING))).opened).toEqual({ row: ASKING, ask: 'k1' })
  expect(shown(pressed(banded, tap(yOf(banded, YES))))).toEqual([YES, undefined])
})

test('⏎ on a row with no asks the view answers expands it, as before: a prompt alone, a row at your turn, a working row; a row of asks and a prompt opens only its asks', () => {
  for (const index of [2, 3, 4]) {
    const state = pressed(onRow(read(), index), ENTER)

    expect([state.expanded, state.opened], String(index)).toEqual([state.band, undefined])
  }

  expect(frameOf(open()).slice(3, 7)).toEqual(['   Northwind', '   Thread replies, or keep them flat?', '   Asked 4m ago                   ━━ ━', '   1 Threaded · Recommended'])
})

test('⏎ on an expanded row that has come to hold asks opens them, folding it', () => {
  const expanded = pressed(onRow(read(board([], askingRow([]))), 0), ENTER)
  const asked = boarded(expanded, board())

  expect(asked.expanded).toBe(ASKING)
  expect([pressed(asked, ENTER).opened, pressed(asked, ENTER).expanded]).toEqual([{ row: ASKING, ask: 'k1' }, undefined])
})

test('→ shows the ask after, ← the one before, at once, in the row\'s order, newest first; nothing wraps', () => {
  const opened = open()

  expect(pressed(opened, RIGHT).opened?.ask).toBe('k2')
  expect(pressed(opened, RIGHT, RIGHT).opened?.ask).toBe('k2')
  expect(pressed(opened, RIGHT, LEFT).opened?.ask).toBe('k1')
  expect(pressed(opened, LEFT).opened?.ask).toBe('k1')
  expect(frameOf(pressed(opened, RIGHT))[5]).toBe('   Asked 12m ago                  ━ ━━')
})

test('a tap on a page dot shows its ask, each dot taking its own cells and the space before it', () => {
  const opened = open()
  const y = lineWith(opened, 'Asked')
  const line = frameOf(opened)[y] ?? ''
  const first = line.indexOf('━')
  const second = line.lastIndexOf('━')

  expect(pressed(opened, tap(y, second)).opened?.ask).toBe('k2')
  expect(pressed(opened, tap(y, second - 1)).opened?.ask).toBe('k2')
  expect(pressed(opened, tap(y, second), tap(y, first)).opened?.ask).toBe('k1')
  expect(pressed(opened, tap(y, first - 1)).opened, 'left of the dots, on the ask: nothing').toEqual({ row: ASKING, ask: 'k1' })
})

test('esc closes the asks, the band kept; ↑ and ↓ close them and move the band, a row a press; at the first row ↑ closes them alone', () => {
  const opened = open()

  expect(shown(pressed(opened, ESC))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, DOWN))).toEqual([YES, undefined])
  expect(shown(pressed(opened, UP))).toEqual([ASKING, undefined])
})

test('a tap anywhere but the ask closes the asks and does nothing more: on the row\'s head, on another row or off the rows; a tap on the ask, off a dot, does nothing yet', () => {
  const opened = open()
  const head = yOf(opened, ASKING)

  expect(shown(pressed(opened, tap(head)))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(head + 1)))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(yOf(opened, YES))))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(SIZE.height - 3)))).toEqual([ASKING, undefined])
  expect(pressed(opened, tap(lineWith(opened, 'Thread replies'))).opened).toEqual({ row: ASKING, ask: 'k1' })
  expect(pressed(opened, tap(lineWith(opened, 'Threaded'))).opened).toEqual({ row: ASKING, ask: 'k1' })
})

test("with the asks open, s, z and the digits do nothing, reaching none of the row's own keys; o asks to open the session", () => {
  const opened = open()

  expect(pressed(opened, S)).toEqual(opened)
  expect(step(opened, { key: Z })).toEqual({ state: opened })
  expect(step(opened, { key: { kind: 'digit', n: 1 } })).toEqual({ state: opened })
  expect(step(opened, { key: O })).toEqual({ state: opened, open: ASKING })
})

test("the key line names the asks' keys while they are open: the digits of the answers, `1` for a yes and none for a words ask, `←→` where the row has more than one, and `esc close`", () => {
  const keyLine = (state: PanelState) => frameOf(state).at(-1)

  expect(keyLine(onRow(read(), 0))).toBe(' ↑↓ move  ⏎ asks  o open  q quit')
  expect(keyLine(onRow(read(), 2))).toBe(' ↑↓ move  ⏎ expand  o open  q quit')
  expect(keyLine(open())).toBe(' 1–2 answer  ←→ ask  esc close')
  expect(keyLine(pressed(open(), RIGHT))).toBe(' ←→ ask  esc close')
  expect(keyLine(pressed(onRow(read(), 1), ENTER))).toBe(' 1 answer  esc close')
})

test('an ask that leaves the board passes the asks to the next still on it, else to the one before; with none left they close', () => {
  const third = boardAsk('k3', 'Which week first?', { wants: 'words' }, NOW - 20 * MIN)
  const three = open(board([THREAD, OFFICE, third]))

  expect(boarded(three, board([OFFICE, third])).opened?.ask).toBe('k2')
  expect(boarded(three, board([third])).opened?.ask).toBe('k3')
  expect(boarded(pressed(three, RIGHT, RIGHT), board([THREAD, OFFICE])).opened?.ask).toBe('k2')
  expect(boarded(pressed(three, RIGHT), board([THREAD])).opened?.ask).toBe('k1')
  expect(shown(boarded(three, board([])))).toEqual([ASKING, undefined])
})

test('an ask new to the board leaves the one shown in its place; an ask edited while shown is drawn as it now reads', () => {
  const newer = boardAsk('k3', 'Ship it?', { wants: 'yes', yes: 'Ship' }, NOW - MIN)
  const edited = { ...THREAD, title: 'Thread the replies?' }

  expect(boarded(open(), board([newer, THREAD, OFFICE])).opened?.ask).toBe('k1')
  expect(frameOf(boarded(open(), board([edited, OFFICE])))[4]).toBe('   Thread the replies?')
})

test("the row leaving Needs you closes its asks: its asks gone to a prompt alone, the session working, snoozed or gone, the band passed on", () => {
  const working = boardRow(ASKING, 'working', { name: 'Help desk redesign' })
  const asleep = feedOfRows(OTHERS, [snoozedRow(ASKING, ['ask'], { name: 'Help desk redesign' })], { [ASKING]: [THREAD] })

  expect(shown(boarded(open(), board([])))).toEqual([ASKING, undefined])
  expect(shown(boarded(open(), board([THREAD], working)))).toEqual([ASKING, undefined])
  expect(shown(boarded(open(), asleep))).toEqual([YES, undefined])
  expect(shown(boarded(open(), feedOfRows(OTHERS, [], { [YES]: [ROTA] })))).toEqual([YES, undefined])
})

test('the asks are kept whole in sight with their row as they open and as they page, the view scrolled the least that shows them', () => {
  const prompts = Array.from({ length: 6 }, (_, at) => boardRow(`sr-lw00${10 + at}`, 'permission', { name: `Import ${at + 1}`, since: NOW - (40 + at) * MIN }))
  const feed = feedOfRows([...prompts, askingRow([THREAD, OFFICE]), ...OTHERS], [], { [ASKING]: [THREAD, OFFICE] })
  const opened = pressed(onRow(read(feed, { width: 39, height: 12 }), 6), ENTER)
  const heightOf = (state: PanelState) => layoutIn(state).rows.find(each => each.key === ASKING)?.height

  expect([heightOf(opened), heightOf({ ...opened, top: opened.top - 1 })]).toEqual([7, undefined])
  expect(heightOf(pressed(opened, RIGHT))).toBe(5)
  expect(frameOf(opened)[yOf(opened, ASKING)]).toBe(' ● Help desk redesign 3              ▿')
})
