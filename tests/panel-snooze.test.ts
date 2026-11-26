import { expect, test } from './kit'
import type { Size } from '../cli/panel/cells'
import type { Key, Press } from '../cli/panel/keys'
import { layoutOf } from '../cli/panel/layout'
import { opening, step, type PanelEvent, type PanelState, type Write } from '../cli/panel/state'
import { viewOf } from '../cli/panel/view'
import { snoozeSettingsOf, type Feed, type Row, type RowKind } from '../core'
import { boardRow, feedOfRows, snoozedRow } from './data'
import { inZone, LONDON, wallClock } from './zoned'

/**
 * The snooze menu and `z`, on a board in London at 14:00 on Wednesday 18
 * November 2026: Help desk redesign asking twice beside a permission
 * prompt, Data import at a prompt alone, Shift schedules Stopped, Mobile
 * app working, and Onboarding flow in Snoozed.
 */
const at = wallClock(LONDON)

const NOW = at(2026, 11, 18, 14)

const SIZE: Size = { width: 40, height: 30 }

const [ASKING, PROMPT, TURN, WORKING, ASLEEP] = ['sr-nw0001', 'sr-lw0002', 'sr-co0003', 'sr-wg0004', 'sr-ts0005'] as const

/** A row's line, an ask's naming its id. */
const lineOf = (session: string, is: RowKind, index: number, ask?: string): Row['lines'][number] => ({
  key: `${is}:${session}:${index}`,
  is,
  ...(ask === undefined ? {} : { ask }),
  first: { lead: ask === undefined ? 'Allow Bash' : `Approve ${ask}` },
  since: NOW,
})

const asking: Row = {
  ...boardRow(ASKING, 'ask', { name: 'Help desk redesign', since: NOW }),
  lines: [lineOf(ASKING, 'ask', 0, 'k1'), lineOf(ASKING, 'ask', 1, 'k2'), lineOf(ASKING, 'permission', 2)],
}

const board = (rows: Row[] = [asking]): Feed =>
  feedOfRows(
    [
      ...rows,
      boardRow(PROMPT, 'permission', { name: 'Data import', since: NOW }),
      boardRow(TURN, 'yourTurn', { name: 'Shift schedules', since: NOW }),
      boardRow(WORKING, 'working', { name: 'Mobile app', since: NOW }),
    ],
    [snoozedRow(ASLEEP, ['ask'], { name: 'Onboarding flow', wakesAt: at(2026, 11, 19, 9) })],
  )

const press = (kind: Press): Key => ({ kind }) as Key

const [DOWN, UP, ENTER, ESC, Z, END] = (['down', 'up', 'enter', 'esc', 'snooze', 'end'] as const).map(press) as [Key, Key, Key, Key, Key, Key]

const tap = (y: number, x = 5): Key => ({ kind: 'tap', x, y })

const read = (feed: Feed = board(), size: Size = SIZE, now = NOW): PanelState =>
  step(opening(size, now), { board: feed, news: [], now }).state

const stepped = (state: PanelState, ...events: PanelEvent[]) => events.reduce<PanelState>((sofar, event) => step(sofar, event).state, state)

const pressed = (state: PanelState, ...keys: Key[]) => stepped(state, ...keys.map(key => ({ key })))

/** The line the last key asks to write, the keys before it pressed first. */
const writeOf = (state: PanelState, ...keys: Key[]): Write | undefined => {
  const last = keys.at(-1) as Key

  return step(pressed(state, ...keys.slice(0, -1)), { key: last }).write
}

const layoutIn = (state: PanelState) => layoutOf(viewOf(state.feed, state, state.now, state.notHere), state.size)

/** The keys that put the band on the row of the session named, from none, at the board's top. */
const onRow = (state: PanelState, index: number) => pressed(state, ...Array.from({ length: index + 1 }, () => DOWN))

const inLondon = (body: () => void) => () => inZone(LONDON, body)

test(
  "z on a row that needs you opens the snooze menu under it: Snooze's times as SitRep sets them, worked out as it opens, worded as the notch's menu words them, then Until it moves",
  inLondon(() => {
    const menu = pressed(onRow(read(), 0), Z).menu

    expect(menu).toEqual({
      row: ASKING,
      session: ASKING,
      asks: ['k1', 'k2'],
      at: 0,
      top: 0,
      options: [
        { title: 'In an hour', time: '15:00', until: at(2026, 11, 18, 15) },
        { title: 'Later today', time: '17:00', until: at(2026, 11, 18, 17) },
        { title: 'Tonight', time: '18:00', until: at(2026, 11, 18, 18) },
        { title: 'Tomorrow', time: '09:00', until: at(2026, 11, 19, 9) },
        { title: 'Next week', time: 'Mon 09:00', until: at(2026, 11, 23, 9) },
        { title: 'Until it moves', time: '' },
      ],
    })
  }),
)

