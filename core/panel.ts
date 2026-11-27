/**
 * The board in the panel's sections, as the notch's card has them (the
 * app's `Sections.swift` and `PanelBoard.swift`): Needs you, Working, then
 * Snoozed, each with its counts, an empty one left out.
 *
 * - Needs you holds its asks, then its Stopped, each those drawn filled
 *   before the away ones, each part in core's order, newest first. A
 *   session in `notHere` is away, as one no window holds is: the app reads
 *   it as one this Mac's screen doesn't show, the terminal view as one open
 *   on no device it is looked at from. Core has it among those a window
 *   holds, so it leads the away ones.
 * - Working keeps core's order: working, then on its own work.
 * - Snoozed keeps core's order (`inSnoozedOrder`). A session there may have
 *   a row in another section too.
 *
 * Needs you counts its asks, the lines of its ask rows, and its Stopped,
 * its rows, apart, each only above zero. Working counts its rows; Snoozed
 * its lines, the asks asleep and the turns put off.
 *
 * The asks the panel answers are a Needs you row's board asks, as the
 * app's `PanelBoard.answerable` takes them: each of its lines that is an
 * ask, as the feed's projects list it, while it waits on Lee.
 */
import type { Feed } from './feed'
import { waitsOnLee } from './replies'
import { needsYou, type Row, type SnoozedRow } from './rows'
import type { Ask } from './types'

export type PanelSection = {
  kind: 'needsYou' | 'working' | 'snoozed'
  rows: (Row | SnoozedRow)[]
  counts: { value: number; need?: 'ask' | 'turn' }[]
}

type Count = PanelSection['counts'][number]

/** A row, away where its session is in `notHere`. */
const awayUnless =
  (notHere: ReadonlySet<string>) =>
  <T extends Row | SnoozedRow>(row: T): T =>
    !row.isAway && notHere.has(row.session) ? { ...row, isAway: true } : row

/** Those drawn filled, then the away ones, each in the order given. */
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

/** An ask the panel answers, and when its line on the row began, which its age counts from. */
export type RowAsk = { ask: Ask; since: number }

/**
 * The asks the panel answers, a yes, a choice or a words ask, by their
 * Needs you rows' sessions: each row's board asks waiting on Lee, in its
 * lines' order, newest first, each timed as its line is. None for a row of
 * Claude Code's own permission prompts and questions alone, nor for a
 * Stopped, working or Snoozed row.
 */
export const answerableAsks = (feed: Feed): ReadonlyMap<string, RowAsk[]> => {
  const open = new Map(feed.projects.flatMap(project => project.sessions).map(session => [session.id, session.asks]))
  const askedIn = (row: Row): RowAsk[] =>
    row.lines.flatMap(line => {
      const ask = line.ask === undefined ? undefined : open.get(row.session)?.find(each => each.id === line.ask)

      return ask !== undefined && waitsOnLee(ask) ? [{ ask, since: line.since }] : []
    })

  return new Map(
    feed.rows.filter(needsYou).flatMap(row => {
      const asks = askedIn(row)

      return asks.length === 0 ? [] : [[row.session, asks] as const]
    }),
  )
}
