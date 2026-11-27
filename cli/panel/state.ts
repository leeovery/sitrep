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
 * - ⏎ looks closer at the band's row: on a row with asks the view answers,
 *   it opens them under it, at the first, and closes them again; on any
 *   other, it expands the row, and folds it again: one row at most, the
 *   band's, folded as the band moves to another row, kept whole in sight.
 *   `o` opens the band's session; nothing else does.
 * - A tap puts the band on the row under it as drawn, a pick's answer
 *   still showing, and looks closer at the band's own row, as ⏎ does; the
 *   wheel scrolls a row a notch, the band staying on its session, in sight
 *   or not.
 * - With a row's asks open, `←` `→` show the ask before or after, at once,
 *   nothing wrapping, and a tap on a page dot shows its ask; ⏎ and `esc`
 *   close them; the band's moves close them, then move it; a tap anywhere
 *   but on the ask, on the row's head or off it, only closes them; `o`, the
 *   wheel and the loop's own keys work as ever; any other key does
 *   nothing. The asks are the band's row's: they close as the band moves
 *   to another row, or as the row has none left; an ask that leaves passes
 *   them to the next still on the board, else to the one before.
 * - `z` on a row that needs Lee opens the snooze menu under it, its
 *   choices worked out at that moment (menu.ts), row and menu kept whole in
 *   sight; on a Snoozed row it asks to wake its session; on any other row
 *   it answers why not, and a wake already asked for, until a board shows
 *   it, writes nothing more. The menu belongs to the band's row, and closes
 *   as the band moves to another, or as the row can no longer be snoozed.
 * - In the menu `↑↓` pick a choice, every one reachable, the menu scrolled
 *   the least that keeps the pick drawn where it has no room for all; ⏎,
 *   a tap on a drawn choice, or the digit of a choice, asks to snooze the
 *   session to it, naming the asks the row showed as the menu opened; a
 *   digit past its choices does nothing; `esc`, `z` or a tap anywhere else
 *   closes it; any other key but the loop's does nothing. A write that
 *   fails sets its answer. With no menu a digit does nothing.
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
import { asksLinesOf, dotAt, isHeadLine, openedIn } from './asks'
import { layoutOf, topFor, type Placed } from './layout'
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
  /** The session `z` last asked to wake, until a board shows whether it woke. */
  waking?: string
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
  /** A look that failed, why, and when, so the menu's times are worked out from now on a stale board too. */
  | { failed: string; now: number }
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
const withField = <K extends 'band' | 'expanded' | 'menu' | 'opened' | 'answer' | 'reason' | 'waking'>(state: PanelState, field: K, value: PanelState[K]): PanelState => {
  const next = { ...state }

  delete next[field]

  return value === undefined ? next : { ...next, [field]: value }
}

