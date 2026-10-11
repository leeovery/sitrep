/**
 * This window's hold on a piece of work: its own file, its heartbeat, and a
 * watch that keeps the work's fold current in `$.state` and tells Lee of an
 * ask that lands. A window holds at most one work.
 *
 * Whatever reads or changes the hold runs in turn (`serially`), so two tool
 * calls never write the window's file over each other, and a heartbeat never
 * lands after the window let go.
 */
import type { Timer } from 'claude-code'
import {
  append,
  attach,
  foldWork,
  heartbeat,
  HEARTBEAT_MS,
  isOpen,
  leave,
  presenceText,
  workPaths,
  type Body,
  type Presence,
  type Work,
  type WorkPaths,
} from '../core'
import type { SitrepAttachment } from '../types'
import { endAnswering, settleAnswering } from './answering'
import { boardOf } from './board'
import { logFailure, rootFor, type Host } from './host'
import { announce } from './news'
import { createReader, ownText, type Reader } from './reader'

/** How often the watch lists the work's folders for what changed. */
export const WATCH_MS = 1_500

type Hold = {
  attachment: SitrepAttachment
  paths: WorkPaths
  /** The window's own file, as it last wrote it. */
  text: string
  presence: Presence
  read: Reader
  timers: Timer[]
  /** The board last put in `$.state`, as JSON, so a fold that changed nothing puts nothing. */
  shown?: string
  /** Every ask the window has seen the work hold; unset until its first fold. */
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

/** The work this window holds, if any. */
export const attached = () => current?.attachment

const beat = async (host: Host, hold: Hold, presence: Presence) => {
  await host.fs.write(hold.paths.heartbeat(hold.attachment.writer), presenceText(presence))
  hold.presence = presence
}

/** Announces the open asks the work holds that the window had not seen; none at its first fold. */
const hear = async (host: Host, hold: Hold, work: Work) => {
  const { heard } = hold
  const landed =
    heard === undefined ? [] : work.asks.filter(ask => isOpen(ask) && !heard.has(ask.id))

  hold.heard = new Set(work.asks.map(ask => ask.id))
  await announce(host, work.id, landed)
}

const show = async (host: Host, hold: Hold, work: Work) => {
  const shown = boardOf(work)
  const json = JSON.stringify(shown)

  if (json !== hold.shown) {
    await host.state.board.write(shown)
    hold.shown = json
    await hear(host, hold, work)
    await settleAnswering(host)
  }
}

/**
 * The held work folded as it stands, put in `$.state` when it changed.
 * Undefined with no work held, or with its work.json missing or torn.
 */
export const refresh = async (host: Host): Promise<Work | undefined> => {
  const hold = current

  if (hold === undefined) {
    return undefined
  }

  const files = await hold.read(host, hold.paths)
  const logs = { ...files.logs, [hold.attachment.writer]: hold.text }
  const work = foldWork({ ...files, logs }, await host.clock.now())

  if (work !== undefined) {
    await show(host, hold, work)
  }

  return work
}

/** The beat and the watch, each run in turn and only while `hold` is still the window's. */
const timersFor = (host: Host, hold: Hold) => {
  const whileHeld = (what: string, task: () => Promise<unknown>) => () =>
    void serially(() => (current === hold ? task() : Promise.resolve())).catch(
      logFailure(host, what),
    )

  return [
    host.clock.every(
      HEARTBEAT_MS,
      whileHeld('the heartbeat', async () =>
        beat(host, hold, heartbeat(hold.presence, await host.clock.now())),
      ),
    ),
    host.clock.every(
      WATCH_MS,
      whileHeld('the watch', () => refresh(host)),
    ),
  ]
}

/** Puts nothing in `$.state` for drawing: no work is held, and no ask of one is being answered. */
const forget = async (host: Host) => {
  await host.state.attachment.write(null)
  await host.state.board.write(null)
  await endAnswering(host)
}

/** Lets go of the held work: the heartbeat says so, and the beat and the watch stop. */
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
 * Holds the work `attaching` names, letting go of any other first: reads the
 * window's own file back, writes its heartbeat, starts the beat and the
 * watch, and folds the work.
 */
export const attachTo = async (host: Host, root: string, attaching: SitrepAttachment) => {
  const { project, work, writer, attachedAt } = attaching
  const paths = workPaths(root, project, work)
  const hold: Hold = {
    attachment: attaching,
    paths,
    text: await ownText(host, paths.log(writer)),
    presence: attach(writer, attachedAt),
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
 * Takes the held work up again from `$.state`, after a reload of the mod's
 * code or a restart of its worker. A hold left by another session (one that
 * ended without letting go) is dropped instead: its file is not this one's.
 */
export const resume = async (host: Host) => {
  const kept = await host.state.attachment.read()

  if (kept === null || current !== undefined) {
    return
  }

  if (kept.writer !== (await host.session.id())) {
    await forget(host)

    return
  }

  await attachTo(host, await rootFor(host), kept)
}

/** Writes lines to the end of the window's own file, the whole file at once, and folds the work again. */
export const post = async (host: Host, bodies: readonly Body[]) => {
  const hold = current

  if (hold === undefined) {
    throw new Error('no piece of work is held to post to')
  }

  const { text } = append(hold.text, bodies, await host.clock.now())

  await host.fs.write(hold.paths.log(hold.attachment.writer), text)
  hold.text = text

  return refresh(host)
}
