import { expect, test, tier } from './kit'
import { parseEntries } from '../core'
import { FLASH_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import { CLOSES, MIN, PROJECT, REVIEW, SENDER, W1, W2 } from './data'
import { file, reply } from './lines'
import { asked, CONVERSATION, INLINE, kindsIn, world, type World } from './world'

tier('user')

const FROM_THE_BOARD = { kind: 'plugin', name: 'sitrep', asUser: true }

const MESSAGE = `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`

/** As long as the watch takes to fold a letter, and the next look to take it in. */
const TAKE_IN = 2 * WATCH_MS

/** This session with an ask, a minute on; and another session's window, sending replies into its inbox. */
async function fromSender(w: World) {
  const { paths } = await w.begin()
  const posted = await asked(w, REVIEW)

  await w.clock.advance(MIN)

  /** Another session's window writes its letters, as it does: the whole file, each line at the time. */
  const lines: Parameters<typeof file> = []
  const send = (...replies: Parameters<typeof reply>[]) => {
    lines.push(...replies.map((each): (typeof lines)[number] => [w.clock.now(), reply(...each)]))
    w.put(paths.letters(SENDER), file(...lines))
  }

  return { paths, posted, send }
}

test("the window delivering for its session submits inbox replies as Lee's own message, once, and marks them once taken", async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const turn = w.holdPrompts()

  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  expect(w.state.inFlight).toMatchObject({
    source: 'inbox',
    replies: [{ id: 'r1' }],
    text: MESSAGE,
    isTaken: false,
  })

  await w.clock.advance(4 * WATCH_MS)
  expect(kindsIn(w, paths.log(W1)), 'no mark while Claude Code has not taken it').toEqual(['ask'])

  turn.end()
  await w.clock.advance(WATCH_MS)

  const lines = parseEntries(w.text(paths.log(W1)))

  expect(w.prompts).toEqual([{ text: MESSAGE, origin: FROM_THE_BOARD, context: undefined }])
  expect(lines.map(line => line.type)).toEqual(['ask', 'delivered'])
  expect(lines.at(-1)).toMatchObject({ replies: ['r1'] })
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.inFlight).toBeNull()

  await w.clock.advance(4 * WATCH_MS)
  expect(w.prompts, 'nothing goes in twice').toHaveLength(1)
})

test("a window that is not its session's deliverer submits nothing", async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const longer = () =>
    w.beat(w.state.attachment?.session ?? '', { writer: W2, attachedAt: 0, seenAt: w.clock.now() })

  longer()
  send(['r1', posted, 'yes'])

  for (let look = 0; look < 4; look++) {
    await w.clock.advance(WATCH_MS)
    longer()
  }

  expect(w.state.board?.deliverer).toBe(W2)
  expect(w.prompts).toEqual([])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
})

test("Lee's comment queued, then sent once an answer to the same ask waits in the inbox for another window, tells Claude that answer, sent apart, closes the ask", async ($, on) => {
  const w = world($, on)
  const { posted, send } = await fromSender(w)
  const longer = () =>
    w.beat(w.state.attachment?.session ?? '', { writer: W2, attachedAt: 0, seenAt: w.clock.now() })
  const ui = await w.opened()

  await ui.press({ key: `comment:${w.item(posted)}` })
  await $.prompt.submit({ text: 'thinner bars', wait: false, origin: { kind: 'composer' } })
  longer()
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  longer()
  expect(w.state.board?.deliverer).toBe(W2)
  expect(w.state.board?.asks[0]).toMatchObject({ answerOnItsWay: { id: 'r1' } })

  await ui.press({ key: 'send' })

  expect(w.prompts.map(prompt => prompt.text)).toEqual([
    [
      'From the board:',
      '- Review Tickets & Replies, round 1 → comment: “thinner bars”',
      "  An answer of Lee's to this ask, sent apart from this message, closes it.",
    ].join('\n'),
  ])
})

test('a refused submission leaves the replies undelivered, for the next look to try again', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)

  w.dropPrompts('the session is closing')
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.inFlight).toBeNull()
  expect(w.state.board?.replies).toMatchObject([{ id: 'r1', delivery: 'waiting' }])
  expect(w.logs.some(line => line.includes('not taken (the session is closing)'))).toBe(true)

  w.dropPrompts()
  await w.clock.advance(WATCH_MS)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([MESSAGE])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'delivered'])
})

