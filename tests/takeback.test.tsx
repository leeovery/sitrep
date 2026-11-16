/**
 * A message the window holds while Claude is mid-turn, submitted once the
 * main conversation's turn ends however it ends, and Lee's take-back of his
 * own send while it is held: one update of the claim decides between the
 * two, so a take-back and the turn's end racing never both win, and never
 * lose the message.
 */
import type { SessionEndReason } from 'claude-code'
import { expect, test, tier } from './kit'
import type { SessionPaths } from '../core'
import { QUIET_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import type { SitrepInFlight } from '../types'
import { AGENT, CLOSES, MIN, SENDER, W1 } from './data'
import { file, kindsIn, reply, sendingIn } from './lines'
import { asking, asksOnBand, CONVERSATION, turnEnded, world, writeDoor, type World } from './world'

tier('user')

type Source = 'send' | 'inbox'

const MESSAGE = `From the board:\n- Review Tickets & Replies, round 1 → Approve${CLOSES}`

const HELD = "⧗ Waiting for Claude's turn to end."

/** A held send's take-back, by its words: found by its key (`w.takeBack()`) where it must be that send's. */
const TAKE_BACK = '↺ take back'

/** What the window's own file holds once the message is written down, by its source. */
const WRITTEN: Record<Source, string[]> = {
  send: ['ask', 'reply', 'delivered'],
  inbox: ['ask', 'delivered'],
}

type Asking = Awaited<ReturnType<typeof asking>>

/**
 * Lee's yes to the review: queued on the board, or in the inbox from another
 * session's window. `claim` has the window claim its message: a press of
 * send, or the looks that take the letter in.
 */
const replying: Record<Source, (w: World) => Promise<Asking & { claim: () => Promise<unknown> }>> =
  {
    send: async w => {
      const at = await asking(w, { advance: MIN })

      await at.ui.press({ key: `yes:${w.item(at.id)}` })

      return { ...at, claim: () => at.ui.press({ key: 'send' }) }
    },
    inbox: async w => {
      const at = await asking(w, { advance: MIN })

      w.put(at.paths.letters(SENDER), file([w.clock.now(), reply('r1', at.id, 'yes')]))

      return { ...at, claim: () => w.clock.advance(2 * WATCH_MS) }
    },
  }

/** Whether the session is as a message written down once leaves it: its lines, the ask closed, nothing in flight. */
const expectWrittenOnce = (w: World, paths: SessionPaths, source: Source) => {
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths.log(W1))).toEqual(WRITTEN[source])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.inFlight).toBeNull()
}

/** Whether the window holds its message, nothing submitted. */
const expectHeld = (w: World, source: Source) => {
  expect(w.submitted).toEqual([])
  expect(w.state.inFlight).toMatchObject({ source, isHeld: true, isTaken: false })
}

