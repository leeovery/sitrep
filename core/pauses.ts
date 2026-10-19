/**
 * A reader's pauses: time the Mac slept while it ran. A heartbeat ages only
 * while the Mac is awake, so a pause counts toward no window's going stale:
 * a window live as the Mac slept has the rest of its time after the wake to
 * beat again, and one stale before stays stale.
 *
 * A sleep is told from a stall by two clocks: the wall clock, which runs on
 * while the Mac sleeps, and its uptime, which does not (on Bun,
 * `performance.now()`, Rust's `Instant`: CLOCK_UPTIME_RAW on macOS). How
 * far the wall clock moved beyond the uptime between two looks is the time
 * the Mac slept. A look held back, by App Nap, by timers coalesced or by a
 * slow look of its own, moves both alike and pauses nothing. Clocks that
 * disagree otherwise, the uptime going back or outrunning the wall, pause
 * nothing either.
 */
import { STALE_MS } from './presence'
import type { Presence } from './types'

/** The least sleep that is a pause: less is drift between the clocks, or no matter. */
export const PAUSE_MS = 5_000

/** The most pauses a reader keeps, however its clocks run, so none can grow without bound. */
export const MAX_PAUSES = 10

/** A sleep, by the wall clock, ending at the look that found it; `up` the uptime then. */
export type Pause = { from: number; to: number; up: number }

/**
 * A reader's time as its looks tell it: the wall clock and the uptime at its
 * last look, how long the Mac has slept in all since it began, and the
 * pauses a heartbeat may still be live across.
 */
export type Clock = { at: number; up: number; paused: number; pauses: readonly Pause[] }

const pausedSince = (pauses: readonly Pause[], at: number) =>
  pauses.reduce((sum, pause) => sum + Math.max(0, pause.to - Math.max(pause.from, at)), 0)

/** A heartbeat as a reader paused through `pauses` ages it: seen later by the time paused since. */
export const unpaused = (presence: Presence, pauses: readonly Pause[]): Presence => {
  const paused = pausedSince(pauses, presence.seenAt)

  return paused === 0 ? presence : { ...presence, seenAt: presence.seenAt + paused }
}

/** How long the Mac slept between two looks: the wall clock's move beyond the uptime's; none where the uptime went back. */
const sleptBetween = (last: Clock, now: number, up: number) => {
  const ran = up - last.up

  return ran < 0 ? 0 : now - last.at - ran
}

/**
 * The clock at a look at `now`, the uptime `up`: a sleep since the look
 * before longer than PAUSE_MS is a pause. A pause is let go once the Mac
 * has been awake STALE_MS since it, every heartbeat seen before it stale
 * with it or without it, and the oldest beyond MAX_PAUSES whatever the
 * clocks say.
 */
export const clockAt = (last: Clock | undefined, now: number, up: number): Clock => {
  if (last === undefined) {
    return { at: now, up, paused: 0, pauses: [] }
  }

  const slept = sleptBetween(last, now, up)
  const isPause = slept > PAUSE_MS
  const pauses = isPause ? [...last.pauses, { from: now - slept, to: now, up }] : last.pauses

  return {
    at: now,
    up,
    paused: last.paused + (isPause ? slept : 0),
    pauses: pauses.filter(pause => up - pause.up <= STALE_MS).slice(-MAX_PAUSES),
  }
}

/** The reader's own time at its last look: the instant, less every pause before it. */
export const ownTime = (clock: Clock) => clock.at - clock.paused
