import { expect, test } from 'claude-code/testing'
import {
  clockAt,
  foldSession,
  isLive,
  metaText,
  nextExpiry,
  ownTime,
  PAUSE_MS,
  rowsOf,
  STALE_MS,
  unpaused,
  type Clock,
  type Pause,
  type Presence,
  type Project,
} from '../core'
import { beat, META, MIN, T0, W1, W2 } from './support'

const HOUR = 60 * MIN

const SWITCHBOARD: Project = { key: 'switchboard', name: 'Switchboard' }

/** A clock's looks, a second apart, for `ms`: the watch running on. */
const ran = (clock: Clock, ms: number) =>
  Array.from({ length: ms / 1_000 }).reduce<Clock>(each => clockAt(each, each.at + 1_000), clock)

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

test('a gap between looks longer than PAUSE_MS is a pause, all of it; a shorter one, the first look and a clock set back are none', () => {
  const first = clockAt(undefined, T0)
  const near = clockAt(first, T0 + PAUSE_MS)
  const slept = clockAt(near, T0 + PAUSE_MS + HOUR)

  expect(first).toEqual({ at: T0, paused: 0, pauses: [] })
  expect(near).toEqual({ at: T0 + PAUSE_MS, paused: 0, pauses: [] })
  expect(slept).toEqual({
    at: T0 + PAUSE_MS + HOUR,
    paused: HOUR,
    pauses: [{ from: T0 + PAUSE_MS, to: T0 + PAUSE_MS + HOUR }],
  })
  expect(ownTime(slept)).toBe(T0 + PAUSE_MS)
  expect(clockAt(slept, slept.at - HOUR)).toMatchObject({ paused: HOUR })
})

test('a window live as the watch paused has the rest of its time after it to beat again; one stale before it stays stale', () => {
  const asleep = T0 + MIN
  const awake = asleep + HOUR
  const { pauses } = clockAt(clockAt(undefined, asleep), awake)
  const live = seenAt(W1, asleep - 30_000)
  const stale = seenAt(W2, asleep - STALE_MS - 1)

  expect(unpaused(live, pauses).seenAt).toBe(live.seenAt + HOUR)
  expect(isLive(unpaused(live, pauses), awake + 60_000)).toBe(true)
  expect(isLive(unpaused(live, pauses), awake + 60_001)).toBe(false)
  expect(isLive(unpaused(stale, pauses), awake)).toBe(false)
  expect(unpaused(seenAt(W1, awake), pauses).seenAt).toBe(awake)
})

test('a session folded across a pause holds its window, its stop still a row, until the rest of its time has run; the next expiry follows', () => {
  const asleep = T0 + MIN
  const awake = asleep + HOUR
  const { pauses } = clockAt(clockAt(undefined, asleep), awake)
  const window = seenAt(W1, asleep - 30_000)
  const across = folded(awake, pauses, window)
  const unaware = folded(awake, [], window)

  expect(across.isOpen).toBe(true)
  expect(rowsOf(SWITCHBOARD, across, awake).map(row => row.key)).toEqual([
    `stop:${META.id}:${W1}:${T0}`,
  ])
  expect(nextExpiry([{ project: SWITCHBOARD, sessions: [across] }], awake)).toBe(awake + 60_001)
  expect(unaware.isOpen).toBe(false)
  expect(rowsOf(SWITCHBOARD, unaware, awake)).toEqual([])
})

test('pauses add up, the time run between them counting', () => {
  const window = seenAt(W1, T0)
  const once = clockAt(clockAt(undefined, T0 + 10_000), T0 + 10_000 + HOUR)
  const twice = clockAt(ran(once, 40_000), once.at + 40_000 + HOUR)

  expect(twice.paused).toBe(2 * HOUR)
  expect(twice.at - unpaused(window, twice.pauses).seenAt).toBe(50_000)
})

test('a pause is let go once the watch has run STALE_MS past it, when every heartbeat seen before it is stale with it or without it', () => {
  const slept = clockAt(clockAt(undefined, T0), T0 + HOUR)
  const kept = ran(slept, STALE_MS)
  const past = clockAt(kept, kept.at + 1)
  const window = seenAt(W1, T0)

  expect(kept.pauses).toEqual([{ from: T0, to: T0 + HOUR }])
  expect(past.pauses).toEqual([])
  expect(past.paused).toBe(HOUR)
  expect(isLive(unpaused(window, kept.pauses), past.at)).toBe(false)
})