test(
  "the menu offers the choices SitRep's snooze.json sets, as a look read them, and only those still to come",
  inLondon(() => {
    const settings = snoozeSettingsOf('{"v":1,"hour":{"on":false},"later":{"on":true,"hours":1},"weekend":{"on":true,"day":"sunday","at":"10:30"}}')
    const set = stepped(read(), { snoozeSettings: settings })
    const evening = read(board(), SIZE, at(2026, 11, 18, 19))
    const titles = (state: PanelState) => pressed(onRow(state, 0), Z).menu?.options.map(each => `${each.title} ${each.time}`.trim())

    expect(titles(set)).toEqual(['Later today 15:00', 'Tonight 18:00', 'Tomorrow 09:00', 'This weekend Sun 10:30', 'Next week Mon 09:00', 'Until it moves'])
    expect(titles(evening)).toEqual(['In an hour 20:00', 'Later today 22:00', 'Tomorrow 09:00', 'Next week Mon 09:00', 'Until it moves'])
  }),
)

test(
  '↑↓ pick a choice within the first and the last; ⏎ asks to snooze the session to it, naming the asks its row showed, and closes the menu',
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)
    const done = step(pressed(open, DOWN, DOWN), { key: ENTER })

    expect(pressed(open, UP).menu?.at).toBe(0)
    expect(pressed(open, DOWN, DOWN, DOWN, DOWN, DOWN, DOWN, DOWN).menu?.at).toBe(5)
    expect(done.write).toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'], until: at(2026, 11, 18, 18) })
    expect([done.state.menu, done.state.band]).toEqual([undefined, ASKING])
    expect(writeOf(open, DOWN, DOWN, DOWN, DOWN, DOWN, ENTER), 'Until it moves').toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'] })
  }),
)

const digit = (n: number): Key => ({ kind: 'digit', n })

test(
  'a digit makes the choice of its number, as ⏎ on it would, the first drawn being 1; past the choices it does nothing, the menu kept open',
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)
    const done = step(open, { key: digit(3) })

    expect(done.write).toEqual(step(pressed(open, DOWN, DOWN), { key: ENTER }).write)
    expect(done.write).toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'], until: at(2026, 11, 18, 18) })
    expect([done.state.menu, done.state.band]).toEqual([undefined, ASKING])
    expect(writeOf(open, digit(1))).toMatchObject({ until: at(2026, 11, 18, 15) })
    expect(writeOf(open, digit(6)), 'Until it moves').toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'] })
    expect(step(open, { key: digit(7) })).toEqual({ state: open })
    expect(step(open, { key: digit(9) })).toEqual({ state: open })
  }),
)

test(
  'a digit chooses by its number wherever the menu is scrolled, its pick aside',
  inLondon(() => {
    const short = stepped(read(board(), { width: 39, height: 8 }), { snoozeSettings: WEEKEND })
    const scrolled = pressed(onRow(short, 0), Z, DOWN, DOWN, DOWN, DOWN, DOWN, DOWN)

    expect(layoutIn(scrolled).menu?.first).toBeGreaterThan(0)
    expect(writeOf(scrolled, digit(1))).toMatchObject({ until: at(2026, 11, 18, 15) })
  }),
)

test(
  'with no menu open a digit does nothing: no answer, no move, no write',
  inLondon(() => {
    const onAsking = onRow(read(), 0)
    const onWorking = onRow(read(), 3)

    for (const state of [read(), onAsking, onWorking]) {
      expect(step(state, { key: digit(1) })).toEqual({ state })
    }
  }),
)

test(
  'a tap on a choice snoozes to it; a tap anywhere else, esc or z closes the menu, writing nothing, the band kept',
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)
    const menu = layoutIn(open).menu ?? { y: -1, lines: 0 }

    expect(menu.lines).toBe(6)
    expect([layoutIn(open).rows[0]?.y, menu.y], 'the row under its heading, under the blank top row, the menu under the row').toEqual([2, 4])
    expect(writeOf(open, tap(menu.y))).toMatchObject({ until: at(2026, 11, 18, 15) })
    expect(writeOf(open, tap(menu.y + 1))).toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'], until: at(2026, 11, 18, 17) })

    for (const key of [tap(menu.y - 1), tap(menu.y + 6), tap(menu.y, 40), ESC, Z]) {
      const closed = step(open, { key })

      expect([closed.write, closed.state.menu, closed.state.band], JSON.stringify(key)).toEqual([undefined, undefined, ASKING])
    }
  }),
)

