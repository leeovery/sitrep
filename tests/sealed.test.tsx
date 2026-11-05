/**
 * Ready to send while a send of Lee's waits for Claude's turn to end: that
 * send sealed, its replies frozen, and whatever Lee queues after it a queue
 * of its own under it, which a press of send makes a second send. Each send
 * goes in as its own prompt, in the order sent, the next once Claude's turn
 * on the one before has ended.
 */
import type { RenderPropsOf } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, parsePresence, type SessionPaths } from '../core'
import { WATCH_MS } from '../hooks/window'
import { rowsOf } from './drawn'
import { MIN, SLOW, W1 } from './support'
import { CONVERSATION, DOCKED, INLINE, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Pane = Awaited<ReturnType<World['pane']>>

/** Lee's message carrying his yes to each of these rounds of review. */
const message = (...rounds: number[]) =>
  ['From the board:', ...rounds.map(round => `- Review round ${round} → Approve`)].join('\n')

/** The rows a send waiting for Claude's turn draws in Ready to send: its heading, each round's reply frozen, and its line. */
const held = (...rounds: number[]) => [
  '',
  'on its way to this session',
  ...rounds.flatMap(round => [`Review round ${round}`, '└ → Approve']),
  "⧗ Waiting for Claude's turn to end. ↺ take back",
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

  await holding(w, ui, ids)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })

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

  await holding(w, ui, ids)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
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

  await holding(w, ui, ids)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
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
  const parked = postedId(await w.call('park', { title: 'A tmux indicator across sessions' }))

  await holding(w, ui, ids)
  await ui.press({ key: `ppick:${w.item(parked)}` })
  await ui.press({ key: `pickup:${w.item(parked)}` })

  expect(await box(ui)).toEqual([
    ...heading(2),
    ...held(1),
    '',
    'to this session',
    'A tmux indicator across sessions ✕',
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
    'From the board:\n- Pick up from parked: A tmux indicator across sessions',
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

  await holding(w, ui, ids)
  await approve(w, ui, second)
  await ui.press({ key: 'send' })
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
