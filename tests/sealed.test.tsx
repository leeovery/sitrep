/**
 * Ready to send while a send of Lee's waits for Claude's turn to end: that
 * send sealed, its replies frozen, and whatever Lee queues after it a queue
 * of its own under it, which a press of send makes a second send. Each send
 * goes in as its own prompt, in the order sent, the next once Claude's turn
 * on the one before has ended.
 */
import type { RenderPropsOf } from 'claude-code'
import { expect, test, tier } from './kit'
import { parseEntries, parsePresence, type SessionPaths } from '../core'
import { QUIET_MS } from '../hooks/deliver'
import { SEND_NOW } from '../hooks/draw/ready'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { CLOSES, MIN, SLOW, W1 } from './support'
import {
  CONVERSATION,
  HELP_DESK,
  DOCKED,
  INLINE,
  postedId,
  PROJECT,
  world,
  writeDoor,
} from './world'

tier('user')

type World = ReturnType<typeof world>

type Pane = Awaited<ReturnType<World['pane']>>

type Engine = Parameters<typeof world>[0]

/** Lee's message carrying his yes to each of these rounds of review. */
const message = (...rounds: number[]) =>
  ['From the board:', ...rounds.map(round => `- Review round ${round} → Approve${CLOSES}`)].join(
    '\n',
  )

/** The line under a send waiting for Claude's turn, its take-back beside it. */
const HELD = "⧗ Waiting for Claude's turn to end. ↺ take back"

/** The rows a send waiting for Claude's turn draws in Ready to send: its heading, each round's reply frozen, and its line. */
const held = (...rounds: number[]) => [
  '',
  'on its way to this session',
  ...rounds.flatMap(round => [`Review round ${round}`, '└ → Approve']),
  HELD,
]

/** The rows the replies still to send draw in Ready to send: their heading, and each round's reply, removable and open to a comment. */
const toSend = (...rounds: number[]) => [
  '',
  'to this session',
  ...rounds.flatMap(round => [`Review round ${round} ✕`, '└ → Approve ✎ comment']),
]

/** Ready to send's heading, by how many replies it holds not yet with Claude. */
const heading = (count: number) => [`READY TO SEND${count} ${count === 1 ? 'reply' : 'replies'}`]

/** Send and cancel all, at the box's foot. */
const CONTROLS = ['', '[ send to Claude ] [ cancel all ]']

/** The board docked over a window tall enough for Ready to send to list everything here, under half of it (its cut is clip.test.tsx's). */
const TALL: RenderPropsOf['Pane'] = { ...DOCKED, scroll: { offset: 0, bodyRows: 60 } }

/** The session begun with three reviews asked, the board drawn, a minute on: their ids, in round order. */
const asking = async (w: World, props = TALL) => {
  const { paths } = await w.begin()
  const ids: string[] = []

  for (const round of [1, 2, 3]) {
    ids.push(
      postedId(
        await w.call('ask', { wants: 'yes', yes: 'Approve', title: `Review round ${round}` }),
      ),
    )
  }

  const ui = await w.pane('terminal', props)

  await w.clock.advance(MIN)

  return { paths, ids, ui }
}

/** Lee approves an ask, opening it first where it is not open. */
const approve = async (w: World, ui: Pane, id: string) => {
  const key = w.item(id)

  if ((await ui.find({ key: `yes:${key}` })) === undefined) {
    await ui.press({ key: `pick:${key}` })
  }

  await ui.press({ key: `yes:${key}` })
}

/** Ready to send as the rows it draws, each trimmed, the blank ones between its groups kept. */
const box = async (ui: Pane) => rowsOf(await ui.find({ key: 'ready' })).map(row => row.trim())

/** What the window's heartbeat says it sends its session: each send's replies, by item. */
const sendingIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending?.map(each =>
    each.replies.map(reply => reply.item),
  )

/** The items the session's reply lines answer, in the order written. */
const repliedIn = (w: World, paths: SessionPaths) =>
  parseEntries(w.text(paths.log(W1))).flatMap(line => (line.type === 'reply' ? [line.item] : []))

/** The items each message in flight carries, in the order claimed, and whether the window holds it. */
const flightsIn = (w: World) =>
  w.flights().map(({ replies, isHeld }) => ({ items: replies.map(each => each.item), isHeld }))

/** The main conversation's turn ending, and what it set going settled. */
const turnEnded = async (w: World) => {
  await w.turnEnds()
  await w.clock.settle()
}

/** Lee approves the first round and sends it while Claude is mid-turn: the window holds it for the turn to end. */
const holding = async (w: World, ui: Pane, ids: readonly string[]) => {
  const [first = ''] = ids

  await approve(w, ui, first)
  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
}

/** Lee sends the first round while Claude is mid-turn, then the second, while the first is held: two sends held, in round order. */
const twoHeld = async (w: World, ui: Pane, ids: readonly string[]) => {
  const [, second = ''] = ids

  await holding(w, ui, ids)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
}

/** The toasts saying a send did not go. */
const notSent = (w: World) => w.toasts.filter(toast => toast.startsWith('Not sent'))

