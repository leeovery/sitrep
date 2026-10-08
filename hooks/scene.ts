/**
 * What the board, the band and the glance are drawn from, as plain data:
 * the held work, the window's own state, and the time. Read inside a render
 * hook, each read subscribes the drawing, so a write draws it again.
 */
import { isOpen, type Ask, type Work } from '../core'
import type { SitrepPane, SitrepPulse, SitrepQueued } from '../types'
import { workOf } from './board'
import { logFailure, type Host } from './host'
import { C, pulseOf } from './look'
import { queuedFor } from './queue'

/** How long an ask Lee's send closed stays in its place, ticked, before it folds into the count. */
export const LINGER_MS = 8_000

/** How often the board is drawn again for the time alone, so its ages move on. */
const TICK_MS = 30_000

export type Scene = {
  work: Work
  /** This work's replies in Ready to send. */
  queue: readonly SitrepQueued[]
  sending: readonly SitrepQueued[]
  pane: SitrepPane
  pulse: SitrepPulse
  now: number
}

/** The scene as it stands; undefined while no work is held. */
export const sceneOf = async (host: Host): Promise<Scene | undefined> => {
  const [board, queue, sending, pane, pulse, now] = await Promise.all([
    host.state.board.read(),
    host.state.queue.read(),
    host.state.sending.read(),
    host.state.pane.read(),
    host.state.pulse.read(),
    host.clock.now(),
    // Read only so the drawing is subscribed to it: a tick draws the scene again.
    host.state.tick.read(),
  ])

  if (board === null) {
    return undefined
  }

  const work = workOf(board)

  return { work, queue: queuedFor(queue, work.id), sending, pane, pulse, now }
}

/** The held work, as the board in `$.state` has it. */
export const heldWork = async (host: Host) => {
  const board = await host.state.board.read()

  return board === null ? undefined : workOf(board)
}

const tick = (host: Host) => () =>
  void host.state.tick.update(count => count + 1).catch(logFailure(host, 'the tick'))

/** Draws the scene again every so often, so its ages move on. */
export const tickEvery = (host: Host) => host.clock.every(TICK_MS, tick(host))

/** Draws the scene again once `ms` have passed. */
export const tickAfter = (host: Host, ms: number) => host.clock.after(ms, tick(host))

const isLingering = (ask: Ask, now: number) =>
  ask.state === 'closed' &&
  ask.answer !== undefined &&
  ask.closedAt !== undefined &&
  now - ask.closedAt < LINGER_MS

/** For you: the open asks, and those Lee's send just closed, the newest first. */
export const forYou = ({ work, now }: Scene) =>
  work.asks.filter(ask => isOpen(ask) || isLingering(ask, now)).reverse()

/** How many asks closed earlier than that, ignored ones aside. */
export const doneEarlier = ({ work, now }: Scene) =>
  work.asks.filter(ask => ask.state === 'closed' && !isLingering(ask, now)).length

/** Whether an ask is one of those pulsing as new; with no ask, whether any is. */
export const isPulsing = ({ pulse }: Scene, ask?: Ask) =>
  pulse.frames > 0 && (ask === undefined || pulse.asks.includes(ask.id))

/** An ask's ◆ as it stands in the pulse; with no ask, the ◆ any new ask pulses. */
export const askMark = (scene: Scene, ask?: Ask) =>
  pulseOf(isPulsing(scene, ask) ? scene.pulse.frames : 0)

/** The ◆ beside the count of asks waiting: grey while none waits or pulses. */
export const countMark = (scene: Scene) => {
  const mark = askMark(scene)

  return scene.work.waiting > 0 || isPulsing(scene) ? mark : { ...mark, color: C.grey }
}
