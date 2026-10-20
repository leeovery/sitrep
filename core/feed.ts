/**
 * The live feed: the board as every surface shows it, which `sitrep watch`
 * prints a line of each time it changes (see "One engine, two front ends"
 * in DESIGN.md), and what decides when it does.
 *
 * - The rows, in the panel's order, and the head (rows.ts).
 * - Each project with a current session, and those sessions, away ones
 *   among them and never a finished one, each with its state and its open
 *   asks, as `board --json` lists them (`openAsks`). They are in the SitRep
 *   window's order, the rows': a session where its first row sits, those
 *   with none after, the latest updated first; a project where its first
 *   session sits.
 * - Every live window: its session, the version it runs, and whether that
 *   is behind the CLI's own.
 * - What is new: a row needing Lee the watch has not shown, or not within a
 *   day of its own time.
 * - When the board next changes by time alone: a heartbeat going stale
 *   changes no file.
 */
import { isLive, STALE_MS } from './presence'
import type { Project } from './project'
import { needsReload } from './release'
import {
  headOf,
  inPanelOrder,
  needsYou,
  rowsOf,
  sessionState,
  type Head,
  type Row,
  type SessionState,
} from './rows'
import { compareText } from './text'
import type { Ask, Session, WindowState, Where } from './types'
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

/** A project as read, with every session filed under it. */
export type ProjectRead = { project: Project; sessions: readonly Session[] }

export type FeedSession = SessionSummary & {
  state: SessionState
  /** When its state began: its first row's time; with no row, its latest line's. */
  since: number
  /** Its open asks, oldest first: waiting, on Lee or on a reply of Lee's going in, or replied, Claude's to act on. */
  asks: Ask[]
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
}

export type Feed = { head: Head; rows: Row[]; projects: FeedProject[]; windows: FeedWindow[] }

/** The place of a session with no row: after every one that has. */
const NO_ROW = Number.MAX_SAFE_INTEGER

/** Each session's first row, and where it sits among the rows, by the session's id. */
type Firsts = ReadonlyMap<string, { place: number; row: Row }>

const firstRows = (rows: readonly Row[]): Firsts => {
  const firsts = new Map<string, { place: number; row: Row }>()

  rows.forEach((row, place) => {
    if (!firsts.has(row.session)) {
      firsts.set(row.session, { place, row })
    }
  })

  return firsts
}

const placeOf = (firsts: Firsts, id: string | undefined) => firsts.get(id ?? '')?.place ?? NO_ROW

/** A project's current sessions as the feed holds them: where their first rows sit, those with none after, the latest updated first. */
const feedProject = (
  { project, sessions }: ProjectRead,
  firsts: Firsts,
  now: number,
): FeedProject => {
  const current = sessions
    .map(session => ({ session, summary: summarise(session) }))
    .filter(({ summary }) => isCurrent(summary, now))
    .map(({ session, summary }): FeedSession => ({
      ...summary,
      state: sessionState(session, now),
      since: firsts.get(session.id)?.row.since ?? session.updatedAt,
      asks: openAsks(session),
    }))
    .sort(
      (a, b) =>
        placeOf(firsts, a.id) - placeOf(firsts, b.id) ||
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

/** Every live window on the board, the longest attached first. */
const liveWindows = (read: readonly ProjectRead[], now: number, own?: string): FeedWindow[] =>
  read
    .flatMap(({ project, sessions }) =>
      sessions.flatMap(session =>
        session.presence
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
          })),
      ),
    )
    .sort((a, b) => a.attachedAt - b.attachedAt || compareText(a.writer, b.writer))

/** The board at `now` as every surface shows it; `own` is the version the CLI runs. */
export const feedOf = (read: readonly ProjectRead[], now: number, own?: string): Feed => {
  const rows = inPanelOrder(
    read.flatMap(({ project, sessions }) =>
      sessions.flatMap(session => rowsOf(project, session, now)),
    ),
  )
  const firsts = firstRows(rows)
  const projectPlace = (project: FeedProject) => placeOf(firsts, project.sessions[0]?.id)

  return {
    head: headOf(rows),
    rows,
    projects: read
      .map(each => feedProject(each, firsts, now))
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
 * How long a row needing Lee may be gone, in the watch's own time, and its
 * coming back still be the same one: a window's heartbeat late, an ask's
 * folder away for a look.
 */
export const FORGET_MS = 24 * 60 * 60_000

/** The rows needing Lee a watch has shown, by their keys: when each went, in its own time, or undefined while it is on the board. */
export type Shown = ReadonlyMap<string, number | undefined>

/**
 * What is new on the board at `at`, the watch's own time: the keys of its
 * rows needing Lee that the watch has not shown, or not since FORGET_MS
 * before, a new ask or a window's new stop, in the rows' order; and what it
 * has shown with this board. Nothing is new on the first board, before which
 * nothing was shown.
 */
export const newRows = (shown: Shown | undefined, feed: Feed, at: number) => {
  const keys = feed.rows.filter(needsYou).map(row => row.key)
  const isOn = new Set(keys)
  const isRemembered = (goneAt: number | undefined) =>
    goneAt === undefined || at - goneAt <= FORGET_MS
  const gone = [...(shown ?? [])].flatMap(([key, goneAt]): [string, number][] =>
    isOn.has(key) || !isRemembered(goneAt) ? [] : [[key, goneAt ?? at]],
  )

  return {
    news:
      shown === undefined
        ? []
        : keys.filter(key => !shown.has(key) || !isRemembered(shown.get(key))),
    shown: new Map<string, number | undefined>([
      ...gone,
      ...keys.map(key => [key, undefined] as const),
    ]),
  }
}

/** Whether a session stays current by its being recent alone, or a window: unfinished, and idle. */
const isAging = (session: Session) => {
  const summary = summarise(session)

  return !summary.isFinished && isIdle(summary)
}

/**
 * When the board next changes by time alone, after `now`: the earliest a
 * live heartbeat goes stale, or an idle session drops out of the views.
 * Neither changes a file, so `watch` looks again then. A heartbeat goes
 * stale as its session was folded: aged only while the watch ran
 * (pauses.ts). Undefined while neither will.
 */
export const nextExpiry = (read: readonly ProjectRead[], now: number) => {
  const instants = read
    .flatMap(({ sessions }) =>
      sessions.flatMap(session => [
        ...session.presence
          .filter(each => isLive(each, now))
          .map(each => each.seenAt + STALE_MS + 1),
        ...(isAging(session) ? [session.updatedAt + CURRENT_MS + 1] : []),
      ]),
    )
    .filter(at => at > now)

  return instants.length === 0 ? undefined : Math.min(...instants)
}