test("a send held for Claude's turn is sealed: a reply after it lands in a queue of its own under it, with its own send and cancel all, which reach only that queue", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await holding(w, ui, ids)
  await approve(w, ui, second)

  expect(await box(ui)).toEqual([...heading(2), ...held(1), ...toSend(2), ...CONTROLS])
  expect(flightsIn(w), 'the send carries only what it was sent with').toEqual([
    { items: [first], isHeld: true },
  ])
  expect(await ui.find({ key: `unready:${w.item(first)}` }), 'frozen').toBeUndefined()
  expect(await ui.find({ key: `readyrewrite:${w.item(first)}` }), 'frozen').toBeUndefined()
  expect(await ui.find({ key: `unready:${w.item(second)}` })).toBeDefined()
  expect(await ui.find({ key: `undo:${w.item(second)}` })).toBeDefined()
  expect(await ui.find({ key: `readyrewrite:${w.item(second)}` })).toBeDefined()
  expect(sendingIn(w, paths)).toEqual([[first]])

  await ui.press({ key: 'cancel-all' })

  expect(w.state.queue).toMatchObject([{ item: first }])
  expect(await box(ui)).toEqual([...heading(1), ...held(1)])

  await turnEnded(w)

  expect(w.submitted).toEqual([message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.queue).toEqual([])
})

test("sent while the first is held, the second queue is a send of its own, held with its own take-back; as Claude's turn ends the first goes in, and the second only once Claude's turn on the first has ended: two prompts, in order", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)

  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])
  expect(await box(ui)).toEqual([...heading(2), ...held(1), ...held(2)])
  expect(await ui.find({ key: w.takeBack(0) })).toBeDefined()
  expect(await ui.find({ key: w.takeBack(1) })).toBeDefined()
  expect(sendingIn(w, paths), 'both on their way, each its own').toEqual([[first], [second]])

  await w.clock.advance(WATCH_MS)
  expect(w.state.board?.waiting, 'the board folds them on their way at its next look').toBe(1)

  const turn = w.holdPrompts()
  const ended = turnEnded(w)

  await turn.arrived
  await w.turnStarts(message(1))

  expect(w.submitted).toEqual([message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])
  expect(await ui.find({ key: w.takeBack() }), 'still to be taken back').toBeDefined()

  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted, 'held through the turn the first started').toEqual([message(1)])

  turn.end()
  await ended
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
  expect(w.state.queue).toEqual([])
  expect(w.state.inFlight).toBeNull()
})

test("taking back the first send while a second waits puts its replies back among those still to send, in the order replied; the second, held still, goes alone as Claude's turn ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = '', third = ''] = ids

  await twoHeld(w, ui, ids)
  await approve(w, ui, third)
  // Lee's presses come seconds apart: on the frozen clock the heartbeat left
  // saying the second alone would match, in size and time, the one the watch
  // last read saying the first alone, and read as unchanged.
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: w.takeBack(0) })

  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])
  expect(await box(ui)).toEqual([...heading(3), ...held(2), ...toSend(1, 3), ...CONTROLS])
  expect(sendingIn(w, paths)).toEqual([[second]])
  expect(w.state.board?.waiting, 'its ask waits on Lee again at once').toBe(2)

  await turnEnded(w)

  expect(w.submitted).toEqual([message(2)])
  expect(repliedIn(w, paths)).toEqual([second])
  expect(await box(ui)).toEqual([...heading(2), ...toSend(1, 3), ...CONTROLS])
})

test('taking back the second send puts its replies back among those still to send, the first held still, and only the first goes in', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = '', third = ''] = ids

  await twoHeld(w, ui, ids)
  await approve(w, ui, third)
  await ui.press({ key: w.takeBack(1) })

  expect(flightsIn(w)).toEqual([{ items: [first], isHeld: true }])
  expect(await box(ui)).toEqual([...heading(3), ...held(1), ...toSend(2, 3), ...CONTROLS])

  await turnEnded(w)
  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.queue).toMatchObject([{ item: second }, { item: third }])
})

test('a pick-up from Parked while a send is held joins no part of it: it is a queue of its own, sent as a message of its own after the first', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const parked = postedId(await w.call('park', { title: 'A priority badge across all tabs' }))

  await holding(w, ui, ids)
  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `pickup:${w.item(parked)}` })

  expect(await box(ui)).toEqual([
    ...heading(2),
    ...held(1),
    '',
    'to this session',
    'A priority badge across all tabs ✕',
    '└ pick it up',
    ...CONTROLS,
  ])

  await ui.press({ key: 'send' })

  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [parked], isHeld: true },
  ])

  await turnEnded(w)
  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([
    message(1),
    'From the board:\n- Pick up from parked: A priority badge across all tabs',
  ])
  expect(repliedIn(w, paths)).toEqual([first, parked])
})

