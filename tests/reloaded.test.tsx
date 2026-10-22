/**
 * A reload in the middle of a send, the module's memory fresh as a real
 * reload leaves it. The test kit loads the mod once per file, so this file
 * holds one test: any other before it would leave the module knowing the
 * message in flight.
 */
import { expect, test, tier } from 'claude-code/testing'
import { metaText, parsePresence, sessionPaths } from '../core'
import type { SitrepInFlight } from '../types'
import { file, META, T0, W1, yesAsk } from './support'
import { CONVERSATION, PROJECT, ROOT, world } from './world'

tier('user')

const NOW = T0 + 60_000

const PATHS = sessionPaths(ROOT, PROJECT.key, META.id)

/** Lee's yes to the session's review, claimed by the load before the reload and not yet taken. */
const LEFT: SitrepInFlight = {
  source: 'send',
  project: PROJECT.key,
  session: META.id,
  writer: W1,
  text: 'From the board:\n- Review round 1 → Approve',
  replies: [{ type: 'reply', id: 'r7', item: 'k1', verdict: 'yes' }],
  claimedAt: T0 + 30_000,
  isTaken: false,
}

test("a reload mid-send says the claim in the load's first heartbeat, so no reader sees the ask need Lee again in between", async ($, on) => {
  const w = world($, on, { now: NOW })
  const beats: string[] = []
  const left: Record<string, unknown> = {
    attachment: { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 },
    inFlight: LEFT,
  }

  on('state.get', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) =>
    e.key in left ? { value: { value: left[e.key], version: 1 } } : next(e),
  )
  on('state.set', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) => {
    delete left[e.key]

    return next(e)
  })
  // The window reads its heartbeat back before each rewrite: what it holds
  // then is what the write before left, as any reader would have seen it.
  const heard = () => {
    const text = w.files.get(PATHS.heartbeat(W1))?.text

    if (text !== undefined) {
      beats.push(text)
    }
  }

  for (let i = 0; i < 20; i += 1) {
    w.after('read', PATHS.heartbeat(W1), heard)
  }

  w.put(PATHS.meta, metaText(META))
  w.put(PATHS.log(W1), file([T0, yesAsk('k1', 'Review round 1')]))
  await $.session.start(CONVERSATION)
  heard()

  expect(beats.length).toBeGreaterThan(0)
  expect(beats.map(text => parsePresence(text, W1)?.sending)).toEqual(
    beats.map(() => ({ at: LEFT.claimedAt, replies: [{ id: 'r7', item: 'k1', verdict: 'yes' }] })),
  )
  expect(w.state.board?.waiting).toBe(0)
})
