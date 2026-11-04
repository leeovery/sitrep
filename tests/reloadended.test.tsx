/** A reload after the background work Claude's turn waited on ended: see tests/holding.ts. */
import { expect, test, tier } from 'claude-code/testing'
import { HELD, LEFT_MESSAGE, LEFT_WAITING, leftHolding, sendingSays } from './holding'
import { AGENT, T0 } from './support'
import { CONVERSATION, world } from './world'

tier('user')

test("a reload that finds Claude's turn waiting on loops the engine no longer lists as running counts them for nothing: from the first draw the send waits for the turn to end, and it goes as the turn ends", async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })

  leftHolding(w, on, LEFT_WAITING)
  w.lists(AGENT, 'completed')
  await $.session.start(CONVERSATION)

  const ui = await w.pane()

  expect(await sendingSays(ui)).toBe(HELD)
  expect(w.submitted).toEqual([])

  await w.turnEnds()
  await w.clock.settle()
  expect(w.submitted).toEqual([LEFT_MESSAGE])
})
