/**
 * The live feed: the board as every surface shows it, which `sitrep watch`
 * prints a line of each time it changes (see "One engine, two front ends"
 * in DESIGN.md), and what decides when it does.
 *
 * - The rows, a session each, in the panel's order, and the head (rows.ts);
 *   and, apart from them, the Snoozed rows, a session's asks and its turn
 *   each a row, soonest to wake first.
 * - Each project with a current session, and those sessions, away ones
 *   among them and never a finished one, each with its state, what it is
 *   doing as the line under its name says it, its open asks, as
 *   `board --json` lists them (`openAsks`), and what it parked. They are in
 *   the SitRep window's order, the rows': a session where its row sits,
 *   those with none after, the latest updated first; a project where its
 *   first session sits.
 * - Every live window: its session, the version it runs, whether that is
 *   behind the CLI's own, and its place in the order a jump tries its
 *   session's windows (windows.ts).
 * - What is new: a line needing Lee the watch has not shown, or not within a
 *   day of its own time; or one it showed asleep, in Snoozed, back as its
 *   snooze ran out.
 * - When the board next changes by time alone: a heartbeat going stale, or
 *   a snooze running out, changes no file; and when a session's fold does,
 *   for a window's look around, which keeps each session's (reading.ts).
 */
import { isLive, STALE_MS } from './presence'
import type { Project } from './project'
import { needsReload } from './release'
import { snoozedAsks } from './replies'
import {
  doingOf,
  headOf,
  inPanelOrder,
  inSnoozedOrder,
  needsYou,
  oldestOf,
  rowOf,
  sessionState,
  snoozedRowsOf,
  snoozedTurnOf,
  type Doing,
  type Head,
  type Line,
  type Row,
  type SessionState,
  type SnoozedLine,
  type SnoozedRow,
} from './rows'
import { compareText } from './text'
import type { Ask, Parked, Session, WindowState, Where } from './types'
import {
  CURRENT_MS,
  isCurrent,
  isIdle,
  openAsks,
  summarise,
  summariseProject,
  type ProjectSummary,
  type SessionSummary,
} from './views'
import { inJumpOrder } from './windows'

/** A project as read, with every session filed under it. */
export type ProjectRead = { project: Project; sessions: readonly Session[] }

export type FeedSession = SessionSummary & {
  state: SessionState
  /** When its state began: its row's oldest line's, as Needs you's first line came; with no row, its latest line's. */
  since: number
  /** What it is doing, as the line under its name says it. */
  doing: Doing
  /** Its open asks, oldest first: waiting, on Lee or on a reply of Lee's going in, or replied, Claude's to act on. */
  asks: Ask[]
  /** What it parked, oldest first. */
  parkedItems: Parked[]
}

export type FeedProject = Omit<ProjectSummary, 'sessions'> & { sessions: FeedSession[] }

/** A live window, and the session it holds. */
export type FeedWindow = {
  writer: string
  session: string
  /** The session's name, and its project's. */
  name: string
  project: string
  version?: string
  /** Whether it runs a sitrep behind the CLI's own, and needs `/reload-plugins`. */
  needsReload: boolean
  where?: Where
  state?: WindowState
  attachedAt: number
  /** Its place in the order a jump tries its session's windows, 0 first; none where it says no `where`, which no jump tries. */
  jumpOrder?: number
}

export type Feed = {
  head: Head
  rows: Row[]
  /** The Snoozed rows, apart from the rows: a session there may have a row too. */
  snoozed: SnoozedRow[]
  projects: FeedProject[]
  windows: FeedWindow[]
}

/** The place of a session with no row: after every one that has. */
const NO_ROW = Number.MAX_SAFE_INTEGER

/** Each session's row, and where it sits among the rows, by the session's id. */
type Places = ReadonlyMap<string, { place: number; row: Row }>

const placesOf = (rows: readonly Row[]): Places =>
  new Map(rows.map((row, place) => [row.session, { place, row }]))

const placeOf = (places: Places, id: string | undefined) => places.get(id ?? '')?.place ?? NO_ROW

