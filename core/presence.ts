/**
 * Which windows have a session open. A mod cannot tell that its own
 * window died, so each attached window rewrites a heartbeat, and a session is
 * open while at least one heartbeat is fresh. A mod cannot delete a file
 * either, so a window that lets go says so in its heartbeat. A heartbeat
 * also says where its window is, the sitrep version it runs, what it is
 * doing (state.ts), the replies its message in flight carries to the
 * session, and when the load of the mod that wrote it began.
 */
import { isFilled, isObject, isTime, parseSentReply } from './entries'
import { parseState } from './state'
import { compareText } from './text'
import type { Presence, Sending } from './types'
import { parseWhere } from './where'

/** How often an attached window rewrites its heartbeat. */
export const HEARTBEAT_MS = 30_000

/** How old a heartbeat may be before its window counts as gone: three missed beats. */
export const STALE_MS = 3 * HEARTBEAT_MS

/** A window's first heartbeat on a session, with where the window is, the version it runs, its state, what it sends and its load, as far as they are known. */
export const attach = (
  writer: string,
  at: number,
  known: Pick<Presence, 'where' | 'version' | 'state' | 'sending' | 'loadedAt'> = {},
): Presence => ({ writer, attachedAt: at, seenAt: at, ...known })

export const heartbeat = (presence: Presence, at: number): Presence => ({ ...presence, seenAt: at })

/** The heartbeat of a window that let go: it is doing nothing on the session, so it says no state, and sends nothing. */
export const leave = (presence: Presence, at: number): Presence => ({
  ...presence,
  state: undefined,
  sending: undefined,
  leftAt: at,
})

export const presenceText = (presence: Presence) => `${JSON.stringify(presence)}\n`

/** What a heartbeat says its window sends: its claim's time and each reply that reads; undefined without the time, or with no reply that reads. */
const parseSending = (value: unknown): Sending | undefined => {
  if (!isObject(value) || !isTime(value.at) || !Array.isArray(value.replies)) {
    return undefined
  }

  const replies = value.replies.flatMap(reply => parseSentReply(reply) ?? [])

  return replies.length === 0 ? undefined : { at: value.at, replies }
}

/**
 * A heartbeat file's presence, its writer named by the file; undefined when
 * the file is torn or bad. A bad `where`, `version`, `state`, `sending` or
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
    sending?: unknown
    loadedAt?: unknown
  }

  try {
    raw = JSON.parse(text) ?? {}
  } catch {
    return undefined
  }

  const { attachedAt, seenAt, leftAt, where, version, state, sending, loadedAt } = raw

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
    sending: parseSending(sending),
    loadedAt: isTime(loadedAt) ? loadedAt : undefined,
  }
}

export const isLive = (presence: Presence, now: number) =>
  presence.leftAt === undefined && now - presence.seenAt <= STALE_MS

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
