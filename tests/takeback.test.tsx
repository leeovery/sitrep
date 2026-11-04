/**
 * A message the window holds while Claude is mid-turn, submitted once the
 * main conversation's turn ends however it ends, and Lee's take-back of his
 * own send while it is held: one update of the claim decides between the
 * two, so a take-back and the turn's end racing never both win, and never
 * lose the message. Held while Claude's turn only waits on its background
 * work, which Claude Code holds open until that work ends, Ready to send
 * says so.
 */
import type { On, RenderPropsOf, SessionEndReason } from 'claude-code'
import { expect, test, tier, type Mounted } from 'claude-code/testing'
import { parseEntries, parsePresence, type SessionPaths } from '../core'
import { QUIET_MS } from '../hooks/deliver'
import { WATCH_MS } from '../hooks/window'
import type { SitrepInFlight } from '../types'
import { rowsOf } from './drawn'
import { HELD, sendingRows, sendingSays, WAITS_ON_WORK, WAITS_ON_WORK_SHORT } from './holding'
import { AGENT, file, FORK, MIN, reply, SENDER, SLOW, W1 } from './support'
import { ACROSS, CONVERSATION, DOCKED, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Source = 'send' | 'inbox'

const REVIEW = { wants: 'yes', yes: 'Approve', title: 'Review Sessions & Runway, round 1' }

const MESSAGE = 'From the board:\n- Review Sessions & Runway, round 1 → Approve'

const TAKE_BACK = 'take-back'

const TAKE_BACK_LABEL = '↺ take back'

/** The cells across a held send's line has on a docked board: Ready to send's border and padding, each side, and its take-back and the gap before it taken. */
const BESIDE_TAKE_BACK = ACROSS - 4 - TAKE_BACK_LABEL.length - 1

/** The rows Ready to send takes besides its lines: its border. */
const BORDER = 2

/** The rows a docked board's header takes: the tabs, their rule, and the way back's row. */
const HEADER = 3

/** The board docked over a window `bodyRows` down and `bodyColumns` across. */
const docked = (bodyRows: number, bodyColumns: number): RenderPropsOf['Pane'] => ({
  ...DOCKED,
  bodyColumns,
  scroll: { offset: 0, bodyRows },
})

/** The most rows of a docked board's window Ready to send takes: under half. */
const readyCap = (bodyRows: number) => Math.floor((bodyRows - 1) / 2)

/** The rows of a docked board's list, between its header and Ready to send. */
const listRows = async (ui: Pick<Mounted, 'findAll'>) =>
  Number(
    (await ui.findAll({ type: 'Box' })).find(box => box.props.overflow === 'hidden')?.props.height,
  )

/** What the window's own file holds once the message is written down, by its source. */
const WRITTEN: Record<Source, string[]> = {
  send: ['ask', 'reply', 'delivered'],
  inbox: ['ask', 'delivered'],
}

const kindsIn = (w: World, paths: SessionPaths) =>
  parseEntries(w.text(paths.log(W1))).map(line => line.type)

/** What the window's heartbeat says it sends its session. */
const sendingIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.sending

/** The band's count of what waits on Lee in this session, where it says `text`. */
const asksOnBand = async (w: World, text: string) =>
  (await w.band()).find({ key: 'band:asks', text })

/** This session with a review asked, the board drawn, a minute on. */
const asking = async (w: World) => {
  const { paths } = await w.begin()
  const id = postedId(await w.call('ask', REVIEW))
  const ui = await w.pane()

  await w.clock.advance(MIN)

  return { paths, id, ui }
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
      const at = await asking(w)

      await at.ui.press({ key: `yes:${w.item(at.id)}` })

      return { ...at, claim: () => at.ui.press({ key: 'send' }) }
    },
    inbox: async w => {
      const at = await asking(w)

      w.put(at.paths.letters(SENDER), file([w.clock.now(), reply('r1', at.id, 'yes')]))

      return { ...at, claim: () => w.clock.advance(2 * WATCH_MS) }
    },
  }

