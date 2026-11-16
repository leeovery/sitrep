import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { projectPlace } from '../hooks/places'
import { MIN, PROJECT, REVIEW, T0 } from './data'
import { askOf, park, resolve, status } from './lines'
import { HELD, pane, sceneFrom, type Drawn } from './render'
import { asked, CONVERSATION, DOCKED, INLINE, postedId, SURFACES, world } from './world'

tier('user')

/** The review, saying where its frames are. */
const IN_PAPER = { ...REVIEW, where: 'In Paper: the help desk file, page "draft 1", panels 1–6' }

const DECIDE = {
  wants: 'choice',
  title: 'Keep the ledger 400 days, or forever?',
  options: ['400 days', 'Forever'],
}

test('an empty board says nothing waits on you, docked and inline, on each surface', async () => {
  for (const surface of SURFACES) {
    for (const props of [DOCKED, INLINE]) {
      const ui = pane(sceneFrom(), props, surface)

      expect(await ui.find({ type: 'Text', text: /Nothing waiting on you/ })).toBeDefined()
    }
  }
})

test("an empty section's line is soft, a grey lighter than its heading's few words, in a session's view and a project's", async () => {
  const colourOf = async (ui: Drawn, text: string) =>
    (await ui.find({ type: 'Text', text }))?.props.color
  const home = pane(sceneFrom())

  for (const line of ['Nothing waiting on you.', 'Nothing under way yet.', 'Nothing yet.']) {
    expect(await colourOf(home, line), line).toBe(C.soft)
  }

  for (const note of ['nothing waiting', 'what happened']) {
    expect(await colourOf(home, note), note).toBe(C.grey)
  }

  const project = pane(sceneFrom({ pane: { place: projectPlace(PROJECT.key) } }))

  expect(await colourOf(project, 'Nothing waiting on you.'), 'the project view').toBe(C.soft)
})

test('with no session held, the board says so in a line and says how Claude starts one', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)

  const ui = await w.pane()

  expect(
    await ui.find({ type: 'Text', text: /no session.*start one on the sitrep board/ }),
  ).toBeDefined()
})

test("this session's view: the name and summary, what is under way and next, each heading's few words", async () => {
  const ui = pane(
    sceneFrom({
      lines: [
        [
          T0,
          status(['Drawing Inbox, round 2'], {
            name: HELD.name,
            summary: HELD.summary,
            next: 'Inbox, round 3',
          }),
        ],
      ],
      now: T0 + 12 * MIN,
    }),
  )

  expect(await ui.find({ key: 'tab:session', text: 'Help desk redesign' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Help desk redesign' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· Northwind' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: 'Redesign the help desk, page by page' }),
  ).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'Drawing Inbox, round 2' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'next: Inbox, round 3' })).toBeDefined()

  for (const note of ['updated 12m ago', 'nothing waiting', 'what happened']) {
    expect(await ui.find({ type: 'Text', text: note }), note).toBeDefined()
  }
})

/** The view's own line and section headings, in the order drawn. */
const SECTIONS = new Set(['Help desk redesign', 'ASKS', 'STATUS', 'NOTES', 'PARKED', 'RESOLVED'])

test("this session's view runs its name and summary, then ASKS, STATUS, NOTES, PARKED and RESOLVED, docked and inline", async () => {
  const scene = sceneFrom({
    lines: [
      [T0, park('p1', 'A priority badge across all tabs')],
      [T0, askOf('k1', { wants: 'yes', yes: 'Done', title: 'Run the production apply' })],
      [T0, resolve('k1', 'Ran it in the chat')],
      [T0, askOf('k2', IN_PAPER)],
    ],
  })

  for (const props of [DOCKED, INLINE]) {
    const order = (await pane(scene, props).findAll({ type: 'Text' }))
      .map(each => each.text)
      .filter(text => SECTIONS.has(text))

    expect(order, props.placement).toEqual([...SECTIONS])
  }
})

