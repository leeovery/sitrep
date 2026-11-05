import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, type SessionPaths } from '../core'
import { FLASH_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import { file, MIN, reply, SENDER, W1, W2 } from './support'
import { INLINE, postedId, PROJECT, CONVERSATION, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const FROM_THE_BOARD = { kind: 'plugin', name: 'sitrep', asUser: true }

const MESSAGE = 'From the board:\n- Review Sessions & Runway, round 1 → Approve'

/** As long as the watch takes to fold a letter, and the next look to take it in. */
const TAKE_IN = 2 * WATCH_MS

/** This session with an ask, a minute on; and another session's window, sending replies into its inbox. */
async function asking(w: World) {
  const { paths } = await w.begin()
  const asked = postedId(
    await w.call('ask', {
      wants: 'yes',
      yes: 'Approve',
      title: 'Review Sessions & Runway, round 1',
    }),
  )

  await w.clock.advance(MIN)

  /** Another session's window writes its letters, as it does: the whole file, each line at the time. */
  const lines: Parameters<typeof file> = []
  const send = (...replies: Parameters<typeof reply>[]) => {
    lines.push(...replies.map((each): (typeof lines)[number] => [w.clock.now(), reply(...each)]))
    w.put(paths.letters(SENDER), file(...lines))
  }

  return { paths, asked, send }
}

/** The kinds of line the window's own file holds, in order. */
const kindsIn = (w: World, paths: SessionPaths) =>
  parseEntries(w.text(paths.log(W1))).map(line => line.type)

test("the window delivering for its session submits inbox replies as Lee's own message, once, and marks them once taken", async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)
  const turn = w.holdPrompts()

  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  expect(w.state.inFlight).toMatchObject({
    source: 'inbox',
    replies: [{ id: 'r1' }],
    text: MESSAGE,
    isTaken: false,
  })

  await w.clock.advance(4 * WATCH_MS)
  expect(kindsIn(w, paths), 'no mark while Claude Code has not taken it').toEqual(['ask'])

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
  const { paths, asked, send } = await asking(w)
  const longer = () =>
    w.beat(w.state.attachment?.session ?? '', { writer: W2, attachedAt: 0, seenAt: w.clock.now() })

  longer()
  send(['r1', asked, 'yes'])

  for (let look = 0; look < 4; look++) {
    await w.clock.advance(WATCH_MS)
    longer()
  }

  expect(w.state.board?.deliverer).toBe(W2)
  expect(w.prompts).toEqual([])
  expect(kindsIn(w, paths)).toEqual(['ask'])
})

test('a refused submission leaves the replies undelivered, for the next look to try again', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)

  w.dropPrompts('the session is closing')
  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(kindsIn(w, paths)).toEqual(['ask'])
  expect(w.state.inFlight).toBeNull()
  expect(w.state.board?.replies).toMatchObject([{ id: 'r1', delivery: 'waiting' }])
  expect(w.logs.some(line => line.includes('not taken (the session is closing)'))).toBe(true)

  w.dropPrompts()
  await w.clock.advance(WATCH_MS)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([MESSAGE])
  expect(kindsIn(w, paths)).toEqual(['ask', 'delivered'])
})

test('the receiving band flashes how many replies came in from the board, for a few seconds', async ($, on) => {
  const w = world($, on)
  const { asked, send } = await asking(w)
  const other = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run the production apply' }),
  )
  const band = await w.band()

  await w.clock.advance(MIN)
  send(['r1', asked, 'yes'], ['r2', other, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(await band.find({ type: 'Text', text: '✦' })).toBeDefined()
  expect(await band.find({ type: 'Text', text: '2 replies from the board' })).toBeDefined()

  await w.clock.advance(FLASH_MS)
  expect(await band.find({ type: 'Text', text: /from the board/ })).toBeUndefined()
})

test('a delivery a reload left on its way is never submitted again, and is marked when its message starts its turn', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)
  const turn = w.holdPrompts()

  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived

  // The reload: the load that submitted is gone, and with it any word of its submit.
  await $.session.start(CONVERSATION)
  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths)).toEqual(['ask'])

  await $.turn.start({ text: MESSAGE, turnId: 'turn-1' })
  expect(kindsIn(w, paths)).toEqual(['ask', 'delivered'])
  expect(w.state.inFlight).toBeNull()

  turn.end()
  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths), 'one mark, however it was heard').toEqual(['ask', 'delivered'])
})

test('a turn that starts with some other message marks nothing', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)
  const turn = w.holdPrompts()

  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)
  await turn.arrived
  await $.turn.start({ text: 'Carry on.', turnId: 'turn-1' })

  expect(kindsIn(w, paths)).toEqual(['ask'])
  expect(w.state.inFlight).toMatchObject({ isTaken: false })

  turn.end()
})

test('replies Claude Code took but whose mark could not be written are never sent again, and are marked at the next look', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)

  w.refuseWrites(path => path === paths.log(W1))
  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)

  expect(w.prompts.map(prompt => prompt.text)).toEqual([MESSAGE])
  expect(w.state.inFlight).toMatchObject({ isTaken: true })

  w.refuseWrites()
  await w.clock.advance(4 * WATCH_MS)

  expect(w.prompts, 'nothing goes in twice').toHaveLength(1)
  expect(kindsIn(w, paths)).toEqual(['ask', 'delivered'])
  expect(w.state.inFlight).toBeNull()
})

test('inbox replies taken after Claude moved to another session mid-turn are marked in their own session, and never go in again', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)
  const answered = w.state.attachment?.session ?? ''

  await w.turnStarts('Carry on.')
  send(['r1', asked, 'yes'])
  await w.clock.advance(TAKE_IN)
  expect(w.state.inFlight).toMatchObject({ source: 'inbox', isHeld: true })

  await w.call('start', { name: 'Themes', summary: 'The dark palette', project: PROJECT.name })
  await w.turnEnds()
  await w.clock.advance(WATCH_MS)

  expect(kindsIn(w, paths)).toEqual(['ask', 'delivered'])

  await w.call('join', { session: answered })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([MESSAGE])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
})

test('the mark names only the replies the message carries: one whose item changed since goes in nowhere, and its item can be answered again', async ($, on) => {
  const w = world($, on)
  const { paths, asked, send } = await asking(w)
  const other = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review the band' }),
  )

  await w.clock.advance(MIN)
  send(['r1', asked, 'yes'], ['r2', other, 'yes'])
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
  const { paths, asked, send } = await asking(w)
  const own = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run the production apply' }),
  )
  const ui = await w.opened()
  const turn = w.holdPrompts()

  send(['r1', asked, 'yes'])
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

  expect(w.submitted).toEqual([MESSAGE, 'From the board:\n- Run the production apply → Done'])
  expect(kindsIn(w, paths)).toEqual(['ask', 'ask', 'delivered', 'reply', 'delivered'])
})

test('an inline board whose send waits behind inbox replies stays open: nothing of it went', async ($, on) => {
  const w = world($, on)
  const { asked, send } = await asking(w)
  const own = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run the production apply' }),
  )

  const ui = await w.opened(INLINE)
  const turn = w.holdPrompts()

  send(['r1', asked, 'yes'])
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
