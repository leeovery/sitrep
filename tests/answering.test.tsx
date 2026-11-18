import { expect, test, tier, type Engine } from './kit'
import { sessionPaths, type Body } from '../core'
import { CLEAR_AFTER_DROP_MS, DRAFT, LEFT, NOT_TAKEN, TAKEN } from '../hooks/answering'
import { AROUND_MS } from '../hooks/around'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import {
  answering,
  at,
  entered,
  EXPORT,
  IMAGE,
  LEDGERS_ASKS,
  LIST,
  onLedgersAsks,
  onLedgersParked,
  OUTPUT,
} from './answers'
import { rowsOf } from './drawn'
import { CLOSES, FRAMES, GO, heldItem, LEDGER, PROJECT, ROOT, T0, W1, W2, W3 } from './data'
import { askOf, delivered, file, finish, kindAsk, park, reply, type Line } from './lines'
import { pane, sceneFrom } from './render'
import { asked, BAND, CONVERSATION, DOCKED, postedId, world, type Board, type World } from './world'

tier('user')

const FOUR_LINES =
  'Northwind\n  sr-k3f9qa  Help desk redesign (open, 1 waiting)\nContoso\n  sr-eeeeee  Onboarding'

/** A paste as the engine wraps it in the prompt Lee submits, the line breaks around it with it (live, 2.1.295). */
const pasted = (text: string, id = '08fd') =>
  `\n\n<pasted_content id="${id}">\n${text}\n</pasted_content id="${id}">\n`

/** The board on a surface the world's own panes leave out. */
const paneOn = (engine: Engine, surface: 'vscode' | 'mobile') =>
  engine.ui.mount({
    plugin: 'sitrep',
    surface,
    component: 'Pane',
    requestId: 'sitrep',
    props: DOCKED,
  })

/** The band on a surface, a survey holding its place where it says. */
const bandOn = (engine: Engine, surface: 'terminal' | 'mobile', hasSurvey = false) =>
  engine.ui.mount({
    plugin: 'sitrep',
    surface,
    component: 'AbovePrompt',
    props: { ...BAND, hasSurvey },
  })

/** The band's one line, as drawn 100 columns across. */
const bandRow = async (w: World) => {
  const band = await w.band()

  return { band, rows: rowsOf(await band.find({ type: 'Box' }), 100) }
}

/** The board drawn once the watch read what `writer` wrote at T0, this window unless told, the item `selected` opened. */
const drawnWith = (bodies: readonly Body[], selected: string, writer = W1) =>
  pane(
    sceneFrom({
      lines: bodies.map((body): Line => [T0, body]),
      writer,
      pane: { selected: heldItem(selected) },
      now: T0 + WATCH_MS,
    }),
  )

test('an ask wanting a yes offers its yes in its own words, a comment, an ignore and a snooze', async () => {
  const ui = drawnWith([askOf('k1', GO)], 'k1')

  expect(rowsOf(await ui.find({ key: `ask:${heldItem('k1')}` }))[1]).toBe(
    '  [ ✓ Go ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
  )
})

test('an ask wanting a yes that names no words for it offers a plain yes', async () => {
  const ui = drawnWith([askOf('k1', { wants: 'yes', title: GO.title })], 'k1')

  expect(await ui.find({ key: `yes:${heldItem('k1')}` })).toMatchObject({ text: '✓ yes' })
})

test('an ask wanting a choice offers each option, a comment, an ignore and a snooze', async () => {
  const ui = drawnWith([askOf('k1', FRAMES)], 'k1')

  expect(rowsOf(await ui.find({ key: `ask:${heldItem('k1')}` }))[1]).toBe(
    '  [ Ship it ] [ Redraw ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
  )
})

