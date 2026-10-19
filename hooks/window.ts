/**
 * This window's hold on a session: its own file, its heartbeat, and a watch
 * that keeps the session's fold current in `$.state` and tells Lee of an
 * ask that lands. A window holds at most one session.
 *
 * Whatever reads or changes the hold runs in turn (`serially`), so two tool
 * calls never write the window's file over each other, and a heartbeat never
 * lands after the window let go. The heartbeat says what the window is
 * doing as it attaches, and again whenever that changes (doing.ts).
 */
import type { Timer } from 'claude-code'
import {
  append,
  attach,
  foldSession,
  heartbeat,
  HEARTBEAT_MS,
  isOpen,
  leave,
  presenceText,
  sessionPaths,
  stateOf,
  type Body,
  type Presence,
  type Session,
  type SessionPaths,
} from '../core'
import type { SitrepAttachment } from '../types'
import { activityNow } from './activity'
import { endAnswering, settleAnswering } from './answering'
import { boardOf } from './board'
import { logFailure, rootFor, type Host } from './host'
import { announce } from './news'
import { createReader, ownText, type Reader } from './reader'
import { versionNow } from './version'
import { whereNow } from './where'

/** How often the watch lists the session's folders for what changed. */
export const WATCH_MS = 1_500

type Hold = {
  attachment: SitrepAttachment
  paths: SessionPaths
  /** The window's own file, as it last wrote it. */
  text: string
  presence: Presence
  read: Reader
  timers: Timer[]
  /** The board last put in `$.state`, as JSON, so a fold that changed nothing puts nothing. */
  shown?: string
  /** Every ask the window has seen the session hold; unset until its first fold. */
  heard?: ReadonlySet<string>
}

let current: Hold | undefined

let queue: Promise<unknown> = Promise.resolve()

/** Runs `task` once every task before it has settled. */
export const serially = <T>(task: () => Promise<T>): Promise<T> => {
  const turn = queue.then(task, task)

  queue = turn.catch(() => undefined)

  return turn
}

/** The session this window holds, if any. */
export const attached = () => current?.attachment

const beat = async (host: Host, hold: Hold, presence: Presence) => {
  await host.fs.write(hold.paths.heartbeat(hold.attachment.writer), presenceText(presence))
  hold.presence = presence
}

/** Announces the open asks the session holds that the window had not seen; none at its first fold. */
const hear = async (host: Host, hold: Hold, session: Session) => {
  const { heard } = hold
  const landed =
    heard === undefined ? [] : session.asks.filter(ask => isOpen(ask) && !heard.has(ask.id))

  hold.heard = new Set(session.asks.map(ask => ask.id))
  await announce(host, session.id, landed)
}

const show = async (host: Host, hold: Hold, session: Session) => {
  const shown = boardOf(session)
  const json = JSON.stringify(shown)

  if (json !== hold.shown) {
    await host.state.board.write(shown)
    hold.shown = json
    await hear(host, hold, session)
    await settleAnswering(host)
  }
}

/**
 * The held session folded as it stands, put in `$.state` when it changed.
 * Undefined with no session held, or with its session.json missing or torn.
 */
export const refresh = async (host: Host): Promise<Session | undefined> => {
  const hold = current

  if (hold === undefined) {
    return undefined
  }

  const files = await hold.read(host, hold.paths)
  const logs = { ...files.logs, [hold.attachment.writer]: hold.text }
  const session = foldSession({ ...files, logs }, await host.clock.now())

  if (session !== undefined) {
    await show(host, hold, session)
  }

  return session
}

/** What the window is doing, as its heartbeat says it: from what it has heard, before any turn your turn since `attachedAt`. */
const stateNow = async (host: Host, attachedAt: number) =>
  stateOf(await activityNow(host), attachedAt)