test('one answer to an item across the sends: an ask a held send carries offers no second reply, two quick presses of send claim the queue once, and each item goes in with one reply', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await holding(w, ui, ids)
  await ui.press({ key: `pick:${w.item(first)}` })
  expect(await ui.find({ key: `yes:${w.item(first)}` }), 'no second reply').toBeUndefined()

  await approve(w, ui, second)
  await Promise.all([ui.press({ key: 'send' }), ui.press({ key: 'send' })])
  await w.clock.advance(WATCH_MS)

  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])
  expect(w.state.board?.asks.map(ask => ask.answerOnItsWay?.verdict)).toEqual([
    'yes',
    'yes',
    undefined,
  ])

  await turnEnded(w)
  await w.turnStarts(message(1))
  await turnEnded(w)
  await w.turnStarts(message(2))
  await turnEnded(w)
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
  expect(w.state.board?.asks.map(ask => ask.state)).toEqual(['closed', 'closed', 'waiting'])
})

test('a reload with two sends held keeps them both, said in the heartbeat in the order sent, and they go in that order, each as its own prompt', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await $.session.start(CONVERSATION)
  await w.clock.advance(WATCH_MS)

  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])
  expect(sendingIn(w, paths)).toEqual([[first], [second]])
  expect(w.state.board?.waiting).toBe(1)

  await turnEnded(w)
  expect(w.submitted).toEqual([message(1)])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
})

test('inline, a send held while the pane was closed shows sealed when it opens again, the reply after it a queue of its own; sending that closes the pane, and both wait as sends of their own', SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w, INLINE)
  const [first = '', second = ''] = ids

  await holding(w, ui, ids)
  expect(w.panes.has('sitrep'), 'closed as the send was claimed').toBe(false)

  await ui.unmount()

  const again = await w.opened(INLINE)

  await approve(w, again, second)
  expect(await box(again)).toEqual([...heading(2), ...held(1), ...toSend(2), ...CONTROLS])

  await again.press({ key: 'send' })
  expect(w.panes.has('sitrep')).toBe(false)
  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])

  await again.unmount()

  const reopened = await w.opened(INLINE)

  expect(await box(reopened)).toEqual([...heading(2), ...held(1), ...held(2)])
})

const LIST = 'Run sitrep list in a shell and paste what it prints'

/** A shell session pasted whole, from a shell begun at home: its prompt's two lines, the first the folder, then what the command printed. */
const SHELL = ['~', '❯ sitrep list', ...Array.from({ length: 19 }, (_, n) => `line ${n + 1}`)]

/** The paste as the engine wraps it in the prompt Lee submits (live, 2.1.295). */
const PASTED = `\n\n<pasted_content id="08fd">\n${SHELL.join('\n')}\n</pasted_content id="08fd">\n`

/** The rows Lee's answer in the prompt draws on its way: its heading, the ask and its words' first line, and its line. */
const ANSWER_HELD = [
  '',
  'on its way to this session',
  LIST,
  `└ “~” +${SHELL.length - 1} lines`,
  HELD,
]

/**
 * The session begun with an ask for a shell's output and the third round's
 * review, the board drawn; Lee answers the first in the prompt with a paste
 * while Claude is mid-turn, and sends it: held. Their ids.
 */
const answeredInPrompt = async (w: World, engine: Engine) => {
  const { paths } = await w.begin()

  const list = postedId(await w.call('ask', { wants: 'words', title: LIST }))
  const review = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 3' }),
  )
  const ui = await w.pane('terminal', TALL)

  if ((await ui.find({ key: `answer:${w.item(list)}` })) === undefined) {
    await ui.press({ key: `pick:${w.item(list)}` })
  }

  await ui.press({ key: `answer:${w.item(list)}` })
  await w.turnStarts('Carry on.')
  w.box.text = `[Pasted text #1 +${SHELL.length - 1} lines]`
  await engine.prompt.submit({ text: PASTED, wait: false, origin: { kind: 'composer' } })
  await ui.press({ key: 'send' })

  return { paths, list, review, ui }
}

test('an answer written in the prompt and sent while Claude is mid-turn, nothing else queued, shows in Ready to send as a send of its own on its way, its words frozen, with its take-back', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, list, ui } = await answeredInPrompt(w, $)

  expect(flightsIn(w)).toEqual([{ items: [list], isHeld: true }])
  expect(await box(ui)).toEqual([...heading(1), ...ANSWER_HELD])
  expect(rowsOf(await ui.find({ key: `ask:${w.item(list)}` })).at(-1)).toBe(
    `└ “~” +${SHELL.length - 1} lines · on its way`,
  )
  expect(await ui.find({ key: `readyrewrite:${w.item(list)}` }), 'frozen').toBeUndefined()

  await turnEnded(w)

  expect(w.submitted).toHaveLength(1)
  expect(repliedIn(w, paths)).toEqual([list])
})

test('a yes given after an answer written in the prompt is held lands in a queue of its own under it, with its own send, and goes as a message of its own after it', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, list, review, ui } = await answeredInPrompt(w, $)

  await approve(w, ui, review)

  expect(await box(ui)).toEqual([...heading(2), ...ANSWER_HELD, ...toSend(3), ...CONTROLS])

  await ui.press({ key: 'send' })

  expect(flightsIn(w)).toEqual([
    { items: [list], isHeld: true },
    { items: [review], isHeld: true },
  ])
  expect(await box(ui)).toEqual([...heading(2), ...ANSWER_HELD, ...held(3)])

  await turnEnded(w)
  await w.turnStarts(w.submitted[0] ?? '')
  await turnEnded(w)

  expect(w.submitted).toHaveLength(2)
  expect(w.submitted[1]).toBe(message(3))
  expect(repliedIn(w, paths)).toEqual([list, review])
})

