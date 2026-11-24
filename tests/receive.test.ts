import { drained, expect, test } from './kit'
import type { Session } from '../core'
import { boardOf } from '../hooks/board'
import type { Host } from '../hooks/host'
import { receiveEvery } from '../hooks/receive'
import type { SitrepInFlight } from '../types'
import { CLI, CLOSES, keyed, META, MIN, T0, W1 } from './data'
import { delivered, file, fold, reply, seen, yesAsk, type Line } from './lines'

const NOW = T0 + 2 * MIN

const ASKED: Line = [T0, yesAsk('k1', 'Review round 1')]

/** The CLI's yes to k1, in the inbox for the window to deliver. */
const INBOX = { [CLI]: file([T0 + MIN, reply('r9', 'k1', 'yes')]) }

const PRESENCE = { [W1]: seen(W1, NOW) }

/** The session as the window's send leaves it written down: its own yes to k1, delivered, and the CLI's void. */
const WRITTEN = fold(
  {
    logs: { [W1]: file(ASKED, [NOW, reply('r1', 'k1', 'yes')], [NOW, delivered('r1')]) },
    inbox: INBOX,
    presence: PRESENCE,
  },
  NOW,
)

/** The session before then: the CLI's yes on its way. */
const UNWRITTEN = fold({ logs: { [W1]: file(ASKED) }, inbox: INBOX, presence: PRESENCE }, NOW)

/** The window's send, taken by Claude Code and not yet written down. */
const SENT: SitrepInFlight = {
  source: 'send',
  project: keyed(META.project),
  session: META.id,
  writer: W1,
  text: `From the board:\n- Review round 1 → Approve${CLOSES}`,
  replies: [{ type: 'reply', id: 'r1', item: 'k1', verdict: 'yes' }],
  claimedAt: NOW,
  isHeld: false,
  isTaken: true,
}

/**
 * A window delivering for the session, its looks run by hand. A read of the
 * message in flight answers only once `land` is called, with the value as it
 * stands then; every other read answers at once, with the value as it stood
 * when made. So the reads of one look can land on either side of a send
 * being written down. Its own file, so the mod's modules start afresh for it.
 */
const delivering = (board: Session, inFlight: SitrepInFlight[]) => {
  const state = { board: boardOf(board), inFlight }
  const submitted: string[] = []
  /** How many reads of the message in flight were made. */
  let reads = 0
  let landed = () => {}
  const landing = new Promise<void>(resolve => {
    landed = resolve
  })
  let look = () => {}
  const host = {
    clock: {
      now: async () => NOW,
      every: (ms: number, task: () => void) => {
        look = task

        return { cancel: () => {} }
      },
      after: () => ({ cancel: () => {} }),
    },
    state: {
      attachment: {
        read: async () => ({ project: META.project, session: META.id, writer: W1, attachedAt: T0 }),
      },
      board: { read: async () => state.board },
      inFlight: {
        read: async () => {
          reads += 1
          await landing

          return state.inFlight
        },
        update: async (change: (value: SitrepInFlight[]) => SitrepInFlight[]) => {
          state.inFlight = change(state.inFlight)
        },
      },
      stopped: { read: async () => false },
      // Nothing heard: the window between turns, so a message claimed goes at once.
      activity: { get: async () => ({ value: undefined, version: 0 }) },
    },
    prompt: {
      submit: async (text: string) => {
        submitted.push(text)

        return { drop: 'held for the test' }
      },
    },
    log: () => {},
  } as unknown as Host

  receiveEvery(host)

  return { state, submitted, look: () => look(), land: () => landed(), reads: () => reads }
}

test('a look with nothing in flight delivers the inbox replies on their way', async () => {
  const window = delivering(UNWRITTEN, [])

  window.look()
  window.land()
  await drained()

  expect(window.submitted).toEqual([`From the board:\n- Review round 1 → Approve${CLOSES}`])
})

test('a tick while the last look is still under way is skipped: the timer stacks no looks up', async () => {
  const window = delivering(UNWRITTEN, [])

  window.look()
  window.look()
  expect(window.reads(), 'the second tick skipped').toBe(1)

  window.land()
  await drained()

  const done = window.reads()

  window.look()
  expect(window.reads(), 'the next tick, once the last look is done').toBe(done + 1)
})

test('a look reads the board only once it finds no message in flight, so a send written down meanwhile is on it: an answer the send voided is never delivered too', async () => {
  const window = delivering(UNWRITTEN, [SENT])

  window.look()
  await drained()
  window.state.board = boardOf(WRITTEN)
  window.state.inFlight = []
  window.land()
  await drained()

  expect(window.submitted).toEqual([])
})