/** When a session's state began: its row's oldest line, as a row's own time is its newest's; with no row, its latest line. */
const sinceOf = (row: Row | undefined, session: Session) =>
  row === undefined ? session.updatedAt : oldestOf(row)

/** A project's current sessions as the feed holds them: where their rows sit, those with none after, the latest updated first. */
const feedProject = (
  { project, sessions }: ProjectRead,
  places: Places,
  now: number,
): FeedProject => {
  const current = sessions
    .map(session => ({ session, summary: summarise(session) }))
    .filter(({ summary }) => isCurrent(summary, now))
    .map(({ session, summary }): FeedSession => ({
      ...summary,
      state: sessionState(session, now),
      since: sinceOf(places.get(session.id)?.row, session),
      doing: doingOf(project, session, now),
      asks: openAsks(session),
      parkedItems: session.parked,
    }))
    .sort(
      (a, b) =>
        placeOf(places, a.id) - placeOf(places, b.id) ||
        b.updatedAt - a.updatedAt ||
        compareText(a.id, b.id),
    )

  return {
    ...summariseProject(project.key, current),
    name: project.name,
    directory: project.directory,
    sessions: current,
  }
}

/** Each of a session's windows a jump tries, by writer, and its place in the order it tries them. */
const jumpOrders = (session: Session, now: number) =>
  new Map(inJumpOrder(session, now).map((each, place) => [each.writer, place]))

/** Every live window on the board, the longest attached first. */
const liveWindows = (read: readonly ProjectRead[], now: number, own?: string): FeedWindow[] =>
  read
    .flatMap(({ project, sessions }) =>
      sessions.flatMap(session => {
        const orders = jumpOrders(session, now)

        return session.presence
          .filter(each => isLive(each, now))
          .map((each): FeedWindow => ({
            writer: each.writer,
            session: session.id,
            name: session.status.name,
            project: project.name,
            version: each.version,
            needsReload: needsReload(each.version, own),
            where: each.where,
            state: each.state,
            attachedAt: each.attachedAt,
            jumpOrder: orders.get(each.writer),
          }))
      }),
    )
    .sort((a, b) => a.attachedAt - b.attachedAt || compareText(a.writer, b.writer))

/** The board at `now` as every surface shows it; `own` is the version the CLI runs. */
export const feedOf = (read: readonly ProjectRead[], now: number, own?: string): Feed => {
  const rows = inPanelOrder(
    read.flatMap(({ project, sessions }) =>
      sessions.flatMap(session => rowOf(project, session, now) ?? []),
    ),
  )
  const places = placesOf(rows)
  const projectPlace = (project: FeedProject) => placeOf(places, project.sessions[0]?.id)

  return {
    head: headOf(rows),
    rows,
    snoozed: inSnoozedOrder(
      read.flatMap(({ project, sessions }) =>
        sessions.flatMap(session => snoozedRowsOf(project, session, now)),
      ),
    ),
    projects: read
      .map(each => feedProject(each, places, now))
      .filter(project => project.sessions.length > 0)
      .sort(
        (a, b) =>
          projectPlace(a) - projectPlace(b) ||
          b.updatedAt - a.updatedAt ||
          compareText(a.name, b.name),
      ),
    windows: liveWindows(read, now, own),
  }
}

/**
 * How long a line needing Lee may be gone, in the watch's own time, and its
 * coming back still be the same one: a window's heartbeat late, an ask's
 * folder away for a look.
 */
export const FORGET_MS = 24 * 60 * 60_000

/** How a watch has shown an ask's line in Snoozed: asleep, kept however long it sleeps. */
export const ASLEEP = 'asleep'

/** Whether a Snoozed line is an ask's, which will need Lee as it wakes; a turn's never does. */
const isAsk = (line: SnoozedLine) => line.is === 'ask'

/** How a watch has shown a line needing Lee: when it went, in its own time; undefined while it is on the board; or asleep, in Snoozed. */
type Seen = number | undefined | typeof ASLEEP

