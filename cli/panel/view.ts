/**
 * The board in the panel's words at an instant: each section with its
 * counts and whether it is open, and each row's mark, name, count, project,
 * status line and time, cleaned for a terminal. No drawing: draw.ts lays
 * this out at a size.
 *
 * - The status line is the row's first line: its lead, then what it acts
 *   on after a space, or after `: ` on a permission prompt; a wake counts
 *   down to its time, `Wakes in 12m`; a question's `+2` comes apart.
 * - The time: in Snoozed, when the row wakes, as `wakeWords` says it, or
 *   `until it moves`; elsewhere, how long its newest line has stood, in
 *   whole units rounded down, as the notch reads it.
 * - A row is new for two seconds from the first view that showed a line of
 *   it new to Needs you.
 * - A stale board says when it was last read, `12:04`; a board not read
 *   says why.
 * - A pick's answer is cleaned as the board's words are: it can carry a
 *   session's name, or the login shell's.
 */
import {
  ago,
  clockOf,
  inUnits,
  oneLine,
  panelSections,
  wakeWords,
  type Feed,
  type PanelSection,
  type Row,
  type RowLine,
  type SnoozedRow,
} from '../../core'
import type { Menu } from './menu'

/** A status line: its words joined, and a question's extra count, which the renderer draws apart. */
export type StatusWords = { text: string; more?: number }

export type PanelRow = {
  session: string
  mark: 'ask' | 'turn' | 'working' | 'onItsWork'
  isAway: boolean
  isSnoozed: boolean
  isNew: boolean
  name: string
  count?: number
  project: string
  status: StatusWords
  /** Each of its lines' words, its status line first: what the chosen row shows expanded. */
  lines: StatusWords[]
  time: string
  /** The asks a snooze of it names, those it shows, none on a turn's row; absent where it can't be snoozed: a row of a window's stops alone, a working one, or one in Snoozed, which wakes. */
  asks?: string[]
}

export type PanelView = {
  sections: {
    kind: PanelSection['kind']
    counts: PanelSection['counts']
    rows: PanelRow[]
    isOpen: boolean
  }[]
  band?: string
  /** The chosen row, expanded. */
  expanded?: string
  /** The snooze menu, open under the chosen row: its choices, the one picked, and the first drawn as the layout last kept it. */
  menu?: Pick<Menu, 'row' | 'options' | 'at' | 'top'>
  top: number
  answer?: string
  board: 'looking' | 'read' | 'stale'
  asOf?: string
  reason?: string
}

/** What the view reads of the panel's state. */
export type ViewState = {
  /** The chosen row, by its key (`rowKey`). */
  band?: string
  /** The chosen row's key, while it is expanded: never another row's. */
  expanded?: string
  /** The snooze menu, open under the chosen row: never another row's. */
  menu?: Menu
  /** The first row in view: its index over the rows of the open sections, in order, one a row, not a screen line. */
  top: number
  isSnoozedOpen: boolean
  /** A pick's answer. */
  answer?: string
  board: PanelView['board']
  /** When each line new to Needs you was first shown, by its key. */
  arrivals: ReadonlyMap<string, number>
  /** When the board was last read. */
  readAt?: number
  /** Why the board can't be read. */
  reason?: string
}

/** A row's key, apart from its session's row in another section: a session can have one in Snoozed too, as the app's `markID` says. */
export const rowKey = (row: PanelRow): string =>
  row.isSnoozed ? `snoozed:${row.session}` : row.session

/** How long a line new to Needs you stays new from its first showing. */
export const NEW_MS = 2_000

const MIN = 60_000

/** Text from the board made harmless: its control characters dropped, then on one line. */
export const cleaned = (text: string) => oneLine(text.replace(/(?!\s)\p{Cc}/gu, ''))

/** A wake's countdown, as the app's `untilText` words it: up to the whole minute, `in 12m`; `now` once due. */
export const countdown = (until: number, now: number) =>
  until <= now ? 'now' : `in ${inUnits(Math.ceil((until - now) / MIN))}`

/** A question's `+2`, as core words it, as its number. */
const moreOf = (more: string | undefined) => (more === undefined ? undefined : Number(more))

