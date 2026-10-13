/**
 * Which windows have a piece of work open. A mod cannot tell that its own
 * window died, so each attached window rewrites a heartbeat, and a work is
 * open while at least one heartbeat is fresh. A mod cannot delete a file
 * either, so a window that lets go says so in its heartbeat.
 */
import { compareText } from './text'
import type { Presence, Where } from './types'
import { parseWhere } from './where'

/** How often an attached window rewrites its heartbeat. */
export const HEARTBEAT_MS = 30_000

/** How old a heartbeat may be before its window counts as gone: three missed beats. */
export const STALE_MS = 3 * HEARTBEAT_MS

const isTime = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value)

/** A window's first heartbeat on a piece of work, and where the window is when that is known. */
export const attach = (writer: string, at: number, where?: Where): Presence => ({
  writer,
  attachedAt: at,
  seenAt: at,
  where,
})

export const heartbeat = (presence: Presence, at: number): Presence => ({ ...presence, seenAt: at })

export const leave = (presence: Presence, at: number): Presence => ({ ...presence, leftAt: at })

export const presenceText = (presence: Presence) => `${JSON.stringify(presence)}\n`

/**
 * A heartbeat file's presence, its writer named by the file; undefined when
 * the file is torn or bad. A bad `where`, or a bad field of it, is dropped
 * and the presence kept.
 */
export const parsePresence = (text: string, writer: string): Presence | undefined => {
  let raw: { attachedAt?: unknown; seenAt?: unknown; leftAt?: unknown; where?: unknown }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const { attachedAt, seenAt, leftAt, where } = raw

  if (!isTime(attachedAt) || !isTime(seenAt) || !(leftAt === undefined || isTime(leftAt))) {
    return undefined
  }

  return { writer, attachedAt, seenAt, leftAt, where: parseWhere(where) }
}

export const isLive = (presence: Presence, now: number) =>
  presence.leftAt === undefined && now - presence.seenAt <= STALE_MS

/**
 * The window that submits a work's inbox replies: the one attached longest,
 * so two windows on one work never both submit. Undefined with none attached.
 */
export const deliverer = (presence: readonly Presence[], now: number) =>
  presence
    .filter(each => isLive(each, now))
    .sort((a, b) => a.attachedAt - b.attachedAt || compareText(a.writer, b.writer))
    .at(0)?.writer