/** Whether the session is as a message written down once leaves it: its lines, the ask closed, nothing in flight. */
const expectWrittenOnce = (w: World, paths: SessionPaths, source: Source) => {
  expect(w.submitted).toEqual([MESSAGE])
  expect(kindsIn(w, paths)).toEqual(WRITTEN[source])
  expect(w.state.board?.asks[0]?.state).toBe('closed')
  expect(w.state.inFlight).toBeNull()
}

/** Whether the window holds its message, nothing submitted. */
const expectHeld = (w: World, source: Source) => {
  expect(w.submitted).toEqual([])
  expect(w.state.inFlight).toMatchObject({ source, isHeld: true, isTaken: false })
}

/** The main conversation's turn ending, and what it set going settled. */
const turnEnded = async (w: World, how?: Parameters<World['turnEnds']>[0]) => {
  await w.turnEnds(how)
  await w.clock.settle()
}

/** Claude's turn started, a subagent sent off from it into the background and at work, and Claude done: its turn only waits on that work. */
const waitsOnItsWork = async (w: World) => {
  w.lists(AGENT)
  await w.turnStarts('Carry on.')
  await w.steps({ tools: ['Agent'] })
  await w.steps({ agentId: AGENT })
  await w.steps()
}

/** How Claude's turn runs as the message is claimed, and what comes before Claude Code can end it: nothing, or its background work ending. */
const TURNS = {
  'at work': {
    starts: (w: World) => w.turnStarts('Carry on.'),
    beforeItEnds: async (_: World) => {},
  },
  'only waiting on its background work': {
    starts: waitsOnItsWork,
    beforeItEnds: (w: World) => turnEnded(w, { agentId: AGENT }),
  },
}

/**
 * A door on the writes of the message in flight, set up before the test
 * first calls the engine: once `hold` picks one, the next write it picks
 * waits there until `open()`, an update read and decided, not yet landed, so
 * another can land first. `arrived` once one waits there.
 */
const writeDoor = (on: On) => {
  let isIt: ((value: SitrepInFlight | null) => boolean) | undefined
  let arrive = () => {}
  let open = () => {}
  const arrived = new Promise<void>(resolve => {
    arrive = resolve
  })
  const opened = new Promise<void>(resolve => {
    open = resolve
  })

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, async ($, e, next) => {
    if (isIt?.(e.value as SitrepInFlight | null) === true) {
      isIt = undefined
      arrive()
      await opened
    }

    return next(e)
  })

  return {
    hold: (pick: (value: SitrepInFlight | null) => boolean) => {
      isIt = pick
    },
    arrived,
    open: () => open(),
  }
}

for (const source of ['send', 'inbox'] as const) {
  for (const [running, turn] of Object.entries(TURNS)) {
    test(`${source}: claimed while Claude's turn is ${running}, the message is held, nothing submitted however long the turn runs; as it ends it goes in, written down once`, SLOW, async ($, on) => {
      const w = world($, on)
      const { paths, claim } = await replying[source](w)

      await turn.starts(w)
      await claim()
      await w.clock.advance(QUIET_MS + MIN)
      expectHeld(w, source)

      await turn.beforeItEnds(w)
      expectHeld(w, source)

      await turnEnded(w)
      expectWrittenOnce(w, paths, source)

      await w.clock.advance(QUIET_MS + 4 * WATCH_MS)
      expectWrittenOnce(w, paths, source)
    })
  }

  test(`${source}: claimed between turns, the message goes in at once`, async ($, on) => {
    const w = world($, on)
    const { paths, claim } = await replying[source](w)

    await w.turnStarts('Carry on.')
    await turnEnded(w)
    await claim()
    await w.clock.settle()
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
    expect(kindsIn(w, paths)).toEqual(['ask'])

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
  expect(await ui.find({ key: TAKE_BACK, text: TAKE_BACK_LABEL }), 'its take-back').toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' }), 'its reply, on its way').toBeDefined()
  expect(await ui.find({ key: `unready:${key}` }), 'frozen while it goes').toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeUndefined()
  expect(sendingIn(w, paths), 'said in the heartbeat').toBeDefined()
  expect(w.state.board?.waiting).toBe(0)
  expect(await asksOnBand(w, '0 asks'), 'none on the band').toBeDefined()

  await ui.press({ key: TAKE_BACK })

  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)
  expect(await ui.find({ type: 'Text', text: HELD })).toBeUndefined()
  expect(await ui.find({ key: TAKE_BACK })).toBeUndefined()
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
  expect(kindsIn(w, paths)).toEqual(['ask'])
})

