/**
 * Which windows have a session open. A mod cannot tell that its own
 * window died, so each attached window rewrites a heartbeat, and a session is
 * open while at least one heartbeat is fresh. A mod cannot delete a file
 * either, so a window that lets go says so in its heartbeat. A heartbeat
 * also says where its window is, the sitrep version it runs, what it is
 * doing (state.ts), and when the load of the mod that wrote it began.
 */
import { isFilled, isTime } from './entries'
import { parseState } from './state'
import { compareText } from './text'
import type { Presence } from './types'
import { parseWhere } from './where'

/** How often an attached window rewrites its heartbeat. */
export const HEARTBEAT_MS = 30_000

/** How old a heartbeat may be before its window counts as gone: three missed beats. */
export const STALE_MS = 3 * HEARTBEAT_MS

/** A window's first heartbeat on a session, with where the window is, the version it runs, its state and its load, as far as they are known. */
export const attach = (
  writer: string,
  at: number,
  known: Pick<Presence, 'where' | 'version' | 'state' | 'loadedAt'> = {},
): Presence => ({ writer, attachedAt: at, seenAt: at, ...known })

export const heartbeat = (presence: Presence, at: number): Presence => ({ ...presence, seenAt: at })

/** The heartbeat of a window that let go: it is doing nothing on the session, so it says no state. */
export const leave = (presence: Presence, at: number): Presence => ({
  ...presence,
  state: undefined,
  leftAt: at,
})

export const presenceText = (presence: Presence) => `${JSON.stringify(presence)}\n`

/**
 * A heartbeat file's presence, its writer named by the file; undefined when
 * the file is torn or bad. A bad `where`, `version`, `state` or
 * `loadedAt`, or a bad field of one, is dropped and the presence kept.
 */
export const parsePresence = (text: string, writer: string): Presence | undefined => {
  let raw: {
    attachedAt?: unknown
    seenAt?: unknown
    leftAt?: unknown
    where?: unknown
    version?: unknown
    state?: unknown
    loadedAt?: unknown
  }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const { attachedAt, seenAt, leftAt, where, version, state, loadedAt } = raw

  if (!isTime(attachedAt) || !isTime(seenAt) || !(leftAt === undefined || isTime(leftAt))) {
    return undefined
  }

  return {
    writer,
    attachedAt,
    seenAt,
    leftAt,
    where: parseWhere(where),
    version: isFilled(version) ? version : undefined,
    state: parseState(state),
    loadedAt: isTime(loadedAt) ? loadedAt : undefined,
  }
}

export const isLive = (presence: Presence, now: number) =>
  presence.leftAt === undefined && now - presence.seenAt <= STALE_MS

/**
 * Whether a heartbeat is a window's on a version from before heartbeats said
 * theirs: it says none. Such a window reads and writes the old layout alone.
 */
export const isOldVersion = (presence: Presence) => presence.version === undefined

/**
 * How long a window on an old version keeps the move of the old layout
 * waiting since it was last seen, unless it let go: a Mac may sleep for
 * days with it open, and it wakes still reading the old layout alone.
 */
export const OLD_WINDOW_MS = 7 * 24 * 60 * 60_000

/**
 * Whether the board's heartbeats keep the move of the old layout waiting: a
 * window whose latest heartbeat anywhere on the board is on an old version,
 * has not let go, and was seen within OLD_WINDOW_MS; or a heartbeat file
 * that does not read, as one torn mid-rewrite, written within it
 * (`unread`, each such file's time). A window's later heartbeat saying its
 * version, as after a reload, stands for those before it.
 */
export const isMoveHeld = (beats: readonly Presence[], unread: readonly number[], now: number) => {
  const isRecent = (at: number) => now - at <= OLD_WINDOW_MS
  const latest = new Map<string, Presence>()

  for (const beat of beats) {
    if (beat.seenAt > (latest.get(beat.writer)?.seenAt ?? -Infinity)) {
      latest.set(beat.writer, beat)
    }
  }

  return (
    unread.some(isRecent) ||
    [...latest.values()].some(
      beat => isOldVersion(beat) && beat.leftAt === undefined && isRecent(beat.seenAt),
    )
  )
}

/**
 * The window that submits a session's inbox replies: the one attached
 * longest, so two windows on one session never both submit. While a window
 * on an old version is live on it, the longest attached of those: one sees
 * no heartbeat under today's layout, so it delivers by its own count, and
 * the rest wait, and with them the letters under today's layout, which it
 * cannot see, until it reloads or leaves. Undefined with none attached.
 */
export const deliverer = (presence: readonly Presence[], now: number) => {
  const live = presence.filter(each => isLive(each, now))
  const old = live.filter(isOldVersion)

  return (old.length > 0 ? old : live)
    .sort((a, b) => a.attachedAt - b.attachedAt || compareText(a.writer, b.writer))
    .at(0)?.writer
}
