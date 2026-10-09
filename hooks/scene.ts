/**
 * What the board and the band are drawn from, as plain data:
 * the held work, the works around it as last read, the window's own state,
 * and the time. Read inside a render hook, each read subscribes the
 * drawing, so a write draws it again.
 */
import type { Timer } from 'claude-code'
import { closingReply, isOpen, type Ask, type Work } from '../core'
import type {
  SitrepAnswering,
  SitrepInFlight,
  SitrepPane,
  SitrepPlace,
  SitrepProject,
  SitrepPulse,
  SitrepQueued,
  SitrepSent,
} from '../types'
import { workOf } from './board'
import { logFailure, type Host } from './host'
import { C, pulseOf } from './look'

/** How long an ask Lee's send closed stays in its place, ticked, before it folds into the count. */
export const LINGER_MS = 8_000

/** How often the board is drawn again for the time alone, so its ages move on. */
const TICK_MS = 30_000

/** A work as folded, and the project it is filed under, by key. */
export type Filed = { project: string; work: Work }

export type Scene = {
  /** The held work. */
  work: Work
  /** The project the held work is filed under. */
  here: string
  /** Where the board is looking: this session, unless Lee went elsewhere. */
  place: SitrepPlace
  /** The projects around the held work, as last read. */
  projects: readonly SitrepProject[]
  /** The other works the board draws in full, by id. */
  others: ReadonlyMap<string, Filed>
  /** Ready to send: every work's replies, in the order queued. */
  queue: readonly SitrepQueued[]
  /** The message on its way to Claude: a send of Lee's, its replies frozen in the queue, or the inbox's. */
  inFlight: SitrepInFlight | null
  sent: readonly SitrepSent[]
  pane: SitrepPane
  /** The ask Lee is answering in the prompt box, as `$.state` holds it: whether it still stands is `answeringIn`'s to say. */
  answering: SitrepAnswering | null
  pulse: SitrepPulse
  flash: number
  now: number
}

let ticking: Timer | undefined

/** The scene as it stands; undefined while no work is held. */
export const sceneOf = async (host: Host): Promise<Scene | undefined> => {
  const [board, held, projects, others, queue, inFlight, sent, pane, answering, pulse, flash, now] =
    await Promise.all([
      host.state.board.read(),
      host.state.attachment.read(),
      host.state.projects.read(),
      host.state.others.read(),
      host.state.queue.read(),
      host.state.inFlight.read(),
      host.state.sent.read(),
      host.state.pane.read(),
      host.state.answering.read(),
      host.state.pulse.read(),
      host.state.flash.read(),
      host.clock.now(),
      // Read only so the drawing is subscribed to it: a tick draws the scene again.
      host.state.tick.read(),
    ])

  if (board === null || held === null) {
    return undefined
  }

  return {
    work: workOf(board),
    here: held.project,
    place: pane.place ?? { level: 'session', project: held.project, work: held.work },
    projects,
    others: new Map(
      others.map(({ project, board: other }) => [other.id, { project, work: workOf(other) }]),
    ),
    queue,
    inFlight,
    sent,
    pane,
    answering,
    pulse,
    flash,
    now,
  }
}

/** The held work, as the board in `$.state` has it. */
export const heldWork = async (host: Host) => {
  const board = await host.state.board.read()

  return board === null ? undefined : workOf(board)
}

const tick = (host: Host) => () =>
  void host.state.tick.update(count => count + 1).catch(logFailure(host, 'the tick'))

/** Draws the scene again every so often, so its ages move on; a session started again keeps one tick. */
export const tickEvery = (host: Host) => {
  ticking?.cancel()
  ticking = host.clock.every(TICK_MS, tick(host))
}

/** Draws the scene again once `ms` have passed. */
export const tickAfter = (host: Host, ms: number) => host.clock.after(ms, tick(host))

/** An ask a reply of Lee's just closed. One Claude resolved after Lee commented was closed by Claude, and does not linger. */
const isLingering = (ask: Ask, now: number) =>
  closingReply(ask) !== undefined && ask.closedAt !== undefined && now - ask.closedAt < LINGER_MS

/** For you: the open asks, and those Lee's send just closed, the newest first. */
export const forYou = (work: Work, now: number) =>
  work.asks.filter(ask => isOpen(ask) || isLingering(ask, now)).reverse()

/** The asks closed earlier than that, ignored ones aside, the newest closed first. */
export const doneEarlier = (work: Work, now: number) =>
  work.asks
    .filter(ask => ask.state === 'closed' && !isLingering(ask, now))
    .sort((a, b) => (b.closedAt ?? b.at) - (a.closedAt ?? a.at))

/** Whether an ask is one of those pulsing as new; with no ask, whether any is. Only the held work's asks pulse. */
export const isPulsing = ({ pulse, work }: Scene, ask?: Ask) =>
  pulse.frames > 0 &&
  (ask === undefined || (pulse.asks.includes(ask.id) && work.asks.includes(ask)))

/** An ask's ◆ as it stands in the pulse; with no ask, the ◆ any new ask pulses. */
export const askMark = (scene: Scene, ask?: Ask) =>
  pulseOf(isPulsing(scene, ask) ? scene.pulse.frames : 0)

/** The ◆ beside the count of asks waiting: grey while none waits or pulses. */
export const countMark = (scene: Scene) => {
  const mark = askMark(scene)

  return scene.work.waiting > 0 || isPulsing(scene) ? mark : { ...mark, color: C.grey }
}