/** Claude starts another session of the project in this window, the board reading it a look later: the window holds it from then on. */
const startedElsewhere = async (w: World) => {
  await w.call('start', {
    name: 'Invoice ledger',
    summary: 'Invoice ledger, area by area',
    project: PROJECT.name,
  })
  await w.clock.advance(WATCH_MS)
}

test("a send held to a session the board has not read, the window holding another since, still shows on its way there, named as its project's briefs name it, its replies counted, with its line and its take-back", SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await holding(w, ui, ids)
  await startedElsewhere(w)

  expect(await box(ui)).toEqual([...heading(1), '', `on its way to ${HELP_DESK.name}`, HELD])

  await ui.press({ key: w.takeBack() })

  expect(w.state.inFlight).toBeNull()
})

test('a send after the first, one row for room, names where it goes when that is not the session held', SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w, { ...DOCKED, scroll: { offset: 0, bodyRows: 16 } })

  await twoHeld(w, ui, ids)
  await startedElsewhere(w)

  expect(await box(ui)).toEqual([
    ...heading(2),
    '',
    `on its way to ${HELP_DESK.name}`,
    HELD,
    `⧗ Then, to ${HELP_DESK.name}: 1 reply ↺ take back`,
  ])
  expect(await ui.find({ key: w.takeBack(1) })).toBeDefined()
})

test('the first send refused with a second held behind it: both are let go together, one toast saying so, every reply back among those still to send in the order replied, and the second never submitted', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  w.dropPrompts('the session is closing')
  await turnEnded(w)
  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)

  expect(w.submitted).toEqual([message(1)])
  expect(notSent(w)).toEqual([
    'Not sent: the session is closing. Your replies are still on the board.',
  ])
  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toMatchObject([{ item: first }, { item: second }])
  expect(repliedIn(w, paths)).toEqual([])
  expect(await box(ui)).toEqual([...heading(2), ...toSend(1, 2), ...CONTROLS])
})

test('the first send never taken with a second held behind it: both are let go together as its quiet passes, one toast saying so, every reply back among those still to send in the order replied', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)

  const turn = w.holdPrompts()

  void w.turnEnds()
  await turn.arrived
  turn.lose()
  await w.clock.advance(QUIET_MS - 1)
  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: false },
    { items: [second], isHeld: true },
  ])

  await w.clock.advance(1)
  expect(w.state.inFlight).toBeNull()
  expect(notSent(w)).toEqual([
    'Not sent: the message never went in. Your replies are still on the board.',
  ])

  await w.clock.advance(4 * WATCH_MS)
  expect(w.submitted).toEqual([message(1)])
  expect(w.state.queue).toMatchObject([{ item: first }, { item: second }])
  expect(repliedIn(w, paths)).toEqual([])
  expect(await box(ui)).toEqual([...heading(2), ...toSend(1, 2), ...CONTROLS])
})

for (const reason of ['resume', 'prompt_input_exit'] as const) {
  test(`two sends held as the conversation ends for ${reason}: both are let go, nothing submitted, every reply back among those still to send in the order replied`, SLOW, async ($, on) => {
    const w = world($, on)
    const { paths, ids, ui } = await asking(w)
    const [first = '', second = ''] = ids

    await twoHeld(w, ui, ids)
    await $.session.end({ reason, sessionId: W1, resume: { id: W1 } })
    await w.clock.advance(QUIET_MS + WATCH_MS)

    expect(w.state.inFlight).toBeNull()
    expect(w.submitted).toEqual([])
    expect(w.state.queue).toMatchObject([{ item: first }, { item: second }])
    expect(repliedIn(w, paths)).toEqual([])
  })
}

test('two sends held as a /clear ends the conversation go into the next in turn: the first at once, the second once the turn the first started has ended', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
  await w.clock.settle()

  expect(w.submitted).toEqual([message(1)])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
  expect(w.state.inFlight).toBeNull()
})

test("a take-back of the first send landing before the turn's end it raced: the second goes in its place, alone, and the first's reply is back among those still to send", SLOW, async ($, on) => {
  const w = world($, on)
  const going = writeDoor(on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  going.hold(([head]) => head?.isHeld === false)

  const ended = turnEnded(w)

  await going.arrived
  await ui.press({ key: w.takeBack(0) })
  going.open()
  await ended

  expect(w.submitted).toEqual([message(2)])
  expect(repliedIn(w, paths)).toEqual([second])
  expect(w.state.queue).toMatchObject([{ item: first }])
  expect(w.state.inFlight).toBeNull()
})

test("a send behind one submitted waits for the turn that one starts: its submit resolving before that turn is heard, a press of send and the window's looks submit nothing, and each goes once the turn before it has ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = '', third = ''] = ids

  await twoHeld(w, ui, ids)
  await turnEnded(w)
  expect(w.submitted).toEqual([message(1)])
  expect(repliedIn(w, paths), 'its submit resolved').toEqual([first])

  await approve(w, ui, third)
  await ui.press({ key: 'send' })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted, 'none until the turn the first started is heard').toEqual([message(1)])
  expect(flightsIn(w)).toEqual([
    { items: [second], isHeld: true },
    { items: [third], isHeld: true },
  ])

  await w.turnStarts(message(1))
  await turnEnded(w)
  expect(w.submitted).toEqual([message(1), message(2)])

  await w.turnStarts(message(2))
  await turnEnded(w)
  expect(w.submitted).toEqual([message(1), message(2), message(3)])
  expect(repliedIn(w, paths)).toEqual([first, second, third])
})

