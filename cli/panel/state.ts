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
 *   wheel and the loop's own keys work as ever; `s` does nothing. The asks
 *   are the band's row's: they close as the band moves to another row, or
 *   as the row has none left; an ask that leaves passes them to the next
 *   still on the board, else to the one before.
 * - On the asks, a digit, or a tap on an answer, holds that answer for
 *   SEND_MS, and `x`, or a tap on Ignore, the ask's ignore; a digit only
 *   while its answer is drawn, `x` only while a line of the ask is. While
 *   one is held no other is: digits and `x` do nothing. `u`, or a tap on
 *   `undo`, takes it back, writing nothing; every other key acts as ever,
 *   and it still goes, as the clock reaches its time, or at once on `q`,
 *   Ctrl-C or Ctrl-Z: its write asked for, its ask left out of its row's
 *   asks at once, the asks open on it stepping on as if the board had
 *   dropped it. A refusal brings the ask back, saying why. The asks left
 *   out come back once the board no longer lists them.
 * - A digit or `x` lands only once the ask shown has stood BEAT_MS since
 *   the board last changed it, by an ask leaving, an edit, or a send
 *   stepping on; the keys' own paging starts no beat.
 * - A tap on the ask lands only on a part that has stood BEAT_MS under it,
 *   as the frames drew it: the same answer of the same ask, as it reads,
 *   the same hint of it, or the dot of the same ask, drawn in that cell
 *   since. A row arriving or leaving above, a line rewrapping, the ask
 *   giving way, the ask changing, the sending line going: each starts the
 *   part's beat afresh where it moves what is under the tap. Paging leaves
 *   a dot standing, which shows the same ask whatever ask shows; a tap on
 *   `undo` never waits.
 * - `z` on the asks, or a tap on Snooze, opens the ask shown's snooze menu
 *   in the foot's place, while Snooze offers a time, a line of the ask is
 *   drawn, and the ask isn't the one sending: its times, and no Until it
 *   moves. A choice asks to snooze that ask alone; the menu closes as the
 *   ask shown changes.
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
 * - `q`, Ctrl-C, Ctrl-Z and `u` act in every mode, ahead of the menu's
 *   keys, the asks' and the board's: the first three send the answer held
 *   at once, and change nothing else here, leaving and suspending being
 *   the loop's; `u` takes it back. Each drops an answer, as any key does.
 * - A frame drawn moves the clock to when it was drawn, so the snooze
 *   times, the ages and the ring are worked out as it showed them.
 * - A pick done with nothing to say leaves the answer as it stands, so a
 *   refusal that came while Claude had the terminal still says why.
 */
import { answerableAsks, SNOOZE_DEFAULTS, type Feed, type SnoozeSettings, type Wants } from '../../core'
import type { Size } from './cells'
import type { Key, Press } from './keys'
import { askingIn, asksLinesOf, isAnswerDrawn, isHeadLine, tapOn, type Asking, type AsksLine, type AsksTap } from './asks'
import { layoutOf, topFor } from './layout'
import { snoozeOptions, snoozeTimes, type Menu } from './menu'
import { askKey, NEW_MS, rowKey, SEND_MS, viewOf, type HeldAnswer, type PanelAsk, type PanelRow, type ViewState } from './view'

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
  /** When the board last changed the ask shown, the asks open: a digit or `x` lands only BEAT_MS on. */
  changedAt?: number
  /** What a tap lands on in each cell of the opened row's lines as the frames drew them, and since when. */
  stood?: Standing
}

/** How long the ask shown stands, once the board changes it, before a digit or `x` lands on it; and a part of it, once drawn where a tap finds it, before the tap lands. */
export const BEAT_MS = 300

/** What a tap on a cell of the opened row's lines lands on, as one string, `''` for nothing; and since when the frames have drawn it there. */
type Stood = { part: string; since: number }

/** Each cell of the opened row's lines as last drawn, by terminal row, then column. */
type Standing = ReadonlyMap<number, readonly Stood[]>

