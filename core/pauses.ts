/**
 * A reader's pauses: time it was not running, as when it or the Mac slept.
 * A heartbeat ages only while the reader runs, so a pause counts toward no
 * window's going stale: a window live as a pause began has the rest of its
 * time after it to beat again, and one stale before it stays stale. A pause
 * is told by the gap between two looks, not by the clock: whether a clock
 * runs while the Mac sleeps is nothing to rely on.
 */
import { STALE_MS } from './presence'
import type { Presence } from './types'

/**
 * The longest two looks of a reader's are apart while it runs: `sitrep
 * watch` looks every second, and a look takes milliseconds. A longer gap is
 * a pause, all of it.
 */
export const PAUSE_MS = 5_000

/** A gap no look was made in, from the look before it to the look after. */
export type Pause = { from: number; to: number }

/**
 * A reader's time as its looks tell it: when it last looked, how long it
 * has been paused in all, and the pauses a heartbeat may still be live
 * across.
 */
export type Clock = { at: number; paused: number; pauses: readonly Pause[] }

const pausedSince = (pauses: readonly Pause[], at: number) =>
  pauses.reduce((sum, pause) => sum + Math.max(0, pause.to - Math.max(pause.from, at)), 0)

/** A heartbeat as a reader paused through `pauses` ages it: seen later by the time paused since. */
export const unpaused = (presence: Presence, pauses: readonly Pause[]): Presence => {
  const paused = pausedSince(pauses, presence.seenAt)

  return paused === 0 ? presence : { ...presence, seenAt: presence.seenAt + paused }
}

/**
 * The clock at a look at `now`, the gap since the look before a pause where
 * it is longer than PAUSE_MS. A pause is let go once the reader has run
 * STALE_MS since it: every heartbeat seen before it is stale with it or
 * without it.
 */
export const clockAt = (last: Clock | undefined, now: number): Clock => {
  if (last === undefined) {
    return { at: now, paused: 0, pauses: [] }
  }

  const gap = now - last.at
  const isPause = gap > PAUSE_MS
  const pauses = isPause ? [...last.pauses, { from: last.at, to: now }] : last.pauses

  return {
    at: now,
    paused: last.paused + (isPause ? gap : 0),
    pauses: pauses.filter(pause => now - pause.to - pausedSince(pauses, pause.to) <= STALE_MS),
  }
}

/** The reader's own time at its last look: the instant, less every pause before it. */
export const ownTime = (clock: Clock) => clock.at - clock.paused
