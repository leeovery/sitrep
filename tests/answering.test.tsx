import { expect, test, tier } from 'claude-code/testing'
import { workPaths } from '../core'
import { CLEAR_AFTER_DROP_MS, DRAFT, NOT_TAKEN, TAKEN } from '../hooks/answering'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { kindAsk, SLOW, W1 } from './support'
import { DOCKED, postedId, PROJECT, ROOT, SESSION, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Engine = Parameters<typeof world>[0]

const OUTPUT = "the command's output"

const GO = { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' }

const FRAMES = {
  wants: 'choice',
  title: 'Ship round 2, or redraw?',
  options: ['Ship it', 'Redraw'],
}

const LIST = {
  wants: 'words',
  title: 'Run sitrep list in a shell and paste what it prints',
  where: 'Any terminal: type sitrep list',
  needs: OUTPUT,
}

const FOUR_LINES =
  'Switchboard\n  sr-k3f9qa  Dashboard redesign (open, 1 waiting)\nSitRep\n  sr-wdsqvn  sitrep'

/** A paste as the engine wraps it in the prompt Lee submits, the line breaks around it with it (live, 2.1.295). */
const pasted = (text: string, id = '08fd') =>
  `\n\n<pasted_content id="${id}">\n${text}\n</pasted_content id="${id}">\n`

/** Claude posts an ask, which the board opens as it does a new one: its id. */
const asked = async (w: World, ask: { [key: string]: unknown }) =>
  postedId(await w.call('ask', ask))

/** Lee pressing Enter at the prompt with `text` in it, the box holding what it showed. */
const entered = (
  w: World,
  engine: Engine,
  text: string,
  extra: {
    attachments?: readonly { type: 'image' }[]
    origin?: { kind: 'composer' | 'bridge' | 'task-notification' }
  } = {},
) => {
  w.box.text = text.includes('<pasted_content') ? '[Pasted text #1 +3 lines]' : text

  return engine.prompt.submit({ text, wait: false, origin: { kind: 'composer' }, ...extra })
}

/** Where a reply to an ask of the held work goes. */
const at = (w: World, item: string) => ({
  project: w.state.attachment?.project,
  work: w.state.attachment?.work,
  item,
})

/** The board on a surface the world's own panes leave out. */
const paneOn = (engine: Engine, surface: 'vscode' | 'mobile') =>
  engine.ui.mount({
    plugin: 'sitrep',
    surface,
    component: 'Pane',
    requestId: 'sitrep',
    props: DOCKED,
  })

/** The band's one line, as drawn 100 columns across. */
const bandRow = async (w: World) => {
  const band = await w.band()

  return { band, rows: rowsOf(await band.find({ type: 'Box' }), 100) }
}

/** The board, opened by /sitrep, on the words ask, answering it. */
const answering = async (w: World) => {
  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.opened()

  await ui.press({ key: `answer:${id}` })

  return { id, ui }
}

test('an ask wanting a yes offers its yes in its own words, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${id}` }))[1]).toBe(
    '  [ ✓ Go ] [ ✎ comment ] [ ✕ ignore ]',
  )
})

test('an ask wanting a choice offers each option, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${id}` }))[1]).toBe(
    '  [ Ship it ] [ Redraw ] [ ✎ comment ] [ ✕ ignore ]',
  )
})

test('an ask wanting words offers an answer and an ignore, and hangs what its words are first, in amber', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${id}` })).slice(0, 5)).toEqual([
    '◆ Run sitrep list in a shell and paste what it now',
    '│ prints',
    `├ needs: ${OUTPUT}`,
    '└ Any terminal: type sitrep list',
    '  [ ✎ Answer ] [ ✕ ignore ]',
  ])
  expect((await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` }))?.props.color).toBe(C.ask)
})

test("an ask written by its kind into a work's file draws as the shape it maps to", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  w.writer(paths)(
    kindAsk('o1', 'review', 'Review round 1'),
    kindAsk('o2', 'do', 'Run the export', { needs: OUTPUT }),
  )
  await w.clock.advance(WATCH_MS)

  const ui = await w.pane()

  expect(await ui.find({ key: 'answer:o2', text: '✎ Answer' })).toBeDefined()
  expect(await ui.find({ key: 'yes:o2' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeDefined()
  await ui.press({ key: 'pick:o1' })
  expect(await ui.find({ key: 'yes:o1', text: '✓ Approve' })).toBeDefined()
  expect(await ui.find({ key: 'comment:o1', text: '✎ comment' })).toBeDefined()
})

test('✎ Answer has the next Enter in the prompt answer the ask: it says so under the ask, its buttons gone', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  expect(w.state.answering).toEqual({ ...at(w, id), as: 'answer', title: LIST.title })
  expect(rowsOf(await ui.find({ key: `ask:${id}` })).slice(2)).toEqual([
    `├ needs: ${OUTPUT}`,
    '├ Any terminal: type sitrep list',
    '└ answering in the prompt…',
  ])
  expect(await ui.find({ key: `answer:${id}` })).toBeUndefined()
})

test('✎ comment has the next Enter comment on the ask', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `comment:${id}` })
  expect(w.state.answering).toEqual({ ...at(w, id), as: 'comment', title: GO.title })
})