const statusOf = (line: RowLine, isPermission: boolean, now: number): StatusWords => {
  const after = [line.mono, line.until === undefined ? line.subject : countdown(line.until, now)]
    .filter(part => part !== undefined)
    .map(cleaned)
    .filter(part => part !== '')
    .join(' ')
  const lead = cleaned(line.lead)
  const text = after === '' ? lead : `${lead}${isPermission ? ': ' : ' '}${after}`
  const more = moreOf(line.more)

  return more === undefined ? { text } : { text, more }
}

const isSnoozedRow = (row: Row | SnoozedRow): row is SnoozedRow => !('section' in row)

const markOf = (row: Row | SnoozedRow): PanelRow['mark'] => {
  if (isSnoozedRow(row)) {
    return row.lines.every(line => line.is === 'yourTurn') ? 'turn' : 'ask'
  }

  switch (row.section) {
    case 'needsYou':
      return 'ask'
    case 'yourTurn':
      return 'turn'
    case 'working':
      return row.lines[0]?.is === 'onItsWork' ? 'onItsWork' : 'working'
  }
}

const timeOf = (row: Row | SnoozedRow, now: number) => {
  if (!isSnoozedRow(row)) {
    return ago(now, row.since)
  }

  return row.wakesAt === undefined ? 'until it moves' : wakeWords(row.wakesAt, now)
}

/** Whether a row holds a line new to Needs you, first shown under NEW_MS ago; a Snoozed row, though it shares an ask's key, never does. */
const isNewAt = (row: Row | SnoozedRow, arrivals: ViewState['arrivals'], now: number) =>
  !isSnoozedRow(row) &&
  row.lines.some(line => {
    const shownAt = arrivals.get(line.key)

    return shownAt !== undefined && now - shownAt < NEW_MS
  })

/** The asks a snooze of the row names, those it shows, none on a turn's row; none at all where the notch offers no Snooze: a row of a window's stops alone, a working one, or one in Snoozed, which wakes. */
const asksOf = (row: Row | SnoozedRow) => {
  if (isSnoozedRow(row) || row.section === 'working') {
    return {}
  }

  const asks = row.lines.flatMap(line => (line.ask === undefined ? [] : [line.ask]))

  return row.section === 'yourTurn' || asks.length > 0 ? { asks } : {}
}

const rowOf = (row: Row | SnoozedRow, arrivals: ViewState['arrivals'], now: number): PanelRow => {
  const lines = row.lines.map(line => statusOf(line.first, line.is === 'permission', now))

  return {
    session: row.session,
    mark: markOf(row),
    isAway: row.isAway,
    isSnoozed: isSnoozedRow(row),
    isNew: isNewAt(row, arrivals, now),
    name: cleaned(row.name),
    ...(row.lines.length > 1 ? { count: row.lines.length } : {}),
    project: cleaned(row.projectName),
    status: lines[0] ?? { text: '' },
    lines,
    time: timeOf(row, now),
    ...asksOf(row),
  }
}

const sectionsOf = (
  feed: Feed | undefined,
  state: ViewState,
  now: number,
  notHere: ReadonlySet<string>,
): PanelView['sections'] =>
  feed === undefined
    ? []
    : panelSections(feed, notHere).map(({ kind, counts, rows }) => ({
        kind,
        counts,
        rows: rows.map(row => rowOf(row, state.arrivals, now)),
        isOpen: kind !== 'snoozed' || state.isSnoozedOpen,
      }))

/**
 * The board in the panel's words at `now`, the sessions in `notHere` drawn
 * away; no sections before any board is read. A stale one says when it was
 * last read.
 */
export const viewOf = (
  feed: Feed | undefined,
  state: ViewState,
  now: number,
  notHere: ReadonlySet<string>,
): PanelView => {
  const { band, expanded, menu, top, answer, board, readAt, reason } = state

  return {
    sections: sectionsOf(feed, state, now, notHere),
    ...(band === undefined ? {} : { band }),
    ...(expanded === undefined ? {} : { expanded }),
    ...(menu === undefined ? {} : { menu: { row: menu.row, options: menu.options, at: menu.at, top: menu.top } }),
    top,
    ...(answer === undefined ? {} : { answer: cleaned(answer) }),
    board,
    ...(board === 'stale' && readAt !== undefined ? { asOf: clockOf(new Date(readAt)) } : {}),
    ...(reason === undefined ? {} : { reason }),
  }
}
