/**
 * The panel's state, and how each event moves it: the board read, the keys,
 * the terminal's size and the clock, with no terminal. The state carries
 * the view's, so it passes straight to `viewOf`; every fit rule is the
 * layout's (`layoutOf`, `topFor`), none copied here.
 *
 * - The band: a first press of a move puts it on the top row in view; then
 *   each moves it across the open sections' rows, never onto a heading.
 *   PgUp and PgDn move it the rows a body shows, Home and End to the first
 *   and the last. The view moves the least that keeps it whole in sight.
 * - On a changing board the band stays on its session, wherever its row
 *   goes, and in sight if it was. A session that leaves passes it to the
 *   row now in its place, else the row above; with no rows left, there's
 *   none.
 * - `s` opens Snoozed, scrolling its last row into view where there's no
 *   band; and folds it, passing the band on as a session leaving does.
 * - `esc` drops the band, and any key a pick's answer, the loop's own among
 *   them. A pick done sets its answer, or none, the band kept whole in
 *   sight above it.
 * - ⏎ expands the band's row, and folds it again: one row at most, the
 *   band's, folded as the band moves to another row, kept whole in sight.
 *   `o` opens the band's session; nothing else does.
 * - A tap puts the band on the row under it as drawn, a pick's answer
 *   still showing, and expands or folds the band's own row, as ⏎ does; the
 *   wheel scrolls a row a notch, the band staying on its session, in sight
 *   or not.
 * - `z` on a row that needs Lee opens the snooze menu under it, its
 *   choices worked out at that moment (menu.ts), row and menu kept whole in
 *   sight; on a Snoozed row it asks to wake its session; on any other row
 *   it answers why not. The menu belongs to the band's row, and closes as
 *   the band moves to another.
 * - In the menu `↑↓` pick a choice, and ⏎ or a tap on one asks to snooze
 *   the session to it, naming the asks the row showed as the menu opened;
 *   `esc`, `z` or a tap anywhere else closes it; any other key but the
 *   loop's does nothing. A write that fails sets its answer.
 * - `top` is kept as the layout clamps it, so scrolling past the end piles
 *   nothing up.
 * - The sessions SitRep's file dims move behind those drawn filled, the
 *   band staying on its session, as on a changing board.
 * - Each line new to Needs you is stamped with the time of the board it
 *   came on, and dropped once NEW_MS old.
 * - `q`, Ctrl-C and Ctrl-Z are stepped as any key, dropping an answer, and
 *   change nothing else here: leaving and suspending are the loop's.
 */
import { SNOOZE_DEFAULTS, type Feed, type SnoozeSettings } from '../../core'
import type { Size } from './cells'
import type { Key } from './keys'
import { layoutOf, topFor } from './layout'
import { snoozeOptions, type Menu } from './menu'
import { NEW_MS, rowKey, viewOf, type PanelRow, type ViewState } from './view'

export type PanelState = ViewState & {
  /** The board last read; none before the first. */
  feed?: Feed
  size: Size
  /** The sessions on the board open on no device the panel is looked at from. */
  notHere: ReadonlySet<string>
  /** Snooze's choices as Lee set them in SitRep, as the last look read them. */
  snoozeSettings: SnoozeSettings
  /** The latest time an event brought. */
  now: number
}

/**
 * A look's board: the lines new to Needs you on it, when it was read, and
 * the sessions open on no device the panel is looked at from as SitRep
 * said them then, where the look read them, stepped with the board so the
 * band follows its row from where it was drawn.
 */
type Board = { board: Feed; news: readonly string[]; now: number; notHere?: ReadonlySet<string> }

export type PanelEvent =
  | Board
  /** A look that failed, and why. */
  | { failed: string }
  | { key: Key }
  | { size: Size }
  /** The clock, moved on. */
  | { tick: number }
  /** A pick done: what it leaves to say, if anything. */
  | { opened: string | undefined }
  /** A write done: why it failed, if it did. */
  | { written: string | undefined }
  /** The sessions open on no device the panel is looked at from, as SitRep last read them. */
  | { notHere: ReadonlySet<string> }
  /** Snooze's choices, as a look read them. */
  | { snoozeSettings: SnoozeSettings }

/** A line to write, as `sitrep snooze` or `sitrep wake` writes it: a session snoozed, naming the asks its row showed, until a time or until it moves; or woken. */
export type Write =
  | { command: 'snooze'; session: string; asks: readonly string[]; until?: number }
  | { command: 'wake'; session: string }

