import { expect, test, tier } from 'claude-code/testing'
import { CLEAR_AFTER_DROP_MS, PASTED_HERE } from '../hooks/actions'
import { C } from '../hooks/look'
import { rowsOf } from './drawn'
import { DOCKED, INLINE, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Ui = Awaited<ReturnType<World['pane']>>

const OUTPUT = "the command's output"

/** What an empty save toasts. */
const EMPTY = 'Type something first, or cancel.'

const EXPORT = {
  kind: 'do',
  title: 'Run the export',
  where: 'In the terminal: bun run export',
  needs: OUTPUT,
}

const FRAMES = {
  kind: 'decide',
  title: 'Ship round 2, or redraw?',
  options: ['Ship it', 'Redraw'],
  needs: 'which frames you would change',
}

/** Claude posts an ask, and the board opens it, as it does a new one: its id. */
const asked = async (w: World, ask: { [key: string]: unknown } = EXPORT) =>
  postedId(await w.call('ask', ask))

/** Types into the open field's text area, a line break between each line given. */
const typeLines = async (ui: Ui, id: string, ...lines: string[]) => {
  for (const [i, line] of lines.entries()) {
    if (i > 0) {
      await ui.key({ key: 'return', shift: true, in: `area:${id}` })
    }

    await ui.key({ key: line, in: `area:${id}` })
  }
}

/** The board docked on a surface the world's own panes leave out. */
const paneOn = <S extends 'vscode' | 'mobile'>(engine: Parameters<typeof world>[0], surface: S) =>
  engine.ui.mount({
    plugin: 'sitrep',
    surface,
    component: 'Pane',
    requestId: 'sitrep',
    props: DOCKED,
  })

/** Where a reply to the ask goes: the held work. */
const at = (w: World, item: string) => ({
  project: w.state.attachment?.project,
  work: w.state.attachment?.work,
  item,
})

test('an ask that needs something back hangs it first from its mark, in the colour of an ask', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  expect(rowsOf(await ui.find({ key: `under:${id}:0:0` }))).toEqual([`├ needs: ${OUTPUT}`])
  expect(rowsOf(await ui.find({ key: `under:${id}:1:0` }))).toEqual([
    '└ In the terminal: bun run export',
  ])
  expect((await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` }))?.props.color).toBe(C.ask)
})

test('inline, what an ask needs shows as its where does: only while the ask is opened', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane('terminal', INLINE)

  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeDefined()

  await ui.press({ key: `pick:${id}` })
  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: EXPORT.where })).toBeUndefined()
})

test('the yes of a review, a try or a do that needs something back keeps its words and opens the field for it', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const ui = await w.pane()

  for (const [kind, label] of [
    ['review', '✓ approve'],
    ['try', '✓ it works'],
    ['do', '✓ done'],
  ]) {
    const id = await asked(w, { kind, title: `A ${kind}`, needs: OUTPUT })

    expect(await ui.find({ key: `yes:${id}`, text: label }), kind).toBeDefined()
    await ui.press({ key: `yes:${id}` })
    expect(await ui.find({ type: 'Text', text: `${OUTPUT}:` }), kind).toBeDefined()
    expect(await ui.find({ key: `save:${id}`, text: label }), kind).toBeDefined()
    expect(await ui.find({ key: `savewith:${id}` }), kind).toBeUndefined()
    expect(await ui.find({ key: `area:${id}` }), kind).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /READY TO SEND/ }), kind).toBeUndefined()

    await ui.press({ key: `cancel:${id}` })
  }
})

test('saving the field queues the yes with what was typed as its note, shown under the ask', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  await typeLines(ui, id, 'v1.2.3', 'exported 42 rows', 'done in 3s')
  await ui.press({ key: `save:${id}` })

  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'yes', note: 'v1.2.3\nexported 42 rows\ndone in 3s' },
  ])
  expect(
    await ui.find({
      type: 'Text',
      text: `done, with ${OUTPUT}: “v1.2.3\nexported 42 rows\ndone in 3s”`,
    }),
  ).toBeDefined()
  expect(await ui.find({ key: `area:${id}` })).toBeUndefined()
})

test('Enter in the field saves the yes too; an empty save is refused, by the button or by Enter', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  await ui.press({ key: `save:${id}` })
  await ui.key({ key: 'return', in: `area:${id}` })
  expect(w.toasts.filter(toast => toast === EMPTY)).toHaveLength(2)
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: `${OUTPUT}:` })).toBeDefined()

  await ui.key({ key: 'v1.2.3', in: `area:${id}` })
  await ui.key({ key: 'return', in: `area:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'v1.2.3' }])
})