test('an ask wanting words offers an answer, an ignore and a snooze, and hangs what its words are first, in amber', async () => {
  const ui = drawnWith([askOf('k1', LIST)], 'k1')

  expect(rowsOf(await ui.find({ key: `ask:${heldItem('k1')}` })).slice(0, 5)).toEqual([
    '◆ Run sitrep list in a shell and paste what it now',
    '│ prints',
    `├ needs: ${OUTPUT}`,
    '└ Any terminal: type sitrep list',
    '  [ ✎ Answer ] [ ✕ ignore ] [ snooze ]',
  ])
  expect((await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` }))?.props.color).toBe(C.ask)
})

test("an ask written by its kind into a session's file draws as the shape it maps to", async () => {
  const kinds = [
    kindAsk('o1', 'review', 'Review round 1'),
    kindAsk('o2', 'do', 'Run the export', { needs: OUTPUT }),
  ]
  const ui = drawnWith(kinds, 'o2', W2)

  expect(await ui.find({ key: `answer:${heldItem('o2')}`, text: '✎ Answer' })).toBeDefined()
  expect(await ui.find({ key: `yes:${heldItem('o2')}` })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeDefined()

  const opened = drawnWith(kinds, 'o1', W2)

  expect(await opened.find({ key: `yes:${heldItem('o1')}`, text: '✓ Approve' })).toBeDefined()
  expect(await opened.find({ key: `comment:${heldItem('o1')}`, text: '✎ comment' })).toBeDefined()
})

test('✎ Answer has the next Enter in the prompt answer the ask: it says so under the ask, its buttons gone', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  expect(w.state.answering).toEqual({
    ...at(w, id),
    as: 'answer',
    title: LIST.title,
    surface: 'terminal',
  })
  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).slice(2)).toEqual([
    `├ needs: ${OUTPUT}`,
    '├ Any terminal: type sitrep list',
    '└ answering in the prompt…',
  ])
  expect(await ui.find({ key: `answer:${w.item(id)}` })).toBeUndefined()
})

test('✎ comment has the next Enter comment on the ask', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `comment:${w.item(id)}` })
  expect(w.state.answering).toEqual({
    ...at(w, id),
    as: 'comment',
    title: GO.title,
    surface: 'terminal',
  })
  expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter comments on /)
})

test('with a draft in the prompt, ✎ is refused, and the draft is left as it is', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.pane()

  w.box.text = 'half a thought'
  await ui.press({ key: `answer:${w.item(id)}` })
  expect(w.toasts).toContain(DRAFT)
  expect(w.state.answering ?? null).toBeNull()
  expect(w.box.text).toBe('half a thought')
})

test('while answering, the band says only what the next Enter does, pointing at the prompt, and cancel', async ($, on) => {
  const w = world($, on)

  await answering(w)

  const { band, rows } = await bandRow(w)
  const says = `✎ Your next Enter answers "${LIST.title}"  ↓`

  expect(rows).toEqual([`${says.padEnd(100 - 'cancel'.length)}cancel`])
  expect(await band.find({ key: 'band:asks' })).toBeUndefined()
  expect(await band.find({ key: 'band:board' })).toBeUndefined()
})

test('the band clips a long title to keep cancel on its line', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { wants: 'words', title: 'Run sitrep list '.repeat(8).trim() })
  const ui = await w.pane()

  await ui.press({ key: `answer:${w.item(id)}` })

  const { rows } = await bandRow(w)

  expect(rows).toHaveLength(1)
  expect(rows[0]).toMatch(/^✎ Your next Enter answers "Run sitrep list .*…" {2}↓ +cancel$/)
  expect([...(rows[0] ?? '')].length).toBeLessThanOrEqual(100)
})

test('below 64 columns the band says Enter alone, so the title keeps room and cancel its line', async ($, on) => {
  const w = world($, on)

  await answering(w)

  const band = await w.band('terminal', 46)
  const rows = rowsOf(await band.find({ type: 'Box' }), 46)

  expect(rows).toHaveLength(1)
  expect(rows[0]).toMatch(/^✎ Enter answers "[^…"]{8,}…?" {2}↓ +cancel$/)
  expect([...(rows[0] ?? '')].length).toBeLessThanOrEqual(46)
})

test('cancel on the band ends it in one press: the counts are back, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)
  const { band } = await bandRow(w)

  await band.press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(await band.find({ key: 'band:asks' })).toBeDefined()
  expect(await ui.find({ key: `answer:${w.item(id)}` })).toBeDefined()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Carry on.'])
})

test('the next Enter is taken as the answer: queued in Ready to send, nothing to Claude, the box emptied', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  expect(await entered(w, $, 'v1.2.3')).toEqual({ drop: TAKEN.answer })
  expect(w.prompts).toEqual([])
  expect(w.toasts).not.toContain(TAKEN.answer)
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'v1.2.3' }])
  expect(w.state.answering).toBeNull()
  expect(w.box.text).toBe('v1.2.3')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('')
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
})

test('a paste is taken unwrapped, the words typed around it in their place', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  expect(await entered(w, $, `Ran it:${pasted(FOUR_LINES)}Looks right?`)).toEqual({
    drop: TAKEN.answer,
  })
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'answer', note: `Ran it:\n${FOUR_LINES}\nLooks right?` },
  ])
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('')
})

test('an empty Enter, an image attached or not, is not taken: a toast, the prompt kept, the mode still on', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  expect(await entered(w, $, '  \n ')).toEqual({ drop: NOT_TAKEN })
  expect(await entered(w, $, '', { attachments: [IMAGE] })).toEqual({ drop: NOT_TAKEN })
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(
    w.toasts.filter(
      toast => toast === 'Write your answer in the prompt first, or cancel it on the band.',
    ),
  ).toHaveLength(2)
  expect(w.prompts).toEqual([])
  expect(w.state.queue ?? []).toEqual([])
  expect(w.state.answering).toMatchObject({ item: id })
})

test('one Enter only: the prompt after the answer goes to Claude as ever', async ($, on) => {
  const w = world($, on)

  await answering(w)
  await entered(w, $, 'v1.2.3')
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Carry on.'])
  expect(w.state.queue).toHaveLength(1)
})

test("a prompt that is not Lee's own, a background task's, goes to Claude while answering, and the mode stands", async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  expect(
    (await entered(w, $, 'Task done.', { origin: { kind: 'task-notification' } })).drop,
  ).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Task done.'])
  expect(w.state.answering).toMatchObject({ item: id })
})

test('a comment on an ask whose yes is queued goes with the yes, as its note', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).at(-1)).toBe(
    '└ → Go · not sent yet ↺ undo ✎ comment',
  )
  await ui.press({ key: `rewrite:${w.item(id)}` })
  expect(w.state.answering).toMatchObject({ item: id, as: 'comment' })
  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).slice(-2)).toEqual([
    '├ → Go · not sent yet ↺ undo ✎ comment',
    '└ answering in the prompt…',
  ])
  expect(await entered(w, $, 'After the copy pass')).toEqual({ drop: TAKEN.comment })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'After the copy pass' }])
  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).at(-1)).toBe(
    '└ → Go, with a comment: “After the copy pass” · not sent yet ↺ undo ✎ edit',
  )
})

test('a comment on an ask with nothing queued is queued as a comment', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  await ui.press({ key: `comment:${w.item(id)}` })
  await entered(w, $, 'Frames 2 and 5 need another pass')
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'comment', note: 'Frames 2 and 5 need another pass' },
  ])
})

test('a queued reply of several lines shows its first, how many more, then not sent yet, undo and edit', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  await entered(w, $, pasted(FOUR_LINES))
  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).at(-1)).toBe(
    '└ “Northwind” +3 lines · not sent yet ↺ undo ✎ edit',
  )
  expect(rowsOf(await ui.find({ key: `readyanswer:${w.item(id)}` }))).toEqual([
    '└ “Northwind” +3 lines ✎ edit',
  ])
})

test('✎ edit fills the prompt with the queued words, and the next Enter replaces them', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  await entered(w, $, 'v1.2.3')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `rewrite:${w.item(id)}` })
  expect(w.box.text).toBe('v1.2.3')
  expect(w.state.answering).toMatchObject({ item: id, as: 'answer' })
  expect(await entered(w, $, 'v1.2.4')).toEqual({ drop: TAKEN.answer })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'v1.2.4' }])
})

test('✎ edit from Ready to send does the same, and is refused while the prompt holds a draft', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  await entered(w, $, 'v1.2.3')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  w.box.text = 'something else'
  await ui.press({ key: `readyrewrite:${w.item(id)}` })
  expect(w.toasts).toContain(DRAFT)
  expect(w.state.answering).toBeNull()

  w.box.text = ''
  await ui.press({ key: `readyrewrite:${w.item(id)}` })
  expect(w.box.text).toBe('v1.2.3')
  expect(w.state.answering).toMatchObject({ item: id, as: 'answer' })
})

test('one send carries the yes with its comment, the choice and the answer, in one message', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const go = await asked(w, GO)
  const frames = await asked(w, FRAMES)
  const list = await asked(w, LIST)
  const ui = await w.pane()

  await ui.press({ key: `pick:${w.item(go)}` })
  await ui.press({ key: `yes:${w.item(go)}` })
  await ui.press({ key: `rewrite:${w.item(go)}` })
  await entered(w, $, 'After the copy pass')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `pick:${w.item(frames)}` })
  await ui.press({ key: `choose:${w.item(frames)}:1` })
  await ui.press({ key: `pick:${w.item(list)}` })
  await ui.press({ key: `answer:${w.item(list)}` })
  await entered(w, $, `Ran it:${pasted(FOUR_LINES)}`)
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: 'send' })

  expect(w.prompts.map(each => each.text)).toEqual([
    [
      'From the board:',
      '- Give the ok for phase 3 → Go, with a comment: “After the copy pass”',
      '  This closes the ask: nothing more to do with it.',
      '- Ship round 2, or redraw? → Redraw',
      '  This closes the ask: nothing more to do with it.',
      `- ${LIST.title} → ${OUTPUT}:`,
      '  ```',
      '  Ran it:',
      '  Northwind',
      '    sr-k3f9qa  Help desk redesign (open, 1 waiting)',
      '  Contoso',
      '    sr-eeeeee  Onboarding',
      '  ```',
      '  This closes the ask: nothing more to do with it.',
    ].join('\n'),
  ])
  expect(w.state.board?.asks.map(each => each.state)).toEqual(['closed', 'closed', 'closed'])
})

