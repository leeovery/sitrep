/**
 * A row on one line, as the notch draws it (Lee, 26 November 2026): its
 * words from the names' column, its project in grey at their right, and its
 * time in its section's lane, ending at column W−2. No pens: draw.ts draws
 * what this fits.
 *
 * - The words: a row of asks, and any row in Snoozed, says the session's
 *   name, then its count where more than one line waits; any other, its
 *   status line, a question's `+2` after it. The count and the `+2` are
 *   never cut.
 * - The project ends 2 columns before the time's lane, so a section's
 *   projects stand right-aligned in a column, 2 columns after the words at
 *   the least.
 * - The time's lane is its section's widest time, 3 columns at the least.
 * - As the width falls: the words are cut down to 12 cells; then the
 *   project is cut with `…` down to 4 cells, then goes; then a Snoozed wake
 *   loses its clock; then the words are cut to 6; then the time goes. The
 *   clocks and the times give way a section at a time, so a section's
 *   times keep one lane; its projects go with its times, so none comes
 *   back in the room the times leave.
 */
import { cut, widthOf } from './cells'
import { countOf, LEAST_CUT, NAME, withoutClock } from './expand'
import type { PanelRow } from './view'

/** The columns between the words and the project, and between the project and the time's lane. */
const GAP = 2

/** The least lane a time takes: an age's, `now`, `4m`, `26m`. */
const LANE = 3

/** The words keep this much before the project gives way. */
const WORDS_LEAST = 12

/** A project cut shorter than this goes. */
const PROJECT_LEAST = 4

/** How a section's times stand, from the widest: whole; its Snoozed wakes without their clocks; or gone. */
type Times = 'whole' | 'clockless' | 'none'

/** The least each way of a section's times leaves a row's words, where the words are wider. */
const LEAST: Record<Exclude<Times, 'none'>, number> = { whole: WORDS_LEAST, clockless: LEAST_CUT }

/** A section's times as they stand at a width: the lane they take, none once they've gone, each row's, and whether its projects still show. */
export type Lane = { cells: number; timeOf: (row: PanelRow) => string; hasProjects: boolean }

/** What a row on one line shows, each part fitted: the words, then what follows them uncut, the project and the column it ends at, exclusive, and the time. */
export type Fitted = { words: string; after: string; project: string; projectEnd: number; time: string }

/** Whether the row says its session's name: a row of asks, or any row in Snoozed. */
const isNamed = (row: PanelRow) => row.isSnoozed || row.mark === 'ask'

/** The row's words, and what follows them that is never cut: its name and count, or its status line and a question's `+2`. */
const wordsOf = (row: PanelRow) =>
  isNamed(row)
    ? { text: row.name, after: countOf(row) }
    : { text: row.status.text, after: row.status.more === undefined ? '' : ` +${row.status.more}` }

const naturalOf = (row: PanelRow) => {
  const { text, after } = wordsOf(row)

  return widthOf(text) + widthOf(after)
}

const timeIn = (row: PanelRow, times: Times) => {
  if (times === 'none') {
    return ''
  }

  return times === 'clockless' && row.isSnoozed ? (withoutClock(row.time) ?? row.time) : row.time
}

/** The column the project ends at, exclusive: 2 before the time's lane, or the layout's last where the times have gone. */
const projectEndOf = (width: number, lane: number) => width - 1 - (lane === 0 ? 0 : lane + GAP)

const laneIn = (rows: readonly PanelRow[], times: Times) =>
  times === 'none' ? 0 : Math.max(LANE, ...rows.map(row => widthOf(timeIn(row, times))))

/** Whether every row keeps its least with the times standing so, its project gone. */
const fits = (rows: readonly PanelRow[], width: number, times: Exclude<Times, 'none'>) => {
  const room = projectEndOf(width, laneIn(rows, times)) - NAME

  return rows.every(row => room >= Math.min(naturalOf(row), LEAST[times]))
}

/** A section's times at the layout's width: the widest way that leaves every row its words' least. */
export const laneOf = (rows: readonly PanelRow[], width: number): Lane => {
  const times = (['whole', 'clockless'] as const).find(each => fits(rows, width, each)) ?? 'none'

  return { cells: laneIn(rows, times), timeOf: row => timeIn(row, times), hasProjects: times !== 'none' }
}

/** The project in the room the words leave it: whole, else cut to 4 cells at the least, else gone. */
const projectIn = (project: string, room: number) => {
  if (widthOf(project) <= room) {
    return project
  }

  return room >= PROJECT_LEAST ? cut(project, room) : ''
}

/** The row on one line at the layout's width, in its section's lane. */
export const fittedOf = (row: PanelRow, width: number, lane: Lane): Fitted => {
  const { text, after } = wordsOf(row)
  const projectEnd = projectEndOf(width, lane.cells)
  const room = projectEnd - NAME - GAP
  const project = lane.hasProjects ? projectIn(row.project, room - Math.min(naturalOf(row), WORDS_LEAST)) : ''
  const wordsRoom = project === '' ? projectEnd - NAME : room - widthOf(project)

  return { words: cut(text, wordsRoom - widthOf(after)), after, project, projectEnd, time: lane.timeOf(row) }
}