test('each option of a decide that needs something back opens the field, and saving queues that choice with the note', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, FRAMES)
  const ui = await w.pane()

  await ui.press({ key: `choose:${id}:1` })
  expect(await ui.find({ type: 'Text', text: 'which frames you would change:' })).toBeDefined()
  expect(await ui.find({ key: `save:${id}`, text: 'Redraw' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()

  await typeLines(ui, id, 'Frames 2 and 5')
  await ui.press({ key: `save:${id}` })
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'choose', option: 'Redraw', note: 'Frames 2 and 5' },
  ])
  expect(
    await ui.find({
      type: 'Text',
      text: '→ Redraw, with which frames you would change: “Frames 2 and 5”',
    }),
  ).toBeDefined()
})

test('comment and ignore on an ask that needs something back work as on any other', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  expect(await ui.find({ key: `comment:${id}`, text: '✎ comment' })).toBeDefined()
  await ui.press({ key: `comment:${id}` })
  expect(await ui.find({ type: 'Text', text: /^Comment$/ })).toBeDefined()
  expect(await ui.find({ key: `save:${id}`, text: 'save comment' })).toBeDefined()

  await ui.key({ key: 'Not until Monday', in: `area:${id}` })
  await ui.press({ key: `save:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'comment', note: 'Not until Monday' }])

  await ui.press({ key: `undo:${id}` })
  await ui.press({ key: `ignore:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'ignore' }])
})

test("a review's approve with its comment needs words when the review needs something back", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, { kind: 'review', title: 'Review round 2', needs: 'which frames' })
  const ui = await w.pane()

  await ui.press({ key: `comment:${id}` })
  await ui.press({ key: `savewith:${id}` })
  expect(w.toasts).toContain(EMPTY)
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()

  await ui.key({ key: 'Frame 3', in: `area:${id}` })
  await ui.press({ key: `savewith:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'Frame 3' }])
})

test("a surface with no text area of the mod's takes what is needed in its own field", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await paneOn($, 'vscode')

  await ui.press({ key: `yes:${id}` })
  expect(await ui.find({ type: 'Text', text: `${OUTPUT}:` })).toBeDefined()

  await ui.input({ key: `field:${id}`, text: 'v1.2.3' })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'v1.2.3' }])
})

test('a surface with no field to type in shows what is needed, and its answers queue as they would without', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await paneOn($, 'mobile')

  expect(await ui.find({ type: 'Text', text: `needs: ${OUTPUT}` })).toBeDefined()
  await ui.press({ key: `yes:${id}` })

  const decide = await asked(w, FRAMES)

  await ui.press({ key: `choose:${decide}:0` })
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'yes' },
    { ...at(w, decide), verdict: 'choose', option: 'Ship it' },
  ])
  expect(await ui.find({ type: 'Text', text: `${OUTPUT}:` })).toBeUndefined()
})

test('the send gives Claude what was needed under its answer, pasted lines fenced and kept', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w)
  const ui = await w.pane()

  await ui.press({ key: `yes:${id}` })
  await ui.key({ key: 'v1.2.3\n\n  exported 42 rows', in: `area:${id}` })
  await ui.press({ key: `save:${id}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    [
      'From the board:',
      `- Run the export → done, with ${OUTPUT}:`,
      '  ```',
      '  v1.2.3',
      '  ',
      '    exported 42 rows',
      '  ```',
    ].join('\n'),
  )
  expect(w.state.board?.asks[0]?.state).toBe('closed')
})

const FOUR_LINES = 'exported 42 rows to out.csv\n  skipped 3 duplicates\ndone in 1.8s\nexit 0'

/** A paste as the engine wraps it in the prompt Lee submits (live, 2.1.295). */
const pasted = (text: string, id = '08fd') =>
  `\n\n<pasted_content id="${id}">\n${text}\n</pasted_content id="${id}">\n`

/** Lee pressing Enter at the prompt, with the box holding `text`. */
const entered = (
  w: World,
  engine: Parameters<typeof world>[0],
  text: string,
  extra: {
    attachments?: readonly { type: 'image' }[]
    origin?: { kind: 'composer' | 'bridge' }
  } = {},
) => {
  w.box.text = '[Pasted text #1 +3 lines]'

  return engine.prompt.submit({ text, wait: false, origin: { kind: 'composer' }, ...extra })
}

/** The board opened by /sitrep on an ask that needs something back, its field open for the yes. */
const fieldOpen = async (w: World) => {
  await w.begin()

  const id = await asked(w)
  const ui = await w.opened()

  await ui.press({ key: `yes:${id}` })

  return { id, ui }
}