test('the mode ends once its ask closes: the band shows the counts, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  await w.call('resolve', { item: id, reason: 'Ran it myself' })
  expect(w.state.answering).toBeNull()

  const { band } = await bandRow(w)

  expect(await band.find({ key: 'band:asks' })).toBeDefined()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts).toHaveLength(1)
})

test('the mode ends once its ask closes in another window, and does not come back when it reopens', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)
  const paths = sessionPaths(ROOT, PROJECT.key, w.state.attachment?.session ?? '')
  const other = w.writer(paths)

  other({ type: 'resolve', item: id })
  await w.clock.advance(WATCH_MS)
  expect(w.state.answering).toBeNull()

  other({ type: 'reopen', item: id })
  await w.clock.advance(WATCH_MS)
  expect(w.state.answering).toBeNull()
})

test('a send carrying the reply its comment would go with ends the mode: the band shows the counts, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })

  const held = w.holdPrompts()

  await ui.press({ key: 'send' })
  await held.arrived

  const { band } = await bandRow(w)

  expect(await band.find({ key: 'band:asks' })).toBeDefined()

  const typed = entered(w, $, 'Carry on.')

  held.end()
  expect((await typed).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- Give the ok for phase 3 → Go${CLOSES}`,
    'Carry on.',
  ])
  expect(w.state.answering).toBeNull()
})

test('the mode ends when the window takes up another session, or the conversation ends', async ($, on) => {
  const w = world($, on)
  const { ui } = await answering(w)

  await w.call('start', { name: 'Another', summary: 'Another one', project: PROJECT.name })
  expect(w.state.answering).toBeNull()

  const id = await asked(w, LIST)

  await ui.press({ key: `answer:${w.item(id)}` })
  expect(w.state.answering).toMatchObject({ item: id })
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
  expect(w.state.answering).toBeNull()
})

test('a reload keeps the mode: the band still shows it, and the next Enter is still the answer', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  await $.session.start(CONVERSATION)

  const { rows } = await bandRow(w)

  expect(rows[0]).toMatch(/^✎ Your next Enter answers/)
  expect(await entered(w, $, 'v1.2.3')).toEqual({ drop: TAKEN.answer })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'v1.2.3' }])
})

test("in Claude's app, ✎ answers too, the app's Enter taken as the answer; its box out of reach, nothing offers to edit", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await paneOn($, 'mobile')

  await ui.press({ key: `answer:${w.item(id)}` })
  expect(await entered(w, $, 'v1.2.3', { origin: { kind: 'bridge' } })).toEqual({
    drop: TAKEN.answer,
  })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'v1.2.3' }])
  expect(await ui.find({ key: `rewrite:${w.item(id)}` })).toBeUndefined()

  const go = await asked(w, GO)

  await ui.press({ key: `yes:${w.item(go)}` })
  expect(await ui.find({ key: `rewrite:${w.item(go)}`, text: '✎ comment' })).toBeDefined()
})

test('VS Code, whose prompts arrive some way unproven, offers nothing to write: words asks only ignore there', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const go = await asked(w, GO)
  const ui = await paneOn($, 'vscode')

  await ui.press({ key: `pick:${w.item(id)}` })
  expect(await ui.find({ key: `answer:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: `ignore:${w.item(id)}` })).toBeDefined()
  await ui.press({ key: `pick:${w.item(go)}` })
  expect(await ui.find({ key: `comment:${w.item(go)}` })).toBeUndefined()
  await ui.press({ key: `yes:${w.item(go)}` })
  expect(await ui.find({ key: `rewrite:${w.item(go)}` })).toBeUndefined()
})

