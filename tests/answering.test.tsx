import { expect, test, tier } from 'claude-code/testing'
import { workPaths, type WorkMeta } from '../core'
import { CLEAR_AFTER_DROP_MS, DRAFT, LEFT, NOT_TAKEN, TAKEN } from '../hooks/answering'
import { C } from '../hooks/look'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { kindAsk, MIN, SLOW, T0, W1, W2, wordsAsk, yesAsk } from './support'
import { BAND, DOCKED, postedId, PROJECT, ROOT, SESSION, toProject, world } from './world'

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

/** The board, opened by /sitrep, on the words ask, answering it. */
const answering = async (w: World) => {
  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.opened()

  await ui.press({ key: `answer:${w.item(id)}` })

  return { id, ui }
}

test('an ask wanting a yes offers its yes in its own words, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` }))[1]).toBe(
    '  [ ✓ Go ] [ ✎ comment ] [ ✕ ignore ]',
  )
})

test('an ask wanting a choice offers each option, a comment and an ignore', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` }))[1]).toBe(
    '  [ Ship it ] [ Redraw ] [ ✎ comment ] [ ✕ ignore ]',
  )
})

test('an ask wanting words offers an answer and an ignore, and hangs what its words are first, in amber', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `ask:${w.item(id)}` })).slice(0, 5)).toEqual([
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

  expect(await ui.find({ key: `answer:${w.item('o2')}`, text: '✎ Answer' })).toBeDefined()
  expect(await ui.find({ key: `yes:${w.item('o2')}` })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeDefined()
  await ui.press({ key: `pick:${w.item('o1')}` })
  expect(await ui.find({ key: `yes:${w.item('o1')}`, text: '✓ Approve' })).toBeDefined()
  expect(await ui.find({ key: `comment:${w.item('o1')}`, text: '✎ comment' })).toBeDefined()
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
  expect(await band.find({ key: 'band:for-you' })).toBeUndefined()
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

test('cancel on the band ends it in one press: the counts are back, and the next Enter goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await answering(w)
  const { band } = await bandRow(w)

  await band.press({ key: 'band:cancel-answer' })
  expect(w.state.answering).toBeNull()
  expect(await band.find({ key: 'band:for-you' })).toBeDefined()
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
    '└ “Switchboard” +3 lines · not sent yet ↺ undo ✎ edit',
  )
  expect(rowsOf(await ui.find({ key: `readyanswer:${w.item(id)}` }))).toEqual([
    '└ “Switchboard” +3 lines ✎ edit',
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

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: `rewrite:${w.item(id)}` })

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

  await ui.press({ key: `answer:${w.item(id)}` })
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

/** Another session of the project, open in another window. */
const LEDGER: WorkMeta = {
  id: 'sr-1edger',
  name: 'Request ledger',
  summary: 'Request ledger, area by area',
  project: PROJECT.key,
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W2,
}

/**
 * The board on the project's view, the ledger's asks drawn from its brief,
 * a minute on. Given `isUnread`, the board's reads of other works in full
 * never land, as before the look that reads one has: only the briefs have it.
 */
const onLedgersAsks = async (w: World, isUnread = false) => {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(wordsAsk('k3', 'Which fields does the ledger keep?', 'the fields'))
  ledger.write(yesAsk('k4', 'Approve the ledger schema'))

  if (isUnread) {
    w.leaveUnread()
  }

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)

  return ui
}

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

    await w.call('note', { text: 'The schema is drawn' })
    expect(w.state.answering, 'a redraw of the held board').toMatchObject({ work: LEDGER.id, item })

    expect((await entered(w, $, 'id, at, by')).drop).toBeDefined()
    expect(w.state.queue).toEqual([
      { project: PROJECT.key, work: LEDGER.id, item, verdict: press, note: 'id, at, by' },
    ])
    expect(w.prompts).toEqual([])
  })
}

test("answering another session's ask has the board read that work in full at once", async ($, on) => {
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

  expect(await app.find({ key: 'band:for-you' })).toBeDefined()
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
  expect(await (await w.band()).find({ key: 'band:for-you' })).toBeDefined()
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
