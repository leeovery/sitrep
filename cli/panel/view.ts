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
 * - A Needs you row carries the asks the view answers (core's
 *   `answerableAsks`), each with the answers its digits send: a yes its
 *   yes; a choice its options, Claude's pick first; a words ask none. Each
 *   is aged as its line on the row is.
 * - The band's row's asks, open under it, say which is shown, and whether
 *   Snooze offers a time for it, as the row's snooze menu decides.
 * - An answer sending says its ask and its answer, and its ring, which
 *   fills a quarter each half second of its two: `◔` `◑` `◕` `●`.
 * - An ask whose answer has gone leaves its row's asks at once, until the
 *   board no longer lists it or the command refuses the answer.
 */
import {
  ago,
  answerableAsks,
  clockOf,
  inUnits,
  oneLine,
  panelSections,
  pickFirst,
  SNOOZE_DEFAULTS,
  snoozeChoicesAt,
  wakeWords,
  yesOf,
  type Ask,
  type Feed,
  type PanelSection,
  type Row,
  type RowAsk,
  type RowLine,
  type SnoozedRow,
  type SnoozeSettings,
  type Wants,
} from '../../core'
import type { Menu } from './menu'

/** A status line: its words joined, and a question's extra count, which the renderer draws apart. */
export type StatusWords = { text: string; more?: number }

/** A board ask the view answers, in its words: what it wants, the answers its digits send, in their order, Claude's pick among them, and how long its line has stood, as the row's time reads. */
export type PanelAsk = {
  id: string
  title: string
  wants: Wants
  /** A yes its yes; a choice its options, Claude's pick first; none for a words ask, or a choice with no options. */
  answers: string[]
  /** Each answer as its digit sends it, in the same order: the board's own words, uncleaned, as `sitrep answer` takes them. */
  sends: string[]
  /** Claude's pick, a choice's, first among its answers. */
  pick?: string
  age: string
}

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
  /** The asks the view answers, in the row's order, newest first; absent where it has none. */
  answerable?: PanelAsk[]
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
  /** The chosen row's asks, open under it: the row's key, the ask shown by its place among them, and whether Snooze offers a time. */
  asking?: { row: string; at: number; offersSnooze: boolean }
  /** The answer sending: its row's key, its ask, the answer by its place and its words, none for an ignore, and its ring as it stands. */
  sending?: { row: string; ask: string; answer?: { index: number; words: string }; ring: string }
  top: number
  answer?: string
  board: 'looking' | 'read' | 'stale'
  asOf?: string
  reason?: string
}

/**
 * An answer held for its two seconds before it goes, on the asks of the row
 * `row`: its session and ask, what the ask wanted as shown, and the answer
 * by its place among the ask's, its words as shown and as it sends them,
 * none for an ignore; and when it was held.
 */
export type Sending = {
  row: string
  session: string
  ask: string
  wants: Wants
  answer?: { index: number; words: string; sends: string }
  at: number
}