/** The lines needing Lee a watch has shown, by their keys. */
export type Shown = ReadonlyMap<string, Seen>

/**
 * What is new on the board at `at`, the watch's own time: the keys of its
 * lines needing Lee that the watch has not shown, or not since FORGET_MS
 * before, a new ask or a window's new stop, in the rows' order; and what it
 * has shown with this board. Nothing is new on the first board, before which
 * nothing was shown. A line shown asleep is new only once its snooze's time
 * wakes it, as its line says (`woke`): woken by Lee, it comes as shown. One
 * gone from Snoozed, as when Lee replies to it, is gone as any line is.
 */
export const newRows = (shown: Shown | undefined, feed: Feed, at: number) => {
  const lines = feed.rows.filter(needsYou).flatMap(row => row.lines)
  const asleep = feed.snoozed.flatMap(row => row.lines.filter(isAsk).map(line => line.key))
  const isOn = new Set(lines.map(line => line.key))
  const isRemembered = (seen: Seen) => typeof seen !== 'number' || at - seen <= FORGET_MS
  const gone = [...(shown ?? [])].flatMap(([key, seen]): [string, number][] =>
    isOn.has(key) || !isRemembered(seen) ? [] : [[key, typeof seen === 'number' ? seen : at]],
  )
  const isNewTo = (before: Shown) => (line: Line) => {
    const seen = before.get(line.key)

    return seen === ASLEEP ? line.woke !== undefined : !before.has(line.key) || !isRemembered(seen)
  }

  return {
    news: shown === undefined ? [] : lines.filter(isNewTo(shown)).map(line => line.key),
    shown: new Map<string, Seen>([
      ...gone,
      ...asleep.map(key => [key, ASLEEP] as const),
      ...lines.map(line => [line.key, undefined] as const),
    ]),
  }
}

/** Whether a session stays current by its being recent alone, or a window: unfinished, and idle. */
const isAging = (session: Session) => {
  const summary = summarise(session)

  return !summary.isFinished && isIdle(summary)
}

/** The earliest of `instants` after `now`; undefined while none is. */
const earliestAfter = (instants: readonly (number | undefined)[], now: number) => {
  const after = instants.filter((at): at is number => at !== undefined && at > now)

  return after.length === 0 ? undefined : Math.min(...after)
}

/**
 * When a session's part of the board next changes by time alone, after
 * `now`: the earliest one of its live heartbeats goes stale, a snooze of an
 * ask snoozed or of its turn runs out, or it drops out of the views, idle.
 * None changes a file. A heartbeat goes stale as the session was folded: aged only while
 * its reader ran (pauses.ts); a snooze runs out on the wall clock.
 * Undefined while none will.
 */
export const nextBoardChange = (session: Session, now: number) =>
  earliestAfter(
    [
      ...session.presence.filter(each => isLive(each, now)).map(each => each.seenAt + STALE_MS + 1),
      ...snoozedAsks(session).map(ask => ask.snoozedUntil),
      snoozedTurnOf(session, now)?.until,
      isAging(session) ? session.updatedAt + CURRENT_MS + 1 : undefined,
    ],
    now,
  )

/**
 * When a session folded at `now` is next to be folded again, no file
 * changed: as its part of the board changes, and as any snooze standing on
 * its asks runs out. That counts the snoozes the board leaves out: over an
 * ask Lee's reply is on its way to, or in a finished session, an ask still
 * goes from `snoozedUntil` to `wokeAt`. Undefined while none will.
 */
export const nextFoldChange = (session: Session, now: number) =>
  earliestAfter([nextBoardChange(session, now), ...session.asks.map(ask => ask.snoozedUntil)], now)

/**
 * When the board next changes by time alone, after `now`: the earliest any
 * session's part of it does (`nextBoardChange`). `watch` looks again then.
 * Undefined while none will.
 */
export const nextExpiry = (read: readonly ProjectRead[], now: number) =>
  earliestAfter(
    read.flatMap(({ sessions }) => sessions.map(session => nextBoardChange(session, now))),
    now,
  )