test("a turn another prompt starts while the next send waits on the turn of the one before opens nothing: the next goes only once that one's own turn has started and ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await turnEnded(w)
  await w.turnStarts('Something Lee typed meanwhile.')
  await turnEnded(w)
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted, "none after another prompt's turn").toEqual([message(1)])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
})

test("two sends held as Lee stops Claude's turn: the first goes as the stopped turn ends, the second once the turn the first started has ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await w.turnEnds({ isAborted: true })
  await w.clock.settle()

  expect(w.submitted).toEqual([message(1)])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
})

test('should the turn a submitted send started never be heard, the send behind it goes at the first look once its quiet has passed, nothing let go', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await turnEnded(w)
  await w.clock.advance(QUIET_MS - 1)
  expect(w.submitted).toEqual([message(1)])

  await w.clock.advance(1 + WATCH_MS)
  expect(w.submitted).toEqual([message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
  expect(notSent(w)).toEqual([])
})

/** Claude Code's refusal of every plugin's prompt once Lee has stopped Claude's turn, until he next types in the window (live, 2.1.318). */
const STOPPED = 'the session was stopped and nobody has sent input since'

/** The line under the first send held while the window is stopped, on a row across the box, its send now and take-back on the row under it. */
const STOPPED_LINE = ['⧗ Interrupted: goes after your next message.', '↑ send now ↺ take back']

/** The rows the first send held while the window is stopped draws in Ready to send: its heading, each round's reply frozen, and its line. */
const stopped = (...rounds: number[]) => [...held(...rounds).slice(0, -1), ...STOPPED_LINE]

/** The rows a send held behind it draws: its heading, each round's reply frozen, and its line. */
const behindStop = (...rounds: number[]) => [
  ...held(...rounds).slice(0, -1),
  '⧗ Goes after your next message. ↺ take back',
]

/** Whether the window is marked stopped, Claude Code refusing its prompts until Lee's input. */
const isStopped = (w: World) => w.state.stopped === true

/** Lee stops Claude's turn, and from then Claude Code refuses the board's prompts until he types in the window. */
const interrupted = async (w: World) => {
  w.dropPrompts(STOPPED)
  await w.turnEnds({ isAborted: true })
  await w.clock.settle()
}

/** Lee types in the window: Claude Code takes the board's prompts again, and his message starts a turn. */
const leeTypes = async (w: World) => {
  w.dropPrompts()
  await w.turnStarts('Look at the failing test instead.')
}

/** Lee types a slash command, as Claude Code raises it to the mod. */
const typedCommand = ($: Engine, command: string) =>
  $.command.run({
    command,
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: true, columns: 160 },
  })

test("a send Claude Code refuses as Lee stopped Claude's turn is not let go: held, the window marked stopped, no toast, its line drawn with send now, its asks on their way still; it goes once Lee's next turn ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)

  expect(w.submitted).toEqual([message(1)])
  expect(notSent(w)).toEqual([])
  expect(flightsIn(w)).toEqual([{ items: [first], isHeld: true }])
  expect(isStopped(w)).toBe(true)
  expect(await box(ui)).toEqual([...heading(1), ...stopped(1)])
  expect(await ui.find({ key: w.takeBack() })).toBeDefined()
  expect(sendingIn(w, paths), 'still on its way').toEqual([[first]])

  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)

  expect(w.submitted, 'no look submits it, nor does its quiet let it go').toEqual([message(1)])
  expect(isStopped(w)).toBe(true)
  expect(w.state.board?.waiting, 'its ask waits on Lee nowhere').toBe(2)

  await leeTypes(w)

  expect(isStopped(w), "Lee's turn lifts the mark").toBe(false)
  expect(w.submitted, 'held to the end of his turn').toEqual([message(1)])

  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.inFlight).toBeNull()
  expect(notSent(w)).toEqual([])
})

test("a subagent's run starting and ending leaves the window stopped and the send unsent", SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()
  await w.agentRunStarts('agent-1')
  await w.turnEnds({ agentId: 'agent-1' })
  await w.clock.advance(4 * WATCH_MS)

  expect(isStopped(w)).toBe(true)
  expect(w.submitted).toEqual([message(1)])
  expect(await box(ui)).toEqual([...heading(1), ...stopped(1)])
})

test("a send sealed behind the first while the window is stopped stays behind it, saying it goes after Lee's next message: the first goes once his turn ends, the second once the first's own turn has ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await interrupted(w)

  expect(w.submitted).toEqual([message(1)])
  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])
  expect(await box(ui)).toEqual([...heading(2), ...stopped(1), ...behindStop(2)])
  expect(await ui.findAll({ key: 'send-now' })).toHaveLength(1)

  await leeTypes(w)
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1), message(2)])
  expect(repliedIn(w, paths)).toEqual([first, second])
  expect(notSent(w)).toEqual([])
})

