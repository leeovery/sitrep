import { expect, test, tier } from 'claude-code/testing'
import { rowsOf } from './drawn'
import { ACROSS, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const FOLD =
  "Fold the trial's lessons into the orchestrate skill: implementers at high and xhigh, model by complexity, plan stops, parallel worktrees"

/** The first row of FOLD opened: its mark, its title's first line, its age. */
const TITLED = /^◇ Fold the trial's lessons into the orchestrate +now$/

const DECIDE = {
  kind: 'decide',
  title: 'Keep the ledger 400 days, or forever?',
  where: 'In Paper: page round 1',
  options: ['400 days', 'Forever'],
}

/** The rows the element keyed `key` is drawn on, as the docked board draws it. */
const rows = async (ui: Awaited<ReturnType<World['pane']>>, key: string) =>
  rowsOf(await ui.find({ key }))

test('a log line is its mark, its text and its age at the right edge; opened, a stem runs down from the mark to its tree', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const long = postedId(
    await w.call('note', {
      text: 'Now also drawing Usage, round 2, and the brief beside it',
      detail: ['Added: Drawing Usage, round 2', 'Next: Usage, round 3'],
    }),
  )
  const short = postedId(await w.call('note', { text: 'PR #82 merged' }))
  const ui = await w.pane()
  const across = async (key: string) => rowsOf(await ui.find({ key }), ACROSS)

  expect(await across(`line:${long}`)).toEqual([
    '• Now also drawing Usage, round 2, and the brie…   now',
  ])

  await ui.press({ key: `log:${long}` })
  expect(await across(`line:${long}`)).toEqual([
    '• Now also drawing Usage, round 2, and the brief   now',
    '│ beside it',
    '├ Added: Drawing Usage, round 2',
    '└ Next: Usage, round 3',
  ])

  await ui.press({ key: `log:${short}` })
  expect(await across(`line:${short}`)).toEqual([
    '• PR #82 merged                                    now',
    '└ nothing more was recorded',
  ])
})

test('an opened parked item hangs where, the session that raised it and its record from its mark, its button under the tree', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('park', {
      title: FOLD,
      where: 'In DESIGN.md, Later',
      ref: 'memory: orchestration-setup.md',
    }),
  )
  const ui = await w.opened()

  await ui.press({ key: 'tab:project' })
  await ui.press({ key: 'parked' })
  await ui.press({ key: `ppick:${id}` })
  const drawn = await rows(ui, `parked:${w.state.attachment?.work}:${id}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '│ skill: implementers at high and xhigh, model',
    '│ by complexity, plan stops, parallel worktrees',
    '├ In DESIGN.md, Later',
    '├ raised in Dashboard redesign',
    '└ see memory: orchestration-setup.md',
    '  [ pick it up ]',
  ])
})

test('a parked item with nothing to hang shows no stem beside its title, only its button', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: FOLD }))
  const ui = await w.pane()

  await ui.press({ key: 'parked' })
  await ui.press({ key: `ppick:${id}` })
  const drawn = await rows(ui, `parked:${w.state.attachment?.work}:${id}`)

  expect(drawn[0]).toMatch(TITLED)
  expect(drawn.slice(1)).toEqual([
    '  skill: implementers at high and xhigh, model',
    '  by complexity, plan stops, parallel worktrees',
    '  [ pick it up ]',
  ])
})

test("a pick-up waiting to be sent is the parked item's last branch, and takes the button's place", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: 'A tmux indicator', where: 'In DESIGN.md' }))
  const ui = await w.pane()

  await ui.press({ key: 'parked' })
  await ui.press({ key: `ppick:${id}` })
  await ui.press({ key: `pickup:${id}` })
  expect((await rows(ui, `parked:${w.state.attachment?.work}:${id}`)).slice(1)).toEqual([
    '├ In DESIGN.md',
    '└ pick it up · not sent yet ↺ undo',
  ])
})

test("an opened ask hangs where and its record from its mark; its buttons and hint come after, at the title's column", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', {
      kind: 'review',
      title: 'Review Sessions & Runway, round 1',
      where: 'In Paper: page round 1',
      ref: 'docs/dashboard.md',
    }),
  )
  const ui = await w.pane()

  expect((await rows(ui, `ask:${id}`)).slice(1, 5)).toEqual([
    '├ In Paper: page round 1',
    '└ see docs/dashboard.md',
    '  [ ✓ approve ] [ ✎ comment ] [ ✕ ignore ]',
    "  Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it.",
  ])
})

test("a reply waiting to be sent is the ask's last branch", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', DECIDE))
  const ui = await w.pane()

  await ui.press({ key: `choose:${id}:1` })
  expect(await rows(ui, `ask:${id}`)).toEqual([
    '◆ Keep the ledger 400 days, or forever? now',
    '├ In Paper: page round 1',
    '└ → Forever · not sent yet ↺ undo',
  ])
})

test('a closed ask keeps its faint title and tick, and hangs that Claude has it from the tick', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', DECIDE))
  const ui = await w.pane()

  await ui.press({ key: `choose:${id}:1` })
  await ui.press({ key: 'send' })
  expect(await rows(ui, `ask:${id}`)).toEqual([
    '✓ Keep the ledger 400 days, or forever? now',
    '└ sent, and Claude has it',
  ])
  expect((await ui.find({ type: 'Text', text: DECIDE.title }))?.props.color).toBe('#565f89')
})

test('a branch whose text wraps keeps the tree unbroken: a stem beside it under a ├, blank under the └', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', {
      kind: 'review',
      title: 'Review Sessions & Runway, round 1',
      where: 'In Paper: the dashboard file, page "round 1", frames 1–6, beside the brief',
      ref: 'docs/dashboard.md, under "Sessions & Runway", the first round of three',
    }),
  )
  const ui = await w.pane()

  expect((await rows(ui, `ask:${id}`)).slice(1, 5)).toEqual([
    '├ In Paper: the dashboard file, page "round 1", frames',
    '│ 1–6, beside the brief',
    '└ see docs/dashboard.md, under "Sessions & Runway",',
    '  the first round of three',
  ])
})