for (const [as, press, item] of [
  ['answering', 'answer', 'k3'],
  ['commenting on', 'comment', 'k4'],
] as const) {
  test(`${as} another session's ask from the project's view stands from the press, a redraw of this session's board between, and its Enter is taken`, async ($, on) => {
    const w = world($, on)
    const ui = await onLedgersAsks(w, true)
    const there = w.item(item, LEDGER.id)

    await ui.press({ key: `pick:${there}` })
    await ui.press({ key: `${press}:${there}` })
    expect(w.state.others, 'the ledger not read in full').toEqual([])
    expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter (answers|comments on) /)

    await w.call('park', { title: 'The schema is drawn' })
    expect(w.state.answering, 'a redraw of the held board').toMatchObject({
      session: LEDGER.id,
      item,
    })

    expect((await entered(w, $, 'id, at, by')).drop).toBeDefined()
    expect(w.state.queue).toEqual([
      { project: PROJECT.key, session: LEDGER.id, item, verdict: press, note: 'id, at, by' },
    ])
    expect(w.prompts).toEqual([])
  })
}

for (const [as, press, item, landing, isStanding] of [
  ['commenting on', 'comment', 'k4', reply('r9', 'k4', 'yes'), true],
  ['answering', 'answer', 'k3', reply('r9', 'k3', 'answer', { note: 'id, at' }), false],
] as const) {
  test(`${as} another session's ask as Lee's answer to it from another window lands: ${isStanding ? 'it stands, an answer barring no comment' : 'it ends, the ask taking no second answer'}`, async ($, on) => {
    const w = world($, on)
    const ui = await onLedgersAsks(w)
    const there = w.item(item, LEDGER.id)

    await ui.press({ key: `pick:${there}` })
    await ui.press({ key: `${press}:${there}` })
    w.put(sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W3), file([w.clock.now(), landing]))
    await w.clock.advance(AROUND_MS)

    expect(w.state.answering !== null).toBe(isStanding)
  })
}

