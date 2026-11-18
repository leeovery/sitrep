/**
 * A reload with a send held that a load before held sends were read again
 * claimed: its claim keeps no lines, the module's memory fresh as a real
 * reload leaves it. The test kit loads the mod once per file, so this file
 * holds one test.
 */
import { expect, test, tier } from './kit'
import { metaText, parseEntries, sessionPaths } from '../core'
import type { SitrepInFlight } from '../types'
import { EXPORT } from './answers'
import { LEDGER, META, PROJECT, ROOT, T0, W1 } from './data'
import { drop, file, park } from './lines'
import { CONVERSATION, world } from './world'

tier('user')

const NOW = T0 + 60_000

const HELD = sessionPaths(ROOT, PROJECT.key, META.id)

const PARKING = sessionPaths(ROOT, PROJECT.key, LEDGER.id)

/** Lee's pick-up of the ledger's export, held by an older load, whose claim kept no lines. */
const LEFT: SitrepInFlight = {
  source: 'send',
  project: PROJECT.key,
  session: META.id,
  writer: W1,
  text: `From the board:\n- Pick up from parked, Invoice ledger's: ${EXPORT}`,
  replies: [{ type: 'reply', id: 'r7', item: `${LEDGER.id}:p1`, verdict: 'pickup' }],
  claimedAt: T0 + 30_000,
  isHeld: true,
  isTaken: false,
}

test("a held send an older load claimed, keeping no lines, goes as claimed, though its pick-up's item was dropped since: nothing thrown, nothing left held", async ($, on) => {
  const w = world($, on, { now: NOW })
  const left: Record<string, unknown> = {
    attachment: { project: PROJECT.key, session: META.id, writer: W1, attachedAt: T0 },
    inFlight: LEFT,
  }

  // At the version of a value never written, so the first update lands on it.
  on('state.get', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) =>
    e.key in left ? { value: { value: left[e.key], version: 0 } } : next(e),
  )
  on('state.set', { plugin: 'sitrep', key: ['attachment', 'inFlight'] }, ($, e, next) => {
    delete left[e.key]

    return next(e)
  })

  w.put(HELD.meta, metaText(META))
  w.put(HELD.log(W1), file())
  w.put(PARKING.meta, metaText(LEDGER))
  w.put(PARKING.log(LEDGER.by), file([T0, park('p1', EXPORT)], [T0 + 40_000, drop('p1')]))
  await $.session.start(CONVERSATION)

  expect(w.submitted).toEqual([LEFT.text])
  expect(w.flights().map(each => each.isHeld)).toEqual([false])
  expect(parseEntries(w.text(PARKING.log(W1))).map(line => line.type)).toEqual([
    'reply',
    'delivered',
  ])
})
