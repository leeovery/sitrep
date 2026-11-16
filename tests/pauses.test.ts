import { expect, test } from './kit'
import {
  clockAt,
  foldSession,
  isLive,
  MAX_PAUSES,
  metaText,
  nextExpiry,
  ownTime,
  PAUSE_MS,
  rowOf,
  STALE_MS,
  unpaused,
  type Clock,
  type Pause,
  type Presence,
  type Project,
} from '../core'
import { beat, META, MIN, T0, W1, W2 } from './support'

const HOUR = 60 * MIN

const NORTHWIND: Project = { key: 'northwind', name: 'Northwind' }

/** A clock after `count` more looks, each `wall` milliseconds on by the wall clock and `up` by the uptime. */
const looked = (clock: Clock, count: number, wall: number, up: number) =>
  Array.from({ length: count }).reduce<Clock>(
    each => clockAt(each, each.at + wall, each.up + up),
    clock,
  )

/** A window seen at `seenAt`, stopped on a permission prompt since T0. */
const seenAt = (writer: string, at: number): Presence => ({
  writer,
  attachedAt: T0,
  seenAt: at,
  version: '0.2.0',
  state: { is: 'permission', since: T0, tool: { name: 'Bash', subject: 'ls' } },
})

/** The session, its windows seen as given, folded at `now` with no heartbeat aging through `pauses`. */
const folded = (now: number, pauses: readonly Pause[], ...beats: Presence[]) => {
  const session = foldSession(
    {
      meta: metaText(META),
      logs: {},
      presence: Object.fromEntries(beats.map(each => [each.writer, beat(each.writer, each)])),
    },
    now,
    pauses,
  )

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

test('a look held back, both clocks moving alike, pauses nothing however long; a sleep, the wall clock alone moving, is a pause of the time slept; a gap holding both pauses the sleep in it alone', () => {
  const first = clockAt(undefined, T0, 0)

  expect(first).toEqual({ at: T0, up: 0, paused: 0, pauses: [] })
  expect(clockAt(first, T0 + HOUR, HOUR)).toEqual({
    at: T0 + HOUR,
    up: HOUR,
    paused: 0,
    pauses: [],
  })
  expect(clockAt(first, T0 + HOUR, 1_000)).toEqual({
    at: T0 + HOUR,
    up: 1_000,
    paused: HOUR - 1_000,
    pauses: [{ from: T0 + 1_000, to: T0 + HOUR, up: 1_000 }],
  })
  expect(clockAt(first, T0 + 20_000 + HOUR, 20_000)).toMatchObject({
    paused: HOUR,
    pauses: [{ from: T0 + 20_000, to: T0 + 20_000 + HOUR, up: 20_000 }],
  })
  expect(ownTime(clockAt(first, T0 + 20_000 + HOUR, 20_000))).toBe(T0 + 20_000)
  expect(clockAt(first, T0 + PAUSE_MS + 1_000, 1_000)).toMatchObject({ paused: 0, pauses: [] })
})

test('clocks that disagree pause nothing: the uptime going back, or outrunning the wall clock', () => {
  const first = clockAt(undefined, T0, HOUR)

  expect(clockAt(first, T0 + HOUR, HOUR - 1)).toMatchObject({ paused: 0, pauses: [] })
  expect(clockAt(first, T0 + 1_000, 2 * HOUR)).toMatchObject({ paused: 0, pauses: [] })
})

test('looks held back to every 6 seconds for an hour, as App Nap would, pause nothing: a window gone an hour is stale', () => {
  const napped = looked(clockAt(undefined, T0, 0), HOUR / 6_000, 6_000, 6_000)

  expect(napped).toMatchObject({ at: T0 + HOUR, paused: 0, pauses: [] })
  expect(isLive(unpaused(seenAt(W1, T0), napped.pauses), napped.at)).toBe(false)
})

test('however the clocks run, no more than MAX_PAUSES are kept, the oldest let go first: an uptime that never moves leaves a window gone an hour stale', () => {
  const stuck = looked(clockAt(undefined, T0, 0), HOUR / 6_000, 6_000, 0)

  expect(stuck.pauses.length).toBe(MAX_PAUSES)
  expect(stuck.pauses[0]).toEqual({
    from: stuck.at - MAX_PAUSES * 6_000,
    to: stuck.at - (MAX_PAUSES - 1) * 6_000,
    up: 0,
  })
  expect(isLive(unpaused(seenAt(W1, T0), stuck.pauses), stuck.at)).toBe(false)
})

test('a window live as the Mac slept has the rest of its time after the wake to beat again; one stale before it stays stale', () => {
  const asleep = T0 + MIN
  const awake = asleep + HOUR
  const { pauses } = clockAt(clockAt(undefined, asleep, 0), awake, 0)
  const live = seenAt(W1, asleep - 30_000)
  const stale = seenAt(W2, asleep - STALE_MS - 1)

  expect(unpaused(live, pauses).seenAt).toBe(live.seenAt + HOUR)
  expect(isLive(unpaused(live, pauses), awake + 60_000)).toBe(true)
  expect(isLive(unpaused(live, pauses), awake + 60_001)).toBe(false)
  expect(isLive(unpaused(stale, pauses), awake)).toBe(false)
  expect(unpaused(seenAt(W1, awake), pauses).seenAt).toBe(awake)
})

test('a session folded across a sleep holds its window, its stop still a row, until the rest of its time has run; the next expiry follows', () => {
  const asleep = T0 + MIN
  const awake = asleep + HOUR
  const { pauses } = clockAt(clockAt(undefined, asleep, 0), awake, 0)
  const window = seenAt(W1, asleep - 30_000)
  const across = folded(awake, pauses, window)
  const unaware = folded(awake, [], window)

  expect(across.isOpen).toBe(true)
  expect(rowOf(NORTHWIND, across, awake)?.lines.map(line => line.key)).toEqual([
    `stop:${META.id}:${W1}:${T0}`,
  ])
  expect(nextExpiry([{ project: NORTHWIND, sessions: [across] }], awake)).toBe(awake + 60_001)
  expect(unaware.isOpen).toBe(false)
  expect(rowOf(NORTHWIND, unaware, awake)).toBeUndefined()
})

test('pauses add up, the time awake between them counting', () => {
  const window = seenAt(W1, T0)
  const once = clockAt(clockAt(undefined, T0 + 10_000, 0), T0 + 10_000 + HOUR, 0)
  const ran = looked(once, 40, 1_000, 1_000)
  const twice = clockAt(ran, ran.at + HOUR, ran.up)

  expect(twice.paused).toBe(2 * HOUR)
  expect(twice.at - unpaused(window, twice.pauses).seenAt).toBe(50_000)
})

test('a pause is let go once the Mac has been awake STALE_MS since it, when every heartbeat seen before it is stale with it or without it', () => {
  const slept = clockAt(clockAt(undefined, T0, 0), T0 + HOUR, 0)
  const kept = looked(slept, STALE_MS / 1_000, 1_000, 1_000)
  const past = clockAt(kept, kept.at + 1, kept.up + 1)
  const window = seenAt(W1, T0)

  expect(kept.pauses).toEqual([{ from: T0, to: T0 + HOUR, up: 0 }])
  expect(past.pauses).toEqual([])
  expect(past.paused).toBe(HOUR)
  expect(isLive(unpaused(window, kept.pauses), past.at)).toBe(false)
})