test("send: held while Claude's turn only waits on its background work, Ready to send says so, wrapped beside its take-back; Claude at work again, it waits for the turn to end; done again, it says so again; that work ended, it waits for the turn to end, and goes as the turn ends, once", async ($, on) => {
  const w = world($, on)
  const { paths, ui, claim } = await replying.send(w)

  await waitsOnItsWork(w)
  await claim()

  expectHeld(w, 'send')
  expect(await sendingSays(ui)).toBe(WAITS_ON_WORK)
  expect((await sendingRows(ui)).length, 'wrapped, not cut short').toBeGreaterThan(1)
  expect(
    (await sendingRows(ui)).filter(row => row.length > BESIDE_TAKE_BACK),
    'each row fits beside the take-back',
  ).toEqual([])
  expect(await ui.find({ key: TAKE_BACK, text: TAKE_BACK_LABEL })).toBeDefined()

  await w.steps({ tools: ['Read'] })
  expect(await sendingSays(ui), 'a request of its own, as a delivery into the turn sets going').toBe(
    HELD,
  )

  await w.steps()
  expect(await sendingSays(ui)).toBe(WAITS_ON_WORK)

  await turnEnded(w, { agentId: AGENT })
  expect(await sendingSays(ui)).toBe(HELD)
  expectHeld(w, 'send')

  await turnEnded(w)
  expectWrittenOnce(w, paths, 'send')
})

test("send: Claude at work through a subagent of its own call, or done with nothing in the background, as every turn's end is, waits for the turn to end", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await w.steps()
  await claim()
  expect(await sendingSays(ui), 'nothing in the background').toBe(HELD)

  await w.steps({ tools: ['Agent'] })
  await w.steps({ agentId: AGENT })
  expect(await sendingSays(ui), 'its own call runs the subagent').toBe(HELD)
  expectHeld(w, 'send')
})

test("send: a loop no list of the session's agents names, as the engine's own forks carry, is no background work: Claude done, the send waits for the turn to end", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await w.steps({ agentId: FORK })
  await w.steps()
  await claim()
  await w.clock.settle()

  expect(await sendingSays(ui)).toBe(HELD)
  expect(w.state.activity?.loops, 'counted for nothing').toEqual([])
})

const UNHEARD_ENDS = {
  'lists it as killed': (w: World) => w.lists(AGENT, 'killed'),
  'lists it no more': (w: World) => w.lists(AGENT, null),
}

for (const [ended, unlists] of Object.entries(UNHEARD_ENDS)) {
  test(`send: a subagent whose end went unheard, the engine ${ended}, counts no more once Claude is done again: the send waits for the turn to end`, async ($, on) => {
    const w = world($, on)
    const { ui, claim } = await replying.send(w)

    await waitsOnItsWork(w)
    await claim()
    expect(await sendingSays(ui)).toBe(WAITS_ON_WORK)

    unlists(w)
    await w.steps({ tools: ['Read'] })
    await w.steps()
    await w.clock.settle()
    expect(await sendingSays(ui)).toBe(HELD)
    expect(w.state.activity?.loops).toEqual([])
  })
}

test("send: an answer to Claude's own request cut short as Lee stopped its turn, coming once the next turn runs, says nothing of that turn: the send waits for it to end", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)
  let answer = () => {}
  const until = new Promise<void>(resolve => {
    answer = resolve
  })

  w.lists(AGENT)
  await w.turnStarts('Carry on.')

  const late = w.steps({ until })

  await w.turnEnds({ isAborted: true })
  await w.turnStarts('Carry on.')
  await w.steps({ tools: ['Agent'] })
  await w.steps({ agentId: AGENT })
  await w.steps({ tools: ['Read'] })
  await claim()
  expect(await sendingSays(ui)).toBe(HELD)

  answer()
  await late
  await w.clock.settle()
  expect(await sendingSays(ui), 'Claude still at work').toBe(HELD)
  expect(w.state.activity?.isDone).toBeUndefined()
})