/** A step's state; the session to open, where `o` asks for one; and the line to write, where the snooze menu or `z` asks for one. */
export type Stepped = { state: PanelState; open?: string; write?: Write }

type Tap = Extract<Key, { kind: 'tap' }>

/** The panel's state before any board: Snoozed folded, no band, the board looked for, Snooze's choices core's defaults. */
export const opening = (size: Size, now: number, notHere: ReadonlySet<string> = new Set()): PanelState => ({
  top: 0,
  isSnoozedOpen: false,
  board: 'looking',
  arrivals: new Map(),
  size,
  notHere,
  snoozeSettings: SNOOZE_DEFAULTS,
  now,
})

const viewIn = (state: PanelState) => viewOf(state.feed, state, state.now, state.notHere)

const layoutIn = (state: PanelState) => layoutOf(viewIn(state), state.size)

/** The rows of the open sections, in order: those the band moves across and `top` counts. */
const openRows = (state: PanelState): PanelRow[] =>
  viewIn(state)
    .sections.filter(section => section.isOpen)
    .flatMap(section => section.rows)

const keysIn = (state: PanelState) => openRows(state).map(rowKey)

/** The state with `field` set, or without it, given none. */
const withField = <K extends 'band' | 'expanded' | 'menu' | 'answer' | 'reason'>(state: PanelState, field: K, value: PanelState[K]): PanelState => {
  const next = { ...state }

  delete next[field]

  return value === undefined ? next : { ...next, [field]: value }
}

/** The band on the row `key`, or on none; where it moves to another, its row folded and its menu closed. */
const withBand = (state: PanelState, key: string | undefined): PanelState => {
  const next = withField(state, 'band', key)
  const folded = next.expanded === key ? next : withField(next, 'expanded', undefined)

  return folded.menu?.row === key ? folded : withField(folded, 'menu', undefined)
}

/** The state with `top` as the layout clamps it. */
const settled = (state: PanelState): PanelState => ({ ...state, top: layoutIn(state).top })

/** Whether the band's row is whole in view, or nothing is in view to scroll it out of; true with no band. */
const isBandInSight = (state: PanelState) => {
  const { rows } = layoutIn(state)

  return state.band === undefined || rows.length === 0 || rows.some(row => row.key === state.band)
}

/** The view moved the least that keeps the band's row whole in sight. */
export const kept = (state: PanelState): PanelState => {
  const top = state.band === undefined ? undefined : topFor(viewIn(state), state.size, state.band)

  return top === undefined ? state : { ...state, top }
}

/** `after`, the band kept in sight where it was in sight `before`. */
const keepingSight = (before: PanelState, after: PanelState) => (isBandInSight(before) ? kept(after) : after)

/** The band on the row `key`, kept whole in sight; the state as it was, given no row. */
const placed = (state: PanelState, key: string | undefined) =>
  key === undefined ? state : settled(kept(withBand(state, key)))

/**
 * Where the band goes as the rows change from `before` to `after`: to its
 * row; else to a row of its session; else to the row now in its place;
 * else to the row above. None with no rows left.
 */
const followed = (before: PanelState, after: PanelState): string | undefined => {
  if (before.band === undefined) {
    return undefined
  }

  const was = openRows(before)
  const rows = openRows(after)
  const at = was.findIndex(row => rowKey(row) === before.band)
  const session = was[at]?.session
  const row =
    rows.find(each => rowKey(each) === before.band) ??
    rows.find(each => each.session === session) ??
    rows[Math.min(Math.max(at, 0), rows.length - 1)]

  return row === undefined ? undefined : rowKey(row)
}

/** `next`, its rows moved from where they stood in `state`: the band following its row, and kept in sight where it was. */
const reflowed = (state: PanelState, next: PanelState) =>
  settled(keepingSight(state, withBand(next, followed(state, next))))

/** Each line new on the board stamped `now`, and those first shown NEW_MS ago or more dropped. */
const arrived = (arrivals: ViewState['arrivals'], news: readonly string[], now: number) =>
  new Map([...arrivals, ...news.map(key => [key, now] as const)].filter(([, at]) => now - at < NEW_MS))

