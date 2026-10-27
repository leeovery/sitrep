import { expect, test } from 'claude-code/testing'
import {
  CURRENT_MS,
  every,
  isOffBoard,
  isSameFiles,
  metaText,
  OFF_BOARD_MS,
  STALE_MS,
  type SessionFiles,
} from '../core'
import { file, finish, fold, META, MIN, note, seen, status, T0, W1, W2, yesAsk } from './support'

const FILES: SessionFiles = {
  meta: metaText(META),
  project: '{"name":"Switchboard"}\n',
  logs: { [W1]: file([T0, note('n1', 'Drew round 1')]) },
  inbox: {},
  presence: { [W1]: seen(W1, T0) },
}

test("two reads of a session's files are the same only where every text is, under the same names; none and empty are alike", () => {
  expect(isSameFiles(FILES, { ...FILES, logs: { ...FILES.logs } })).toBe(true)
  expect(isSameFiles(FILES, { ...FILES, inbox: undefined })).toBe(true)

  for (const [other, why] of [
    [{ ...FILES, meta: metaText({ ...META, name: 'Renamed' }) }, 'its meta'],
    [{ ...FILES, project: undefined }, 'its project'],
    [{ ...FILES, logs: { [W1]: file([T0, note('n1', 'Drew round 2')]) } }, 'a line'],
    [{ ...FILES, logs: { [W2]: FILES.logs[W1] ?? '' } }, 'a writer'],
    [{ ...FILES, logs: { ...FILES.logs, [W2]: '' } }, 'a writer more'],
    [{ ...FILES, inbox: { cli: '' } }, 'a letter'],
    [{ ...FILES, presence: { [W1]: seen(W1, T0 + MIN) } }, 'a beat'],
  ] as const) {
    expect(isSameFiles(FILES, other), why).toBe(false)
    expect(isSameFiles(other, FILES), why).toBe(false)
  }
})

test('a session is off the board with no live window, finished or idle past the views; one that does not fold never is', () => {
  const finished = { logs: { [W1]: file([T0, finish('lee')]) } }
  const idle = { logs: { [W1]: file([T0, status(['Idle'])]) } }
  const past = T0 + CURRENT_MS + 1

  expect(isOffBoard(fold(finished), T0 + MIN)).toBe(true)
  expect(isOffBoard(fold(idle, past), past)).toBe(true)
  expect(isOffBoard(fold(idle, T0 + MIN), T0 + MIN), 'idle, but recent').toBe(false)
  expect(
    isOffBoard(fold({ logs: { [W1]: file([T0, yesAsk('k1', 'Keep me')]) } }, past), past),
    'an ask waiting',
  ).toBe(false)
  const held = { ...finished, presence: { [W1]: seen(W1, T0) } }
  const gone = T0 + STALE_MS + 1

  expect(isOffBoard(fold(held, T0 + MIN), T0 + MIN), 'a finished one a live window holds').toBe(
    false,
  )
  expect(isOffBoard(fold(held, gone), gone), 'its window gone').toBe(true)
  expect(isOffBoard(undefined, T0)).toBe(false)
})

test('something done every OFF_BOARD_MS is due at its first time, and then once the time has passed since it last was', () => {
  const isDue = every(OFF_BOARD_MS, -Infinity)

  expect(
    [T0, T0 + 1, T0 + OFF_BOARD_MS - 1, T0 + OFF_BOARD_MS, T0 + OFF_BOARD_MS + 1].map(isDue),
  ).toEqual([true, false, false, true, false])
})
