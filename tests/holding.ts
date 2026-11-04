/**
 * A send the window holds for Claude's turn to end: what Ready to send says
 * of it, and a reload while it is held. A reload leaves the module's memory
 * fresh, and the test kit loads the mod once per file, so a file reloading
 * holds one test: any other before it would leave the module knowing what
 * the window heard.
 */
import type { On } from 'claude-code'
import type { Mounted } from 'claude-code/testing'
import { metaText, sessionPaths } from '../core'
import type { SitrepActivity, SitrepInFlight } from '../types'
import { rowsOf } from './drawn'
import { AGENT, file, FORK, META, T0, W1, yesAsk } from './support'
import { PROJECT, ROOT, world } from './world'

/** What Ready to send says of a held send. */
export const HELD = "⧗ Waiting for Claude's turn to end."

/** The same while Claude's turn only waits on its background work. */
export const WAITS_ON_WORK =
  '⧗ Claude is waiting on its background work: this goes in when that ends. Type your answer in the prompt to reach Claude now.'

/** That, in the one row Ready to send has for it where room is short. */
export const WAITS_ON_WORK_SHORT = "⧗ Waiting on Claude's background work."

/** The rows of what Ready to send says of the send on its way, none with none. */
export const sendingRows = async (ui: Pick<Mounted, 'find'>) =>
  rowsOf(await ui.find({ key: 'sending' }))

/** What Ready to send says of the send on its way, its rows joined. */
export const sendingSays = async (ui: Pick<Mounted, 'find'>) => (await sendingRows(ui)).join(' ')

/** The message the load before the reload held. */
export const LEFT_MESSAGE = 'From the board:\n- Review round 1 → Approve'

/** What the load before heard: Claude done inside its turn, which waits on its subagent's loop and the engine's fork. */
export const LEFT_WAITING: SitrepActivity = {
  turnAt: T0 + 10_000,
  turnId: 'turn-1',
  tools: [],
  asked: [],
  stops: [],
  watches: [],
  loops: [AGENT, FORK],
  isDone: true,
}

/** Lee's yes to the session's review, sent, and held by the load before for Claude's turn to end. */
const LEFT_HELD: SitrepInFlight = {
  source: 'send',
  project: PROJECT.key,
  session: META.id,
  writer: W1,
  text: LEFT_MESSAGE,
  replies: [{ type: 'reply', id: 'r7', item: 'k1', verdict: 'yes' }],
  claimedAt: T0 + 30_000,
  isHeld: true,
  isTaken: false,
}

/**
 * The session as the load before the reload left it, its review asked and
 * Lee's send held, and `activity` as it heard the turn: each value read
 * from `$.state` as never written, until this load writes it.
 */
export const leftHolding = (w: ReturnType<typeof world>, on: On, activity: SitrepActivity) => {
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)
  const left: Record<string, unknown> = {
    attachment: { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 },
    inFlight: LEFT_HELD,
    queue: [{ project: PROJECT.key, session: META.id, item: 'k1', verdict: 'yes' }],
    activity,
  }

  on('state.get', { plugin: 'sitrep' }, ($, e, next) =>
    e.key in left ? ({ value: { value: left[e.key], version: 0 } } as never) : next(e),
  )
  on('state.set', { plugin: 'sitrep' }, ($, e, next) => {
    delete left[e.key]

    return next(e)
  })
  w.put(paths.meta, metaText(META))
  w.put(paths.log(W1), file([T0, yesAsk('k1', 'Review round 1')]))
}