const boarded = (state: PanelState, { board, news, now, notHere = state.notHere }: Board): PanelState => {
  const read: PanelState = {
    ...withField(state, 'reason', undefined),
    feed: board,
    board: 'read',
    readAt: now,
    now,
    arrivals: arrived(state.arrivals, news, now),
    notHere,
  }

  return reflowed(state, read)
}

/** A failed look: after a board, the board kept, stale; before any, why it can't be read. */
const failed = (state: PanelState, reason: string): PanelState =>
  state.feed === undefined ? { ...state, reason } : { ...state, board: 'stale' }

/** The band moved `by` rows, within the first and the last; a first press puts it on the top row in view. */
const movedBy = (state: PanelState, by: number): PanelState => {
  const keys = keysIn(state)
  const at = state.band === undefined ? -1 : keys.indexOf(state.band)
  const to = at === -1 ? layoutIn(state).top : Math.min(Math.max(at + by, 0), keys.length - 1)

  return placed(state, keys[to])
}

/** The rows a page moves: as many as the body shows, at least one. */
const pageOf = (state: PanelState) => Math.max(layoutIn(state).rows.length, 1)

/** Snoozed opened, its last row scrolled into view where there's no band; or folded, the band passed on where it was on Snoozed's rows. */
const toggled = (state: PanelState): PanelState => {
  const last = viewIn(state)
    .sections.find(section => section.kind === 'snoozed')
    ?.rows.at(-1)

  if (last === undefined) {
    return state
  }

  const next = { ...state, isSnoozedOpen: !state.isSnoozedOpen }

  if (!next.isSnoozedOpen) {
    return reflowed(state, next)
  }

  if (state.band !== undefined) {
    return settled(keepingSight(state, next))
  }

  return settled({ ...next, top: topFor(viewIn(next), next.size, rowKey(last)) ?? next.top })
}

/** `o`: the band's session to open, if there's a band. */
const opened = (state: PanelState): Stepped => {
  const session = openRows(state).find(row => rowKey(row) === state.band)?.session

  return session === undefined ? { state } : { state, open: session }
}

/** ⏎: the band's row expanded, or folded again, kept whole in sight; nothing with no band. */
const expanded = (state: PanelState): PanelState => {
  if (state.band === undefined) {
    return state
  }

  return settled(kept(withField(state, 'expanded', state.expanded === state.band ? undefined : state.band)))
}

/**
 * A tap on any line of a row, found where the rows stood as `drawn`, with a
 * pick's answer under them: the band put on it, or, on the band's own row,
 * expanded or folded.
 */
const tapped = (state: PanelState, { x, y }: Tap, drawn: PanelState): PanelState => {
  const layout = layoutIn(drawn)
  const row = x < layout.width ? layout.rows.find(each => y >= each.y && y < each.y + each.height) : undefined

  if (row === undefined) {
    return state
  }

  return row.key === state.band ? expanded(state) : placed(state, row.key)
}

const only = (state: PanelState): Stepped => ({ state })

/** The state saying `answer`, the band kept whole in sight above it. */
const answered = (state: PanelState, answer: string | undefined) => settled(kept(withField(state, 'answer', answer)))

/** Why `z` snoozes nothing on a row the notch offers no Snooze, in words naming it: a window's prompt is its own, and a working row needs nothing. */
const unsnoozable = (row: PanelRow) =>
  row.mark === 'ask'
    ? `${row.name} waits on a prompt in its window, and a prompt can't be snoozed.`
    : `${row.name} needs nothing of you: there is nothing to snooze.`

/** `z`: on a Snoozed row, its session to wake; on one that needs Lee, the menu opened under it, the two kept whole in sight; on any other, why not; nothing with no band. */
const snoozing = (state: PanelState): Stepped => {
  const row = openRows(state).find(each => rowKey(each) === state.band)

  if (row === undefined) {
    return { state }
  }

  if (row.isSnoozed) {
    return { state, write: { command: 'wake', session: row.session } }
  }

  if (row.asks === undefined) {
    return { state: answered(state, unsnoozable(row)) }
  }

  const options = snoozeOptions(state.now, state.snoozeSettings)
  const menu: Menu = { row: rowKey(row), session: row.session, asks: row.asks, options, at: 0 }

  return { state: settled(kept(withField(state, 'menu', menu))) }
}

/** The menu closed. */
const closed = (state: PanelState) => settled(withField(state, 'menu', undefined))