test('a new ask opens with its buttons, by what it wants: a yes in its own words, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, IN_PAPER)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${w.item(id)}`, text: '✓ Approve' })).toBeDefined()
  expect(await ui.find({ key: `comment:${w.item(id)}`, text: '✎ comment' })).toBeDefined()
  expect(await ui.find({ key: `ignore:${w.item(id)}`, text: '✕ ignore' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^In Paper: the help desk file/ })).toBeDefined()

  await ui.press({ key: `pick:${w.item(id)}` })
  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeUndefined()
})

test('a choice offers its options and a comment, never a yes', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, DECIDE)
  const ui = await w.pane()

  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: `comment:${w.item(id)}`, text: '✎ comment' })).toBeDefined()
  await ui.press({ key: `choose:${w.item(id)}:0` })
  expect(await ui.find({ type: 'Text', text: /→ 400 days/ })).toBeDefined()
})

test('a reply waits under its ask, not sent yet, until it is undone', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, IN_PAPER)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  expect(await ui.find({ type: 'Text', text: '→ Approve' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· not sent yet' })).toBeDefined()
  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeUndefined()

  await ui.press({ key: `undo:${w.item(id)}` })
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
  expect(await ui.find({ key: `yes:${w.item(id)}` })).toBeDefined()
})

test('each reply in Ready to send can go on its own, or all at once', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const first = await asked(w, IN_PAPER)
  const second = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const ui = await w.pane()

  await ui.press({ key: `ignore:${w.item(second)}` })
  await ui.press({ key: `pick:${w.item(first)}` })
  await ui.press({ key: `yes:${w.item(first)}` })
  expect(await ui.find({ type: 'Text', text: '2 replies' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'to this session' })).toBeDefined()

  await ui.press({ key: `unready:${w.item(second)}` })
  expect(await ui.find({ type: 'Text', text: '1 reply' })).toBeDefined()

  await ui.press({ key: `pick:${w.item(second)}` })
  expect(await ui.find({ key: `ignore:${w.item(second)}` })).toBeDefined()

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
      ref: 'github.com/me/northwind/pull/82',
    }),
  )
  const ui = await w.pane()

  expect(await ui.find({ type: 'Text', text: /^NOTES$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeUndefined()

  await ui.press({ key: `log:${w.item(id)}` })
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: 'see github.com/me/northwind/pull/82' }),
  ).toBeDefined()

  await ui.press({ key: `log:${w.item(id)}` })
  expect(await ui.find({ type: 'Text', text: '6 files, +214 −51' })).toBeUndefined()
})

test('an opened item shows its whole title, and where its own record is; closed, the title keeps to a line', async ($, on) => {
  const w = world($, on)
  const title =
    "Move the pilot's results into the spreadsheet pages: contributors by team and level, owner by department, week tally, separate summaries"

  await w.begin()
  await w.call('park', { title, ref: 'notes: spreadsheet-pilot.md' })

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
    await ui.find({ type: 'Text', text: /see notes: spreadsheet-pilot.md/ }),
  ).toBeUndefined()

  await ui.press({ key })
  expect((await lines()).length).toBeGreaterThan(1)
  expect((await lines()).join(' ')).toBe(title)
  expect(await ui.find({ type: 'Text', text: /see notes: spreadsheet-pilot.md/ })).toBeDefined()
  expect(await ui.find({ key: `pickup:${key.slice('ppick:'.length)}` })).toBeDefined()

  await ui.press({ key: `${key}:1` })
  expect(await lines()).toHaveLength(1)
})

test("a pick-up from this session's PARKED waits in Ready to send", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: 'A priority badge across all tabs' }))
  const ui = await w.pane()

  await ui.press({ key: `ppick:${w.item(id)}` })
  await ui.press({ key: `pickup:${w.item(id)}` })
  expect(await ui.find({ type: 'Text', text: 'pick it up' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})
