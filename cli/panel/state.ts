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
 *   them.
 * - A tap puts the band on the row under it, and opens the band's own row,
 *   as ⏎ does; the wheel scrolls a row a notch, the band staying on its
 *   session, in sight or not.
 * - `top` is kept as the layout clamps it, so scrolling past the end piles
 *   nothing up.
 * - Each line new to Needs you is stamped with the time of the board it
 *   came on, and dropped once NEW_MS old.
 * - `q`, Ctrl-C and Ctrl-Z are the loop's: they change nothing else here.
 */
import type { Feed } from '../../core'
import type { Size } from './cells'
import type { Key } from './keys'
import { layoutOf, topFor } from './layout'
import { NEW_MS, rowKey, viewOf, type PanelRow, type ViewState } from './view'

export type PanelState = ViewState & {
  /** The board last read; none before the first. */
  feed?: Feed
  size: Size
  /** The sessions on the board no terminal on this Mac shows. */
  notHere: ReadonlySet<string>
  /** The latest time an event brought. */
  now: number
}

/** A look's board: the lines new to Needs you on it, and when it was read. */
type Board = { board: Feed; news: readonly string[]; now: number }

export type PanelEvent =
  | Board
  /** A look that failed, and why. */
  | { failed: string }
  | { key: Key }
  | { size: Size }
  /** The clock, moved on. */
  | { tick: number }

/** A step's state, and the session to open, where ⏎ or a tap asks for one. */
export type Stepped = { state: PanelState; open?: string }

type Tap = Extract<Key, { kind: 'tap' }>

/** The panel's state before any board: Snoozed folded, no band, the board looked for. */
export const opening = (size: Size, now: number, notHere: ReadonlySet<string> = new Set()): PanelState => ({
  top: 0,
  isSnoozedOpen: false,
  board: 'looking',
  arrivals: new Map(),
  size,
  notHere,
  now,
})

const viewIn = (state: PanelState) => viewOf(state.feed, state, state.now, state.notHere)

const layoutIn = (state: PanelState) => layoutOf(viewIn(state), state.size)

/** The rows of the open sections, in order: those the band moves across and `top` counts. */
const rowsIn = (state: PanelState): PanelRow[] =>
  viewIn(state)
    .sections.filter(section => section.isOpen)
    .flatMap(section => section.rows)

const keysIn = (state: PanelState) => rowsIn(state).map(rowKey)

/** The state with `field` set, or without it, given none. */
const withField = <K extends 'band' | 'answer' | 'reason'>(state: PanelState, field: K, value: PanelState[K]): PanelState => {
  const next = { ...state }

  delete next[field]

  return value === undefined ? next : { ...next, [field]: value }
}

/** The state with `top` as the layout clamps it. */
const settled = (state: PanelState): PanelState => ({ ...state, top: layoutIn(state).top })

/** Whether the band's row is whole in view, or nothing is in view to scroll it out of; true with no band. */
const isBandInSight = (state: PanelState) => {
  const { rows } = layoutIn(state)

  return state.band === undefined || rows.length === 0 || rows.some(row => row.key === state.band)
}

/** The view moved the least that keeps the band's row whole in sight. */
const kept = (state: PanelState): PanelState => {
  const top = state.band === undefined ? undefined : topFor(viewIn(state), state.size, state.band)

  return top === undefined ? state : { ...state, top }
}

/** `after`, the band kept in sight where it was in sight `before`. */
const keepingSight = (before: PanelState, after: PanelState) => (isBandInSight(before) ? kept(after) : after)

/** The band on the row `key`, kept whole in sight; the state as it was, given no row. */
const placed = (state: PanelState, key: string | undefined) =>
  key === undefined ? state : settled(kept(withField(state, 'band', key)))

/**
 * Where the band goes as the rows change from `before` to `after`: to its
 * row; else to a row of its session; else to the row now in its place;
 * else to the row above. None with no rows left.
 */
const followed = (before: PanelState, after: PanelState): string | undefined => {
  if (before.band === undefined) {
    return undefined
  }

  const was = rowsIn(before)
  const rows = rowsIn(after)
  const at = was.findIndex(row => rowKey(row) === before.band)
  const session = was[at]?.session
  const row =
    rows.find(each => rowKey(each) === before.band) ??
    rows.find(each => each.session === session) ??
    rows[Math.min(Math.max(at, 0), rows.length - 1)]

  return row === undefined ? undefined : rowKey(row)
}

/** Each line new on the board stamped `now`, and those first shown NEW_MS ago or more dropped. */
const arrived = (arrivals: ViewState['arrivals'], news: readonly string[], now: number) =>
  new Map([...arrivals, ...news.map(key => [key, now] as const)].filter(([, at]) => now - at < NEW_MS))

const boarded = (state: PanelState, { board, news, now }: Board): PanelState => {
  const read: PanelState = {
    ...withField(state, 'reason', undefined),
    feed: board,
    board: 'read',
    readAt: now,
    now,
    arrivals: arrived(state.arrivals, news, now),
  }

  return settled(keepingSight(state, withField(read, 'band', followed(state, read))))
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
    return settled(keepingSight(state, withField(next, 'band', followed(state, next))))
  }

  if (state.band !== undefined) {
    return settled(keepingSight(state, next))
  }

  return settled({ ...next, top: topFor(viewIn(next), next.size, rowKey(last)) ?? next.top })
}

/** ⏎: the band's session to open, if there's a band. */
const opened = (state: PanelState): Stepped => {
  const session = rowsIn(state).find(row => rowKey(row) === state.band)?.session

  return session === undefined ? { state } : { state, open: session }
}

/** A tap on a row in view, on either of its lines: the band put on it, or, on the band's own row, opened. */
const tapped = (state: PanelState, { x, y }: Tap): Stepped => {
  const layout = layoutIn(state)
  const row = x < layout.width ? layout.rows.find(each => y === each.y || y === each.y + 1) : undefined

  if (row === undefined) {
    return { state }
  }

  return row.key === state.band ? opened(state) : { state: placed(state, row.key) }
}

const only = (state: PanelState): Stepped => ({ state })

/** What each key does to the state, its answer already dropped. */
const ON_KEY: { [K in Key['kind']]: (state: PanelState, key: Extract<Key, { kind: K }>) => Stepped } = {
  up: state => only(movedBy(state, -1)),
  down: state => only(movedBy(state, 1)),
  pageUp: state => only(movedBy(state, -pageOf(state))),
  pageDown: state => only(movedBy(state, pageOf(state))),
  home: state => only(placed(state, keysIn(state)[0])),
  end: state => only(placed(state, keysIn(state).at(-1))),
  snoozed: state => only(toggled(state)),
  esc: state => only(settled(withField(state, 'band', undefined))),
  enter: opened,
  tap: tapped,
  wheel: (state, { by }) => only(settled({ ...state, top: layoutIn(state).top + by })),
  quit: only,
  suspend: only,
}

const pressed = (state: PanelState, key: Key): Stepped => {
  const onKey = ON_KEY[key.kind] as (state: PanelState, key: Key) => Stepped

  return onKey(withField(state, 'answer', undefined), key)
}

/** The panel's state after the event, and the session it asks to open, if any. */
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

  return only({ ...state, now: event.tick, arrivals: arrived(state.arrivals, [], event.tick) })
}
