/**
 * What the board and the band are drawn from, as plain data: the held
 * session, the sessions around it as last read, the window's own state, and
 * the time. Read inside a render hook, each read subscribes the drawing, so
 * a write draws it again.
 */
import type { Timer } from 'claude-code'
import { closingReply, isOpen, resolvedAsks, type Ask, type Session } from '../core'
import type {
  SitrepAnswering,
  SitrepInFlight,
  SitrepPane,
  SitrepPlace,
  SitrepProject,
  SitrepPulse,
  SitrepQueued,
  SitrepScroll,
  SitrepSent,
} from '../types'
import { sessionOf } from './board'
import { logFailure, type Host } from './host'
import { C, pulseOf } from './look'

/** How long an ask Lee's send closed stays in its place, ticked, before it folds into the count. */
export const LINGER_MS = 8_000

/** How often the board is drawn again for the time alone, so its ages move on. */
const TICK_MS = 30_000

/** A session as folded, and the project it is filed under, by key. */
export type Filed = { project: string; session: Session }

export type Scene = {
  /** The held session. */
  session: Session
  /** The project the held session is filed under. */
  here: string
  /** Where the board is looking: this session, unless Lee went elsewhere. */
  place: SitrepPlace
  /** The projects around the held session, as last read. */
  projects: readonly SitrepProject[]
  /** The other sessions the board draws in full, by id. */
  others: ReadonlyMap<string, Filed>
  /** Ready to send: every session's replies, in the order queued. */
  queue: readonly SitrepQueued[]
  /** The messages on their way to Claude, in the order claimed: sends of Lee's, their replies frozen in the queue, or the inbox's. */
  inFlight: readonly SitrepInFlight[]
  sent: readonly SitrepSent[]
  pane: SitrepPane
  /** How far down the docked board's list stands, at the place it was moved at. */
  scroll: SitrepScroll | null
  /** The item Lee is answering in the prompt box, as `$.state` holds it: whether it still stands is `answeringIn`'s to say. */
  answering: SitrepAnswering | null
  pulse: SitrepPulse
  flash: number
  now: number
}

let ticking: Timer | undefined

/** The scene as it stands; undefined while no session is held. */
export const sceneOf = async (host: Host): Promise<Scene | undefined> => {
  const [
    board,
    held,
    projects,
    others,
    queue,
    inFlight,
    sent,
    pane,
    scroll,
    answering,
    pulse,
    flash,
    now,
  ] = await Promise.all([
    host.state.board.read(),
    host.state.attachment.read(),
    host.state.projects.read(),
    host.state.others.read(),
    host.state.queue.read(),
    host.state.inFlight.read(),
    host.state.sent.read(),
    host.state.pane.read(),
    host.state.scroll.read(),
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
    session: sessionOf(board),
    here: held.project,
    place: pane.place ?? { level: 'session', project: held.project, session: held.session },
    projects,
    others: new Map(
      others.map(({ project, board: other }) => [other.id, { project, session: sessionOf(other) }]),
    ),
    queue,
    inFlight,
    sent,
    pane,
    scroll,
    answering,
    pulse,
    flash,
    now,
  }
}

/** The held session, as the board in `$.state` has it. */
export const heldSession = async (host: Host) => {
  const board = await host.state.board.read()

  return board === null ? undefined : sessionOf(board)
}

const tick = (host: Host) => () =>
  void host.state.tick.update(count => count + 1).catch(logFailure(host, 'the tick'))

/** Draws the scene again every so often, so its ages move on; a window started again keeps one tick. */
export const tickEvery = (host: Host) => {
  ticking?.cancel()
  ticking = host.clock.every(TICK_MS, tick(host))
}

/** Draws the scene again once `ms` have passed. */
export const tickAfter = (host: Host, ms: number) => host.clock.after(ms, tick(host))

/** An ask a reply of Lee's just closed. One Claude resolved after Lee commented was closed by Claude, and does not linger. */
const isLingering = (ask: Ask, now: number) =>
  closingReply(ask) !== undefined && ask.closedAt !== undefined && now - ask.closedAt < LINGER_MS

/** Asks: the open asks, and those Lee's send just closed, the newest first. */
export const shownAsks = (session: Session, now: number) =>
  session.asks.filter(ask => isOpen(ask) || isLingering(ask, now)).reverse()

/** The asks closed earlier than that, ignored ones aside, the newest closed first. */
export const resolvedEarlier = (session: Session, now: number) =>
  resolvedAsks(session).filter(ask => !isLingering(ask, now))

/** Whether an ask is one of those pulsing as new; with no ask, whether any is. Only the held session's asks pulse. */
export const isPulsing = ({ pulse, session }: Scene, ask?: Ask) =>
  pulse.frames > 0 &&
  (ask === undefined || (pulse.asks.includes(ask.id) && session.asks.includes(ask)))

/** An ask's ◆ as it stands in the pulse; with no ask, the ◆ any new ask pulses. */
export const askMark = (scene: Scene, ask?: Ask) =>
  pulseOf(isPulsing(scene, ask) ? scene.pulse.frames : 0)

/** The ◆ beside the count of asks waiting: grey while none waits or pulses. */
export const countMark = (scene: Scene) => {
  const mark = askMark(scene)

  return scene.session.waiting > 0 || isPulsing(scene) ? mark : { ...mark, color: C.grey }
}
