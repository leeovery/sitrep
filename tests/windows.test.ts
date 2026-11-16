import { expect, test } from './kit'
import {
  attach,
  leave,
  presenceText,
  rowOf,
  windowsOf,
  type Where,
  type WindowState,
} from '../core'
import { MIN, T0, W1, W2 } from './data'
import { fold } from './lines'

const IN_TMUX: Where = {
  device: '/dev/ttys043',
  terminal: 'tmux',
  tmux: { socket: '/private/tmp/tmux-501/default', pane: '%148' },
}

const IN_GHOSTTY: Where = { device: '/dev/ttys041', terminal: 'ghostty' }

/** A window's whereabouts, by its writer: a device of its own. */
const whereOf = (writer: string): Where => ({ device: `/dev/tty${writer}`, terminal: 'ghostty' })

type Window = [writer: string, at: number, state?: WindowState]

/** When the windows below are looked at: a minute on. */
const LOOKED = T0 + MIN

/** A session of these live windows, each attached at its time and in its state, if any. */
const sessionAt = (...windows: Window[]) =>
  fold(
    {
      presence: Object.fromEntries(
        windows.map(([writer, at, state]) => [
          writer,
          presenceText(attach(writer, at, { where: whereOf(writer), state })),
        ]),
      ),
    },
    LOOKED,
  )

/** The windows a session of these live windows is in, by writer, in the order a jump tries them. */
const windowsAt = (...windows: Window[]) =>
  windowsOf(sessionAt(...windows), LOOKED).map(where => where.device?.slice('/dev/tty'.length))

test("a session's windows are its live presences' whereabouts; a window gone, stale or not saying where is left out", () => {
  const now = T0 + MIN
  const session = fold(
    {
      presence: {
        [W1]: presenceText(attach(W1, T0 + 30_000, { where: IN_GHOSTTY })),
        [W2]: presenceText(attach(W2, T0, { where: IN_TMUX })),
        gone: presenceText(leave(attach('gone', T0, { where: IN_GHOSTTY }), T0 + 40_000)),
        stale: presenceText(attach('stale', T0 - 10 * MIN, { where: IN_GHOSTTY })),
        unsaid: presenceText(attach('unsaid', T0 + 50_000)),
      },
    },
    now,
  )

  expect(session.deliverer, 'the deliverer, attached first, is not first').toBe(W2)
  expect(windowsOf(session, now)).toEqual([IN_GHOSTTY, IN_TMUX])
})

test("a session's windows go the one stopped on Lee first, at a permission prompt or a question, then those working, then the rest; within each, the latest state's start, then the latest attach", () => {
  const at = (is: WindowState['is'], since: number): WindowState => ({ is, since })

  expect(
    windowsAt(
      ['a', T0 + 30_000, at('working', T0 + 50_000)],
      ['b', T0, at('permission', T0 + 10_000)],
    ),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0 + 30_000, at('yourTurn', T0 + 50_000)],
      ['b', T0, at('question', T0 + 10_000)],
    ),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 50_000)], ['b', T0, at('working', T0 + 10_000)]),
    'working, however long ago its turn began',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('working', T0 + 20_000)], ['b', T0, at('working', T0 + 40_000)]),
    'of two working, the turn begun last',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 20_000)], ['b', T0, at('yourTurn', T0 + 40_000)]),
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0, at('yourTurn', T0 + 40_000)],
      ['b', T0 + 10_000, at('yourTurn', T0 + 40_000)],
    ),
    'the same start, so the later attach',
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(
      ['a', T0, at('question', T0 + 20_000)],
      ['b', T0, at('permission', T0 + 30_000)],
      ['c', T0, at('working', T0 + 50_000)],
    ),
    'of two stopped on Lee, the later stop',
  ).toEqual(['b', 'a', 'c'])
  expect(
    windowsAt(['a', T0, at('yourTurn', T0 + 20_000)], ['b', T0 + 30_000]),
    "a window saying no state goes by its attach, as a state's start before any turn is, among those on their turn",
  ).toEqual(['b', 'a'])
  expect(
    windowsAt(['a', T0 + 30_000], ['b', T0, at('working', T0 + 5_000)]),
    'and below one working',
  ).toEqual(['b', 'a'])
})

test("a window on its own work goes below one working and above one on its turn, though that turn ended later: the window the session's row describes", () => {
  const work = { agents: { count: 1, first: 'Review the diff' } }
  const waiting: Window = ['a', T0, { is: 'onItsWork', since: T0 + 10_000, work }]
  const turn: Window = ['b', T0, { is: 'yourTurn', since: T0 + 40_000 }]
  const row = rowOf({ key: 'litware', name: 'Litware' }, sessionAt(waiting, turn), LOOKED)

  expect(row?.lines[0]?.writer).toBe('a')
  expect(windowsAt(waiting, turn)).toEqual(['a', 'b'])
  expect(windowsAt(waiting, ['b', T0, { is: 'working', since: T0 + 5_000 }])).toEqual(['b', 'a'])
})
