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
 *   `until it moves`; elsewhere, how long its newest line has stood, as
 *   `ago` gives it.
 * - A row is new for two seconds from the first view that showed a line of
 *   it new to Needs you.
 */
import {
  ago,
  oneLine,
  panelSections,
  wakeWords,
  type Feed,
  type PanelSection,
  type Row,
  type RowLine,
  type SnoozedRow,
} from '../../core'

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
  time: string
}

export type PanelView = {
  sections: {
    kind: PanelSection['kind']
    counts: PanelSection['counts']
    rows: PanelRow[]
    isOpen: boolean
  }[]
  band?: string
  top: number
  answer?: string
  board: 'looking' | 'read' | 'stale'
}

/** What the view reads of the panel's state. */
export type ViewState = {
  /** The chosen row's session. */
  band?: string
  /** The body's first row in view. */
  top: number
  isSnoozedOpen: boolean
  /** A pick's answer. */
  answer?: string
  board: PanelView['board']
  /** When each line new to Needs you was first shown, by its key. */
  arrivals: ReadonlyMap<string, number>
}

/** How long a line new to Needs you stays new from its first showing. */
export const NEW_MS = 2_000

const MIN = 60_000

/** Shown text: its control characters dropped, then on one line. */
export const shown = (text: string) => oneLine(text.replace(/(?!\s)\p{Cc}/gu, ''))

/**
 * A time in ms in its largest whole unit, rounded down as the app's `Age`
 * rounds: `12m`, `2h`, `3d`. Not `ago`, which rounds to the nearest: 90
 * minutes to go reads `in 1h` in the app.
 */
const wholeUnits = (ms: number) => {
  const minutes = Math.floor(ms / MIN)
  const hours = Math.floor(minutes / 60)

  return minutes < 60 ? `${minutes}m` : hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`
}

/** A wake's countdown, as the app's `untilText` words it: up to the whole minute, `in 12m`; `now` once due. */
export const countdown = (until: number, now: number) =>
  until <= now ? 'now' : `in ${wholeUnits(Math.ceil((until - now) / MIN) * MIN)}`

/** A question's `+2`, as core words it, as its number. */
const moreOf = (more: string | undefined) => (more === undefined ? undefined : Number(more.slice(1)))

const statusOf = (line: RowLine, isPermission: boolean, now: number): StatusWords => {
  const after = [line.mono, line.until === undefined ? line.subject : countdown(line.until, now)]
    .filter(part => part !== undefined)
    .map(shown)
    .filter(part => part !== '')
    .join(' ')
  const lead = shown(line.lead)
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

const rowOf = (row: Row | SnoozedRow, arrivals: ViewState['arrivals'], now: number): PanelRow => {
  const [first] = row.lines

  return {
    session: row.session,
    mark: markOf(row),
    isAway: row.isAway,
    isSnoozed: isSnoozedRow(row),
    isNew: isNewAt(row, arrivals, now),
    name: shown(row.name),
    ...(row.lines.length > 1 ? { count: row.lines.length } : {}),
    project: shown(row.projectName),
    status:
      first === undefined
        ? { text: '' }
        : statusOf(first.first, first.is === 'permission', now),
    time: timeOf(row, now),
  }
}

/** The board in the panel's words at `now`, the sessions in `notHere` drawn away. */
export const viewOf = (
  feed: Feed,
  state: ViewState,
  now: number,
  notHere: ReadonlySet<string>,
): PanelView => ({
  sections: panelSections(feed, notHere).map(({ kind, counts, rows }) => ({
    kind,
    counts,
    rows: rows.map(row => rowOf(row, state.arrivals, now)),
    isOpen: kind !== 'snoozed' || state.isSnoozedOpen,
  })),
  ...(state.band === undefined ? {} : { band: state.band }),
  top: state.top,
  ...(state.answer === undefined ? {} : { answer: state.answer }),
  board: state.board,
})