for (const source of ['send', 'inbox'] as const) {
  test(`${source}: claimed while Claude is mid-turn, the message is held, nothing submitted however long the turn runs; as it ends it goes in, written down once`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await claim()
    await w.clock.advance(QUIET_MS + MIN)
    expectHeld(w, source)

    await turnEnded(w)
    expectWrittenOnce(w, paths, source)

    await w.clock.advance(QUIET_MS + 4 * WATCH_MS)
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: claimed between turns, the message goes in at once`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await turnEnded(w)
    await claim()
    await w.clock.settle()
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: a subagent's run starting after Claude's turn ended starts no turn of Claude's: the message claimed then goes in at once, and the run's end changes nothing`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await turnEnded(w)
    await w.agentRunStarts(AGENT)
    await claim()
    await w.clock.settle()
    expectWrittenOnce(w, paths, source)

    await turnEnded(w, { agentId: AGENT })
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: held mid-turn, the message stays held through a subagent's run starting and ending, and goes as Claude's turn ends`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await claim()
    await w.agentRunStarts(AGENT)
    await turnEnded(w, { agentId: AGENT })
    expectHeld(w, source)

    await turnEnded(w)
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: a turn that starts as the last one ends, before the held message goes, keeps it held to its own end`, async ($, on) => {
    const w = world($, on)
    let isRacing = false

    // As the turn's end reads the claim to send it, Lee's next prompt starts a turn.
    on('state.get', { plugin: 'sitrep', key: ['inFlight'] }, async ($, e, next) => {
      if (isRacing) {
        isRacing = false
        await w.turnStarts('Lee typed this meanwhile.')
      }

      return next(e)
    })

    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await claim()
    isRacing = true
    await turnEnded(w)
    expect(isRacing, 'the turn started as the claim was read').toBe(false)
    expectHeld(w, source)

    await turnEnded(w)
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: a turn starting with a held message's own text is some other prompt: nothing is written down until the message goes`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await claim()
    await w.turnStarts(MESSAGE)
    expectHeld(w, source)
    expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])

    await turnEnded(w)
    expectWrittenOnce(w, paths, source)
  })

  test(`${source}: a subagent's turn ending is not the main conversation's: the message stays held`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await claim()
    await turnEnded(w, { agentId: AGENT })
    expectHeld(w, source)

    await turnEnded(w)
    expectWrittenOnce(w, paths, source)
  })
}

for (const reason of ['aborted', 'error', 'refusal'] as const) {
  test(`a turn ended ${reason === 'aborted' ? 'by Lee stopping it' : `by ${reason === 'error' ? 'an API error' : "the model's refusal"}`} lets the held message go, as an answered one does`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying.send(w)

    await w.turnStarts('Carry on.')
    await claim()
    expectHeld(w, 'send')

    await $.turn.complete({
      answer: '',
      durationMs: 1_000,
      isAborted: reason === 'aborted',
      turnId: 'turn-1',
      ...(reason === 'refusal'
        ? { reason, refusal: { category: null, explanation: null } }
        : { reason }),
    })
    await w.clock.settle()
    expectWrittenOnce(w, paths, 'send')
  })
}

test('a turn stopped on a permission prompt or a question is still mid-turn: the send stays held through the stop and after it, until the turn ends', async ($, on) => {
  const w = world($, on)
  const { paths, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')

  const pr = w.calls(
    'Bash',
    { command: 'gh pr create --fill', description: 'Open the pull request' },
    { verdict: 'ask', isShown: true },
  )
  const asked = w.calls('AskUserQuestion', {
    questions: [
      {
        question: 'Which edge?',
        header: 'Edge',
        options: [
          { label: 'Left', description: 'As drawn' },
          { label: 'Right', description: 'Nearer the menu bar' },
        ],
        multiSelect: false,
      },
    ],
  })

  await w.clock.settle()
  expect(w.state.activity?.stops.map(stop => stop.is).sort(), 'stopped on Lee').toEqual([
    'permission',
    'question',
  ])

  await claim()
  expectHeld(w, 'send')

  pr.finish()
  asked.finish({ answers: { 'Which edge?': 'Left' } })
  await Promise.all([pr.done, asked.done])
  expectHeld(w, 'send')

  await turnEnded(w)
  expectWrittenOnce(w, paths, 'send')
})

test("send: while held, Ready to send says it waits for Claude's turn to end, with its take-back; taken back, its replies are back as they were, editable and removable, the heartbeat says them no more, and the ask waits on Lee again", async ($, on) => {
  const w = world($, on)
  const { paths, id, ui } = await replying.send(w)
  const key = w.item(id)
  const queued = w.state.queue

  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await w.clock.advance(WATCH_MS)

  expectHeld(w, 'send')
  expect(await ui.find({ type: 'Text', text: HELD }), 'what it waits for').toBeDefined()
  expect(await ui.find({ key: w.takeBack(), text: TAKE_BACK }), 'its take-back').toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' }), 'its reply, on its way').toBeDefined()
  expect(await ui.find({ key: `unready:${key}` }), 'frozen while it goes').toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeUndefined()
  expect(sendingIn(w, paths), 'said in the heartbeat').toBeDefined()
  expect(w.state.board?.waiting).toBe(0)
  expect(await asksOnBand(w, '0 asks'), 'none on the band').toBeDefined()

  await ui.press({ key: w.takeBack() })

  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)
  expect(await ui.find({ type: 'Text', text: HELD })).toBeUndefined()
  expect(await ui.find({ text: TAKE_BACK })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '· not sent yet' }), 'its reply, not sent').toBeDefined()
  expect(await ui.find({ key: `unready:${key}` }), 'removable').toBeDefined()
  expect(await ui.find({ key: `undo:${key}` }), 'undone from its ask').toBeDefined()
  expect(await ui.find({ key: `readyrewrite:${key}`, text: '✎ comment' }), 'editable').toBeDefined()
  expect(await ui.find({ key: 'send' }), 'sent again').toBeDefined()
  expect(sendingIn(w, paths), 'said no more').toBeUndefined()
  expect(w.state.board?.waiting, 'at once, not at the next look').toBe(1)
  expect(await asksOnBand(w, '1 ask'), 'one on the band').toBeDefined()

  await turnEnded(w)
  expect(w.submitted, 'nothing goes as the turn ends').toEqual([])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
})