test("answering another session's ask has the board read that session in full at once", async ($, on) => {
  const w = world($, on)
  const ui = await onLedgersAsks(w)
  const there = w.item('k3', LEDGER.id)

  expect(w.state.others).toEqual([])
  await ui.press({ key: `pick:${there}` })
  await ui.press({ key: `answer:${there}` })
  expect(w.state.others?.map(other => other.board.id)).toEqual([LEDGER.id])
})

test('the mode begun at the terminal takes nothing from Claude’s app, whose band shows the counts', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)
  const app = await bandOn($, 'mobile')

  expect(await app.find({ key: 'band:asks' })).toBeDefined()
  expect((await entered(w, $, 'v1.2.3', { origin: { kind: 'bridge' } })).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['v1.2.3'])
  expect(w.state.answering).toMatchObject({ item: id, surface: 'terminal' })
  expect(await entered(w, $, 'v1.2.4')).toEqual({ drop: TAKEN.answer })
})

test('the mode begun in Claude’s app takes nothing from the terminal, whose band shows the counts', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)

  await (await paneOn($, 'mobile')).press({ key: `answer:${w.item(id)}` })
  expect(await (await w.band()).find({ key: 'band:asks' })).toBeDefined()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Carry on.'])
  expect(await entered(w, $, 'v1.2.3', { origin: { kind: 'bridge' } })).toEqual({
    drop: TAKEN.answer,
  })
})