test('taking back the first send while the window is stopped leaves the second held, unsubmitted, now first, with send now', SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await interrupted(w)
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: w.takeBack(0) })
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([message(1)])
  expect(flightsIn(w)).toEqual([{ items: [second], isHeld: true }])
  expect(w.state.queue).toMatchObject([{ item: first }, { item: second }])
  expect(await box(ui)).toEqual([...heading(2), ...stopped(2), ...toSend(1), ...CONTROLS])
  expect(w.state.board?.waiting, "the first's ask waits on Lee again at once").toBe(2)
})

test("send pressed while the window is stopped submits from within Lee's press, whatever is first going: refused all the same, it waits, the window stopped again, silently; taken, it goes in", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
  await w.clock.settle()

  expect(w.submitted, 'the first goes from the press').toEqual([message(1), message(1)])
  expect(isStopped(w)).toBe(true)
  expect(flightsIn(w)).toEqual([
    { items: [first], isHeld: true },
    { items: [second], isHeld: true },
  ])
  expect(notSent(w)).toEqual([])

  w.dropPrompts()
  await ui.press({ key: 'send-now' })
  await w.clock.settle()

  expect(w.submitted).toEqual([message(1), message(1), message(1)])
  expect(isStopped(w)).toBe(false)
  expect(repliedIn(w, paths)).toEqual([first])

  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted.at(-1)).toBe(message(2))
  expect(repliedIn(w, paths)).toEqual([first, second])
})

test('send pressed while the window is stopped and nothing is in flight goes in at once from the press', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  await ui.press({ key: w.takeBack() })
  w.dropPrompts()
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
  await w.clock.settle()

  expect(w.submitted).toEqual([message(1), message(1, 2)])
  expect(isStopped(w)).toBe(false)
  expect(repliedIn(w, paths)).toEqual([first, second])
})

test('send now shows only while the window is stopped, beside the first send held', SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await twoHeld(w, ui, ids)
  expect(await ui.find({ key: 'send-now' })).toBeUndefined()

  await interrupted(w)
  expect(await ui.findAll({ key: 'send-now' })).toHaveLength(1)

  await leeTypes(w)
  expect(await ui.find({ key: 'send-now' })).toBeUndefined()
})

test("refused again for the same reason after Lee's turn, the window is marked stopped again, nothing lost; the send goes once a later turn of his ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  await w.turnStarts('A task notification, which Claude Code does not count as input.')
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(flightsIn(w)).toEqual([{ items: [first], isHeld: true }])
  expect(isStopped(w)).toBe(true)
  expect(notSent(w)).toEqual([])

  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)
  expect(flightsIn(w), 'no quiet lets it go').toEqual([{ items: [first], isHeld: true }])

  await leeTypes(w)
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})

test("a send held while the window was stopped, refused for another reason once Lee's turn ends, is let go as any refusal is, with the send behind it, one toast saying so", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = '', second = ''] = ids

  await twoHeld(w, ui, ids)
  await interrupted(w)
  await w.turnStarts('Look at the failing test instead.')
  w.dropPrompts('the session is closing')
  await turnEnded(w)
  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(notSent(w)).toEqual([
    'Not sent: the session is closing. Your replies are still on the board.',
  ])
  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toMatchObject([{ item: first }, { item: second }])
  expect(repliedIn(w, paths)).toEqual([])
})

test("taking back the only send while the window is stopped puts its replies back among those still to send, its ask waiting on Lee again at once", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  await w.clock.advance(WATCH_MS)
  await ui.press({ key: w.takeBack() })

  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toMatchObject([{ item: first }])
  expect(await box(ui)).toEqual([...heading(1), ...toSend(1), ...CONTROLS])
  expect(sendingIn(w, paths)).toBeUndefined()
  expect(w.state.board?.waiting).toBe(3)

  await leeTypes(w)
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1)])
  expect(notSent(w)).toEqual([])
})

test("a file-watch reload keeps the window stopped and the send held, the refusal standing; a /clear lifts it, and the send goes into the next conversation at once", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  await $.session.start(CONVERSATION)
  await w.clock.advance(4 * WATCH_MS)

  expect(w.submitted).toEqual([message(1)])
  expect(isStopped(w)).toBe(true)
  expect(sendingIn(w, paths)).toEqual([[first]])

  w.dropPrompts()
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
  await w.clock.settle()

  expect(isStopped(w)).toBe(false)
  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.inFlight).toBeNull()
})