test('the receiving band flashes how many replies came in from the board, for a few seconds', async ($, on) => {
  const w = world($, on)
  const { posted, send } = await fromSender(w)
  const other = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const band = await w.band()

  await w.clock.advance(MIN)
  send(['r1', posted, 'yes'], ['r2', other, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(await band.find({ type: 'Text', text: '✦' })).toBeDefined()
  expect(await band.find({ type: 'Text', text: /from the board/ })).toMatchObject({
    text: '2 replies from the board',
  })

  // The flash began somewhere within the take-in: here it is still short of FLASH_MS
  // after it, and one take-in later past it.
  await w.clock.advance(FLASH_MS - TAKE_IN)
  expect(await band.find({ type: 'Text', text: /from the board/ }), 'still flashing').toBeDefined()

  await w.clock.advance(TAKE_IN)
  expect(await band.find({ type: 'Text', text: /from the board/ })).toBeUndefined()
})

test('a delivery a reload left on its way is never submitted again, and is marked when its message starts its turn', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const turn = w.holdPrompts()

  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  // The reload: the load that submitted is gone, and with it any word of its submit.
  await $.session.start(CONVERSATION)
  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])

  await $.turn.start({ text: MESSAGE, turnId: 'turn-1' })
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'delivered'])
  expect(w.state.inFlight).toBeNull()

  turn.end()
  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths.log(W1)), 'one mark, however it was heard').toEqual(['ask', 'delivered'])
})

test('a turn that starts with some other message marks nothing', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const turn = w.holdPrompts()

  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived
  await $.turn.start({ text: 'Carry on.', turnId: 'turn-1' })

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.inFlight).toMatchObject({ isTaken: false })

  turn.end()
})

test('replies Claude Code took but whose mark could not be written are never sent again, and are marked at the next look', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)

  w.refuseWrites(path => path === paths.log(W1))
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([MESSAGE])
  expect(w.state.inFlight).toMatchObject({ isTaken: true })

  w.refuseWrites()
  await w.clock.advance(4 * WATCH_MS)

  expect(w.prompts, 'nothing goes in twice').toHaveLength(1)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'delivered'])
  expect(w.state.inFlight).toBeNull()
})

test('inbox replies taken after Claude moved to another session mid-turn are marked in their own session, and never go in again', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const answered = w.state.attachment?.session ?? ''

  await w.turnStarts('Carry on.')
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isHeld: true })

  await w.call('start', { name: 'Themes', summary: 'The dark palette', project: PROJECT.name })
  await w.turnEnds()
  await w.clock.advance(WATCH_MS)

  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'delivered'])

  await w.call('join', { session: answered })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([MESSAGE])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
})

test('the mark names only the replies the message carries: one whose item changed since goes in nowhere, and its item can be answered again', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const other = await asked(w, { wants: 'yes', yes: 'Approve', title: 'Review the band' })

  await w.clock.advance(MIN)
  send(['r1', posted, 'yes'], ['r2', other, 'yes'])
  await w.clock.advance(1)
  await w.call('edit', { item: other, wants: 'choice', options: ['Now', 'Later'] })
  await w.clock.advance(TAKE_IN)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([MESSAGE])
  expect(parseEntries(w.text(paths.log(W1))).at(-1)).toMatchObject({
    type: 'delivered',
    replies: ['r1'],
  })
  expect(w.state.board?.asks.map(each => each.state)).toEqual(['closed', 'waiting'])

  const ui = await w.opened()

  expect(w.state.pane?.selected, 'the ask that landed last is open').toBe(w.item(other))
  expect(await ui.find({ key: `choose:${w.item(other)}:0` })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeUndefined()

  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted, 'nothing is left to go in').toEqual([MESSAGE])
})