test('while a survey holds the band in its place, the mode is hidden and takes nothing; it stands, and takes the Enter once the band is back', async ($, on) => {
  const w = world($, on)

  // What the engine draws in the band's place while its survey holds it.
  on('ui.render', ($, e) => {
    const { Box } = $.ui.resolve(e)

    return <Box />
  })

  const { id } = await answering(w)

  await bandOn($, 'terminal', true)
  expect((await entered(w, $, '3')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['3'])
  expect(w.state.answering).toMatchObject({ item: id })

  expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter answers/)
  expect(await entered(w, $, 'v1.2.3')).toEqual({ drop: TAKEN.answer })
})

/** The board on the words ask, answered, then ✎ edit pressed: the prompt holds the queued words again. */
const editing = async (w: World, engine: Engine) => {
  const { id, ui } = await answering(w)

  await entered(w, engine, 'v1.2.3')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `rewrite:${w.item(id)}` })
  expect(w.box.text).toBe('v1.2.3')

  return { id, ui }
}

test('✎ edit then cancel empties the prompt of the words it put there', async ($, on) => {
  const w = world($, on)

  await editing(w, $)
  await (await w.band()).press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(w.box.text).toBe('')
  expect(w.toasts).not.toContain(LEFT)
})

test('✎ edit then the ask closing empties the prompt of the words it put there', async ($, on) => {
  const w = world($, on)
  const { id } = await editing(w, $)

  await w.call('resolve', { item: id, reason: 'Ran it myself' })
  expect(w.state.answering).toBeNull()
  expect(w.box.text).toBe('')
})

test('✎ edit, the words changed, then cancel leaves them in the prompt, and a toast says so', async ($, on) => {
  const w = world($, on)

  await editing(w, $)
  w.box.text = 'v1.2.3, and the build number'
  await (await w.band()).press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(w.box.text).toBe('v1.2.3, and the build number')
  expect(w.toasts).toContain(LEFT)
})

test('a send carrying the reply being edited empties the prompt of its words as it is claimed', async ($, on) => {
  const w = world($, on)
  const { ui } = await editing(w, $)
  const held = w.holdPrompts()
  const pressed = ui.press({ key: 'send' })

  await held.arrived
  expect(w.state.answering).toBeNull()
  expect(w.box.text).toBe('')

  held.end()
  await pressed
})

test('✎ on another ask while editing: the words the mode put in the prompt are no draft, and give way', async ($, on) => {
  const w = world($, on)
  const { ui } = await editing(w, $)
  const go = await asked(w, GO)

  await ui.press({ key: `comment:${w.item(go)}` })
  expect(w.toasts).not.toContain(DRAFT)
  expect(w.state.answering).toMatchObject({ item: go, as: 'comment' })
  expect(w.box.text).toBe('')
})

test('a comment that closes an old decide is an answer everywhere: its button, the band and the transcript', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  w.writer(paths)(
    kindAsk('o2', 'decide', 'Keep the ledger 400 days, or forever?', {
      options: ['400 days', 'Forever'],
    }),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.pane()

  expect(await ui.find({ key: `comment:${w.item('o2')}`, text: '✎ answer' })).toBeDefined()
  await ui.press({ key: `comment:${w.item('o2')}` })
  expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter answers "Keep the ledger/)
  expect(await entered(w, $, 'Two years, then archive')).toEqual({ drop: TAKEN.answer })
  await w.clock.advance(CLEAR_AFTER_DROP_MS)

  await ui.press({ key: `unready:${w.item('o2')}` })
  await ui.press({ key: `choose:${w.item('o2')}:1` })
  await ui.press({ key: `rewrite:${w.item('o2')}` })
  expect((await bandRow(w)).rows[0], 'a comment going with the choice').toMatch(
    /^✎ Your next Enter comments on /,
  )
  expect(await entered(w, $, 'Storage is cheap')).toEqual({ drop: TAKEN.comment })
})

const TMUX = 'A priority badge'

