import { expect, test, tier } from 'claude-code/testing'
import { INLINE, DOCKED, postedId, SESSION, SURFACES, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const REVIEW = {
  kind: 'review',
  title: 'Review Sessions & Runway, round 1',
  where: 'In Paper: the dashboard file, page "round 1", frames 1–6',
}

const DECIDE = {
  kind: 'decide',
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
  expect(await ui.find({ key: 'parked' })).toBeUndefined()
})

test("this session's view: the name and summary, what is under way and next, each heading's few words", async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.call('status', { now: ['Drawing Usage, round 2'], next: 'Usage, round 3' })
  await w.clock.advance(12 * 60_000)

  const ui = await w.pane()

  expect(await ui.find({ key: 'tab:session', text: 'This session' })).toBeDefined()
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
})

test('parked turns the board, and back', async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const surface of SURFACES) {
    const ui = await w.pane(surface)

    await ui.press({ key: 'parked' })
    expect(await ui.find({ type: 'Text', text: /Nothing parked/ })).toBeDefined()
    await ui.press({ key: 'back' })
    expect(await ui.find({ type: 'Text', text: /Nothing waiting on you/ })).toBeDefined()
    await ui.unmount()
  }
})

test('a new ask opens with its buttons, by its kind: a review approves, comments and ignores', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${id}`, text: '✓ approve' })).toBeDefined()
  expect(await ui.find({ key: `comment:${id}`, text: '✎ comment' })).toBeDefined()
  expect(await ui.find({ key: `ignore:${id}`, text: '✕ ignore' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: REVIEW.where })).toBeDefined()

  await ui.press({ key: `pick:${id}` })
  expect(await ui.find({ key: `yes:${id}` })).toBeUndefined()
})

test('a decide offers its choices and an answer, never an approve', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, DECIDE)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${id}` })).toBeUndefined()
  expect(await ui.find({ key: `comment:${id}`, text: /answer/ })).toBeDefined()
  await ui.press({ key: `choose:${id}:0` })
  expect(await ui.find({ type: 'Text', text: /→ 400 days/ })).toBeDefined()
})

test('a comment takes typed rows and saves them; cancel backs out', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `comment:${id}` })
  expect(await ui.find({ type: 'Text', text: /^Comment$/ })).toBeDefined()
  await ui.press({ key: `cancel:${id}` })
  expect(await ui.find({ type: 'Text', text: /^Comment$/ })).toBeUndefined()
  expect(await ui.find({ key: `yes:${id}` })).toBeDefined()

  await ui.press({ key: `comment:${id}` })

  for (const key of ['t', 'h', 'i', 'n', 'n', 'e', 'r']) {
    await ui.key({ key, in: `area:${id}` })
  }

  await ui.key({ key: 'return', shift: true, in: `area:${id}` })
  await ui.key({ key: 'bars', in: `area:${id}` })
  await ui.press({ key: `save:${id}` })

  expect(await ui.find({ type: 'Text', text: /comment: “thinner\nbars”/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(w.state.queue).toEqual([
    {
      project: w.state.attachment?.project,
      work: w.state.attachment?.work,
      item: id,
      verdict: 'comment',
      note: 'thinner\nbars',
    },
  ])
})

test('Enter in the field saves the comment; an empty one is refused', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `comment:${id}` })
  await ui.press({ key: `save:${id}` })
  expect(w.toasts).toContain('Type something first, or cancel.')

  await ui.key({ key: 'ok', in: `area:${id}` })
  await ui.key({ key: 'return', in: `area:${id}` })
  expect(await ui.find({ type: 'Text', text: /comment: “ok”/ })).toBeDefined()
})

test('a review takes its approve with the comment; a try or a do does not', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const review = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `comment:${review}` })
  await ui.key({ key: 'nice', in: `area:${review}` })
  await ui.press({ key: `savewith:${review}` })
  expect(await ui.find({ type: 'Text', text: /approved, with a comment: “nice”/ })).toBeDefined()

  const tried = await asked(w, { kind: 'try', title: 'Try signing in on the iPad' })

  await ui.press({ key: `comment:${tried}` })
  expect(await ui.find({ type: 'Text', text: 'How did it go?' })).toBeDefined()
  expect(await ui.find({ key: `savewith:${tried}` })).toBeUndefined()
})

test('a reply waits under its ask, not sent yet, until it is undone', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  expect(await ui.find({ type: 'Text', text: 'approved' })).toBeDefined()
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
  const second = await asked(w, { kind: 'do', title: 'Run the production apply' })
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

test('Ready to send stays at the foot of the parked view too', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))
  const ui = await w.pane()

  await ui.press({ key: 'parked' })
  await ui.press({ key: `ppick:${id}` })
  await ui.press({ key: `pickup:${id}` })
  expect(await ui.find({ type: 'Text', text: 'pick it up' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test("a surface with no text area of the mod's takes the comment in its own field", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await $.ui.mount({
    plugin: 'sitrep',
    surface: 'vscode',
    component: 'Pane',
    requestId: 'board',
    props: DOCKED,
  })

  await ui.press({ key: `comment:${id}` })
  await ui.input({ key: `field:${id}`, text: 'thinner bars' })
  expect(await ui.find({ type: 'Text', text: /comment: “thinner bars”/ })).toBeDefined()
})

test('a surface with no field to type in offers no comment', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await $.ui.mount({
    plugin: 'sitrep',
    surface: 'mobile',
    component: 'Pane',
    requestId: 'board',
    props: DOCKED,
  })

  expect(await ui.find({ key: `yes:${id}` })).toBeDefined()
  expect(await ui.find({ key: `comment:${id}` })).toBeUndefined()
})
