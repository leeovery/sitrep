import { expect, test, tier } from './kit'
import { parseEntries, sessionPaths } from '../core'
import { LINGER_MS } from '../hooks/scene'
import { WATCH_MS } from '../hooks/window'
import { CLOSES, LEAVES_OPEN, PROJECT, REVIEW, ROOT, W1 } from './data'
import { note } from './lines'
import { CONVERSATION, INLINE, postedId, PROMPT, startedId, world, type World } from './world'

tier('user')

const FROM_THE_BOARD = { kind: 'plugin', name: 'sitrep', asUser: true }

/** A session begun with one review asked: its folder's paths, the ask's id, and the board drawn. */
async function asking(w: World) {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))

  return { paths, id, ui: await w.pane() }
}

/** The kinds of line the window's own file holds, in order. */
const kindsIn = (w: World, path: string) => parseEntries(w.text(path)).map(line => line.type)

test("send delivers the replies as Lee's own message, and writes them only once it is taken", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${w.item(id)}` })

  const pressed = ui.press({ key: 'send' })

  await turn.arrived
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.inFlight).toMatchObject({
    source: 'send',
    project: w.state.attachment?.project,
    session: w.state.attachment?.session,
    replies: [{ type: 'reply', item: id, verdict: 'yes' }],
    isTaken: false,
  })

  turn.end()
  await pressed

  const lines = parseEntries(w.text(paths.log(W1)))
  const replied = lines.find(line => line.type === 'reply')

  expect(w.prompts).toEqual([
    {
      text: `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
      origin: FROM_THE_BOARD,
      context: undefined,
    },
  ])
  expect(lines.map(line => line.type)).toEqual(['ask', 'reply', 'delivered'])
  expect(replied).toMatchObject({ item: id, verdict: 'yes' })
  expect(lines.at(-1)).toMatchObject({ replies: [replied?.type === 'reply' && replied.id] })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.queue).toEqual([])
  expect(w.state.inFlight).toBeNull()
})

test('the board then shows the ask closed, and folds it into what was done once its moment passes', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeDefined()
  expect(await ui.find({ key: `pick:${w.item(id)}` })).toBeUndefined()

  await w.clock.advance(LINGER_MS)

  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeUndefined()
  expect(await ui.find({ key: `closed:${w.item(id)}` }), 'in RESOLVED').toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'nothing waiting' })).toBeDefined()
})

test("an ignore, once sent, drops its ask at once: no moment of 'sent, and Claude has it', and Resolved never lists it", async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `ignore:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(w.state.board?.asks[0]?.state).toBe('ignored')
  expect(await ui.find({ key: `ask:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeUndefined()

  await w.clock.advance(LINGER_MS)

  expect(await ui.find({ key: `closed:${w.item(id)}` })).toBeUndefined()
})

test('while a send submitted waits for Claude Code to take it, its replies are on their way and cannot be undone', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${w.item(id)}` })

  const pressed = ui.press({ key: 'send' })

  await turn.arrived

  expect(await ui.find({ type: 'Text', text: /⧗ Sending/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  expect(await ui.find({ key: `undo:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: `unready:${w.item(id)}` })).toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeUndefined()

  turn.end()
  await pressed
})

test('a send Claude Code refuses leaves every reply on the board, and a toast says why', async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)

  w.dropPrompts('the session is closing')
  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.toasts).toContain(
    'Not sent: the session is closing. Your replies are still on the board.',
  )
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'sent, and Claude has it' })).toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test('a comment on a review leaves the ask open, replied, for Claude to act on', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `comment:${w.item(id)}` })
  await $.prompt.submit({ text: 'thinner bars', wait: false, origin: { kind: 'composer' } })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    `From the board:\n- Review Tickets & Replies, round 1 → comment: “thinner bars”${LEAVES_OPEN}`,
  )
  expect(w.state.board?.asks[0]?.state).toBe('replied')
  expect(w.state.board?.waiting).toBe(0)
  expect(
    await ui.find({ type: 'Text', text: 'you commented: “thinner bars”. Claude has it.' }),
  ).toBeDefined()
  expect(await ui.find({ key: `pick:${w.item(id)}` })).toBeDefined()
})