/**
 * A look's board: the lines new to Needs you on it, when it was read, when
 * it was stepped in, where that was later, which the beat counts from, and
 * the sessions open on no device the panel is looked at from as SitRep
 * said them then, where the look read them, stepped with the board so the
 * band follows its row from where it was drawn.
 */
type Board = { board: Feed; news: readonly string[]; now: number; at?: number; notHere?: ReadonlySet<string> }

export type PanelEvent =
  | Board
  /** A look that failed, why, and when, so the menu's times are worked out from now on a stale board too. */
  | { failed: string; now: number }
  /** A key, and when it was pressed, where the loop says; else at the latest time an event brought. */
  | { key: Key; at?: number }
  | { size: Size }
  /** The clock, moved on: the answer held goes once its time has come. */
  | { tick: number }
  /** A frame drawn, and when: the clock moved to then, and what a tap lands on in each cell of it standing from then where it is new there. */
  | { drawn: number }
  /** A pick done: what it leaves to say, if anything. */
  | { opened: string | undefined }
  /** A write done: why it failed, if it did, and what it was. */
  | { written: string | undefined; write?: Write }
  /** The sessions open on no device the panel is looked at from, as SitRep last read them. */
  | { notHere: ReadonlySet<string> }
  /** Snooze's choices, as a look read them. */
  | { snoozeSettings: SnoozeSettings }

/**
 * A line to write, as `sitrep snooze`, `sitrep wake` or `sitrep answer`
 * writes it: a session snoozed, naming the asks its row showed, until a
 * time or until it moves; or woken; an ask answered in the words the
 * command takes, or ignored, either with what it wanted as shown; or one
 * ask snoozed alone, until a time.
 */
export type Write =
  | { command: 'snooze'; session: string; asks: readonly string[]; until?: number }
  | { command: 'wake'; session: string }
  | { command: 'answer'; session: string; ask: string; wants: Wants; answer: string }
  | { command: 'ignore'; session: string; ask: string; wants: Wants }
  | { command: 'snoozeAsk'; session: string; ask: string; until: number }

/** A step's state; the session to open, where `o` asks for one; and the line to write, where the snooze menu, `z` or an answer going asks for one. */
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

/** The open row `key`, if one is. */
const rowIn = (state: PanelState, key: string | undefined) => openRows(state).find(row => rowKey(row) === key)

/** The state with `field` set, or without it, given none. */
const withField = <K extends 'band' | 'expanded' | 'menu' | 'asking' | 'answer' | 'reason' | 'waking' | 'sending' | 'sent' | 'changedAt' | 'stood'>(
  state: PanelState,
  field: K,
  value: PanelState[K],
): PanelState => {
  const next = { ...state }

  delete next[field]

  return value === undefined ? next : { ...next, [field]: value }
}

/** The band on the row `key`, or on none; where it moves to another, its row folded, and its menu and its asks closed. */
const withBand = (state: PanelState, key: string | undefined): PanelState => {
  const next = withField(state, 'band', key)
  const folded = next.expanded === key ? next : withField(next, 'expanded', undefined)
  const unmenued = folded.menu?.row === key ? folded : withField(folded, 'menu', undefined)

  return unmenued.asking?.row === key ? unmenued : withField(unmenued, 'asking', undefined)
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
  const row = state.menu === undefined ? undefined : rowIn(state, state.menu.row)

  return state.menu === undefined || (row?.asks !== undefined && !row.isSnoozed) ? state : withField(state, 'menu', undefined)
}

/** The ids of the asks the view answers on the row `key`. */
const askIdsOn = (state: PanelState, key: string) => rowIn(state, key)?.answerable?.map(ask => ask.id) ?? []

/**
 * The asks open on `after`'s row, as the board changed from `before`: the
 * ask shown where it is still on the board, else the next of those it had
 * after it still there, else the nearest before it, else the row's first;
 * closed with none left.
 */
