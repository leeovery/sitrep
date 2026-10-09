import { expect, test, tier } from 'claude-code/testing'
import { INLINE, DOCKED, postedId, SESSION, SURFACES, world } from './world'
import { SLOW } from './support'

tier('user')

type World = ReturnType<typeof world>

const REVIEW = {
  wants: 'yes',
  yes: 'Approve',
  title: 'Review Sessions & Runway, round 1',
  where: 'In Paper: the dashboard file, page "round 1", frames 1–6',
}

const DECIDE = {
  wants: 'choice',
  title: 'Keep the ledger 400 days, or forever?',
  options: ['400 days', 'Forever'],
}

/** Claude posts an ask, and the board opens it, as it does a new one: its id. */
const asked = async (w: World, ask: { [key: string]: unknown } = REVIEW) =>
  postedId(await w.call('ask', ask))

test('an empty board says nothing waits on you, docked and inline, on each surface', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const surface of SURFACES) {
    for (const props of [DOCKED, INLINE]) {
      const ui = await w.pane(surface, props)

      expect(await ui.find({ type: 'Text', text: /Nothing waiting on you/ })).toBeDefined()
      await ui.unmount()
    }
  }
})

test('with no work held, the board says so in a line and says how Claude starts one', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  const ui = await w.pane()

  expect(
    await ui.find({ type: 'Text', text: /no piece of work.*start one on the sitrep board/ }),
  ).toBeDefined()
})

test(
  "this session's view: the name and summary, what is under way and next, each heading's few words",
  SLOW,
  async ($, on) => {
    const w = world($, on)

    await w.begin()
    await w.call('status', { now: ['Drawing Usage, round 2'], next: 'Usage, round 3' })
    await w.clock.advance(12 * 60_000)

    const ui = await w.pane()

    expect(await ui.find({ key: 'tab:session', text: 'Dashboard redesign' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Dashboard redesign' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '· Switchboard' })).toBeDefined()
    expect(
      await ui.find({ type: 'Text', text: 'Redesign the dashboard, area by area' }),
    ).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Drawing Usage, round 2' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'next: Usage, round 3' })).toBeDefined()

    for (const note of ['updated 12m ago', 'nothing waiting', 'what happened']) {
      expect(await ui.find({ type: 'Text', text: note }), note).toBeDefined()
    }
  },
)

/** The view's own line and section headings, in the order drawn. */
const SECTIONS = new Set(['Dashboard redesign', 'FOR YOU', 'STATUS', 'LOG', 'PARKED', 'DONE'])

test("this session's view runs its name and summary, then FOR YOU, STATUS, LOG, PARKED and DONE, docked and inline", async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('park', { title: 'A tmux indicator across sessions' })

  const done = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })

  await w.call('resolve', { item: done, reason: 'Ran it in the chat' })
  await asked(w)

  for (const props of [DOCKED, INLINE]) {
    const ui = await w.pane('terminal', props)
    const order = (await ui.findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => SECTIONS.has(text))

    expect(order, props.placement).toEqual([...SECTIONS])
    await ui.unmount()
  }
})

test('a new ask opens with its buttons, by what it wants: a yes in its own words, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${id}`, text: '✓ Approve' })).toBeDefined()
  expect(await ui.find({ key: `comment:${id}`, text: '✎ comment' })).toBeDefined()
  expect(await ui.find({ key: `ignore:${id}`, text: '✕ ignore' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^In Paper: the dashboard file/ })).toBeDefined()

  await ui.press({ key: `pick:${id}` })
  expect(await ui.find({ key: `yes:${id}` })).toBeUndefined()
})

test('a choice offers its options and a comment, never a yes', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, DECIDE)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${id}` })).toBeUndefined()
  expect(await ui.find({ key: `comment:${id}`, text: '✎ comment' })).toBeDefined()
  await ui.press({ key: `choose:${id}:0` })
  expect(await ui.find({ type: 'Text', text: /→ 400 days/ })).toBeDefined()
})

test('a reply waits under its ask, not sent yet, until it is undone', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  expect(await ui.find({ type: 'Text', text: '→ Approve' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· not sent yet' })).toBeDefined()
  expect(await ui.find({ key: `yes:${id}` })).toBeUndefined()

  await ui.press({ key: `undo:${id}` })
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
  expect(await ui.find({ key: `yes:${id}` })).toBeDefined()
})

test('each reply in Ready to send can go on its own, or all at once', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const first = await asked(w)
  const second = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const ui = await w.pane()

  await ui.press({ key: `ignore:${second}` })
  await ui.press({ key: `pick:${first}` })
  await ui.press({ key: `yes:${first}` })
  expect(await ui.find({ type: 'Text', text: '2 replies' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'to this session' })).toBeDefined()

  await ui.press({ key: `unready:${second}` })
  expect(await ui.find({ type: 'Text', text: '1 reply' })).toBeDefined()

  await ui.press({ key: `pick:${second}` })
  expect(await ui.find({ key: `ignore:${second}` })).toBeDefined()

  await ui.press({ key: 'cancel-all' })
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
})

test('a log line opens to what happened and where it is recorded, and closes again', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('note', {
      text: 'PR #82 merged',
      detail: ['6 files, +214 −51'],
      ref: 'github.com/leeovery/switchboard/pull/82',
    }),
  )
  const ui = await w.pane()

  expect(await ui.find({ type: 'Text', text: /^LOG$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeUndefined()

  await ui.press({ key: `log:${id}` })
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: 'see github.com/leeovery/switchboard/pull/82' }),
  ).toBeDefined()

  await ui.press({ key: `log:${id}` })
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeUndefined()
})

test('an opened item shows its whole title, and where its own record is; closed, the title keeps to a line', async ($, on) => {
  const w = world($, on)
  const title =
    "Fold the trial's lessons into the orchestrate skill: implementers at high and xhigh, model by complexity, plan stops, parallel worktrees"

  await w.begin()
  await w.call('park', { title, ref: 'memory: orchestration-setup.md' })

  const ui = await w.pane()
  const [parked] = (await ui.findAll({ type: 'Button' })).filter(each =>
    each.key?.startsWith('ppick:'),
  )
  const key = parked?.key ?? ''
  const lines = async () =>
    (await ui.findAll({ type: 'Button' }))
      .filter(each => each.key === key || each.key?.startsWith(`${key}:`))
      .map(each => each.text)

  expect(await lines()).toHaveLength(1)
  expect((await lines())[0]).toMatch(/…$/)
  expect(
    await ui.find({ type: 'Text', text: /see memory: orchestration-setup.md/ }),
  ).toBeUndefined()

  await ui.press({ key })
  expect((await lines()).length).toBeGreaterThan(1)
  expect((await lines()).join(' ')).toBe(title)
  expect(await ui.find({ type: 'Text', text: /see memory: orchestration-setup.md/ })).toBeDefined()
  expect(await ui.find({ key: `pickup:${key.slice('ppick:'.length)}` })).toBeDefined()

  await ui.press({ key: `${key}:1` })
  expect(await lines()).toHaveLength(1)
})

test("a pick-up from this session's PARKED waits in Ready to send", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))
  const ui = await w.pane()

  await ui.press({ key: `ppick:${id}` })
  await ui.press({ key: `pickup:${id}` })
  expect(await ui.find({ type: 'Text', text: 'pick it up' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})
