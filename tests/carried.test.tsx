/**
 * A reload with two sends of Lee's held, the module's memory fresh as a real
 * reload leaves it, and `$.state` keeping them as a list. The test kit loads
 * the mod once per file, so this file holds one test.
 */
import { expect, test, tier } from 'claude-code/testing'
import { metaText, parseEntries, parsePresence, sessionPaths } from '../core'
import { WATCH_MS } from '../hooks/window'
import type { SitrepInFlight } from '../types'
import { CLOSES, file, META, SLOW, T0, W1, yesAsk } from './support'
import { CONVERSATION, PROJECT, ROOT, world } from './world'

tier('user')

const NOW = T0 + 60_000

const PATHS = sessionPaths(ROOT, PROJECT.key, META.id)

/** Lee's yes to a review, sent as a message of its own and held by the load before the reload. */
const held = (item: string, title: string, id: string, claimedAt: number): SitrepInFlight => ({
  source: 'send',
  project: PROJECT.key,
  session: META.id,
  writer: W1,
  text: `From the board:\n- ${title} → Approve${CLOSES}`,
  replies: [{ type: 'reply', id, item, verdict: 'yes' }],
  claimedAt,
  isHeld: true,
  isTaken: false,
})

const FIRST = held('k1', 'Review round 1', 'r7', T0 + 20_000)

const SECOND = held('k2', 'Review round 2', 'r8', T0 + 30_000)

test("a reload with two sends held says both in its heartbeat in the order sent, and sends them in that order, the second once Claude's turn on the first has ended", SLOW, async ($, on) => {
  const w = world($, on, { now: NOW })
  const left: Record<string, unknown> = {
    attachment: { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 },
    inFlight: [FIRST, SECOND],
  }

  // At the version of a value never written, so the first update lands on it.
  on('state.get', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) =>
    e.key in left ? { value: { value: left[e.key], version: 0 } } : next(e),
  )
  on('state.set', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) => {
    delete left[e.key]

    return next(e)
  })

  const beats: string[] = []
  const sending = (text: string) =>
    parsePresence(text, W1)?.sending?.map(each => [each.at, each.replies.map(reply => reply.id)])
  const replied = () =>
    parseEntries(w.text(PATHS.log(W1))).flatMap(line => (line.type === 'reply' ? [line.id] : []))

  // The window reads its heartbeat back before each rewrite: what it holds
  // then is what the write before left, as any reader would have seen it.
  for (let i = 0; i < 20; i += 1) {
    w.after('read', PATHS.heartbeat(W1), () => {
      const text = w.files.get(PATHS.heartbeat(W1))?.text

      if (text !== undefined) {
        beats.push(text)
      }
    })
  }

  w.put(PATHS.meta, metaText(META))
  w.put(
    PATHS.log(W1),
    file([T0, yesAsk('k1', 'Review round 1')], [T0, yesAsk('k2', 'Review round 2')]),
  )
  await $.session.start(CONVERSATION)

  expect(beats.map(sending)[0], 'the first heartbeat says both, in order').toEqual([
    [FIRST.claimedAt, ['r7']],
    [SECOND.claimedAt, ['r8']],
  ])
  expect(w.submitted, 'between turns, the first goes at once').toEqual([FIRST.text])
  expect(replied()).toEqual(['r7'])

  await w.turnStarts(FIRST.text)
  await w.clock.advance(4 * WATCH_MS)

  expect(sending(w.text(PATHS.heartbeat(W1)))).toEqual([[SECOND.claimedAt, ['r8']]])
  expect(w.submitted, 'held through the turn the first started').toEqual([FIRST.text])

  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([FIRST.text, SECOND.text])
  expect(replied()).toEqual(['r7', 'r8'])
  expect(w.state.inFlight).toBeNull()
})
