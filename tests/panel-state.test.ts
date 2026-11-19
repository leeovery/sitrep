import { expect, test } from './kit'
import type { Size } from '../cli/panel/cells'
import type { Key, Press } from '../cli/panel/keys'
import { layoutOf } from '../cli/panel/layout'
import { kept, opening, step, type PanelEvent, type PanelState } from '../cli/panel/state'
import { NEW_MS, viewOf } from '../cli/panel/view'
import type { Feed } from '../core'
import { boardRow, feedOfRows, snoozedRow, T0 } from './data'

/**
 * The board under test: three asks, five working and two in Snoozed, each
 * row named by its session. At 40×15 the body is rows 2 to 13: from the
 * top it shows Needs you's heading on row 2, its three rows from rows 3, 5
 * and 7, a blank row, Working's heading on row 10 and its first row from
 * 11, then `▼ 4 more` on 13.
 */
const SIZE: Size = { width: 40, height: 15 }

const ASKS = ['sr-nw0001', 'sr-nw0002', 'sr-nw0003']

const WORKING = ['sr-wg0001', 'sr-wg0002', 'sr-wg0003', 'sr-wg0004', 'sr-wg0005']

const SNOOZED = ['sr-cn0001', 'sr-cn0002']

const [N1, N2, N3] = ASKS as [string, string, string]

const [W1, W2, W3, W4, W5] = WORKING as [string, string, string, string, string]

const [S1, S2] = SNOOZED as [string, string]

type Board = { asks?: string[]; working?: string[]; snoozed?: string[] }

const boardOf = ({ asks = ASKS, working = WORKING, snoozed = SNOOZED }: Board = {}): Feed =>
  feedOfRows(
    [...asks.map(id => boardRow(id, 'ask')), ...working.map(id => boardRow(id, 'working'))],
    snoozed.map(id => snoozedRow(id, ['ask'])),
  )

const press = (kind: Press): Key => ({ kind }) as Key

const [DOWN, UP, PAGE_DOWN, PAGE_UP, HOME, END, ENTER, SNOOZE, ESC] = (
  ['down', 'up', 'pageDown', 'pageUp', 'home', 'end', 'enter', 'snoozed', 'esc'] as const
).map(press) as [Key, Key, Key, Key, Key, Key, Key, Key, Key]

const wheel = (by: number): Key => ({ kind: 'wheel', by })

const tap = (y: number, x = 5): Key => ({ kind: 'tap', x, y })

/** A board read at T0 into the panel's first state, at a size. */
const read = (feed: Feed = boardOf(), size: Size = SIZE, now = T0): PanelState =>
  step(opening(size, now), { board: feed, news: [], now }).state

const stepped = (state: PanelState, ...events: PanelEvent[]) =>
  events.reduce<PanelState>((sofar, event) => step(sofar, event).state, state)

const pressed = (state: PanelState, ...keys: Key[]) => stepped(state, ...keys.map(key => ({ key })))

/** The rows whole in view, by their keys. */
const inView = (state: PanelState) =>
  layoutOf(viewOf(state.feed, state, state.now, state.notHere), state.size).rows.map(row => row.key)

const layoutIn = (state: PanelState) => layoutOf(viewOf(state.feed, state, state.now, state.notHere), state.size)

test('the first press of a move puts the band on the top row in view, ↑ as ↓', () => {
  const scrolled = pressed(read(), wheel(1), wheel(1))

  expect(pressed(read(), DOWN).band).toBe(N1)
  expect(pressed(read(), UP).band).toBe(N1)
  expect(inView(scrolled)[0]).toBe(N3)
  expect([pressed(scrolled, DOWN).band, pressed(scrolled, DOWN).top]).toEqual([N3, 2])
})

test('then each move takes the band a row, across sections, never onto a heading', () => {
  const onLastAsk = pressed(read(), DOWN, DOWN, DOWN)

  expect(onLastAsk.band).toBe(N3)
  expect(pressed(onLastAsk, DOWN).band).toBe(W1)
  expect(pressed(onLastAsk, DOWN, UP).band).toBe(N3)
})

test('the band goes no further than the first row or the last, Home and End taking it there', () => {
  expect(pressed(read(), DOWN, UP, UP).band).toBe(N1)
  expect(pressed(read(), END).band).toBe(W5)
  expect(pressed(read(), END, DOWN).band).toBe(W5)
  expect(pressed(read(), END, HOME).band).toBe(N1)
})