test("a prompt Lee types that the answering mode takes lifts the stop, though no turn follows: the send held goes at the next look, and his answer's send after it", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = postedId(await w.call('ask', { wants: 'words', title: 'Name the release' }))

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()

  if ((await ui.find({ key: `answer:${w.item(words)}` })) === undefined) {
    await ui.press({ key: `pick:${w.item(words)}` })
  }

  await ui.press({ key: `answer:${w.item(words)}` })
  await $.prompt.submit({ text: 'Harbour', wait: false, origin: { kind: 'composer' } })

  expect(isStopped(w)).toBe(false)

  await w.clock.advance(WATCH_MS)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.queue).toMatchObject([{ item: words }])

  await ui.press({ key: 'send' })
  await w.turnStarts(message(1))
  await turnEnded(w)

  expect(w.submitted.at(-1)).toBe(
    `From the board:\n- Name the release → answer: “Harbour”${CLOSES}`,
  )
  expect(repliedIn(w, paths)).toEqual([first, words])
})

test("a prompt of Lee's going on to start a turn leaves the window stopped until that turn starts, so no look puts the send in ahead of it", SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()
  await $.prompt.submit({
    text: 'Look at the failing test instead.',
    wait: false,
    origin: { kind: 'composer' },
  })
  await w.clock.advance(4 * WATCH_MS)

  expect(isStopped(w)).toBe(true)
  expect(w.submitted).toEqual([message(1), 'Look at the failing test instead.'])
})

/** The answer to "Name the release" that goes in with an image: Lee's prompt, rewritten. */
const RODE = `From the board:\n- Name the release → answer: “Harbour [Image #1]”${CLOSES}`

/** The session stopped with the first round's send held, and Lee answering a words ask in the prompt: its id. */
const answeringStopped = async (w: World, ui: Pane, ids: readonly string[]) => {
  const words = postedId(await w.call('ask', { wants: 'words', title: 'Name the release' }))

  await holding(w, ui, ids)
  await interrupted(w)

  if ((await ui.find({ key: `answer:${w.item(words)}` })) === undefined) {
    await ui.press({ key: `pick:${w.item(words)}` })
  }

  await ui.press({ key: `answer:${w.item(words)}` })

  return words
}

/** Lee's answer, an image attached, entered at the prompt. */
const answeredWithImage = ($: Engine) =>
  $.prompt.submit({
    text: 'Harbour [Image #1]',
    attachments: [{ type: 'image' }],
    wait: false,
    origin: { kind: 'composer' },
  })

test("an answer going in with an image is a prompt of Lee's going on: the window stays stopped until its turn starts, then the send held goes as that turn ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = await answeringStopped(w, ui, ids)

  w.dropPrompts()
  await answeredWithImage($)
  await w.clock.advance(4 * WATCH_MS)

  expect(isStopped(w)).toBe(true)
  expect(w.submitted).toEqual([message(1), RODE])
  expect(repliedIn(w, paths)).toEqual([words])

  await w.turnStarts(RODE)

  expect(isStopped(w)).toBe(false)

  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), RODE, message(1)])
  expect(repliedIn(w, paths)).toEqual([words, first])
})

test('an answer with an image dropped beneath lifts the stop, though no turn follows: the send held goes at the next look, and the answer still waits on Lee', SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = await answeringStopped(w, ui, ids)

  w.dropPrompts('Blocked by a hook')
  await answeredWithImage($)

  expect(isStopped(w)).toBe(false)

  w.dropPrompts()
  await w.clock.advance(WATCH_MS)

  expect(w.submitted).toEqual([message(1), RODE, message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
  expect(w.state.answering).toMatchObject({ item: words })
})

/** The first round's send held for Claude's turn, and Lee answering a words ask in the prompt meanwhile: its id. */
const answeringWhileHeld = async (w: World, ui: Pane, ids: readonly string[]) => {
  const words = postedId(await w.call('ask', { wants: 'words', title: 'Name the release' }))

  await holding(w, ui, ids)

  if ((await ui.find({ key: `answer:${w.item(words)}` })) === undefined) {
    await ui.press({ key: `pick:${w.item(words)}` })
  }

  await ui.press({ key: `answer:${w.item(words)}` })

  return words
}

test("an answer going in with an image while a send is held goes ahead of it, and the send goes once the answer's own turn has ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = await answeringWhileHeld(w, ui, ids)
  const held = w.holdPrompts()
  const typed = answeredWithImage($)

  await held.arrived

  expect(flightsIn(w)).toEqual([
    { items: [words], isHeld: false },
    { items: [first], isHeld: true },
  ])

  held.end()
  await typed

  expect(repliedIn(w, paths)).toEqual([words])

  await turnEnded(w)

  expect(w.submitted, 'nothing goes until the answer’s turn is heard').toEqual([RODE])

  await w.turnStarts(RODE)
  await turnEnded(w)

  expect(w.submitted).toEqual([RODE, message(1)])
  expect(repliedIn(w, paths)).toEqual([words, first])
})

test("an answer typed while Claude's turn runs holds the send behind it however long that turn runs, until the answer's own turn has started and ended", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = await answeringWhileHeld(w, ui, ids)

  await answeredWithImage($)
  await w.clock.advance(2 * QUIET_MS)
  await turnEnded(w)

  expect(w.submitted).toEqual([RODE])

  await w.turnStarts(RODE)
  await turnEnded(w)

  expect(w.submitted).toEqual([RODE, message(1)])
  expect(repliedIn(w, paths)).toEqual([words, first])
})