test(
  'with the menu open, any other key does nothing: no move, no open, no fold, no scroll',
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)

    for (const kind of ['open', 'snoozed', 'pageDown', 'pageUp', 'home', 'end'] as const) {
      expect(step(open, { key: press(kind) }), kind).toEqual({ state: open })
    }

    expect(step(open, { key: { kind: 'wheel', by: 1 } })).toEqual({ state: open })
  }),
)

test(
  'z on a row of your turn alone opens the menu too, and its snooze names no asks',
  inLondon(() => {
    expect(writeOf(onRow(read(), 2), Z, ENTER)).toEqual({ command: 'snooze', session: TURN, asks: [], until: at(2026, 11, 18, 15) })
  }),
)

test(
  'z on a Snoozed row asks to wake its session, with no menu',
  inLondon(() => {
    const onAsleep = pressed(read(), press('snoozed'), END)
    const woken = step(onAsleep, { key: Z })

    expect(woken.write).toEqual({ command: 'wake', session: ASLEEP })
    expect(woken.state.menu).toBeUndefined()
  }),
)

test(
  "z on a row that can't be snoozed says why in the answer line, as a pick's refusal does: a window's prompt alone, a working row; with no band it does nothing",
  inLondon(() => {
    const answer = (state: PanelState) => step(state, { key: Z })

    expect(answer(onRow(read(), 1)).state.answer).toBe("Data import waits on a prompt in its window, and a prompt can't be snoozed.")
    expect(answer(onRow(read(), 3)).state.answer).toBe('Mobile app needs nothing of you: there is nothing to snooze.')
    expect([answer(onRow(read(), 3)).write, answer(onRow(read(), 3)).state.menu]).toEqual([undefined, undefined])
    expect(answer(read())).toEqual({ state: read() })
  }),
)

test(
  "the menu is the band's row's: a board that passes the band on closes it, one that only moves the row keeps it, and its asks stay those the row showed",
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)
    const another: Row = { ...asking, lines: [...asking.lines, lineOf(ASKING, 'ask', 3, 'k3')] }
    const gone = stepped(open, { board: board([]), news: [], now: NOW })
    const grown = stepped(open, { board: board([another]), news: [], now: NOW })

    expect(gone.menu).toBeUndefined()
    expect(grown.menu?.asks).toEqual(['k1', 'k2'])
  }),
)

test('a write that fails says why in the answer, the band kept whole in sight; one done says nothing', () => {
  const onLast = pressed(read(board(), { width: 40, height: 11 }), END)
  const words = 'Something else now waits on you in Help desk redesign: snooze it from its row again.'
  const failed = stepped(onLast, { written: words })

  expect(failed.answer).toBe(words)
  expect(layoutIn(failed).rows.map(row => row.key)).toContain(failed.band)
  expect(stepped(onLast, { written: undefined })).toEqual(onLast)
})

test(
  'the menu and its row are kept whole in sight; short of room, the row gives way to its first line, then the menu its last choices',
  inLondon(() => {
    const low = pressed(read(board(), { width: 40, height: 15 }), DOWN, DOWN, DOWN, Z)
    const short = pressed(read(board(), { width: 40, height: 8 }), DOWN, Z)
    const weekend = pressed(stepped(read(board(), { width: 40, height: 8 }), { snoozeSettings: snoozeSettingsOf('{"v":1,"weekend":{"on":true}}') }), DOWN, Z)
    const lowLayout = layoutIn(low)
    const row = lowLayout.rows.find(each => each.key === TURN)

    expect([row?.height, lowLayout.menu]).toEqual([2, { y: (row?.y ?? 0) + 2, lines: 6, first: 0 }])
    expect(lowLayout.menu === undefined ? 0 : lowLayout.menu.y + lowLayout.menu.lines).toBeLessThanOrEqual(lowLayout.body.to)
    expect(layoutIn(short).rows.find(each => each.key === ASKING)?.height).toBe(1)
    expect(layoutIn(short).menu?.lines).toBe(6)
    expect([weekend.menu?.options.length, layoutIn(weekend).rows[0]?.height, layoutIn(weekend).menu?.lines]).toEqual([7, 1, 6])
  }),
)

/** Snooze's choices with This weekend on: seven on a Wednesday afternoon, Until it moves among them. */
const WEEKEND = snoozeSettingsOf('{"v":1,"weekend":{"on":true}}')

/** Whether the menu's pick is among the choices drawn. */
const isPickDrawn = (state: PanelState) => {
  const menu = layoutIn(state).menu

  return menu !== undefined && state.menu !== undefined && state.menu.at >= menu.first && state.menu.at < menu.first + menu.lines
}

