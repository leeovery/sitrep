/**
 * The board in the panel's sections, as the notch's card has them (the
 * app's `Sections.swift` and `PanelBoard.swift`): Needs you, Working, then
 * Snoozed, each with its counts, an empty one left out.
 *
 * - Needs you holds its asks, then its Stopped, each those this Mac shows
 *   before the away ones, each part in core's order, newest first. A
 *   session this Mac doesn't show is away, as one no window holds is; core
 *   has it among those a window holds, so it leads the away ones.
 * - Working keeps core's order: working, then on its own work.
 * - Snoozed keeps core's order (`inSnoozedOrder`). A session there may have
 *   a row in another section too.
 *
 * Needs you counts its asks, the lines of its ask rows, and its Stopped,
 * its rows, apart, each only above zero. Working counts its rows; Snoozed
 * its lines, the asks asleep and the turns put off.
 */
import type { Feed } from './feed'
import type { Row, SnoozedRow } from './rows'

export type PanelSection = {
  kind: 'needsYou' | 'working' | 'snoozed'
  rows: (Row | SnoozedRow)[]
  counts: { value: number; need?: 'ask' | 'turn' }[]
}

type Count = PanelSection['counts'][number]

/** A row, away where this Mac doesn't show its session. */
const awayUnless =
  (notHere: ReadonlySet<string>) =>
  <T extends Row | SnoozedRow>(row: T): T =>
    !row.isAway && notHere.has(row.session) ? { ...row, isAway: true } : row

/** Those this Mac shows, then the away ones, each in the order given. */
const hereFirst = <T extends Row>(rows: readonly T[]) => [
  ...rows.filter(row => !row.isAway),
  ...rows.filter(row => row.isAway),
]

const linesIn = (rows: readonly (Row | SnoozedRow)[]) =>
  rows.reduce((count, row) => count + row.lines.length, 0)

const needsYouOf = (rows: readonly Row[]): PanelSection => {
  const asks = hereFirst(rows.filter(row => row.section === 'needsYou'))
  const stopped = hereFirst(rows.filter(row => row.section === 'yourTurn'))
  const counts: Count[] = [
    { value: linesIn(asks), need: 'ask' },
    { value: stopped.length, need: 'turn' },
  ]

  return {
    kind: 'needsYou',
    rows: [...asks, ...stopped],
    counts: counts.filter(count => count.value > 0),
  }
}

/** The board's sections at `feed`, the sessions in `notHere` drawn away. */
export const panelSections = (feed: Feed, notHere: ReadonlySet<string>): PanelSection[] => {
  const rows = feed.rows.map(awayUnless(notHere))
  const working = rows.filter(row => row.section === 'working')
  const snoozed = feed.snoozed.map(awayUnless(notHere))
  const sections: PanelSection[] = [
    needsYouOf(rows),
    { kind: 'working', rows: working, counts: [{ value: working.length }] },
    { kind: 'snoozed', rows: snoozed, counts: [{ value: linesIn(snoozed) }] },
  ]

  return sections.filter(section => section.rows.length > 0)
}