test("an answer folded into Claude's running turn, starting no turn of its own, holds the send behind it until the window has been quiet a while after that turn", SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await answeringWhileHeld(w, ui, ids)
  await answeredWithImage($)
  await w.clock.advance(2 * QUIET_MS)
  await turnEnded(w)
  await w.clock.advance(QUIET_MS - WATCH_MS)

  expect(w.submitted).toEqual([RODE])

  await w.clock.advance(2 * WATCH_MS)

  expect(w.submitted).toEqual([RODE, message(1)])
})

test("an answer whose turn starts before its hook hears back holds the send behind it only until that turn ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids
  const words = await answeringWhileHeld(w, ui, ids)
  const held = w.holdPrompts()
  const typed = answeredWithImage($)

  await held.arrived
  await turnEnded(w)
  await w.turnStarts(RODE)

  expect(repliedIn(w, paths)).toEqual([words])

  held.end()
  await typed
  await turnEnded(w)

  expect(w.submitted).toEqual([RODE, message(1)])
  expect(repliedIn(w, paths)).toEqual([words, first])
})

test('while the window is stopped, the first send held behind an answer going in with an image offers no send now, which could not send it', SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await answeringStopped(w, ui, ids)
  w.dropPrompts()

  const held = w.holdPrompts()
  const typed = answeredWithImage($)

  await held.arrived

  expect(flightsIn(w).map(each => each.isHeld)).toEqual([false, true])
  expect(await ui.find({ key: SEND_NOW })).toBeUndefined()
  expect(await box(ui)).toContain('⧗ Goes after your next message. ↺ take back')

  held.end()
  await typed
})

test("a prompt another plugin submits, or the SDK's, lifts nothing: only Lee's own input counts", SLOW, async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await asking(w)

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts('another reason')
  await $.prompt.submit({
    text: 'Run the linter.',
    wait: false,
    origin: { kind: 'plugin', name: 'linter' },
  })
  await $.prompt.submit({ text: 'Run the linter.', wait: false, origin: { kind: 'sdk' } })

  expect(isStopped(w)).toBe(true)
})

test("a slash command Lee types lifts the stop, though no turn follows; nothing is submitted while it runs, and the send held goes at the next look after it", SLOW, async ($, on) => {
  let finish = () => {}
  const compacting = new Promise<void>(resolve => {
    finish = resolve
  })

  on('command.run', { command: 'compact' }, async () => {
    await compacting

    return {}
  })

  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()

  const ran = typedCommand($, 'compact')

  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)

  expect(isStopped(w)).toBe(false)
  expect(w.submitted, 'nothing while it runs').toEqual([message(1)])

  finish()
  await ran
  await w.clock.advance(WATCH_MS)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})

test('a /reload-plugins Lee types lifts the stop: the load after it sends the send held at once', SLOW, async ($, on) => {
  on('command.run', { command: 'reload-plugins' }, () => ({}))

  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()
  await typedCommand($, 'reload-plugins')
  await $.session.start(CONVERSATION)
  await w.clock.settle()

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})

test('a /clear Lee types lifts the stop, and the send held goes into the next conversation at the first look once the command has ended', SLOW, async ($, on) => {
  on('command.run', { command: 'clear' }, async () => {
    await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })

    return {}
  })

  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  await interrupted(w)
  w.dropPrompts()
  await typedCommand($, 'clear')
  await w.clock.settle()

  expect(isStopped(w)).toBe(false)
  expect(w.submitted, 'nothing while the command ran').toEqual([message(1)])

  await w.clock.advance(WATCH_MS)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})

test("Lee's turn starting between a submit and Claude Code's refusal of it leaves the window unmarked, the send held to go as that turn ends", SLOW, async ($, on) => {
  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  w.dropPrompts(STOPPED)

  const turn = w.holdPrompts()

  void w.turnEnds({ isAborted: true })
  await turn.arrived
  await w.turnStarts('Look at the failing test instead.')
  turn.end()
  await w.clock.settle()

  expect(flightsIn(w)).toEqual([{ items: [first], isHeld: true }])
  expect(isStopped(w)).toBe(false)
  expect(await box(ui)).toEqual([...heading(1), ...held(1)])

  w.dropPrompts()
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})

test("Lee's turn starting while the stop is being written lifts it once written", SLOW, async ($, on) => {
  let arrive = () => {}
  let open = () => {}
  const arrived = new Promise<void>(resolve => {
    arrive = resolve
  })
  const opened = new Promise<void>(resolve => {
    open = resolve
  })

  on('state.set', { plugin: 'sitrep', key: 'stopped' }, async ($, e, next) => {
    if (e.value === true) {
      arrive()
      await opened
    }

    return next(e)
  })

  const w = world($, on)
  const { paths, ids, ui } = await asking(w)
  const [first = ''] = ids

  await holding(w, ui, ids)
  w.dropPrompts(STOPPED)

  const ended = w.turnEnds({ isAborted: true })

  await arrived
  await w.turnStarts('Look at the failing test instead.')
  open()
  await ended
  await w.clock.settle()

  expect(isStopped(w)).toBe(false)

  w.dropPrompts()
  await turnEnded(w)

  expect(w.submitted).toEqual([message(1), message(1)])
  expect(repliedIn(w, paths)).toEqual([first])
})