test('a send Lee presses while inbox replies are in flight waits for them: a toast says so, and the replies stay queued', async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const own = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const ui = await w.opened()
  const turn = w.holdPrompts()

  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived
  await ui.press({ key: `yes:${w.item(own)}` })
  await ui.press({ key: 'send' })

  expect(w.toasts).toContain(
    'Not sent yet: replies from another session are going in first. Your replies are still on the board.',
  )
  expect(w.state.queue).toMatchObject([{ item: own, verdict: 'yes' }])
  expect(await ui.find({ key: `undo:${w.item(own)}` })).toBeDefined()

  turn.end()
  await w.turnStarts(MESSAGE)
  await w.turnEnds()
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: 'send' })

  expect(w.submitted).toEqual([
    MESSAGE,
    `From the board:\n- Run the production apply → Done${CLOSES}`,
  ])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'ask', 'delivered', 'reply', 'delivered'])
})

/** Claude Code's refusal of every plugin's prompt once Lee has stopped Claude's turn, until he next types in the window (live, 2.1.318). */
const STOPPED = 'the session was stopped and nobody has sent input since'

test("a send Lee presses while the window is stopped behind the inbox's message carries that message on from his press, his own replies waiting for it, a toast saying so", async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const own = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const ui = await w.opened()

  w.dropPrompts(STOPPED)
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isHeld: true })
  expect(w.state.stopped).toBe(true)

  w.dropPrompts()
  await ui.press({ key: `yes:${w.item(own)}` })
  await ui.press({ key: 'send' })
  await w.clock.settle()

  expect(w.submitted).toEqual([MESSAGE, MESSAGE])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'ask', 'delivered'])
  expect(w.toasts.filter(toast => toast.startsWith('Not sent'))).toEqual([
    'Not sent yet: replies from another session are going in first. Your replies are still on the board.',
  ])
  expect(w.state.queue).toMatchObject([{ item: own, verdict: 'yes' }])
})

test("inbox replies arriving while the window is stopped are claimed but not submitted, no refusal spent on them; they go once Lee's turn ends", async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const own = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })
  const ui = await w.opened()

  await ui.press({ key: `yes:${w.item(own)}` })
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  w.dropPrompts(STOPPED)
  await w.turnEnds({ isAborted: true })
  await w.clock.settle()
  await ui.press({ key: w.takeBack() })
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN + 4 * WATCH_MS)

  expect(w.state.stopped).toBe(true)
  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isHeld: true })
  expect(w.submitted, 'only the send refused as Claude was stopped').toHaveLength(1)

  w.dropPrompts()
  await w.turnStarts('Look at the failing test instead.')
  await w.turnEnds()
  await w.clock.settle()

  expect(w.submitted.at(-1)).toBe(MESSAGE)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask', 'ask', 'delivered'])
})

test("inbox replies held while the window is stopped are let go once another window delivers for the session, left in the inbox for it", async ($, on) => {
  const w = world($, on)
  const { paths, posted, send } = await fromSender(w)
  const longer = () =>
    w.beat(w.state.attachment?.session ?? '', { writer: W2, attachedAt: 0, seenAt: w.clock.now() })

  w.dropPrompts(STOPPED)
  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isHeld: true })
  expect(w.state.stopped).toBe(true)

  for (let look = 0; look < 4; look++) {
    longer()
    await w.clock.advance(WATCH_MS)
  }

  expect(w.state.board?.deliverer).toBe(W2)
  expect(w.state.inFlight).toBeNull()
  expect(w.submitted).toEqual([MESSAGE])
  expect(w.state.board?.replies).toMatchObject([{ id: 'r1', delivery: 'waiting' }])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.logs.some(line => line.includes('not taken'))).toBe(false)
})

test('an inline board whose send waits behind inbox replies stays open: nothing of it went', async ($, on) => {
  const w = world($, on)
  const { posted, send } = await fromSender(w)
  const own = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })

  const ui = await w.opened(INLINE)
  const turn = w.holdPrompts()

  send(['r1', posted, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived
  await ui.press({ key: `yes:${w.item(own)}` })
  await ui.press({ key: 'send' })

  expect(w.toasts).toContain(
    'Not sent yet: replies from another session are going in first. Your replies are still on the board.',
  )
  expect(w.panes.get('sitrep')).toBe(true)
  expect(w.state.pane?.isOpen).toBe(true)

  turn.end()
})