/** The beat, saying the state as it stands, and the watch, each run in turn and only while `hold` is still the window's. */
const timersFor = (host: Host, hold: Hold) => {
  const whileHeld = (what: string, task: () => Promise<unknown>) => () =>
    void serially(() => (current === hold ? task() : Promise.resolve())).catch(
      logFailure(host, what),
    )

  return [
    host.clock.every(
      HEARTBEAT_MS,
      whileHeld('the heartbeat', async () =>
        beat(
          host,
          hold,
          heartbeat(
            { ...hold.presence, state: await stateNow(host, hold.presence.attachedAt) },
            await host.clock.now(),
          ),
        ),
      ),
    ),
    host.clock.every(
      WATCH_MS,
      whileHeld('the watch', () => refresh(host)),
    ),
  ]
}

/** Puts nothing in `$.state` for drawing: no session is held, and nothing of one is being answered. */
const forget = async (host: Host) => {
  await host.state.attachment.write(null)
  await host.state.board.write(null)
  await endAnswering(host)
}

/**
 * Rewrites the heartbeat of the held session with what the window is doing,
 * should that differ from what it last said: whether it did. With no
 * session held, nothing: the window's state waits for its next attach.
 */
export const restate = (host: Host) =>
  serially(async () => {
    const hold = current

    if (hold === undefined) {
      return false
    }

    const state = await stateNow(host, hold.presence.attachedAt)

    if (JSON.stringify(state) === JSON.stringify(hold.presence.state)) {
      return false
    }

    await beat(host, hold, heartbeat({ ...hold.presence, state }, await host.clock.now()))

    return true
  })

/** Lets go of the held session: the heartbeat says so, and the beat and the watch stop. */
export const letGo = async (host: Host) => {
  const hold = current

  if (hold === undefined) {
    return
  }

  current = undefined

  for (const timer of hold.timers) {
    timer.cancel()
  }

  try {
    await beat(host, hold, leave(hold.presence, await host.clock.now()))
  } finally {
    await forget(host)
  }
}

/**
 * Holds the session `attaching` names, letting go of any other first: reads
 * the window's own file back, under either layout, works out where the
 * window is, writes its heartbeat, saying the version it runs and what it is
 * doing as it stands, starts the beat and the watch, and folds the session.
 */
export const attachTo = async (host: Host, root: string, attaching: SitrepAttachment) => {
  const { project, session, writer, attachedAt } = attaching
  const paths = sessionPaths(root, project, session)
  const [where, version, state] = await Promise.all([
    whereNow(host),
    versionNow(host),
    stateNow(host, attachedAt),
  ])
  const hold: Hold = {
    attachment: attaching,
    paths,
    text: await ownText(host, paths, folder => folder.log(writer)),
    presence: attach(writer, attachedAt, { where, version, state }),
    read: createReader(),
    timers: [],
  }

  await letGo(host)
  await beat(host, hold, heartbeat(hold.presence, await host.clock.now()))
  current = hold
  await host.state.attachment.write(attaching)
  hold.timers = timersFor(host, hold)

  return refresh(host)
}

/**
 * Takes the held session up again from `$.state`, after a reload of the
 * mod's code or a restart of its worker. A hold left by another
 * conversation (one that ended without letting go) is dropped instead: its
 * file is not this one's.
 */
export const resume = async (host: Host) => {
  const kept = await host.state.attachment.read()

  if (kept === null || current !== undefined) {
    return
  }

  if (kept.writer !== (await host.conversation.id())) {
    await forget(host)

    return
  }

  await attachTo(host, await rootFor(host), kept)
}

/** Writes lines to the end of the window's own file, the whole file at once under today's layout, and folds the session again. */
export const post = async (host: Host, bodies: readonly Body[]) => {
  const hold = current

  if (hold === undefined) {
    throw new Error('no session is held to post to')
  }

  const { text } = append(hold.text, bodies, await host.clock.now())

  await host.fs.write(hold.paths.log(hold.attachment.writer), text)
  hold.text = text

  return refresh(host)
}