test("the view moves the least that keeps the band's row whole in sight", () => {
  const onW1 = pressed(read(), DOWN, DOWN, DOWN, DOWN)
  const onW2 = pressed(onW1, DOWN)

  expect([onW1.band, onW1.top]).toEqual([W1, 0])
  expect([onW2.band, onW2.top]).toEqual([W2, 2])
  expect(inView(onW2)).toContain(W2)
  expect(inView({ ...onW2, top: 1 })).not.toContain(W2)
  expect(pressed(onW2, UP, UP, UP).top, 'up to N2, shown from 1').toBe(1)
})

test('PgDn and PgUp move the band as many rows as the body shows, the view kept on it', () => {
  const paged = pressed(read(), DOWN, PAGE_DOWN)
  const back = pressed(paged, PAGE_UP)

  expect(inView(pressed(read(), DOWN))).toEqual([N1, N2, N3, W1])
  expect([paged.band, paged.top]).toEqual([W2, 2])
  expect(inView(paged)).toEqual([N3, W1, W2])
  expect([back.band, back.top]).toEqual([N2, 1])
  expect(pressed(read(), PAGE_DOWN).band, 'a first press, as ↓ is').toBe(N1)
})

test('s opens Snoozed and, with no band, scrolls the least that shows its last row; s again folds it', () => {
  const opened = pressed(read(), SNOOZE)
  const folded = pressed(opened, SNOOZE)

  expect(opened.isSnoozedOpen).toBe(true)
  expect(inView(opened)).toContain(`snoozed:${S2}`)
  expect(inView({ ...opened, top: opened.top - 1 })).not.toContain(`snoozed:${S2}`)
  expect(folded.isSnoozedOpen).toBe(false)
  expect(folded.top, "scrolled to the end, as the folded board's end clamps it").toBe(layoutIn(folded).lastTop)
})

test('with a band, opening Snoozed keeps the band where it is in sight', () => {
  const opened = pressed(read(), DOWN, SNOOZE)

  expect([opened.band, opened.top, opened.isSnoozedOpen]).toEqual([N1, 0, true])
})

test("folding Snoozed passes a band on its rows to the row now in its place, else the row above; a band elsewhere stays", () => {
  expect(pressed(read(), SNOOZE, END, SNOOZE).band).toBe(W5)
  expect(pressed(read(), SNOOZE, END, UP, SNOOZE).band).toBe(W5)
  expect(pressed(read(), SNOOZE, HOME, SNOOZE).band).toBe(N1)
  expect(inView(pressed(read(), SNOOZE, END, SNOOZE))).toContain(W5)
})

test("a band on a session's Snoozed row stays on that session as Snoozed folds, where it has a row elsewhere", () => {
  const both = boardOf({ snoozed: [W2, S2] })

  expect(pressed(read(both), SNOOZE, END, UP).band).toBe(`snoozed:${W2}`)
  expect(pressed(read(both), SNOOZE, END, UP, SNOOZE).band).toBe(W2)
})

test('s does nothing while Snoozed holds no rows', () => {
  const quiet = read(boardOf({ snoozed: [] }))

  expect(pressed(quiet, SNOOZE)).toEqual(quiet)
})

test('esc drops the band; any key drops a pick\'s answer, the band staying but for esc', () => {
  const answered = { ...pressed(read(), DOWN), answer: "Release notes can't be opened here." }

  expect(pressed(read(), DOWN, ESC).band).toBeUndefined()
  expect(pressed(answered, DOWN).answer).toBeUndefined()
  expect(pressed(answered, wheel(1)).answer).toBeUndefined()
  expect([pressed(answered, press('suspend')).band, pressed(answered, press('suspend')).answer]).toEqual([N1, undefined])
  expect([pressed(answered, ESC).band, pressed(answered, ESC).answer]).toEqual([undefined, undefined])
})