test("send: held mid-turn, it is taken back while a subagent's run is under way: nothing goes as that run or Claude's turn ends", async ($, on) => {
  const w = world($, on)
  const { paths, ui, claim } = await replying.send(w)
  const queued = w.state.queue

  await w.turnStarts('Carry on.')
  await claim()
  await w.agentRunStarts(AGENT)
  await ui.press({ key: w.takeBack() })

  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)

  await turnEnded(w, { agentId: AGENT })
  await turnEnded(w)
  expect(w.submitted).toEqual([])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
})

test('send: taken back, it can be sent again, held again while Claude is mid-turn, and goes as the turn ends', async ($, on) => {
  const w = world($, on)
  const { paths, ui } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await ui.press({ key: w.takeBack() })
  await ui.press({ key: 'send' })
  expectHeld(w, 'send')

  await turnEnded(w)
  expectWrittenOnce(w, paths, 'send')
})

test('send: once submitted it cannot be taken back: the control is gone, and Ready to send says it is sending', async ($, on) => {
  const w = world($, on)
  const { paths, ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  expect(await ui.find({ key: w.takeBack() })).toBeDefined()

  const turn = w.holdPrompts()
  const ended = turnEnded(w)

  await turn.arrived
  expect(w.state.inFlight).toMatchObject({ isHeld: false, isTaken: false })
  expect(await ui.find({ text: TAKE_BACK })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '⧗ Sending.' })).toBeDefined()
  expect(sendingIn(w, paths), 'still on its way').toBeDefined()

  turn.end()
  await ended
  await w.clock.settle()
  expectWrittenOnce(w, paths, 'send')
})

test("the turn's end landing before a take-back it raced: the take-back finds the send submitted and lets it be, and it is written down once", async ($, on) => {
  const w = world($, on)
  const takingBack = writeDoor(on)
  const { paths, ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  takingBack.hold(flights => flights.length === 0)

  const pressed = ui.press({ key: w.takeBack() })

  await takingBack.arrived

  const turn = w.holdPrompts()
  const ended = turnEnded(w)

  await turn.arrived
  takingBack.open()
  await w.clock.settle()
  expect(w.state.inFlight, 'still on its way').toMatchObject({ isHeld: false, isTaken: false })

  turn.end()
  await Promise.all([pressed, ended])
  await w.clock.settle()
  expectWrittenOnce(w, paths, 'send')
  expect(w.state.queue).toEqual([])
})

test("a take-back landing before the turn's end it raced: the turn's end finds the send gone and submits nothing, its replies back in Ready to send", async ($, on) => {
  const w = world($, on)
  const going = writeDoor(on)
  const { paths, ui, claim } = await replying.send(w)
  const queued = w.state.queue

  await w.turnStarts('Carry on.')
  await claim()
  going.hold(([first]) => first?.isHeld === false)

  const ended = turnEnded(w)

  await going.arrived
  await ui.press({ key: w.takeBack() })
  going.open()
  await ended
  await w.clock.advance(QUIET_MS + WATCH_MS)

  expect(w.submitted).toEqual([])
  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.state.board?.waiting).toBe(1)
})

