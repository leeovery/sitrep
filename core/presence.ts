/**
 * Which windows have a session open. A mod cannot tell that its own
 * window died, so each attached window rewrites a heartbeat, and a session is
 * open while at least one heartbeat is fresh. A mod cannot delete a file
 * either, so a window that lets go says so in its heartbeat. A heartbeat
 * also says where its window is and the sitrep version it runs.
 */
import { isFilled } from './entries'
import { compareText } from './text'
import type { Presence } from './types'
import { parseWhere } from './where'

/** How often an attached window rewrites its heartbeat. */
export const HEARTBEAT_MS = 30_000

/** How old a heartbeat may be before its window counts as gone: three missed beats. */
export const STALE_MS = 3 * HEARTBEAT_MS

const isTime = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value)

/** A window's first heartbeat on a session, with where the window is and the version it runs, as far as they are known. */
export const attach = (
  writer: string,
  at: number,
  known: Pick<Presence, 'where' | 'version'> = {},
): Presence => ({ writer, attachedAt: at, seenAt: at, ...known })

export const heartbeat = (presence: Presence, at: number): Presence => ({ ...presence, seenAt: at })

export const leave = (presence: Presence, at: number): Presence => ({ ...presence, leftAt: at })

export const presenceText = (presence: Presence) => `${JSON.stringify(presence)}\n`

/**
 * A heartbeat file's presence, its writer named by the file; undefined when
 * the file is torn or bad. A bad `where`, or a bad field of it, or a bad
 * `version`, is dropped and the presence kept.
 */
export const parsePresence = (text: string, writer: string): Presence | undefined => {
  let raw: {
    attachedAt?: unknown
    seenAt?: unknown
    leftAt?: unknown
    where?: unknown
    version?: unknown
  }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const { attachedAt, seenAt, leftAt, where, version } = raw

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
  }
}

export const isLive = (presence: Presence, now: number) =>
  presence.leftAt === undefined && now - presence.seenAt <= STALE_MS

/**
 * Whether a window runs a version from before heartbeats said theirs: live,
 * and saying none. Such a window still writes the old layout, so while one
 * runs, nothing is moved out of it.
 */
export const isOnOldVersion = (presence: Presence, now: number) =>
  isLive(presence, now) && presence.version === undefined

/**
 * The window that submits a session's inbox replies: the one attached
 * longest, so two windows on one session never both submit. Undefined with
 * none attached.
 */
export const deliverer = (presence: readonly Presence[], now: number) =>
  presence
    .filter(each => isLive(each, now))
    .sort((a, b) => a.attachedAt - b.attachedAt || compareText(a.writer, b.writer))
    .at(0)?.writer