/** The band on the row `key`, or on none; where it moves to another, its row folded, and its menu and its asks closed. */
const withBand = (state: PanelState, key: string | undefined): PanelState => {
  const next = withField(state, 'band', key)
  const folded = next.expanded === key ? next : withField(next, 'expanded', undefined)
  const unmenued = folded.menu?.row === key ? folded : withField(folded, 'menu', undefined)

  return unmenued.opened?.row === key ? unmenued : withField(unmenued, 'opened', undefined)
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

/** The menu closed where its row can no longer be snoozed: its asks gone, or the row now Working or Snoozed. */
const stillSnoozable = (state: PanelState): PanelState => {
  const row = state.menu === undefined ? undefined : openRows(state).find(each => rowKey(each) === state.menu?.row)

  return state.menu === undefined || (row?.asks !== undefined && !row.isSnoozed) ? state : withField(state, 'menu', undefined)
}

/** The ids of the asks the view answers on the row `key`. */
const askIdsOn = (state: PanelState, key: string) =>
  openRows(state)
    .find(row => rowKey(row) === key)
    ?.answerable?.map(ask => ask.id) ?? []

/**
 * The asks open on `after`'s row, as the board changed from `before`: the
 * ask shown where it is still on the board, else the next of those it had
 * after it still there, else the nearest before it, else the row's first;
 * closed with none left.
 */
const stillAsking = (before: PanelState, after: PanelState): PanelState => {
  const { opened } = after

  if (opened === undefined) {
    return after
  }

  const now = askIdsOn(after, opened.row)
  const was = askIdsOn(before, opened.row)
  const at = Math.max(was.indexOf(opened.ask), 0)
  const ask = now.includes(opened.ask)
    ? opened.ask
    : ([...was.slice(at + 1), ...was.slice(0, at).reverse()].find(id => now.includes(id)) ?? now[0])

  return ask === undefined ? withField(after, 'opened', undefined) : { ...after, opened: { ...opened, ask } }
}

/** `next`, its rows moved from where they stood in `state`: the band following its row, and kept in sight where it was. */
const reflowed = (state: PanelState, next: PanelState) =>
  settled(keepingSight(state, stillAsking(state, stillSnoozable(withBand(next, followed(state, next))))))

/** Each line new on the board stamped `now`, and those first shown NEW_MS ago or more dropped. */
const arrived = (arrivals: ViewState['arrivals'], news: readonly string[], now: number) =>
  new Map([...arrivals, ...news.map(key => [key, now] as const)].filter(([, at]) => now - at < NEW_MS))

const boarded = (state: PanelState, { board, news, now, notHere = state.notHere }: Board): PanelState => {
  const read: PanelState = {
    ...withField(withField(state, 'reason', undefined), 'waking', undefined),
    feed: board,
    board: 'read',
    readAt: now,
    now,
    arrivals: arrived(state.arrivals, news, now),
    notHere,
  }

  return reflowed(state, read)
}

/** A failed look at `now`: after a board, the board kept, stale; before any, why it can't be read. */
const failed = (state: PanelState, { failed: reason, now }: { failed: string; now: number }): PanelState =>
  state.feed === undefined ? { ...state, reason, now } : { ...state, board: 'stale', now }

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

/** ⏎ on the band's row: its asks opened under it at the first, where the view answers one, the row folded, the two kept whole in sight; else the row expanded or folded. */
const lookedCloser = (state: PanelState): PanelState => {
  const first = openRows(state).find(row => rowKey(row) === state.band)?.answerable?.[0]

  if (state.band === undefined || first === undefined) {
    return expanded(state)
  }

  return settled(kept(withField(withField(state, 'expanded', undefined), 'opened', { row: state.band, ask: first.id })))
}

/**
 * A tap on any line of a row, found where the rows stood as `drawn`, with a
 * pick's answer under them: the band put on it, or, on the band's own row,
 * looked closer at.
 */
const tapped = (state: PanelState, { x, y }: Tap, drawn: PanelState): PanelState => {
  const layout = layoutIn(drawn)
  const row = x < layout.width ? layout.rows.find(each => y >= each.y && y < each.y + each.height) : undefined

  if (row === undefined) {
    return state
  }

  return row.key === state.band ? lookedCloser(state) : placed(state, row.key)
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
    return state.waking === row.session ? { state } : { state: withField(state, 'waking', row.session), write: { command: 'wake', session: row.session } }
  }

  if (row.asks === undefined) {
    return { state: answered(state, unsnoozable(row)) }
  }

  const options = snoozeOptions(state.now, state.snoozeSettings)
  const menu: Menu = { row: rowKey(row), session: row.session, asks: row.asks, options, at: 0, top: 0 }

  return { state: settled(kept(withField(state, 'menu', menu))) }
}

/** The menu closed. */
const closed = (state: PanelState) => settled(withField(state, 'menu', undefined))

/** The menu's pick moved `by`, within its first choice and its last, the menu scrolled as the layout keeps it drawn. */
const pickedBy = (state: PanelState, menu: Menu, by: number): PanelState => {
  const picked = { ...state, menu: { ...menu, at: Math.min(Math.max(menu.at + by, 0), menu.options.length - 1) } }
  const top = layoutIn(picked).menu?.first

  return top === undefined ? picked : { ...picked, menu: { ...picked.menu, top } }
}

/** The choice drawn on the menu's line `line`, counted from its first, as `drawn` lays the menu out; -1 where none is drawn there. */
const drawnChoice = (drawn: PanelState, line: number) => {
  const menu = layoutIn(drawn).menu

  return menu === undefined || line < 0 || line >= menu.lines ? -1 : menu.first + line
}

/** The choice at `at` made: the menu closed, and the session to snooze to its time, naming the asks its row showed. */
const chosen = (state: PanelState, menu: Menu, at: number): Stepped => {
  const option = menu.options[at]

  if (option === undefined) {
    return { state: closed(state) }
  }

  const until = option.until === undefined ? {} : { until: option.until }

  return { state: closed(state), write: { command: 'snooze', session: menu.session, asks: menu.asks, ...until } }
}

/** A tap with the menu open, found where it stood as `drawn`: on a drawn choice, that choice made; anywhere else, the menu closed. */
const tappedMenu = (state: PanelState, menu: Menu, { x, y }: Tap, drawn: PanelState): Stepped => {
  const layout = layoutIn(drawn)
  const at = layout.menu === undefined || x >= layout.width ? -1 : drawnChoice(drawn, y - layout.menu.y)

  return at === -1 ? { state: closed(state) } : chosen(state, menu, at)
}

/** Whether the menu, as `drawn` lays it out, draws a line. */
const isMenuDrawn = (drawn: PanelState) => (layoutIn(drawn).menu?.lines ?? 0) > 0

/** ⏎ with the menu open: the pick made, which the layout always draws while the menu has a line; with none, nothing. */
const enteredMenu = (state: PanelState, menu: Menu, drawn: PanelState): Stepped =>
  isMenuDrawn(drawn) ? chosen(state, menu, menu.at) : only(state)