test("send: a request of Claude's own whose answer fails leaves Claude at work, not done: the send waits for the turn to end", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)

  await waitsOnItsWork(w)
  await claim()
  await w.steps({ fails: 'overloaded' }).catch(() => {})
  await w.clock.settle()

  expect(await sendingSays(ui)).toBe(HELD)
  expect(w.state.activity?.isDone).toBeUndefined()
})

test("send: whether Claude's turn only waits on its background work, changed, draws the board again of itself, nothing written but the window's own state", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)

  w.lists(AGENT)
  await w.turnStarts('Carry on.')
  await w.steps({ tools: ['Agent'] })
  await w.steps({ agentId: AGENT })
  await claim()
  await w.clock.settle()
  expect(await sendingSays(ui)).toBe(HELD)

  for (const [plan, says] of [
    [{}, WAITS_ON_WORK],
    [{ tools: ['Read'] }, HELD],
  ] as const) {
    const before = { writes: { ...w.writes }, redraws: w.redraws() }

    await w.steps(plan)
    await w.clock.settle()
    expect(await sendingSays(ui)).toBe(says)
    expect({ writes: w.writes, redraws: w.redraws() }, says).toEqual({
      writes: { ...before.writes, activity: (before.writes.activity ?? 0) + 1 },
      redraws: before.redraws + 1,
    })
  }
})

/**
 * Docked windows, tall and short, as wide as the tests' own and narrower,
 * and how a held send's line reads in each while Claude's turn only waits on
 * its background work: whole beside its take-back, whole over it, or short.
 */
const ROOMS = [
  { bodyRows: 30, bodyColumns: 56, says: WAITS_ON_WORK, isBelow: false },
  { bodyRows: 20, bodyColumns: 56, says: WAITS_ON_WORK_SHORT, isBelow: false },
  { bodyRows: 14, bodyColumns: 56, says: WAITS_ON_WORK_SHORT, isBelow: false },
  { bodyRows: 30, bodyColumns: 32, says: WAITS_ON_WORK, isBelow: true },
  { bodyRows: 30, bodyColumns: 26, says: WAITS_ON_WORK_SHORT, isBelow: false },
  { bodyRows: 40, bodyColumns: 26, says: WAITS_ON_WORK, isBelow: true },
  { bodyRows: 14, bodyColumns: 26, says: WAITS_ON_WORK_SHORT, isBelow: false },
]

test("send: held while Claude's turn only waits on its background work, Ready to send keeps to the rows a docked board gives it: its line whole where they hold it, its take-back under it where that takes fewer rows, else short; the list keeps rows of its own", async ($, on) => {
  const w = world($, on)
  const { ui, claim } = await replying.send(w)

  await waitsOnItsWork(w)
  await claim()

  for (const { bodyRows, bodyColumns, says, isBelow } of ROOMS) {
    const room = `${bodyColumns} across, ${bodyRows} down`

    await ui.redraw(docked(bodyRows, bodyColumns))

    const drawn = rowsOf(await ui.find({ key: 'ready' }))
    const list = await listRows(ui)

    expect(await sendingSays(ui), room).toBe(says)
    expect(drawn.length + BORDER, `${room}: Ready to send's rows`).toBeLessThanOrEqual(
      readyCap(bodyRows),
    )
    expect(list, `${room}: the list's rows`).toBeGreaterThan(0)
    expect(bodyRows - HEADER - list, `${room}: the rows Ready to send is given`).toBe(
      drawn.length + BORDER,
    )
    expect(
      drawn.some(row => row.trim() === TAKE_BACK_LABEL),
      `${room}: the take-back on a row of its own`,
    ).toBe(isBelow)
  }
})

test("send: taken back while Claude's turn only waits on its background work, its replies are back in Ready to send, and nothing goes as the turn ends", async ($, on) => {
  const w = world($, on)
  const { paths, ui, claim } = await replying.send(w)
  const queued = w.state.queue

  await waitsOnItsWork(w)
  await claim()
  await ui.press({ key: TAKE_BACK })

  expect(w.state.inFlight).toBeNull()
  expect(w.state.queue).toEqual(queued)
  expect(await sendingSays(ui)).toBe('')
  expect(await ui.find({ key: 'send' }), 'sent again').toBeDefined()

  await turnEnded(w, { agentId: AGENT })
  await turnEnded(w)
  expect(w.submitted).toEqual([])
  expect(kindsIn(w, paths)).toEqual(['ask'])
})