test('with a draft in the prompt, ✎ is refused, and the draft is left as it is', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.pane()

  w.box.text = 'half a thought'
  await ui.press({ key: `answer:${id}` })
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
  expect(await band.find({ key: 'band:for-you' })).toBeUndefined()
  expect(await band.find({ key: 'band:board' })).toBeUndefined()
})

test('the band clips a long title to keep cancel on its line', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { wants: 'words', title: 'Run sitrep list '.repeat(8).trim() })
  const ui = await w.pane()

  await ui.press({ key: `answer:${id}` })

  const { rows } = await bandRow(w)

  expect(rows).toHaveLength(1)
  expect(rows[0]).toMatch(/^✎ Your next Enter answers "Run sitrep list .*…" {2}↓ +cancel$/)
  expect([...(rows[0] ?? '')].length).toBeLessThanOrEqual(100)
})

test('cancel on the band ends it in one press: the counts are back, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)
  const { band } = await bandRow(w)

  await band.press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(await band.find({ key: 'band:for-you' })).toBeDefined()
  expect(await ui.find({ key: `answer:${id}` })).toBeDefined()
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

test('an empty Enter, or one with something attached, is not taken: a toast, the prompt kept, the mode still on', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  expect(await entered(w, $, '  \n ')).toEqual({ drop: NOT_TAKEN })
  expect(await entered(w, $, 'See the screenshot', { attachments: [{ type: 'image' }] })).toEqual({
    drop: NOT_TAKEN,
  })
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('See the screenshot')
  expect(w.toasts).toContain('Write your answer in the prompt first, or cancel it on the band.')
  expect(w.toasts).toContain(
    'An answer is words alone: take the attachment out, or cancel answering on the band.',
  )
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

  await ui.press({ key: `yes:${id}` })
  expect(rowsOf(await ui.find({ key: `ask:${id}` })).at(-1)).toBe(
    '└ → Go · not sent yet ↺ undo ✎ comment',
  )
  await ui.press({ key: `rewrite:${id}` })
  expect(w.state.answering).toMatchObject({ item: id, as: 'comment' })
  expect(rowsOf(await ui.find({ key: `ask:${id}` })).slice(-2)).toEqual([
    '├ → Go · not sent yet ↺ undo ✎ comment',
    '└ answering in the prompt…',
  ])
  expect(await entered(w, $, 'After the copy pass')).toEqual({ drop: TAKEN.comment })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'After the copy pass' }])
  expect(rowsOf(await ui.find({ key: `ask:${id}` })).at(-1)).toBe(
    '└ → Go, with a comment: “After the copy pass” · not sent yet ↺ undo ✎ edit',
  )
})

test('a comment on an ask with nothing queued is queued as a comment', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  await ui.press({ key: `comment:${id}` })
  await entered(w, $, 'Frames 2 and 5 need another pass')
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'comment', note: 'Frames 2 and 5 need another pass' },
  ])
})

test('a queued reply of several lines shows its first, how many more, then not sent yet, undo and edit', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  await entered(w, $, pasted(FOUR_LINES))
  expect(rowsOf(await ui.find({ key: `ask:${id}` })).at(-1)).toBe(
    '└ “Switchboard” +3 lines · not sent yet ↺ undo ✎ edit',
  )
  expect(rowsOf(await ui.find({ key: `readyanswer:${id}` }))).toEqual([
    '└ “Switchboard” +3 lines ✎ edit',
  ])
})