test('a pick done sets its answer, the band kept whole in sight above it; one with nothing to say leaves none', () => {
  const words = "Data import can't be opened here: its terminal has no tmux or zmx."

  for (const height of [11, 15]) {
    const onLast = pressed(read(boardOf(), { width: 40, height }), END)
    const answered = stepped(onLast, { opened: words })

    expect(inView({ ...onLast, answer: words }), `at ${height} rows the answer alone hides the band`).not.toContain(W5)
    expect([answered.answer, answered.band, inView(answered)], `at ${height} rows`).toEqual([words, W5, expect.arrayContaining([W5])])
    expect(answered.top).toBe(layoutIn(answered).top)
  }

  expect(stepped(pressed(read(), DOWN), { opened: undefined })).toEqual(pressed(read(), DOWN))
})

test("⏎ asks to open the band's session, a Snoozed row's own session; with no band it asks nothing", () => {
  expect(step(pressed(read(), DOWN, DOWN), { key: ENTER }).open).toBe(N2)
  expect(step(pressed(read(), SNOOZE, END), { key: ENTER }).open).toBe(S2)
  expect(step(read(), { key: ENTER })).toEqual({ state: read() })
})

test("a tap on either line of a row puts the band on it, a tap on the band's row opens it; anywhere else, nothing", () => {
  const onN2 = pressed(read(), tap(5))

  expect(inView(read())).toEqual([N1, N2, N3, W1])
  expect(onN2.band).toBe(N2)
  expect(pressed(read(), tap(12)).band, "W1's second line").toBe(W1)
  expect(step(onN2, { key: tap(6) }).open).toBe(N2)
  expect(step(onN2, { key: tap(6) }).state.band).toBe(N2)
  expect([2, 9, 13, 14].map(y => pressed(read(), tap(y)).band), 'a heading, a blank row, ▼, the key line').toEqual([undefined, undefined, undefined, undefined])
  expect(pressed(read(), tap(5, 40)).band, 'past the layout').toBeUndefined()
})

test("a tap while a pick's answer shows finds the row under it as drawn, the answer's rows holding none, and drops the answer", () => {
  for (const height of [11, 15, 20]) {
    const size = { width: 40, height }
    const answered = kept({
      ...pressed(read(boardOf(), size), DOWN, DOWN, DOWN, DOWN),
      answer: "Release notes can't be opened here, as its window is on another Mac.",
    })
    const { answer: _, ...bare } = answered
    const rowAt = (state: PanelState, y: number) => layoutIn(state).rows.find(row => y === row.y || y === row.y + 1)?.key
    const ys = Array.from({ length: height }, (_, y) => y)

    expect(ys.some(y => rowAt(answered, y) !== rowAt(bare, y)), `at ${height} rows the answer moves what is under a tap`).toBe(true)

    for (const y of ys) {
      const tapped = pressed(answered, tap(y))

      expect([tapped.band, tapped.answer], `row ${y} of ${height}`).toEqual([rowAt(answered, y) ?? answered.band, undefined])
    }
  }
})

test('the wheel scrolls the view a row a notch, the band staying on its session in sight or not; past the end piles nothing up', () => {
  const banded = pressed(read(), DOWN)
  const far = pressed(banded, ...Array.from({ length: 50 }, () => wheel(1)))
  const { lastTop } = layoutIn(far)

  expect(pressed(banded, wheel(1)).top).toBe(1)
  expect(pressed(banded, wheel(1), wheel(1), wheel(1)).band).toBe(N1)
  expect(inView(pressed(banded, wheel(1)))).not.toContain(N1)
  expect(far.top).toBe(lastTop)
  expect(pressed(far, wheel(-1)).top).toBe(lastTop - 1)
  expect(pressed(read(), wheel(-1)).top).toBe(0)
})

test('on a changing board the band stays on its session wherever its row goes, and in sight', () => {
  const onW2 = pressed(read(), DOWN, PAGE_DOWN)
  const reordered = stepped(onW2, { board: boardOf({ working: [W2, W1, W3, W4, W5] }), news: [], now: T0 })
  const pushed = stepped(onW2, { board: boardOf({ asks: [...ASKS, 'sr-nw0004', 'sr-nw0005'] }), news: [], now: T0 })

  expect(reordered.band).toBe(W2)
  expect(pushed.band).toBe(W2)
  expect(inView(pushed)).toContain(W2)
  expect(inView({ ...pushed, top: pushed.top - 1 })).not.toContain(W2)
})

test('a band the wheel scrolled out of sight stays out of sight as the board changes', () => {
  const away = pressed(read(), DOWN, wheel(1), wheel(1), wheel(1))
  const changed = stepped(away, { board: boardOf({ working: [W2, W1, W3, W4, W5] }), news: [], now: T0 })

  expect([changed.band, changed.top]).toEqual([N1, 3])
})