test('send: taken back, it can be sent again, held again while Claude is mid-turn, and goes as the turn ends', async ($, on) => {
  const w = world($, on)
  const { paths, ui } = await replying.send(w)

  await w.turnStarts('Carry on.')
  await ui.press({ key: 'send' })
  await ui.press({ key: TAKE_BACK })
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
  expect(await ui.find({ key: TAKE_BACK })).toBeDefined()

  const turn = w.holdPrompts()
  const ended = turnEnded(w)

  await turn.arrived
  expect(w.state.inFlight).toMatchObject({ isHeld: false, isTaken: false })
  expect(await ui.find({ key: TAKE_BACK })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: '⧗ Sending.' })).toBeDefined()
  expect(sendingIn(w, paths), 'still on its way').toBeDefined()

  turn.end()
  await ended
  await w.clock.settle()
  expectWrittenOnce(w, paths, 'send')
})

for (const [running, turn] of Object.entries(TURNS)) {
  test(`claimed while Claude's turn is ${running}, the turn's end landing before a take-back it raced: the take-back finds the send submitted and lets it be, and it is written down once`, async ($, on) => {
    const w = world($, on)
    const takingBack = writeDoor(on)
    const { paths, ui, claim } = await replying.send(w)

    await turn.starts(w)
    await claim()
    await turn.beforeItEnds(w)
    takingBack.hold(value => value === null)

    const pressed = ui.press({ key: TAKE_BACK })

    await takingBack.arrived

    const prompts = w.holdPrompts()
    const ended = turnEnded(w)

    await prompts.arrived
    takingBack.open()
    await w.clock.settle()
    expect(w.state.inFlight, 'still on its way').toMatchObject({ isHeld: false, isTaken: false })

    prompts.end()
    await Promise.all([pressed, ended])
    await w.clock.settle()
    expectWrittenOnce(w, paths, 'send')
    expect(w.state.queue).toEqual([])
  })

  test(`claimed while Claude's turn is ${running}, a take-back landing before the turn's end it raced: the turn's end finds the send gone and submits nothing, its replies back in Ready to send`, async ($, on) => {
    const w = world($, on)
    const going = writeDoor(on)
    const { paths, ui, claim } = await replying.send(w)
    const queued = w.state.queue

    await turn.starts(w)
    await claim()
    await turn.beforeItEnds(w)
    going.hold(value => value?.isHeld === false)

    const ended = turnEnded(w)

    await going.arrived
    await ui.press({ key: TAKE_BACK })
    going.open()
    await ended
    await w.clock.advance(QUIET_MS + WATCH_MS)

    expect(w.submitted).toEqual([])
    expect(w.state.inFlight).toBeNull()
    expect(w.state.queue).toEqual(queued)
    expect(kindsIn(w, paths)).toEqual(['ask'])
    expect(w.state.board?.waiting).toBe(1)
  })
}

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
  expect(await ui.find({ key: TAKE_BACK }), 'still held').toBeDefined()

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
  expect(await ui.find({ key: TAKE_BACK }), 'still held').toBeDefined()

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
  expect(kindsIn(w, paths)).toEqual(WRITTEN.send)
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
    expect(kindsIn(w, paths)).toEqual(['ask'])
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
  expect(kindsIn(w, paths)).toEqual(['ask'])
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

for (const [running, turn] of Object.entries(TURNS)) {
  test(`inbox: a message held while Claude's turn is ${running} offers no take-back, nor any line, though the window holds it as it holds a send`, async ($, on) => {
    const w = world($, on)
    const { ui, claim } = await replying.inbox(w)

    await turn.starts(w)
    await claim()

    expectHeld(w, 'inbox')
    expect(await ui.find({ key: TAKE_BACK })).toBeUndefined()
    expect(await sendingSays(ui)).toBe('')
  })
}

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
  expect(kindsIn(w, paths)).toEqual(['ask'])
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