test('✎ edit fills the prompt with the queued words, and the next Enter replaces them', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)

  await entered(w, $, 'v1.2.3')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `rewrite:${id}` })
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
  await ui.press({ key: `readyrewrite:${id}` })
  expect(w.toasts).toContain(DRAFT)
  expect(w.state.answering).toBeNull()

  w.box.text = ''
  await ui.press({ key: `readyrewrite:${id}` })
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

  await ui.press({ key: `pick:${go}` })
  await ui.press({ key: `yes:${go}` })
  await ui.press({ key: `rewrite:${go}` })
  await entered(w, $, 'After the copy pass')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `pick:${frames}` })
  await ui.press({ key: `choose:${frames}:1` })
  await ui.press({ key: `pick:${list}` })
  await ui.press({ key: `answer:${list}` })
  await entered(w, $, `Ran it:${pasted(FOUR_LINES)}`)
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: 'send' })

  expect(w.prompts.map(each => each.text)).toEqual([
    [
      'From the board:',
      '- Give the go for stage 3 → Go, with a comment: “After the copy pass”',
      '- Ship round 2, or redraw? → Redraw',
      `- ${LIST.title} → ${OUTPUT}:`,
      '  ```',
      '  Ran it:',
      '  Switchboard',
      '    sr-k3f9qa  Dashboard redesign (open, 1 waiting)',
      '  SitRep',
      '    sr-wdsqvn  sitrep',
      '  ```',
    ].join('\n'),
  ])
  expect(w.state.board?.asks.map(each => each.state)).toEqual(['closed', 'closed', 'closed'])
})

test(
  'the mode ends once its ask closes: the band shows the counts, and the next Enter goes to Claude',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { id } = await answering(w)

    await w.call('resolve', { item: id, reason: 'Ran it myself' })
    expect(w.state.answering).toBeNull()

    const { band } = await bandRow(w)

    expect(await band.find({ key: 'band:for-you' })).toBeDefined()
    expect((await entered(w, $, 'Carry on.')).drop).toBeUndefined()
    expect(w.prompts).toHaveLength(1)
  },
)

test(
  'the mode ends once its ask closes in another window, and does not come back when it reopens',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { id } = await answering(w)
    const paths = workPaths(ROOT, PROJECT.key, w.state.attachment?.work ?? '')
    const other = w.writer(paths)

    other({ type: 'resolve', item: id })
    await w.clock.advance(WATCH_MS)
    expect(w.state.answering).toBeNull()

    other({ type: 'reopen', item: id })
    await w.clock.advance(WATCH_MS)
    expect(w.state.answering).toBeNull()
  },
)

test('a send carrying the reply its comment would go with ends the mode: the band shows the counts, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: `rewrite:${id}` })

  const held = w.holdPrompts()

  await ui.press({ key: 'send' })
  await held.arrived

  const { band } = await bandRow(w)

  expect(await band.find({ key: 'band:for-you' })).toBeDefined()

  const typed = entered(w, $, 'Carry on.')

  held.end()
  expect((await typed).drop).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual([
    'From the board:\n- Give the go for stage 3 → Go',
    'Carry on.',
  ])
  expect(w.state.answering).toBeNull()
})

test('the mode ends when the window takes up another work, or the session ends', async ($, on) => {
  const w = world($, on)
  const { ui } = await answering(w)

  await w.call('start', { name: 'Another', summary: 'Another one', project: PROJECT.name })
  expect(w.state.answering).toBeNull()

  const id = await asked(w, LIST)

  await ui.press({ key: `answer:${id}` })
  expect(w.state.answering).toMatchObject({ item: id })
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
  expect(w.state.answering).toBeNull()
})

test('a reload keeps the mode: the band still shows it, and the next Enter is still the answer', async ($, on) => {
  const w = world($, on)
  const { id } = await answering(w)

  await $.session.start(SESSION)

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

  await ui.press({ key: `answer:${id}` })
  expect(await entered(w, $, 'v1.2.3', { origin: { kind: 'bridge' } })).toEqual({
    drop: TAKEN.answer,
  })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'v1.2.3' }])
  expect(await ui.find({ key: `rewrite:${id}` })).toBeUndefined()

  const go = await asked(w, GO)

  await ui.press({ key: `yes:${go}` })
  expect(await ui.find({ key: `rewrite:${go}`, text: '✎ comment' })).toBeDefined()
})

test('VS Code, whose prompts arrive some way unproven, offers nothing to write: words asks only ignore there', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const go = await asked(w, GO)
  const ui = await paneOn($, 'vscode')

  await ui.press({ key: `pick:${id}` })
  expect(await ui.find({ key: `answer:${id}` })).toBeUndefined()
  expect(await ui.find({ key: `ignore:${id}` })).toBeDefined()
  await ui.press({ key: `pick:${go}` })
  expect(await ui.find({ key: `comment:${go}` })).toBeUndefined()
  await ui.press({ key: `yes:${go}` })
  expect(await ui.find({ key: `rewrite:${go}` })).toBeUndefined()
})