test('a session that leaves passes the band to the row now in its place, else the row above; with no rows left there is none', () => {
  const onW2 = pressed(read(), DOWN, PAGE_DOWN)
  const onW5 = pressed(read(), END)
  const board = (working: string[]) => ({ board: boardOf({ working }), news: [], now: T0 })

  expect(stepped(onW2, board([W1, W3, W4, W5])).band).toBe(W3)
  expect(stepped(onW5, board([W1, W2, W3, W4])).band).toBe(W4)
  expect(stepped(onW5, { board: boardOf({ asks: [], working: [], snoozed: [] }), news: [], now: T0 }).band).toBeUndefined()
})

test('a session that moves into Snoozed takes the band there while Snoozed is open, and passes it on while folded', () => {
  const into = (state: PanelState) => stepped(state, { board: boardOf({ working: [W1, W2, W3, W4], snoozed: [W5, S1] }), news: [], now: T0 })

  expect(into(pressed(read(), SNOOZE, END, UP, UP)).band).toBe(`snoozed:${W5}`)
  expect(into(pressed(read(), END)).band).toBe(W4)
})

test('a resize keeps the band in sight, `top` as the layout clamps it', () => {
  const onW2 = pressed(read(), DOWN, PAGE_DOWN)
  const tall = stepped(onW2, { size: { width: 40, height: 30 } })
  const short = stepped(onW2, { size: { width: 40, height: 9 } })

  expect(tall.top).toBe(0)
  expect(inView(tall)).toContain(W2)
  expect(inView(short)).toContain(W2)
})

test('too small to draw, nothing is out of sight: the band comes back into view as the terminal grows', () => {
  const onW5 = pressed(read(), END)
  const back = stepped(onW5, { size: { width: 20, height: 6 } }, { size: SIZE })

  expect(inView(back)).toContain(W5)
})

test('each line new to Needs you is stamped with its board\'s time, and dropped once NEW_MS old, by the clock or the next board', () => {
  const key = `ask:${N1}:0`
  const arrived = stepped(read(), { board: boardOf(), news: [key], now: T0 + 1_000 })
  const later = T0 + 1_000 + NEW_MS

  expect([...arrived.arrivals]).toEqual([[key, T0 + 1_000]])
  expect([...stepped(arrived, { tick: later - 1 }).arrivals]).toEqual([[key, T0 + 1_000]])
  expect([...stepped(arrived, { tick: later }).arrivals]).toEqual([])
  expect([...stepped(arrived, { board: boardOf(), news: [], now: later }).arrivals]).toEqual([])
})

test('a line new again, as an ask woken, is stamped again with the time of the board it came back on', () => {
  const key = `ask:${N1}:0`
  const woken = stepped(read(), { board: boardOf(), news: [key], now: T0 }, { board: boardOf(), news: [key], now: T0 + 1_500 })

  expect([...woken.arrivals]).toEqual([[key, T0 + 1_500]])
})

test('a failed look before any board says why; after a board, it keeps the board, stale, as read when it last read', () => {
  const before = step(opening(SIZE, T0), { failed: "EACCES: can't read the folder." }).state
  const after = stepped(read(), { failed: "EACCES: can't read the folder." })
  const again = stepped(after, { board: boardOf(), news: [], now: T0 + 5_000 })

  expect([before.board, before.reason, before.feed]).toEqual(['looking', "EACCES: can't read the folder.", undefined])
  expect([after.board, after.readAt, after.feed]).toEqual(['stale', T0, boardOf()])
  expect([again.board, again.readAt]).toEqual(['read', T0 + 5_000])
  expect(stepped(before, { board: boardOf(), news: [], now: T0 }).reason).toBeUndefined()
})

test('q, Ctrl-C and Ctrl-Z are the loop\'s: they move nothing here, and drop an answer as any key does', () => {
  const banded = pressed(read(), DOWN, wheel(1))
  const answered = { ...banded, answer: "Release notes can't be opened here." }

  expect(pressed(banded, press('quit'), press('suspend'))).toEqual(banded)
  expect([pressed(answered, press('quit')).answer, pressed(answered, press('suspend')).answer]).toEqual([undefined, undefined])
})