/** The board, opened by /sitrep, on a parked item, opened. */
const onParked = async (w: World) => {
  const { paths } = await w.begin()
  const id = postedId(await w.call('park', { title: TMUX }))
  const ui = await w.opened()

  await ui.press({ key: `ppick:${w.item(id)}` })

  return { id, ui, paths }
}

/** The board on a parked item, ✎ with a comment pressed: the next Enter picks it up. */
const pickingUp = async (w: World) => {
  const parked = await onParked(w)

  await parked.ui.press({ key: `comment:${w.item(parked.id)}` })

  return parked
}

/** The rows a parked item is drawn on. */
const parkedRows = async (ui: Board, key: string) => rowsOf(await ui.find({ key: `parked:${key}` }))

test('an opened parked item offers pick it up, ✎ with a comment and ✕ drop; none once a pick-up is queued', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await onParked(w)

  expect((await parkedRows(ui, w.item(id))).at(-1)).toBe(
    '  [ pick it up ] [ ✎ with a comment ] [ ✕ drop ]',
  )
  await ui.press({ key: `pickup:${w.item(id)}` })
  expect(await parkedRows(ui, w.item(id))).toEqual([
    expect.stringMatching(/^◇ A priority badge/),
    '└ pick it up · not sent yet ↺ undo',
  ])
  expect(await ui.find({ key: `pickup:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: `comment:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: `drop:${w.item(id)}` })).toBeUndefined()
})

test('✎ with a comment has the next Enter pick the parked item up: it says so under the item, its buttons gone, and the band names it', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await pickingUp(w)

  expect(w.state.answering).toEqual({
    ...at(w, id),
    as: 'pickup',
    title: TMUX,
    surface: 'terminal',
  })
  expect((await parkedRows(ui, w.item(id))).slice(1)).toEqual(['└ answering in the prompt…'])
  expect(await ui.find({ key: `pickup:${w.item(id)}` })).toBeUndefined()

  const { rows } = await bandRow(w)
  const says = `✎ Your next Enter picks up "${TMUX}"  ↓`

  expect(rows).toEqual([`${says.padEnd(100 - 'cancel'.length)}cancel`])
})

test('the next Enter is taken as the pick-up, its words the note: queued in Ready to send, nothing to Claude, the box emptied', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await pickingUp(w)

  expect(await entered(w, $, 'Before the release')).toEqual({
    drop: 'Your pick-up waits in Ready to send.',
  })
  expect(w.prompts).toEqual([])
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'pickup', note: 'Before the release' }])
  expect(w.state.answering).toBeNull()
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('')
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
})