/** A digit with the menu open: the choice of its number made, as ⏎ on it; past the choices, or with no line drawn, nothing. */
const numberedMenu = (state: PanelState, menu: Menu, n: number, drawn: PanelState): Stepped =>
  n <= menu.options.length && isMenuDrawn(drawn) ? chosen(state, menu, n - 1) : only(state)

/** What each key does with the menu open, its answer already dropped; any other does nothing, the loop's own aside. */
const MENU_KEY: { [K in Key['kind']]?: (state: PanelState, menu: Menu, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped } = {
  up: (state, menu) => only(pickedBy(state, menu, -1)),
  down: (state, menu) => only(pickedBy(state, menu, 1)),
  enter: (state, menu, _, drawn) => enteredMenu(state, menu, drawn),
  digit: (state, menu, { n }, drawn) => numberedMenu(state, menu, n, drawn),
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
  enter: state => only(lookedCloser(state)),
  open: opened,
  snooze: snoozing,
  tap: (state, key, drawn) => only(tapped(state, key, drawn)),
  wheel: (state, { by }) => only(settled({ ...state, top: layoutIn(state).top + by })),
  left: only,
  right: only,
  digit: only,
  quit: only,
  suspend: only,
}

type Asking = NonNullable<PanelState['opened']>

/** The asks closed. */
const closedAsks = (state: PanelState) => settled(withField(state, 'opened', undefined))

/** The ask at `index` among the row's shown, within its first and its last, the asks kept whole in sight. */
const shownAt = (state: PanelState, opened: Asking, index: number): PanelState => {
  const asks = askIdsOn(state, opened.row)
  const ask = asks[Math.min(Math.max(index, 0), asks.length - 1)]

  return ask === undefined ? state : settled(kept({ ...state, opened: { ...opened, ask } }))
}

/** The ask before or after the one shown, `by` -1 or 1. */
const pagedBy = (state: PanelState, opened: Asking, by: number) =>
  shownAt(state, opened, askIdsOn(state, opened.row).indexOf(opened.ask) + by)

/** The line of the opened row a tap at terminal row `y` lands on, as `drawn` lays it out; none off it. */
const openedLineAt = (drawn: PanelState, placed: Extract<Placed, { kind: 'row' }>, y: number) => {
  const opened = openedIn(viewIn(drawn), placed.row)

  return opened === undefined ? undefined : asksLinesOf(opened, layoutIn(drawn).width, placed.lane, placed.height)[y - placed.y]
}

/** A tap with a row's asks open, found where they stood as `drawn`: on a page dot, its ask shown; on the ask, nothing yet; anywhere else, the asks closed and nothing more. */
const tappedAsks = (state: PanelState, opened: Asking, { x, y }: Tap, drawn: PanelState): PanelState => {
  const layout = layoutIn(drawn)
  const placed = layout.placed.find(each => each.kind === 'row' && each.key === opened.row)
  const line = placed?.kind === 'row' && x < layout.width ? openedLineAt(drawn, placed, y) : undefined

  if (line === undefined || isHeadLine(line)) {
    return closedAsks(state)
  }

  const dot = line.part === 'asked' ? dotAt(line.dots, x) : undefined

  return dot === undefined ? state : shownAt(state, opened, dot)
}

/** The band moved as `onKey` moves it, the asks closed first. */
const closing =
  <K extends Key['kind']>(onKey: (state: PanelState, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped) =>
  (state: PanelState, _: Asking, key: Extract<Key, { kind: K }>, drawn: PanelState) =>
    onKey(closedAsks(state), key, drawn)

/** What each key does with a row's asks open, its answer already dropped; any other does nothing, the loop's own aside. */
const ASKS_KEY: { [K in Key['kind']]?: (state: PanelState, opened: Asking, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped } = {
  up: closing(ON_KEY.up),
  down: closing(ON_KEY.down),
  pageUp: closing(ON_KEY.pageUp),
  pageDown: closing(ON_KEY.pageDown),
  home: closing(ON_KEY.home),
  end: closing(ON_KEY.end),
  enter: state => only(closedAsks(state)),
  esc: state => only(closedAsks(state)),
  left: (state, opened) => only(pagedBy(state, opened, -1)),
  right: (state, opened) => only(pagedBy(state, opened, 1)),
  tap: (state, opened, key, drawn) => only(tappedAsks(state, opened, key, drawn)),
  open: state => opened(state),
  wheel: (state, _, key, drawn) => ON_KEY.wheel(state, key, drawn),
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

  if (drawn.opened !== undefined) {
    const onAsks = ASKS_KEY[key.kind] as ((state: PanelState, opened: Asking, key: Key, drawn: PanelState) => Stepped) | undefined

    return onAsks === undefined ? only(state) : onAsks(state, drawn.opened, key, drawn)
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
    return only(failed(state, event))
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