test('a paste alone, entered at the prompt while a field is open, goes into the field under what it holds, not to Claude', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await fieldOpen(w)

  await ui.key({ key: 'Ran it:', in: `area:${id}` })

  expect(await entered(w, $, pasted(FOUR_LINES))).toEqual({ drop: PASTED_HERE })
  expect(w.prompts).toEqual([])
  expect(w.toasts, 'the drop says it once, in the transcript').not.toContain(PASTED_HERE)
  expect(w.box.text).toBe('[Pasted text #1 +3 lines]')
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('')
  expect((await ui.find({ key: `area:${id}` }))?.props.props).toMatchObject({
    filled: { text: `Ran it:\n${FOUR_LINES}`, times: 1 },
  })

  await ui.press({ key: `save:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: `Ran it:\n${FOUR_LINES}` }])
})

test('two pastes and nothing else go into the field together, a line apart', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await fieldOpen(w)

  await entered(w, $, `${pasted('first', 'a1')}\n${pasted('second', 'b2')}`)
  await ui.press({ key: `save:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'first\nsecond' }])
})

test('while a field is open, a typed message, words around a paste, an attachment or a prompt from elsewhere go to Claude', async ($, on) => {
  const w = world($, on)
  const { ui } = await fieldOpen(w)

  for (const [text, extra] of [
    ['Carry on.', {}],
    [`Look at this:${pasted(FOUR_LINES)}`, {}],
    [`${pasted(FOUR_LINES)}what now?`, {}],
    [pasted(FOUR_LINES), { attachments: [{ type: 'image' as const }] }],
    [pasted(FOUR_LINES), { origin: { kind: 'bridge' as const } }],
    ['<pasted_content id="a1">\nhalf a tag\n</pasted_content id="b2">', {}],
  ] as const) {
    expect((await entered(w, $, text, extra)).drop, text).toBeUndefined()
  }

  expect(w.prompts).toHaveLength(6)
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  expect(w.box.text).toBe('[Pasted text #1 +3 lines]')
  expect(w.toasts).not.toContain(PASTED_HERE)
  expect(await ui.find({ type: 'Text', text: `${OUTPUT}:` })).toBeDefined()
})

test('with no field open, a paste goes to Claude', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await asked(w)
  await w.opened()
  expect((await entered(w, $, pasted(FOUR_LINES))).drop).toBeUndefined()
  expect(w.prompts).toHaveLength(1)
})

test('with the board closed on an open field, a paste goes to Claude', async ($, on) => {
  const w = world($, on)
  const { id } = await fieldOpen(w)

  await (await w.band()).press({ key: 'band:board' })
  expect(w.state.pane?.commenting?.item).toBe(id)
  expect(w.state.pane?.isOpen).toBe(false)
  expect((await entered(w, $, pasted(FOUR_LINES))).drop).toBeUndefined()
  expect(w.prompts).toHaveLength(1)
})

test('the take button takes a paste the prompt box holds as text, under what the field holds, and empties the box', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await fieldOpen(w)

  await ui.key({ key: 'Ran it:', in: `area:${id}` })
  w.box.text = 'v1.2.3\nexit 0'
  await ui.press({ key: `take:${id}` })
  expect(w.box.text).toBe('')
  expect((await ui.find({ key: `area:${id}` }))?.props.props).toMatchObject({
    filled: { text: 'Ran it:\nv1.2.3\nexit 0', times: 1 },
  })

  await ui.press({ key: `save:${id}` })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'yes', note: 'Ran it:\nv1.2.3\nexit 0' }])
})

test('the take button refuses an empty box, and a paste the box folded away, which Enter sends instead', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await fieldOpen(w)

  await ui.press({ key: `take:${id}` })
  expect(w.toasts).toContain('Paste into the prompt first.')

  w.box.text = 'see [Pasted text #2 +7 lines]'
  await ui.press({ key: `take:${id}` })
  expect(w.toasts).toContain('Press Enter in the prompt to send the paste here.')
  expect(w.box.text).toBe('see [Pasted text #2 +7 lines]')

  await ui.press({ key: `save:${id}` })
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
})

test('the field says how a paste gets in', async ($, on) => {
  const w = world($, on)
  const { ui } = await fieldOpen(w)

  expect(
    await ui.find({
      type: 'Text',
      text: 'Paste into the prompt and press Enter there: it comes here, not to Claude.',
    }),
  ).toBeDefined()
  expect(await ui.find({ type: 'Button', text: "⤓ take what's in the prompt" })).toBeDefined()
})