test(
  'short of room for every choice, the menu scrolls the least that keeps the pick drawn, every choice reachable: at 39×8, the seventh, Until it moves, is reached, drawn and made',
  inLondon(() => {
    const open = pressed(stepped(read(board(), { width: 39, height: 8 }), { snoozeSettings: WEEKEND }), DOWN, Z)
    const walk = Array.from({ length: 7 }, (_, steps) => pressed(open, ...Array<Key>(steps).fill(DOWN)))
    const last = walk[6] as PanelState
    const back = pressed(last, UP, UP, UP, UP, UP)

    expect([open.menu?.options.length, layoutIn(open).menu?.lines]).toEqual([7, 6])
    expect(walk.map(state => [state.menu?.at, layoutIn(state).menu?.first])).toEqual([
      [0, 0],
      [1, 0],
      [2, 0],
      [3, 0],
      [4, 0],
      [5, 0],
      [6, 1],
    ])
    expect(walk.every(isPickDrawn)).toBe(true)
    expect(writeOf(last, ENTER)).toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'] })
    expect([back.menu?.at, layoutIn(back).menu?.first], 'back up, scrolled only once the pick reaches the top').toEqual([1, 1])
    expect(layoutIn(pressed(back, UP)).menu?.first).toBe(0)
    expect(writeOf(last, tap((layoutIn(last).menu?.y ?? 0) + 5)), 'a tap on the last line drawn makes the choice drawn there').toEqual({
      command: 'snooze',
      session: ASKING,
      asks: ['k1', 'k2'],
    })
    expect(writeOf(last, tap(layoutIn(last).menu?.y ?? 0))).toMatchObject({ until: at(2026, 11, 18, 17) })
  }),
)

test(
  'an answer landing while the menu is open shrinks it, and the pick stays drawn: ⏎ makes only the choice drawn',
  inLondon(() => {
    const picked = pressed(onRow(read(board(), { width: 40, height: 11 }), 0), Z, DOWN, DOWN, DOWN, DOWN, DOWN)
    const words = 'Something else now waits on you in Help desk redesign: snooze it from its row again, once you have looked at it there.'
    const shrunk = stepped(picked, { written: words })

    expect([layoutIn(picked).menu?.lines, picked.menu?.at]).toEqual([6, 5])
    expect(layoutIn(shrunk).menu?.lines).toBeLessThan(6)
    expect(isPickDrawn(shrunk)).toBe(true)
    expect(writeOf(shrunk, ENTER)).toEqual({ command: 'snooze', session: ASKING, asks: ['k1', 'k2'] })
  }),
)

test(
  "on a stale board the menu's times are worked out from the failed look's time, not the last good one: no In an hour already past, no Tonight after its time",
  inLondon(() => {
    const stale = stepped(read(), { failed: 'EACCES: permission denied', now: at(2026, 11, 18, 19) })
    const options = pressed(onRow(stale, 0), Z).menu?.options.map(each => `${each.title} ${each.time}`.trim())

    expect(stale.board).toBe('stale')
    expect(options).toEqual(['In an hour 20:00', 'Later today 22:00', 'Tomorrow 09:00', 'Next week Mon 09:00', 'Until it moves'])
  }),
)

test(
  'the menu closes once its row can no longer be snoozed: its asks gone to a prompt alone, or the row now working; a row that keeps an ask keeps it',
  inLondon(() => {
    const open = pressed(onRow(read(), 0), Z)
    const promptOnly: Row = { ...asking, lines: [lineOf(ASKING, 'permission', 2)] }
    const working = boardRow(ASKING, 'working', { name: 'Help desk redesign', since: NOW })
    const fewer: Row = { ...asking, lines: [lineOf(ASKING, 'ask', 0, 'k1')] }

    expect(stepped(open, { board: board([promptOnly]), news: [], now: NOW }).menu).toBeUndefined()
    expect(stepped(open, { board: board([working]), news: [], now: NOW }).menu).toBeUndefined()
    expect(stepped(open, { board: board([fewer]), news: [], now: NOW }).menu?.row).toBe(ASKING)
  }),
)

test(
  'a second z on a Snoozed row before a board shows the wake writes nothing more; once a board comes, z wakes again',
  inLondon(() => {
    const onAsleep = pressed(read(), press('snoozed'), END)
    const woken = step(onAsleep, { key: Z })
    const again = step(woken.state, { key: Z })
    const boarded = stepped(woken.state, { board: board(), news: [], now: NOW })

    expect(woken.write).toEqual({ command: 'wake', session: ASLEEP })
    expect(again.write).toBeUndefined()
    expect(step(boarded, { key: Z }).write).toEqual({ command: 'wake', session: ASLEEP })
  }),
)