/** What the view reads of the panel's state. */
export type ViewState = {
  /** The chosen row, by its key (`rowKey`). */
  band?: string
  /** The chosen row's key, while it is expanded: never another row's. */
  expanded?: string
  /** The snooze menu, open under the chosen row: never another row's. */
  menu?: Menu
  /** The chosen row's asks, open under it, by its key, at the ask shown, by its id: never another row's. */
  asking?: { row: string; ask: string }
  /** The answer held, sending. */
  sending?: Sending
  /** The asks whose answers have gone, by `askKey`, left out of their rows' asks. */
  sent?: ReadonlySet<string>
  /** Snooze's choices as Lee set them in SitRep; core's defaults where none were read. */
  snoozeSettings?: SnoozeSettings
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

/** How long an answer is held before it goes. */
export const SEND_MS = 2_000

/** The ring an answer sending shows, a quarter more of it filled each part of its hold. */
const RING = ['◔', '◑', '◕', '●'] as const

/** How long each of the ring's quarters stands. */
export const RING_MS = SEND_MS / RING.length

/** An ask's key among every session's: its session, then its id. */
export const askKey = (session: string, ask: string) => `${session}/${ask}`

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

/** What an ask's digits send: a yes its yes; a choice its options, Claude's pick first; none for words. */
const sendsOf = (ask: Ask): string[] => {
  switch (ask.wants) {
    case 'yes':
      return [yesOf(ask)]
    case 'choice':
      return [...pickFirst(ask.options ?? [], ask.recommended)]
    case 'words':
      return []
  }
}

/** An ask's answers as it sends them and as they read, and Claude's pick, a choice's, first among them. */
const answersOf = (ask: Ask): Pick<PanelAsk, 'answers' | 'sends' | 'pick'> => {
  const { options = [], recommended } = ask
  const sends = sendsOf(ask)
  const pick = ask.wants === 'choice' && recommended !== undefined && options.includes(recommended) ? recommended : undefined

  return { answers: sends.map(cleaned), sends, ...(pick === undefined ? {} : { pick: cleaned(pick) }) }
}

const askOf = ({ ask, since }: RowAsk, now: number): PanelAsk => ({
  id: ask.id,
  title: cleaned(ask.title),
  wants: ask.wants,
  ...answersOf(ask),
  age: ago(now, since),
})

/** What the view adds to a row of the board's: the asks it answers, where it has any. */
type Answerable = ReadonlyMap<string, RowAsk[]>

/** The asks the view answers on the row, those whose answers have gone left out; none where none is left. */
const answerableOf = (row: Row | SnoozedRow, answerable: Answerable, sent: ReadonlySet<string>, now: number) => {
  const asks = (isSnoozedRow(row) ? undefined : answerable.get(row.session))?.filter(each => !sent.has(askKey(row.session, each.ask.id)))

  return asks === undefined || asks.length === 0 ? {} : { answerable: asks.map(each => askOf(each, now)) }
}

const rowOf = (row: Row | SnoozedRow, { arrivals, sent = new Set() }: ViewState, answerable: Answerable, now: number): PanelRow => {
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
    ...answerableOf(row, answerable, sent, now),
  }
}

const sectionsOf = (
  feed: Feed | undefined,
  state: ViewState,
  now: number,
  notHere: ReadonlySet<string>,
): PanelView['sections'] => {
  if (feed === undefined) {
    return []
  }

  const answerable = answerableAsks(feed)

  return panelSections(feed, notHere).map(({ kind, counts, rows }) => ({
    kind,
    counts,
    rows: rows.map(row => rowOf(row, state, answerable, now)),
    isOpen: kind !== 'snoozed' || state.isSnoozedOpen,
  }))
}

/** The asks open under the chosen row, the one shown by its place; none where the state's ask is not among the row's. */
const askingOf = (sections: PanelView['sections'], { asking, snoozeSettings = SNOOZE_DEFAULTS }: ViewState, now: number) => {
  const row = sections.flatMap(section => section.rows).find(each => rowKey(each) === asking?.row)
  const at = row?.answerable?.findIndex(ask => ask.id === asking?.ask) ?? -1

  return asking === undefined || at === -1
    ? {}
    : { asking: { row: asking.row, at, offersSnooze: snoozeChoicesAt(now, snoozeSettings).length > 0 } }
}

/** The answer sending, its ring as it stands at `now`: a quarter more filled each `RING_MS`, full for the last. */
const sendingOf = ({ sending }: ViewState, now: number) => {
  if (sending === undefined) {
    return {}
  }

  const { row, ask, answer, at } = sending
  const ring = RING[Math.min(Math.max(Math.floor((now - at) / RING_MS), 0), RING.length - 1)] ?? ''

  return { sending: { row, ask, ...(answer === undefined ? {} : { answer: { index: answer.index, words: answer.words } }), ring } }
}

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
  const sections = sectionsOf(feed, state, now, notHere)

  return {
    sections,
    ...(band === undefined ? {} : { band }),
    ...(expanded === undefined ? {} : { expanded }),
    ...(menu === undefined ? {} : { menu: { row: menu.row, options: menu.options, at: menu.at, top: menu.top } }),
    ...askingOf(sections, state, now),
    ...sendingOf(state, now),
    top,
    ...(answer === undefined ? {} : { answer: cleaned(answer) }),
    board,
    ...(board === 'stale' && readAt !== undefined ? { asOf: clockOf(new Date(readAt)) } : {}),
    ...(reason === undefined ? {} : { reason }),
  }
}