const stillAsking = (before: PanelState, after: PanelState): PanelState => {
  const { asking } = after

  if (asking === undefined) {
    return after
  }

  const now = askIdsOn(after, asking.row)
  const was = askIdsOn(before, asking.row)
  const at = Math.max(was.indexOf(asking.ask), 0)
  const ask = now.includes(asking.ask)
    ? asking.ask
    : ([...was.slice(at + 1), ...was.slice(0, at).reverse()].find(id => now.includes(id)) ?? now[0])

  return ask === undefined ? withField(after, 'asking', undefined) : { ...after, asking: { ...asking, ask } }
}

/** The ask's snooze menu closed where its ask is no longer the one shown. */
const stillOnItsAsk = (state: PanelState): PanelState =>
  state.menu !== undefined && 'ask' in state.menu && state.asking?.ask !== state.menu.ask ? withField(state, 'menu', undefined) : state

/** `next`, its rows moved from where they stood in `state`: the band following its row, and kept in sight where it was. */
const reflowed = (state: PanelState, next: PanelState) =>
  settled(keepingSight(state, stillOnItsAsk(stillAsking(state, stillSnoozable(withBand(next, followed(state, next)))))))

/** The ask shown, the asks open, as the view words it. */
const shownAsk = (state: PanelState): PanelAsk | undefined => {
  const { asking } = state

  return asking === undefined ? undefined : rowIn(state, asking.row)?.answerable?.find(ask => ask.id === asking.ask)
}

/** What an ask reads as, its age aside: another ask, or the same reworded, reads otherwise. */
const readingOf = ({ id, title, wants, answers, sends, pick }: PanelAsk) => JSON.stringify([id, title, wants, answers, sends, pick])

/** `after`, the beat started at `now` where the ask shown reads otherwise than it did `before`; as it was, where either shows none. */
const beaten = (before: PanelState, after: PanelState, now: number): PanelState => {
  const [was, is] = [shownAsk(before), shownAsk(after)]

  return was === undefined || is === undefined || readingOf(was) === readingOf(is) ? after : { ...after, changedAt: now }
}

/** Whether a key at `at` lands on the ask: it has stood BEAT_MS since the board last changed it. */
const hasAskStood = (state: PanelState, at: number) => state.changedAt === undefined || at - state.changedAt >= BEAT_MS

/** Each line new on the board stamped `now`, and those first shown NEW_MS ago or more dropped. */
const arrived = (arrivals: ViewState['arrivals'], news: readonly string[], now: number) =>
  new Map([...arrivals, ...news.map(key => [key, now] as const)].filter(([, at]) => now - at < NEW_MS))

/** The asks whose answers have gone that the board still lists among those the view answers: the others have left it, and need leaving out no more. */
const stillListed = (sent: ReadonlySet<string> | undefined, board: Feed) => {
  const listed = new Set([...answerableAsks(board)].flatMap(([session, asks]) => asks.map(each => askKey(session, each.ask.id))))
  const kept = [...(sent ?? [])].filter(key => listed.has(key))

  return kept.length === 0 ? undefined : new Set(kept)
}