test('a reload while Claude is mid-turn keeps holding the send, said in the heartbeat, and it goes as the turn ends', async ($, on) => {
  const w = world($, on)
  const { paths, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  await $.session.start(CONVERSATION)
  await w.clock.advance(WATCH_MS)

  expectHeld(w, 'send')
  expect(sendingIn(w, paths)).toBeDefined()
  expect(w.state.board?.waiting).toBe(0)

  await turnEnded(w)
  expectWrittenOnce(w, paths, 'send')
})

test("a load that finds the send held between turns, its last load's going cut short as the turn ended, sends it at once", async ($, on) => {
  const w = world($, on)
  let isCut = true

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, ($, e, next) =>
    isCut && (e.value as SitrepInFlight | null)?.isHeld === false
      ? { deny: 'the load was cut short' }
      : next(e),
  )

  const { paths, ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  await turnEnded(w)
  expect(w.submitted).toEqual([])
  expect(await ui.find({ key: w.takeBack() }), 'still held').toBeDefined()

  isCut = false
  await $.session.start(CONVERSATION)
  await w.clock.settle()
  expectWrittenOnce(w, paths, 'send')
})

test("a send left held between turns, its update as the turn ended refused, goes at the window's next look, once", async ($, on) => {
  const w = world($, on)
  let isRefused = true

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, ($, e, next) =>
    isRefused && (e.value as SitrepInFlight | null)?.isHeld === false
      ? { deny: 'the update failed' }
      : next(e),
  )

  const { paths, ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  await turnEnded(w)
  expect(w.submitted).toEqual([])
  expect(await ui.find({ key: w.takeBack() }), 'still held').toBeDefined()

  isRefused = false
  await w.clock.advance(WATCH_MS)
  expectWrittenOnce(w, paths, 'send')

  await w.clock.advance(QUIET_MS + 4 * WATCH_MS)
  expectWrittenOnce(w, paths, 'send')
})

test('nothing in flight, a load, a turn and its end, and the looks write no claim; a claim held while a turn runs, the looks leave unwritten', async ($, on) => {
  const w = world($, on)
  const { claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await turnEnded(w)
  await w.clock.advance(4 * WATCH_MS)
  expect(w.writes.inFlight).toBeUndefined()

  await w.turnStarts('Carry on.')
  await claim()

  const claimed = w.writes.inFlight

  await w.clock.advance(4 * WATCH_MS)
  expect(claimed).toBe(1)
  expect(w.writes.inFlight).toBe(claimed)
})

/** The conversation ending, for `reason`. */
const ending = (reason: SessionEndReason) => ({ reason, sessionId: W1, resume: { id: W1 } })

test('a send held as a /clear ends the conversation goes into the next, and is written into its session though the window holds none', async ($, on) => {
  const w = world($, on)
  const { paths, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  await $.session.end(ending('clear'))
  await w.clock.settle()

  expect(w.state.attachment ?? null).toBeNull()
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths.log(W1))).toEqual(WRITTEN.send)
  expect(w.state.inFlight).toBeNull()
})

for (const reason of ['resume', 'prompt_input_exit', 'logout', 'other'] as const) {
  test(`a send held as the conversation ends for ${reason}, no conversation of its own going on, is let go as a take-back lets it go: nothing submitted, its replies in Ready to send as they were`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying.send(w)
    const queued = w.state.queue

    await w.turnStarts('Carry on.')
    await claim()
    await $.session.end(ending(reason))
    await w.clock.advance(QUIET_MS + WATCH_MS)

    expect(w.state.inFlight).toBeNull()
    expect(w.submitted).toEqual([])
    expect(w.state.queue).toEqual(queued)
    expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  })
}

