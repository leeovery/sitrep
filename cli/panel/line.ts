/**
 * A row on one line, as the notch draws it (Lee, 26 November 2026): its
 * words from the names' column, its project in grey at their right, and its
 * time in its section's lane, ending at column W−2. No pens: draw.ts draws
 * what this fits.
 *
 * - The words: a row of asks, and any row in Snoozed, says the session's
 *   name, then its count where more than one line waits; any other, its
 *   status line. The count is never cut.
 * - The project ends 2 columns before the time's lane, so a section's
 *   projects stand right-aligned in a column, 2 columns after the words at
 *   the least.
 * - The time's lane is its section's widest time, 3 columns at the least.
 * - As the width falls: the words are cut down to 12 cells; then the
 *   project is cut with `…` down to 4 cells, then goes; then a Snoozed wake
 *   loses its clock, where that narrows the lane; then the words are cut to
 *   6; then the time goes. The clocks and the times give way a section at a
 *   time, so a section's times keep one lane; its projects go with its
 *   times, so none comes back in the room the times leave.
 */
import { cut, widthOf } from './cells'
import type { PanelRow } from './view'

/** The column of a row's words, and of an expanded row's lines. */
export const NAME = 3

/** The fewest cells a name or a status line is cut to. */
export const LEAST_CUT = 6

/** The columns between the words and the project, and between the project and the time's lane. */
const GAP = 2

/** The least lane a time takes: an age's, `now`, `4m`, `26m`. */
const LANE = 3

/** The words keep this much before the project gives way. */
const WORDS_LEAST = 12

/** A project cut shorter than this goes. */
const PROJECT_LEAST = 4

/** How a section's times stand: whole; its Snoozed wakes without their clocks; or gone. */
type Times = 'whole' | 'clockless' | 'none'

/** A way the times may stand, and the least it leaves each row's words, where the words are wider. */
type Stage = { times: Exclude<Times, 'none'>; least: number }

/** A section's times as they stand at a width: the lane they take, none once they've gone, each row's, and whether its projects still show. */
export type Lane = { cells: number; timeOf: (row: PanelRow) => string; hasProjects: boolean }

/** What a row on one line shows, each part fitted: the words, then the count after them uncut, the project and the column it ends at, exclusive, and the time. */
export type Fitted = { words: string; count: string; project: string; projectEnd: number; time: string }

/** A Snoozed wake without its clock, `tomorrow` for `tomorrow 09:00`; none for a bare clock. */
export const withoutClock = (time: string) => /^(.+) \d{1,2}:\d{2}$/.exec(time)?.[1]

/** The count a row of several lines shows after its name, ` 3`; none for one. */
export const countOf = (row: PanelRow) => (row.count !== undefined && row.count > 1 ? ` ${row.count}` : '')

/** The row's words, and the count after them that is never cut: its name and count, a row of asks or one in Snoozed; else its status line. */
const sayingOf = (row: PanelRow) =>
  row.isSnoozed || row.mark === 'ask' ? { text: row.name, count: countOf(row) } : { text: row.status.text, count: '' }

const naturalOf = (row: PanelRow) => {
  const { text, count } = sayingOf(row)

  return widthOf(text) + widthOf(count)
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
const fits = (rows: readonly PanelRow[], width: number, { times, least }: Stage) => {
  const room = projectEndOf(width, laneIn(rows, times)) - NAME

  return rows.every(row => room >= Math.min(naturalOf(row), least))
}

/**
 * The ways a section's times stand, widest first: whole, its words keeping
 * 12 cells; then, its words keeping 6, its wakes without their clocks where
 * that narrows its lane, else whole still. A lane its widest time sets with
 * no clock, as `until it moves`, keeps its clocks.
 */
const stagesOf = (rows: readonly PanelRow[]): Stage[] => {
  const isNarrower = laneIn(rows, 'clockless') < laneIn(rows, 'whole')

  return [
    { times: 'whole', least: WORDS_LEAST },
    { times: isNarrower ? 'clockless' : 'whole', least: LEAST_CUT },
  ]
}

/** A section's times at the layout's width: the widest way that leaves every row its words' least, else none. */
export const laneOf = (rows: readonly PanelRow[], width: number): Lane => {
  const times = stagesOf(rows).find(stage => fits(rows, width, stage))?.times ?? 'none'

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
  const { text, count } = sayingOf(row)
  const projectEnd = projectEndOf(width, lane.cells)
  const room = projectEnd - NAME - GAP
  const project = lane.hasProjects ? projectIn(row.project, room - Math.min(naturalOf(row), WORDS_LEAST)) : ''
  const wordsRoom = project === '' ? projectEnd - NAME : room - widthOf(project)

  return { words: cut(text, wordsRoom - widthOf(count)), count, project, projectEnd, time: lane.timeOf(row) }
}
