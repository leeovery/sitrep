import { expect, test } from 'claude-code/testing'
import { lastSeen, rejoinable, type Session } from '../core'
import {
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
  yesAsk,
} from './support'

/** The session under test under another id. */
const as = (id: string, session: Session): Session => ({ ...session, id })

test('a window is last seen in a session by its heartbeat, as it let go or last beat', () => {
  const session = fold({
    presence: {
      [W1]: beat(W1, { attachedAt: T0, seenAt: T0 + 5 * MIN, leftAt: T0 + 6 * MIN }),
      [W2]: beat(W2, { attachedAt: T0, seenAt: T0 + 7 * MIN }),
    },
  })

  expect(lastSeen(session, W1)).toBe(T0 + 6 * MIN)
  expect(lastSeen(session, W2)).toBe(T0 + 7 * MIN)
})

test('with no heartbeat, by the latest item or status it posted; starting a session or sending to its inbox is not being in it', () => {
  const session = fold({
    logs: {
      [W1]: file([T0 + MIN, yesAsk('k1', 'Run it', 'Done')], [T0 + 3 * MIN, status(['Drawing'])]),
      [W2]: file([T0 + 2 * MIN, note('n1', 'Noted')]),
    },
    inbox: { [SENDER]: file([T0 + 4 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(lastSeen(session, W1)).toBe(T0 + 3 * MIN)
  expect(lastSeen(session, W2)).toBe(T0 + 2 * MIN)
  expect(lastSeen(session, SENDER)).toBeUndefined()
  expect(lastSeen(fold({}), META.by)).toBeUndefined()
})

test('a window rejoins the session it was last seen in; none, if it was seen in none', () => {
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

test('a window never rejoins a finished session by itself, nor an older one it had moved on from', () => {
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