test('a pick-up from parked is sent like any reply, and the log says what was picked up', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = postedId(await w.call('park', { title: 'A priority badge across all tabs' }))
  const ui = await w.pane()

  await ui.press({ key: `ppick:${w.item(id)}` })
  await ui.press({ key: `pickup:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.text).toBe(
    'From the board:\n- Pick up from parked: A priority badge across all tabs',
  )
  expect(kindsIn(w, paths.log(W1))).toEqual(['park', 'reply', 'delivered'])
  expect(await ui.find({ type: 'Text', text: 'PARKED' }), 'nothing is parked now').toBeUndefined()
  expect(w.state.board?.log[0]?.text).toBe(
    'Picked up from parked: A priority badge across all tabs',
  )
})

test("the board's own message carries no board context; a change it did not carry rides in with the next prompt", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const elsewhere = w.writer(paths)

  elsewhere(note('n9', 'Merged the band'))
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.at(-1)?.context).toBeUndefined()

  const next = await $.prompt.submit(PROMPT)

  expect(next.context?.[0]).toContain('- n9: Merged the band')
  expect(next.context?.[0]).not.toContain('Review Tickets & Replies')
})

test('with nothing else changed, what a send told Claude never rides in again', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect((await $.prompt.submit(PROMPT)).context).toBeUndefined()
})

test('a prompt from the board itself is left as it came, whatever changed', async ($, on) => {
  const w = world($, on)
  const { paths } = await asking(w)

  w.writer(paths)(note('n9', 'Merged the band'))
  await w.clock.advance(WATCH_MS)

  const entered = await $.prompt.submit({ ...PROMPT, origin: FROM_THE_BOARD } as never)

  expect(entered.context).toBeUndefined()
  expect((await $.prompt.submit(PROMPT)).context?.[0]).toContain('- n9: Merged the band')
})

test('a reload keeps Ready to send as Lee left it', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await $.session.start(CONVERSATION)

  expect(w.state.queue).toMatchObject([{ item: id, verdict: 'yes' }])
  expect(await ui.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await ui.find({ key: 'send' })).toBeDefined()
})

test('a send taken after Claude moved to another session mid-turn is written into the session it answered, and that ask closes', async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const answered = w.state.attachment?.session ?? ''

  await ui.press({ key: `yes:${w.item(id)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  const themes = startedId(
    await w.call('start', { name: 'Themes', summary: 'The dark palette', project: PROJECT.name }),
  )

  await w.turnEnds()
  await w.clock.settle()

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  expect(w.files.has(sessionPaths(ROOT, PROJECT.key, themes).log(W1))).toBe(false)
  expect(w.state.queue).toEqual([])

  await w.call('join', { session: answered })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
})

test('a yes Claude made a choice while its send waited reaches Claude all the same, settles nothing, and the ask waits on Lee in its new shape', async ($, on) => {
  const w = world($, on)
  const { id, ui } = await asking(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.call('edit', { item: id, wants: 'choice', options: ['Now', 'Later'] })
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted).toEqual([
    `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`,
  ])
  expect(w.state.board?.replies).toMatchObject([
    { item: id, verdict: 'yes', delivery: 'delivered', voided: 'changed' },
  ])
  expect(w.state.board?.asks[0]?.state).toBe('waiting')
  expect(w.state.board?.waiting).toBe(1)
  expect(await ui.find({ key: `choose:${w.item(id)}:0` })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeUndefined()
})

test('two quick presses of send submit the replies once', async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await asking(w)
  const turn = w.holdPrompts()

  await ui.press({ key: `yes:${w.item(id)}` })

  const presses = [ui.press({ key: 'send' }), ui.press({ key: 'send' })]

  await turn.arrived
  turn.end()
  await Promise.all(presses)

  expect(w.submitted).toHaveLength(1)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
})

/** A session begun with one review asked, the board opened by /sitrep and drawn inline, as on a phone. */
async function askingInline(w: World) {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))

  return { paths, id, ui: await w.opened(INLINE) }
}

test("send closes an inline board once the send is claimed, not waiting for Claude's turn to end", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await askingInline(w)

  await ui.press({ key: `yes:${w.item(id)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })

  expect(w.state.inFlight).toMatchObject({ source: 'send', isHeld: true })
  expect(w.panes.has('sitrep')).toBe(false)
  expect(w.state.pane).toMatchObject({ isOpen: false, selected: null })

  await w.turnEnds()
  await w.clock.settle()

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  expect(w.state.queue).toEqual([])
})

test('send leaves a docked board open', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.opened()

  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'reply', 'delivered'])
  expect(w.panes.get('sitrep')).toBe(true)
  expect(w.state.pane?.isOpen).toBe(true)
})

test('a send refused from an inline board still closes it; the toast says why, and opened again it shows the replies queued', async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await askingInline(w)

  w.dropPrompts('the session is closing')
  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(w.panes.has('sitrep')).toBe(false)
  expect(w.toasts).toContain(
    'Not sent: the session is closing. Your replies are still on the board.',
  )
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.queue).toMatchObject([{ item: id, verdict: 'yes' }])

  await ui.unmount()

  const again = await w.opened()

  expect(await again.find({ type: 'Text', text: /READY TO SEND/ })).toBeDefined()
  expect(await again.find({ type: 'Text', text: '· not sent yet' })).toBeDefined()
  expect(await again.find({ key: 'send' })).toBeDefined()
})