const boarded = (state: PanelState, { board, news, now, at = now, notHere = state.notHere }: Board): PanelState => {
  const read: PanelState = {
    ...withField(withField(withField(state, 'reason', undefined), 'waking', undefined), 'sent', stillListed(state.sent, board)),
    feed: board,
    board: 'read',
    readAt: now,
    now,
    arrivals: arrived(state.arrivals, news, now),
    notHere,
  }

  return beaten(state, reflowed(state, read), at)
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
  const session = rowIn(state, state.band)?.session

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
  const first = rowIn(state, state.band)?.answerable?.[0]

  if (state.band === undefined || first === undefined) {
    return expanded(state)
  }

  return settled(kept(withField(withField(state, 'expanded', undefined), 'asking', { row: state.band, ask: first.id })))
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
  const row = rowIn(state, state.band)

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

/** What a choice of the menu writes: the session snoozed to its time, naming the asks its row showed; or the ask alone, to a time. */
const snoozeWrite = (menu: Menu, until: number | undefined): Write | undefined => {
  if (!('ask' in menu)) {
    return { command: 'snooze', session: menu.session, asks: menu.asks, ...(until === undefined ? {} : { until }) }
  }

  return until === undefined ? undefined : { command: 'snoozeAsk', session: menu.session, ask: menu.ask, until }
}

/** The choice at `at` made: the menu closed, and what it snoozes to its time. */
const chosen = (state: PanelState, menu: Menu, at: number): Stepped => {
  const option = menu.options[at]
  const write = option === undefined ? undefined : snoozeWrite(menu, option.until)

  return write === undefined ? { state: closed(state) } : { state: closed(state), write }
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

/** The answer sending taken back: nothing is written. */
const undone = (state: PanelState) => withField(state, 'sending', undefined)

/** The keys that act in every mode, ahead of the menu's, the asks' and the board's own. */
type Everywhere = 'quit' | 'suspend' | 'undo'

/** A key each mode takes in its own way. */
type ModeKey = Exclude<Key, { kind: Everywhere }>

/** What each key does to the state, its answer already dropped, and the state as it was drawn: every key but those that act in every mode. */
const ON_KEY: { [K in ModeKey['kind']]: (state: PanelState, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped } = {
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
  ignore: only,
}

/** The asks open, as the state holds them: the row's key and the ask shown, by its id. */
type AskShown = NonNullable<PanelState['asking']>

/** The answer sending, as `sitrep answer` writes it: its words, or its ignore, with what its ask wanted as shown. */
const answerWrite = ({ session, ask, wants, answer }: HeldAnswer): Write =>
  answer === undefined ? { command: 'ignore', session, ask, wants } : { command: 'answer', session, ask, wants, answer: answer.sends }

/**
 * The answer sending gone at `now`: its write, its ask left out of its
 * row's asks at once, the asks open on it stepping on as they would were
 * the board to drop it, and the beat started where the ask shown changed.
 */
const goes = (state: PanelState, now: number): Stepped => {
  const { sending } = state

  if (sending === undefined) {
    return only(state)
  }

  const held = undone(state)
  const gone = { ...held, sent: new Set([...(state.sent ?? []), askKey(sending.session, sending.ask)]) }

  return { state: beaten(held, reflowed(held, gone), now), write: answerWrite(sending) }
}

/** What the keys that act in every mode do, as pressed at `at`: `q`, Ctrl-C and Ctrl-Z send the answer held at once, the loop leaving or suspending once it is written; `u` takes it back. */
const EVERYWHERE: { [K in Everywhere]: (state: PanelState, at: number) => Stepped } = {
  quit: goes,
  suspend: goes,
  undo: state => only(undone(state)),
}

const isEverywhere = (key: Key): key is Extract<Key, { kind: Everywhere }> => key.kind in EVERYWHERE

/** The clock at `now`: the washes past their time dropped, and the answer sending gone once its time has come. */
const ticked = (state: PanelState, now: number): Stepped => {
  const moved = { ...state, now, arrivals: arrived(state.arrivals, [], now) }

  return state.sending !== undefined && now - state.sending.at >= SEND_MS ? goes(moved, now) : only(moved)
}

/** The ask an answer or an ignore names, by `askKey`; none for any other write. */
const answeredBy = (write: Write | undefined) =>
  write?.command === 'answer' || write?.command === 'ignore' ? askKey(write.session, write.ask) : undefined

/** A write done: where it failed, why, said, and an answer's ask back in its row's asks, where it was left out as the answer went. */
const writeDone = (state: PanelState, { written: why, write }: { written: string | undefined; write?: Write }): PanelState => {
  const back = why === undefined ? undefined : answeredBy(write)
  const sent = [...(state.sent ?? [])].filter(each => each !== back)

  return answered(withField(state, 'sent', sent.length === 0 ? undefined : new Set(sent)), why)
}

/** Whether the ask shown is the one sending, whose foot is the sending line. */
const isSendingShown = ({ sending }: PanelState, shown: AskShown) => sending?.row === shown.row && sending.ask === shown.ask

/** The ask shown's answer at `index`, its words as shown and as it sends them; none past its answers. */
const answerAt = (ask: PanelAsk, index: number): HeldAnswer['answer'] => {
  const [words, sends] = [ask.answers[index], ask.sends[index]]

  return words === undefined || sends === undefined ? undefined : { words, sends }
}

/** The ask shown's answer at `index`, or, with none, its ignore, as held from `at`; none past its answers. */
const sendingFrom = (state: PanelState, shown: AskShown, index: number | undefined, at: number): HeldAnswer | undefined => {
  const row = rowIn(state, shown.row)
  const ask = row?.answerable?.find(each => each.id === shown.ask)

  if (row === undefined || ask === undefined) {
    return undefined
  }

  const held = { row: shown.row, session: row.session, ask: ask.id, wants: ask.wants, at }

  if (index === undefined) {
    return held
  }

  const answer = answerAt(ask, index)

  return answer === undefined ? undefined : { ...held, answer }
}

/** The ask shown's answer at `index` held from `at`, or, with none, its ignore: only while no other is sending. */
const holding = (state: PanelState, shown: AskShown, index: number | undefined, at: number): PanelState => {
  const sending = state.sending === undefined ? sendingFrom(state, shown, index, at) : undefined

  return sending === undefined ? state : { ...state, sending }
}

/** `z` on the asks: the ask shown's snooze menu in the foot's place, its times worked out on the clock the frame showed the foot by, the two kept whole in sight; nothing where Snooze offers no time, nor on the ask sending. */
const snoozingAsk = (state: PanelState, shown: AskShown): Stepped => {
  const row = rowIn(state, shown.row)
  const options = snoozeTimes(state.now, state.snoozeSettings)

  if (row === undefined || options.length === 0 || isSendingShown(state, shown)) {
    return only(state)
  }

  const menu: Menu = { row: shown.row, session: row.session, ask: shown.ask, options, at: 0, top: 0 }

  return only(settled(kept(withField(state, 'menu', menu))))
}

/** The asks closed. */
const closedAsks = (state: PanelState) => settled(withField(state, 'asking', undefined))

/** The ask at `index` among the row's shown, within its first and its last, the asks kept whole in sight. */
const shownAt = (state: PanelState, shown: AskShown, index: number): PanelState => {
  const asks = askIdsOn(state, shown.row)
  const ask = asks[Math.min(Math.max(index, 0), asks.length - 1)]

  return ask === undefined ? state : settled(kept({ ...state, asking: { ...shown, ask } }))
}

/** The ask before or after the one shown, `by` -1 or 1. */
const pagedBy = (state: PanelState, shown: AskShown, by: number) =>
  shownAt(state, shown, askIdsOn(state, shown.row).indexOf(shown.ask) + by)

/** The opened row as `drawn` lays it out: its asks, its lines, the terminal row of its first, and the layout's width; none where it isn't in view. */
const drawnAsks = (drawn: PanelState, row: string): { asking: Asking; y: number; lines: AsksLine[]; width: number } | undefined => {
  const layout = layoutIn(drawn)
  const placed = layout.placed.find(each => each.kind === 'row' && each.key === row)

  if (placed?.kind !== 'row') {
    return undefined
  }

  const asking = askingIn(viewIn(drawn), placed.row)

  return asking === undefined
    ? undefined
    : { asking, y: placed.y, lines: asksLinesOf(asking, layout.width, placed.lane, placed.height), width: layout.width }
}

/** Whether `drawn` draws a line of the ask shown in view, past the row's head. */
const isAskInView = (drawn: PanelState, shown: AskShown) => drawnAsks(drawn, shown.row)?.lines.some(line => !isHeadLine(line)) ?? false

/** What a tap lands on, as one string: a dot by the ask it shows, so paging leaves it standing; any other part with the ask it is of, as the ask reads. */
const partOf = ({ row, asks, ask }: Asking, tap: AsksTap) =>
  JSON.stringify('dot' in tap ? [rowKey(row), asks[tap.dot]?.id] : [rowKey(row), readingOf(ask), tap])

/** Each cell of the opened row's lines in view, by terminal row, as the part a tap there lands on, `''` for none. */
const partsDrawn = (state: PanelState): [number, string[]][] => {
  const drawn = state.asking === undefined ? undefined : drawnAsks(state, state.asking.row)

  if (drawn === undefined) {
    return []
  }

  const { asking, y, lines, width } = drawn
  const partAt = (line: AsksLine, x: number) => {
    const tap = tapOn(line, x)

    return tap === undefined ? '' : partOf(asking, tap)
  }

  return lines.map((line, at) => [y + at, Array.from({ length: width }, (_, x) => partAt(line, x))])
}

/** A cell's part drawn at `at`: standing since it was, where the frame before drew it there too, as `was` says; else from `at`. */
const standing = (part: string, was: Stood | undefined, at: number): Stood => ({ part, since: was?.part === part ? was.since : at })

/** A frame drawn at `at`: the clock moved to it, and each cell of the opened row standing as it is drawn now. */
const drawnAt = (state: PanelState, at: number): PanelState => {
  const moved = { ...state, now: at }
  const stood = new Map(partsDrawn(moved).map(([y, parts]) => [y, parts.map((part, x) => standing(part, state.stood?.get(y)?.[x], at))]))

  return withField(moved, 'stood', stood.size === 0 ? undefined : stood)
}

/** Whether the part a tap at `x`, `y` lands on in `drawn`, `part`, has stood there BEAT_MS by `at`, each frame since drawing it there. */
const hasPartStood = (drawn: PanelState, x: number, y: number, part: string, at: number) => {
  const stood = drawn.stood?.get(y)?.[x]

  return stood?.part === part && at - stood.since >= BEAT_MS
}

/** A digit on the asks: the answer of its number held, where `drawn` draws it. */
const numbered = (state: PanelState, shown: AskShown, n: number, drawn: PanelState, at: number): PanelState => {
  const asks = drawnAsks(drawn, shown.row)

  return asks !== undefined && isAnswerDrawn(asks.lines, n - 1) ? holding(state, shown, n - 1, at) : state
}

/** The key each of the foot's hints, and the sending line's `undo`, stands for: a tap on one acts as its key. */
const HINTED: Readonly<Record<string, Press>> = { x: 'ignore', z: 'snooze', o: 'open', u: 'undo' }

/** Whether a tap lands on the sending line's `undo`, which waits on no beat, so an undo is never lost. */
const isUndo = (tap: AsksTap) => 'key' in tap && HINTED[tap.key] === 'undo'

/** What a key does on the asks, with the ask shown, the state as it was drawn, and when it was pressed. */
type OnAsks<K extends Key['kind']> = (state: PanelState, shown: AskShown, key: Extract<Key, { kind: K }>, drawn: PanelState, at: number) => Stepped

/** A key on the asks, as ASKS_KEY takes it; any it holds none for does nothing. */
const onAsks = (state: PanelState, shown: AskShown, key: ModeKey, drawn: PanelState, at: number): Stepped => {
  const act = ASKS_KEY[key.kind] as OnAsks<ModeKey['kind']> | undefined

  return act === undefined ? only(state) : act(state, shown, key, drawn, at)
}

/** A tap landed on the ask: a page dot shows its ask; an answer is held; a hint acts as its key. */
const landed = (state: PanelState, shown: AskShown, tap: AsksTap, drawn: PanelState, at: number): Stepped => {
  if ('dot' in tap) {
    return only(shownAt(state, shown, tap.dot))
  }

  if ('answer' in tap) {
    return only(holding(state, shown, tap.answer, at))
  }

  const kind = HINTED[tap.key]

  return kind === undefined ? only(state) : keyed(state, { kind } as Key, drawn, at)
}

/**
 * A tap with a row's asks open, found where they stood as `drawn`: on a
 * part of the ask that has stood its beat under it, or on `undo`, where it
 * lands (`landed`); on its other lines, or a part still new there, nothing;
 * anywhere else, the asks closed and nothing more.
 */
const tappedAsks = (state: PanelState, shown: AskShown, { x, y }: Tap, drawn: PanelState, at: number): Stepped => {
  const asks = drawnAsks(drawn, shown.row)
  const line = asks === undefined || x >= asks.width ? undefined : asks.lines[y - asks.y]

  if (asks === undefined || line === undefined || isHeadLine(line)) {
    return only(closedAsks(state))
  }

  const tap = tapOn(line, x)
  const lands = tap !== undefined && (isUndo(tap) || hasPartStood(drawn, x, y, partOf(asks.asking, tap), at))

  return lands ? landed(state, shown, tap, drawn, at) : only(state)
}

/** The band moved as `onKey` moves it, the asks closed first. */
const closing =
  <K extends Key['kind']>(onKey: (state: PanelState, key: Extract<Key, { kind: K }>, drawn: PanelState) => Stepped): OnAsks<K> =>
  (state, _, key, drawn) =>
    onKey(closedAsks(state), key, drawn)

/** What each key does with a row's asks open, its answer already dropped; any other does nothing, those that act in every mode aside. */
const ASKS_KEY: { [K in ModeKey['kind']]?: OnAsks<K> } = {
  up: closing(ON_KEY.up),
  down: closing(ON_KEY.down),
  pageUp: closing(ON_KEY.pageUp),
  pageDown: closing(ON_KEY.pageDown),
  home: closing(ON_KEY.home),
  end: closing(ON_KEY.end),
  enter: state => only(closedAsks(state)),
  esc: state => only(closedAsks(state)),
  left: (state, shown) => only(pagedBy(state, shown, -1)),
  right: (state, shown) => only(pagedBy(state, shown, 1)),
  digit: (state, shown, { n }, drawn, at) => only(numbered(state, shown, n, drawn, at)),
  ignore: (state, shown, _, drawn, at) => only(isAskInView(drawn, shown) ? holding(state, shown, undefined, at) : state),
  snooze: (state, shown, _, drawn) => (isAskInView(drawn, shown) ? snoozingAsk(state, shown) : only(state)),
  tap: tappedAsks,
  open: opened,
  wheel: (state, _, key, drawn) => ON_KEY.wheel(state, key, drawn),
}

/** A key acted on at `at`: those that act in every mode first; then the menu's, while it is open, the asks', while they are, or the board's. */
const keyed = (state: PanelState, key: Key, drawn: PanelState, at: number): Stepped => {
  if (isEverywhere(key)) {
    return EVERYWHERE[key.kind](state, at)
  }

  if (drawn.menu !== undefined) {
    const onMenu = MENU_KEY[key.kind] as ((state: PanelState, menu: Menu, key: Key, drawn: PanelState) => Stepped) | undefined

    return onMenu === undefined ? only(state) : onMenu(state, drawn.menu, key, drawn)
  }

  if (drawn.asking !== undefined) {
    return onAsks(state, drawn.asking, key, drawn, at)
  }

  const onKey = ON_KEY[key.kind] as (state: PanelState, key: Key, drawn: PanelState) => Stepped

  return onKey(state, key, drawn)
}

/** Whether the beat holds a key pressed at `at`: a digit or `x` on the asks, within BEAT_MS of the board changing the ask shown. */
const isBeaten = (drawn: PanelState, key: Key, at: number) =>
  drawn.asking !== undefined && drawn.menu === undefined && (key.kind === 'digit' || key.kind === 'ignore') && !hasAskStood(drawn, at)

/** A key pressed at `at`, its answer dropped first; nothing more where the beat holds it. */
const pressed = (drawn: PanelState, key: Key, at: number): Stepped => {
  const state = withField(drawn, 'answer', undefined)

  return isBeaten(drawn, key, at) ? only(state) : keyed(state, key, drawn, at)
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
    return pressed(state, event.key, event.at ?? state.now)
  }

  if ('size' in event) {
    return only(settled(keepingSight(state, { ...state, size: event.size })))
  }

  if ('opened' in event) {
    return only(answered(state, event.opened ?? state.answer))
  }

  if ('written' in event) {
    return only(writeDone(state, event))
  }

  if ('notHere' in event) {
    return only(reflowed(state, { ...state, notHere: event.notHere }))
  }

  if ('snoozeSettings' in event) {
    return only({ ...state, snoozeSettings: event.snoozeSettings })
  }

  if ('drawn' in event) {
    return only(drawnAt(state, event.drawn))
  }

  return ticked(state, event.tick)
}