/** The menu's pick moved `by`, within its first choice and its last. */
const pickedBy = (state: PanelState, menu: Menu, by: number): PanelState => ({
  ...state,
  menu: { ...menu, at: Math.min(Math.max(menu.at + by, 0), menu.options.length - 1) },
})

/** The choice at `at` made: the menu closed, and the session to snooze to its time, naming the asks its row showed. */
const chosen = (state: PanelState, menu: Menu, at: number): Stepped => {
  const option = menu.options[at]

  if (option === undefined) {
    return { state: closed(state) }
  }

  const until = option.until === undefined ? {} : { until: option.until }

  return { state: closed(state), write: { command: 'snooze', session: menu.session, asks: menu.asks, ...until } }
}

/** A tap with the menu open, found where it stood as `drawn`: on a choice, that choice made; anywhere else, the menu closed. */
const tappedMenu = (state: PanelState, menu: Menu, { x, y }: Tap, drawn: PanelState): Stepped => {
  const layout = layoutIn(drawn)
  const at = layout.menu === undefined || x >= layout.width ? -1 : y - layout.menu.y

  return at >= 0 && at < (layout.menu?.lines ?? 0) ? chosen(state, menu, at) : { state: closed(state) }
}

/** What each key does with the menu open, its answer already dropped; any other does nothing, the loop's own aside. */
const MENU_KEY: { [K in Key['kind']]?: (state: PanelState, menu: Menu, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped } = {
  up: (state, menu) => only(pickedBy(state, menu, -1)),
  down: (state, menu) => only(pickedBy(state, menu, 1)),
  enter: (state, menu) => chosen(state, menu, menu.at),
  tap: tappedMenu,
  esc: state => only(closed(state)),
  snooze: state => only(closed(state)),
}

/** What each key does to the state, its answer already dropped, and the state as it was drawn. */
const ON_KEY: { [K in Key['kind']]: (state: PanelState, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped } = {
  up: state => only(movedBy(state, -1)),
  down: state => only(movedBy(state, 1)),
  pageUp: state => only(movedBy(state, -pageOf(state))),
  pageDown: state => only(movedBy(state, pageOf(state))),
  home: state => only(placed(state, keysIn(state)[0])),
  end: state => only(placed(state, keysIn(state).at(-1))),
  snoozed: state => only(toggled(state)),
  esc: state => only(settled(withBand(state, undefined))),
  enter: state => only(expanded(state)),
  open: opened,
  snooze: snoozing,
  tap: (state, key, drawn) => only(tapped(state, key, drawn)),
  wheel: (state, { by }) => only(settled({ ...state, top: layoutIn(state).top + by })),
  quit: only,
  suspend: only,
}

/** A key, its answer dropped first: to the menu, while it is open, else as the board takes it. */
const pressed = (drawn: PanelState, key: Key): Stepped => {
  const state = withField(drawn, 'answer', undefined)

  if (drawn.menu !== undefined) {
    const onMenu = MENU_KEY[key.kind] as ((state: PanelState, menu: Menu, key: Key, drawn: PanelState) => Stepped) | undefined

    return onMenu === undefined ? only(state) : onMenu(state, drawn.menu, key, drawn)
  }

  const onKey = ON_KEY[key.kind] as (state: PanelState, key: Key, drawn: PanelState) => Stepped

  return onKey(state, key, drawn)
}

/** The panel's state after the event, and the session it asks to open or the line it asks to write, if any. */
export const step = (state: PanelState, event: PanelEvent): Stepped => {
  if ('board' in event) {
    return only(boarded(state, event))
  }

  if ('failed' in event) {
    return only(failed(state, event.failed))
  }

  if ('key' in event) {
    return pressed(state, event.key)
  }

  if ('size' in event) {
    return only(settled(keepingSight(state, { ...state, size: event.size })))
  }

  if ('opened' in event) {
    return only(answered(state, event.opened))
  }

  if ('written' in event) {
    return only(answered(state, event.written))
  }

  if ('notHere' in event) {
    return only(reflowed(state, { ...state, notHere: event.notHere }))
  }

  if ('snoozeSettings' in event) {
    return only({ ...state, snoozeSettings: event.snoozeSettings })
  }

  return only({ ...state, now: event.tick, arrivals: arrived(state.arrivals, [], event.tick) })
}