test("inbox: a message held as the conversation ends for a resume is let go, its letters left unmarked in the inbox", async ($, on) => {
  const w = world($, on)
  const { paths, claim } = await replying.inbox(w)

  await w.turnStarts('Carry on.')
  await claim()
  await $.session.end(ending('resume'))
  await w.clock.settle()

  expect(w.state.inFlight).toBeNull()
  expect(w.submitted).toEqual([])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
  expect(w.files.has(paths.letters(SENDER))).toBe(true)
})

test('a send submitted and not yet taken as the conversation ends for an exit is Claude Code’s: it is left on its way, its claim unwritten', async ($, on) => {
  const w = world($, on)
  const { claim } = await replying.send(w)
  const turn = w.holdPrompts()

  void claim()
  await turn.arrived

  const claimed = w.writes.inFlight

  await $.session.end(ending('prompt_input_exit'))
  await w.clock.settle()

  expect(w.state.inFlight).toMatchObject({ isHeld: false, isTaken: false })
  expect(w.writes.inFlight).toBe(claimed)

  turn.end()
})

test('inbox: a held message offers no take-back, though the window holds it as it holds a send', async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.inbox(w)

  await w.turnStarts('Carry on.')
  await claim()

  expectHeld(w, 'inbox')
  expect(await ui.find({ text: TAKE_BACK })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: HELD })).toBeUndefined()
})

test('a held send is never let go as never taken: the 30 seconds count from its submit at the turn’s end, not its claim', async ($, on) => {
  const w = world($, on)
  const { paths, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await claim()
  await w.clock.advance(2 * QUIET_MS)
  expectHeld(w, 'send')

  const turn = w.holdPrompts()

  void w.turnEnds()
  await turn.arrived
  turn.lose()
  await w.clock.advance(QUIET_MS - 1)
  expect(w.state.inFlight).toMatchObject({ isHeld: false, isTaken: false })

  await w.clock.advance(1)
  expect(w.state.inFlight).toBeNull()
  expect(w.toasts).toContain(
    'Not sent: the message never went in. Your replies are still on the board.',
  )
  expect(w.state.queue).toMatchObject([{ verdict: 'yes' }])
  expect(kindsIn(w, paths.log(W1))).toEqual(['ask'])
})

test('a message submitted between turns that never goes in is let go 30 seconds after its submit, no turn ending, its ask waiting on Lee again at once', async ($, on) => {
  const w = world($, on)
  const { claim } = await replying.send(w)
  const turn = w.holdPrompts()

  // Half a look on, so the message is let go between the watch's looks.
  await w.clock.advance(WATCH_MS / 2)
  void claim()
  await turn.arrived
  turn.lose()
  await w.clock.advance(QUIET_MS - 1)
  expect(w.state.inFlight).toMatchObject({ isHeld: false, isTaken: false })
  expect(w.state.board?.waiting).toBe(0)

  await w.clock.advance(1)
  expect(w.state.inFlight).toBeNull()
  expect(w.state.board?.waiting, 'not at the next look').toBe(1)
})

test("a message submitted between turns that never goes in is let go 30 seconds after its submit though a subagent's run starts meanwhile: only a turn of Claude's own is heard", async ($, on) => {
  const w = world($, on)
  const { claim } = await replying.send(w)
  const turn = w.holdPrompts()

  void claim()
  await turn.arrived
  turn.lose()
  await w.clock.advance(QUIET_MS / 2)
  await w.agentRunStarts(AGENT)
  await w.clock.advance(QUIET_MS / 2)

  expect(w.state.inFlight).toBeNull()
  expect(w.state.board?.waiting).toBe(1)
})
