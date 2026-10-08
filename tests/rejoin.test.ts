import { expect, test } from 'claude-code/testing'
import { lastSeen, rejoinable, type Work } from '../core'
import {
  ask,
  beat,
  file,
  finish,
  fold,
  MIN,
  META,
  note,
  reply,
  SENDER,
  status,
  T0,
  W1,
  W2,
} from './support'

/** The work under test under another id. */
const as = (id: string, work: Work): Work => ({ ...work, id })

test('a window is last seen in a work by its heartbeat, as it let go or last beat', () => {
  const work = fold({
    presence: {
      [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + 5 * MIN, leftAt: T0 + 6 * MIN }),
      [W2]: beat(W2, { attachedAt: T0, seenAt: T0 + 7 * MIN }),
    },
  })

  expect(lastSeen(work, W1)).toBe(T0 + 6 * MIN)
  expect(lastSeen(work, W2)).toBe(T0 + 7 * MIN)
})

test('with no heartbeat, by the latest item or status it posted; starting a work or sending to its inbox is not being in it', () => {
  const work = fold({
    logs: {
      [W1]: file([T0 + MIN, ask('k1', 'do', 'Run it')], [T0 + 3 * MIN, status(['Drawing'])]),
      [W2]: file([T0 + 2 * MIN, note('n1', 'Noted')]),
    },
    inbox: { [SENDER]: file([T0 + 4 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(lastSeen(work, W1)).toBe(T0 + 3 * MIN)
  expect(lastSeen(work, W2)).toBe(T0 + 2 * MIN)
  expect(lastSeen(work, SENDER)).toBeUndefined()
  expect(lastSeen(fold({}), META.by)).toBeUndefined()
})

test('a window rejoins the work it was last seen in; none, if it was seen in none', () => {
  const older = as(
    'sr-aaaaaa',
    fold({ presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + MIN }) } }),
  )
  const newer = as(
    'sr-bbbbbb',
    fold({ presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + 2 * MIN }) } }),
  )
  const other = as(
    'sr-cccccc',
    fold({ presence: { [W2]: beat(W2, { attachedAt: T0, seenAt: T0 + 9 * MIN }) } }),
  )

  expect(rejoinable([older, newer, other], W1)).toBe('sr-bbbbbb')
  expect(rejoinable([older, other], W1)).toBe('sr-aaaaaa')
  expect(rejoinable([other], W1)).toBeUndefined()
})

test('a window never rejoins a finished work by itself, nor an older one it had moved on from', () => {
  const older = as(
    'sr-aaaaaa',
    fold({ presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + MIN }) } }),
  )
  const finished = as(
    'sr-bbbbbb',
    fold({
      logs: { [W1]: file([T0 + MIN, finish('claude')]) },
      presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + 2 * MIN }) },
    }),
  )

  expect(rejoinable([older, finished], W1)).toBeUndefined()
})