test('a send carries the pick-up with its note, and the item picked up opens to the note', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await pickingUp(w)

  await entered(w, $, 'Before the release')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: 'send' })

  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- Pick up from parked: ${TMUX}. Before the release`,
  ])
  await ui.press({ key: `pickedup:project:${PROJECT.key}` })
  await ui.press({ key: `picked:${w.item(id)}` })
  expect(rowsOf(await ui.find({ key: `taken:${w.item(id)}` }))).toEqual([
    `✓ ${TMUX} · picked up by Help desk now`,
    '│ redesign',
    '└ Before the release',
  ])
})

test('cancel ends picking up in one press: the buttons and the counts are back, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await pickingUp(w)
  const { band } = await bandRow(w)

  await band.press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(await band.find({ key: 'band:asks' })).toBeDefined()
  expect(await ui.find({ key: `comment:${w.item(id)}` })).toBeDefined()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Carry on.'])
})

test('a reload keeps picking up: the band still names it, and the next Enter is still the pick-up', async ($, on) => {
  const w = world($, on)
  const { id } = await pickingUp(w)

  await $.session.start(CONVERSATION)
  expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter picks up "A priority badge"/)
  expect(await entered(w, $, 'Before the release')).toEqual({ drop: TAKEN.pickup })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'pickup', note: 'Before the release' }])
})

test('picking up ends once the parked item is picked up from elsewhere: the counts are back, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await pickingUp(w)

  w.writer(paths)(reply('r9', id, 'pickup'), delivered('r9'))
  await w.clock.advance(WATCH_MS)
  expect(w.state.answering).toBeNull()
  expect(await (await w.band()).find({ key: 'band:asks' })).toBeDefined()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual(['Carry on.'])
})

test("picking up another session's parked item from the project's view stands from the press, and its Enter is taken", async ($, on) => {
  const w = world($, on)

  await onLedgersParked(w, true)
  expect(w.state.others, 'the ledger not read in full').toEqual([])
  expect((await bandRow(w)).rows[0]).toMatch(`✎ Your next Enter picks up "${EXPORT}"`)
  expect(await entered(w, $, 'With the totals')).toEqual({ drop: TAKEN.pickup })
  expect(w.state.queue).toEqual([
    {
      project: PROJECT.key,
      session: LEDGER.id,
      item: 'p3',
      verdict: 'pickup',
      note: 'With the totals',
    },
  ])
  expect(w.prompts).toEqual([])
})

test("picking up another session's parked item stands once its session is finished: the item is its project's", async ($, on) => {
  const w = world($, on)
  const ledger = await onLedgersParked(w)

  expect(w.state.answering).toMatchObject({ session: LEDGER.id, item: 'p3', as: 'pickup' })
  ledger.write(finish('claude', 'Shipped'))
  await w.clock.advance(AROUND_MS)
  expect(w.state.answering).toMatchObject({ session: LEDGER.id, item: 'p3', as: 'pickup' })
  expect(await entered(w, $, 'With the totals')).toEqual({ drop: TAKEN.pickup })
  expect(w.state.queue).toEqual([
    {
      project: PROJECT.key,
      session: LEDGER.id,
      item: 'p3',
      verdict: 'pickup',
      note: 'With the totals',
    },
  ])
})

test("answering another session's ask still ends once its session is finished", async ($, on) => {
  const w = world($, on)
  const ui = await onLedgersAsks(w)
  const there = w.item('k3', LEDGER.id)

  await ui.press({ key: `pick:${there}` })
  await ui.press({ key: `answer:${there}` })
  expect(w.state.answering).toMatchObject({ session: LEDGER.id, item: 'k3' })
  // A writer of its own writes the ledger's file whole: its asks kept with the finish, so the finish alone ends the mode.
  w.writer(sessionPaths(ROOT, PROJECT.key, LEDGER.id), W2)(
    ...LEDGERS_ASKS,
    finish('claude', 'Shipped'),
  )
  await w.clock.advance(AROUND_MS)
  expect(w.state.answering).toBeNull()
  expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
})

test('a queued pick-up with a note shows it, how many lines more, undo and ✎ edit; edit fills the prompt, and the next Enter replaces the note', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await pickingUp(w)

  await entered(w, $, pasted(FOUR_LINES))
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect((await parkedRows(ui, w.item(id))).at(-1)).toBe(
    '└ pick it up, with a comment: “Northwind” +3 lines · not sent yet ↺ undo ✎ edit',
  )
  expect(rowsOf(await ui.find({ key: `readyanswer:${w.item(id)}` }))).toEqual([
    '└ pick it up, with a comment: “Northwind” +3 lines ✎ edit',
  ])

  await ui.press({ key: `rewrite:${w.item(id)}` })
  expect(w.box.text).toBe(FOUR_LINES)
  expect(w.state.answering).toMatchObject({ item: id, as: 'pickup' })
  expect((await bandRow(w)).rows[0]).toMatch(/^✎ Your next Enter picks up /)
  expect(await entered(w, $, 'Before the release')).toEqual({ drop: TAKEN.pickup })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'pickup', note: 'Before the release' }])
})

test("in Claude's app ✎ with a comment picks up too, nothing offering to edit it; VS Code offers only the pick-up", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('park', { title: TMUX }))
  const app = await paneOn($, 'mobile')

  await app.press({ key: `ppick:${w.item(id)}` })
  await app.press({ key: `comment:${w.item(id)}` })
  expect(await entered(w, $, 'Before the release', { origin: { kind: 'bridge' } })).toEqual({
    drop: TAKEN.pickup,
  })
  expect(await app.find({ key: `rewrite:${w.item(id)}` })).toBeUndefined()

  await app.press({ key: `unready:${w.item(id)}` })

  const vscode = await paneOn($, 'vscode')

  expect(await vscode.find({ key: `pickup:${w.item(id)}` })).toBeDefined()
  expect(await vscode.find({ key: `comment:${w.item(id)}` })).toBeUndefined()
})
