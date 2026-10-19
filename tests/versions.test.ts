import { expect, test } from 'claude-code/testing'
import {
  attach,
  heartbeat,
  isMoveHeld,
  leave,
  metaText,
  parseEntries,
  parseMeta,
  parsePresence,
  parseProject,
  presenceText,
  OLD_WINDOW_MS,
  projectText,
  upgraded,
  VERSION,
  versionOf,
  type Upgrade,
} from '../core'
import { META, MIN, T0, W1, W2 } from './support'

/** A made-up past: at version 1, an ask's title was its `heading`. */
const headingToTitle: Upgrade = ({ heading, ...rest }) => ({ ...rest, title: heading })

/** A made-up past: at version 2, a note's detail was one text of lines. */
const detailToLines: Upgrade = raw =>
  typeof raw.detail === 'string' ? { ...raw, detail: raw.detail.split('\n') } : raw

test("a format's version is one past its upgrades; the lines' are at their first, with none", () => {
  expect(versionOf([])).toBe(1)
  expect(versionOf([headingToTitle, detailToLines])).toBe(3)
  expect(VERSION).toBe(1)
})

test('an object of a past version is brought to the format’s shape as it is read, and stamped with the version it reaches', () => {
  const upgrades = [headingToTitle]

  expect(upgraded({ v: 1, type: 'ask', heading: 'Go?' }, upgrades)).toEqual({
    v: 2,
    type: 'ask',
    title: 'Go?',
  })
  expect(upgraded({ v: 2, type: 'ask', title: 'Go?' }, upgrades)).toEqual({
    v: 2,
    type: 'ask',
    title: 'Go?',
  })
})

test('the upgrades chain: each from the object’s own version on, in turn, and none before it', () => {
  const upgrades = [headingToTitle, detailToLines]
  const note = { type: 'note', heading: 'Drawn', detail: 'Frame 1\nFrame 2' }

  expect(upgraded({ v: 1, ...note }, upgrades)).toEqual({
    v: 3,
    type: 'note',
    title: 'Drawn',
    detail: ['Frame 1', 'Frame 2'],
  })
  expect(upgraded({ v: 2, ...note }, upgrades)).toEqual({
    v: 3,
    ...note,
    detail: ['Frame 1', 'Frame 2'],
  })
})

test('an object of a version later than the format’s, or of none, is not read', () => {
  for (const v of [3, 0, -1, 1.5, '1', null, undefined]) {
    expect(upgraded({ v, title: 'Go?' }, [headingToTitle]), String(v)).toBeUndefined()
  }
})

test('the object read is left as it was: an old line keeps its version', () => {
  const raw = { v: 1, heading: 'Go?' }

  upgraded(raw, [headingToTitle])

  expect(raw).toEqual({ v: 1, heading: 'Go?' })
})

test('a line of no version, or of version 0, is skipped as one of a later version is', () => {
  const line = (v: unknown) =>
    JSON.stringify({ v, at: T0, seq: 1, type: 'note', id: 'n1', text: 'hi' })

  expect(parseEntries(line(VERSION))).toHaveLength(1)

  for (const v of [undefined, 0, VERSION + 1, '1']) {
    expect(parseEntries(line(v)), String(v)).toEqual([])
  }
})

test('session.json and project.json each say their version, 1, and neither reads at a later one, nor at none', () => {
  const project = { name: 'SitRep', created: T0, by: W1 }
  const at = (text: string, v: unknown) => JSON.stringify({ ...JSON.parse(text), v })

  expect(JSON.parse(metaText(META)).v).toBe(1)
  expect(JSON.parse(projectText(project)).v).toBe(1)
  expect(parseMeta(at(metaText(META), 1))).toEqual(META)
  expect(parseProject(at(projectText(project), 1))).toEqual(project)

  for (const v of [2, 0, undefined]) {
    expect(parseMeta(at(metaText(META), v)), String(v)).toBeUndefined()
    expect(parseProject(at(projectText(project), v)), String(v)).toBeUndefined()
  }
})

test('a heartbeat says the sitrep version its window runs, through every beat and the leaving', () => {
  const left = leave(attach(W1, T0, { version: '0.1.0' }), T0 + MIN)

  expect(parsePresence(presenceText(left), W1)).toEqual(left)
  expect(parsePresence(presenceText(left), W1)?.version).toBe('0.1.0')
})

test('a heartbeat written before heartbeats said their version reads as ever, with none', () => {
  const read = parsePresence('{"writer":"w","attachedAt":1,"seenAt":2}\n', W1)

  expect(read).toEqual({ writer: W1, attachedAt: 1, seenAt: 2 })
  expect(read?.version).toBeUndefined()
})

test('a bad version is dropped and the heartbeat kept', () => {
  for (const version of [7, '', null, ['0.1.0'], {}]) {
    const read = parsePresence(JSON.stringify({ attachedAt: T0, seenAt: T0, version }), W1)

    expect(read, JSON.stringify(version)).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 })
  }
})

test('the move waits a week on a window on an old version: a heartbeat saying no version, not let go, seen within OLD_WINDOW_MS', () => {
  const now = T0 + 30 * 24 * 60 * MIN
  const old = (seenAt: number) => heartbeat(attach(W1, T0), seenAt)

  expect(OLD_WINDOW_MS).toBe(7 * 24 * 60 * MIN)
  expect(isMoveHeld([], [], now)).toBe(false)
  expect(isMoveHeld([old(now - 6 * 24 * 60 * MIN)], [], now), 'asleep six days').toBe(true)
  expect(isMoveHeld([old(now - OLD_WINDOW_MS)], [], now), 'a week to the moment').toBe(true)
  expect(isMoveHeld([old(now - OLD_WINDOW_MS - 1)], [], now), 'past the week').toBe(false)
  expect(isMoveHeld([leave(old(now - MIN), now - MIN)], [], now), 'let go').toBe(false)
  expect(
    isMoveHeld([heartbeat(attach(W1, T0, { version: '0.1.0' }), now)], [], now),
    'saying its version',
  ).toBe(false)
})

test("a window's later heartbeat stands for its earlier ones: one saying its version, as after a reload, frees the move; one saying none still holds it", () => {
  const now = T0 + 60 * MIN
  const before = heartbeat(attach(W1, T0), now - 10 * MIN)
  const reloaded = heartbeat(attach(W1, T0, { version: '0.1.0' }), now)

  expect(isMoveHeld([before, reloaded], [], now)).toBe(false)
  expect(isMoveHeld([reloaded, before], [], now), 'whatever their order').toBe(false)
  expect(
    isMoveHeld([{ ...before, writer: W2 }, reloaded], [], now),
    "another window's is its own",
  ).toBe(true)
  expect(
    isMoveHeld([heartbeat(reloaded, now - 10 * MIN), heartbeat(before, now)], [], now),
    'the later saying none',
  ).toBe(true)
})

test('a heartbeat file that does not read holds the move while it was written within OLD_WINDOW_MS', () => {
  const now = T0 + 30 * 24 * 60 * MIN

  expect(isMoveHeld([], [now - MIN], now)).toBe(true)
  expect(isMoveHeld([], [now - OLD_WINDOW_MS - 1], now)).toBe(false)
})
