/** A reload while Claude's turn only waits on its background work: see tests/holding.ts. */
import { expect, test, tier } from 'claude-code/testing'
import {
  HELD,
  LEFT_MESSAGE,
  LEFT_WAITING,
  leftHolding,
  sendingSays,
  WAITS_ON_WORK,
} from './holding'
import { AGENT, T0 } from './support'
import { CONVERSATION, world } from './world'

tier('user')

test("a reload while Claude's turn only waits on its background work draws the board again once loaded; the subagent's end leaves the send waiting for the turn to end, the fork no list names counting for nothing, and it goes as the turn ends", async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })

  leftHolding(w, on, LEFT_WAITING)
  w.lists(AGENT)
  await $.session.start(CONVERSATION)

  expect(w.redraws(), 'a board drawn before the load is drawn again').toBeGreaterThan(0)

  const ui = await w.pane()

  expect(await sendingSays(ui)).toBe(WAITS_ON_WORK)

  await w.turnEnds({ agentId: AGENT })
  expect(await sendingSays(ui)).toBe(HELD)
  expect(w.submitted).toEqual([])

  await w.turnEnds()
  await w.clock.settle()
  expect(w.submitted).toEqual([LEFT_MESSAGE])
})
