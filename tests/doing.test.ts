import type { On } from 'claude-code'
import { expect, test, tier } from './kit'
import { HEARTBEAT_MS, metaText, parsePresence, sessionPaths, type SessionPaths } from '../core'
import { rewriteAt, STATE_MS } from '../hooks/doing'
import type { SitrepActivity, SitrepAttachment } from '../types'
import { AGENT, HELP_DESK, META, PROJECT, ROOT, T0, W1, W2 } from './data'
import { CONVERSATION, startedId, world, type World } from './world'

tier('user')

/** The state the window's heartbeat on a session says, as a reader reads it. */
const stateIn = (w: World, paths: SessionPaths) =>
  parsePresence(w.text(paths.heartbeat(W1)), W1)?.state

/** How many times the window has written its heartbeat on a session. */
const beats = (w: World, paths: SessionPaths) =>
  w.written.filter(path => path === paths.heartbeat(W1)).length

/** Lets every rewrite the window has put off land: past STATE_MS, and the event loop settled. */
const later = (w: World) => w.clock.advance(STATE_MS)

const BUN_TEST = { command: 'bun test', description: 'Run the tests' }

const PR_CREATE = { command: 'gh pr create --fill', description: 'Open the pull request' }

const QUESTIONS = {
  questions: [
    {
      question: 'Which edge should the notch sit on?',
      header: 'Edge',
      options: [
        { label: 'Left', description: 'As the prototype has it' },
        { label: 'Right', description: 'Nearer the menu bar item' },
      ],
      multiSelect: false,
    },
    {
      question: 'Should it swell twice?',
      header: 'Swell',
      options: [
        { label: 'Twice', description: 'As Lee set it' },
        { label: 'Once', description: 'As the prototype does' },
      ],
      multiSelect: false,
    },
  ],
}

const REVIEW = { description: 'Review the diff', prompt: 'Review the change on this branch.' }

test('a window that has had no turn yet is your turn since it attached', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 })
})

test('a turn starting is working since it began, written into the heartbeat at once, not on the beat', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.clock.advance(5_000)
  await w.turnStarts('Carry on.')
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 + 5_000 })
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.seenAt).toBe(T0 + 5_000)
})

test("while a tool runs, working carries it and its subject, and the time is still the turn's", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.advance(2_000)

  const bash = w.calls('Bash', BUN_TEST)

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Bash', subject: 'bun test' },
  })

  bash.finish()
  await bash.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
})

test('of several tools running at once, working carries the latest started, then the one still running', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')

  const first = w.calls('Read', { file_path: '/repo/DESIGN.md' })
  const second = w.calls('Read', { file_path: '/repo/core/state.ts' })

  await later(w)

  expect(stateIn(w, paths)?.tool).toEqual({ name: 'Read', subject: '/repo/core/state.ts' })

  second.finish()
  await second.done
  await later(w)

  expect(stateIn(w, paths)?.tool).toEqual({ name: 'Read', subject: '/repo/DESIGN.md' })

  first.finish()
  await first.done
})

test('the dialog shown for a call put to Lee is a permission prompt with its tool and subject, since it showed; once answered and run, working again', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Open the PR.')
  await w.clock.advance(3_000)

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + 3_000,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  })

  pr.finish()
  await pr.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
})

for (const verdict of ['allow', 'deny'] as const) {
  test(`a check that gives "${verdict}" puts nothing to Lee`, async ($, on) => {
    const w = world($, on)
    const { paths } = await w.begin()

    await w.turnStarts('Carry on.')

    const bash = w.calls('Bash', BUN_TEST, { verdict })

    await later(w)

    expect(stateIn(w, paths)?.is).toBe('working')

    bash.finish()
    await bash.done
  })
}

test("a check that puts the call to the mode's decider stops nothing, as when auto mode's classifier approves it: working throughout, never a prompt", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Run the tests.')

  const bash = w.calls('Bash', BUN_TEST, { verdict: 'ask' })
  const said = new Set<string | undefined>()

  for (const step of [1, 2, 3]) {
    await w.clock.advance(STATE_MS * step)
    said.add(stateIn(w, paths)?.is)
  }

  bash.finish()
  await bash.done
  await later(w)

  expect([...said]).toEqual(['working'])
  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
  expect(w.logs.filter(line => line.startsWith('sitrep: stop '))).toEqual([])
})

test('of two calls put to Lee with one tool, the dialog stops the window on the one whose input it is for', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Ship it.')

  const push = w.calls('Bash', { command: 'git push' }, { verdict: 'ask' })
  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  expect(stateIn(w, paths)?.tool).toEqual({ name: 'Bash', subject: 'gh pr create --fill' })

  pr.finish()
  push.finish()
  await Promise.all([pr.done, push.done])
})

test('a dialog matching no call put to Lee is logged and stops nothing', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')

  const answer = await $.classic.PermissionRequest({
    tool_name: 'Bash',
    tool_input: { command: 'rm -rf build' },
  })

  await later(w)

  expect(answer).toEqual({})
  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
  expect(w.logs).toEqual([
    'sitrep: a permission dialog for Bash matched no call put to Lee: no stop',
  ])
})

test('a permission request a settings hook beneath answers shows no dialog, so it stops nothing, and its answer goes on as it came', async ($, on) => {
  const allowed = { decision: { behavior: 'allow' as const } }

  // A settings hook beneath, registered before the world's own so it is outermost: it answers in the dialog's place.
  on('classic.PermissionRequest', { tool_name: 'Bash' }, () => allowed)

  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Open the PR.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  expect(stateIn(w, paths)?.is).toBe('working')
  expect(await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: PR_CREATE })).toEqual(
    allowed,
  )

  pr.finish()
  await pr.done
})

test('each stop begun and ended goes to the debug log, with its tool and how it was matched', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.turnStarts('Open the PR.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)
  pr.finish()
  await pr.done

  const asked = w.calls('AskUserQuestion', QUESTIONS)

  await later(w)
  await w.turnEnds()
  asked.finish()
  await asked.done

  expect(w.logs).toEqual([
    expect.stringMatching(
      /^sitrep: stop begun, call \S+: a permission prompt for Bash: gh pr create --fill; its dialog shown, matched by tool, loop and input to the oldest call put to Lee$/,
    ),
    expect.stringMatching(
      /^sitrep: stop ended, call \S+: a permission prompt for Bash: gh pr create --fill; its call settled$/,
    ),
    expect.stringMatching(
      /^sitrep: stop begun, call \S+: a question: Which edge should the notch sit on\?; its call started$/,
    ),
    expect.stringMatching(
      /^sitrep: stop ended, call \S+: a question: Which edge should the notch sit on\?; the turn ended$/,
    ),
  ])
})

test('a query of the check, which is no call, puts nothing to Lee', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const asked = await $.tool.check({ tool: 'Bash', input: PR_CREATE })

  await later(w)

  expect(asked.decision).toBe('allow')
  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 })
})

test('a refused permission prompt ends the stop as an answered one does', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Open the PR.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)
  pr.refuse('Lee said no.')

  expect((await pr.done).deny).toBe('Lee said no.')

  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
})

test("Claude asking a question is a question with the first one's text and how many there are; once answered, working again", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Settle the edge.')
  await w.clock.advance(4_000)

  const asked = w.calls('AskUserQuestion', QUESTIONS, { verdict: 'ask' })

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'question',
    since: T0 + 4_000,
    question: { text: 'Which edge should the notch sit on?', count: 2 },
  })

  asked.finish()
  await asked.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
})

test('the turn ending is your turn since it ended', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.advance(20_000)
  await w.turnEnds()
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 20_000 })
})

test('Lee stopping the turn at a permission prompt is your turn since then, and the refused call that follows changes nothing', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Open the PR.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await w.clock.advance(6_000)
  await w.turnEnds({ isAborted: true })
  pr.refuse('The user stopped the turn.')
  await pr.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 6_000 })
})

test("a subagent's turns neither start nor end the window's, and its tools do not show: the agent's does", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it.')

  const agent = w.calls('Agent', REVIEW)

  await w.agentRunStarts(AGENT)

  const inside = w.calls('Read', { file_path: '/repo/core/state.ts' }, { agentId: AGENT })

  await w.turnEnds({ agentId: AGENT })
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Agent', subject: 'Review the diff' },
  })

  inside.finish()
  agent.finish()
  await Promise.all([inside.done, agent.done])
})

test("a subagent's run starting mid-turn starts no turn of the window's: its own tools, candidates and stops stand, and the turn's time", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it.')
  await w.clock.advance(1_000)

  const agent = w.calls('Agent', REVIEW)
  const tests = w.calls('Bash', BUN_TEST, { verdict: 'ask' })
  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  const heard = w.state.activity

  expect(
    [heard?.tools.length, heard?.asked.length, heard?.stops.length],
    'tools, a candidate and a stop of its own',
  ).toEqual([3, 1, 1])

  await w.clock.advance(1_000)
  await w.agentRunStarts(AGENT)
  await later(w)

  expect(w.state.activity).toEqual(heard)
  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + 1_000,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  })

  for (const call of [agent, tests, pr]) {
    call.finish()
    await call.done
  }
})

test("a subagent's run starting and ending between the window's turns changes nothing the window heard: your turn still, since the turn ended", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await later(w)

  const heard = { activity: w.state.activity, writes: w.writes.activity }

  await w.clock.advance(60_000)
  await w.agentRunStarts(AGENT)
  await w.turnEnds({ agentId: AGENT })
  await later(w)

  expect({ activity: w.state.activity, writes: w.writes.activity }).toEqual(heard)
  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })
})

test("a subagent's permission prompt and its question stop the window on Lee, and once answered it works on with the agent", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it.')

  const agent = w.calls('Agent', REVIEW)

  await w.clock.advance(1_000)

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true, agentId: AGENT })

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + 1_000,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  })

  pr.finish()
  await pr.done

  const asked = w.calls('AskUserQuestion', QUESTIONS, { agentId: AGENT })

  await later(w)

  expect(stateIn(w, paths)?.is).toBe('question')

  asked.finish()
  await asked.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Agent', subject: 'Review the diff' },
  })

  agent.finish()
  await agent.done
})

test('of two calls waiting on Lee, the older shows, then the other once it is answered', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await w.clock.advance(STATE_MS)

  const push = w.calls(
    'Bash',
    { command: 'git push' },
    { verdict: 'ask', isShown: true, agentId: AGENT },
  )

  await later(w)

  expect(stateIn(w, paths)?.tool?.subject).toBe('gh pr create --fill')

  pr.finish()
  await pr.done
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + STATE_MS,
    tool: { name: 'Bash', subject: 'git push' },
  })

  push.finish()
  await push.done
})

test('a burst of quick calls is written once a second at most, the state as it stands then, and a change after a quiet second at once', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await later(w)
  await w.turnStarts('Read it all.')
  await w.clock.settle()

  const before = beats(w, paths)

  for (const n of [1, 2, 3, 4, 5, 6, 7, 8]) {
    const read = w.calls('Read', { file_path: `/repo/file-${n}.ts` })

    read.finish()
    await read.done
  }

  const last = w.calls('Read', { file_path: '/repo/last.ts' })

  await w.clock.advance(STATE_MS - 1)

  expect(beats(w, paths), 'none within the second').toBe(before)

  await w.clock.advance(1)

  expect(beats(w, paths), 'one once it is up').toBe(before + 1)
  expect(stateIn(w, paths)?.tool).toEqual({ name: 'Read', subject: '/repo/last.ts' })

  await w.clock.advance(5_000)
  last.finish()
  await last.done
  await w.clock.settle()

  expect(beats(w, paths), 'at once after a quiet second').toBe(before + 2)
  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 + STATE_MS })
})

test('a change that comes back to what the heartbeat says writes nothing', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await later(w)
  await w.turnStarts('Carry on.')
  await w.clock.settle()

  const before = beats(w, paths)
  const read = w.calls('Read', { file_path: '/repo/DESIGN.md' })

  read.finish()
  await read.done
  await later(w)

  expect(beats(w, paths)).toBe(before)
})

test('the beat says the state as it stands, every 30 seconds as before', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')

  const bash = w.calls('Bash', BUN_TEST)

  await w.clock.advance(HEARTBEAT_MS)

  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)).toMatchObject({
    seenAt: T0 + HEARTBEAT_MS,
    state: { is: 'working', since: T0, tool: { name: 'Bash', subject: 'bun test' } },
  })

  bash.finish()
  await bash.done
})

test('a window holding no session writes no heartbeat, but keeps its state, and attaching mid-turn writes it as it stands', async ($, on) => {
  const w = world($, on)

  await $.session.start(CONVERSATION)
  await w.turnStarts('Build the panel.')

  const bash = w.calls('Bash', BUN_TEST)

  await w.clock.advance(10_000)

  expect(w.written).toEqual([])

  const id = startedId(await w.call('start', HELP_DESK))
  const paths = sessionPaths(ROOT, PROJECT.key, id)

  expect(stateIn(w, paths)).toMatchObject({ is: 'working', since: T0 })

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Bash', subject: 'bun test' },
  })

  bash.finish()
  await bash.done
})

test('letting go ends the state: the heartbeat that says so says none', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.settle()
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })

  const left = JSON.parse(w.text(paths.heartbeat(W1)))

  expect(left.leftAt).toBe(T0)
  expect(left).not.toHaveProperty('state')
})

/** What an earlier load left in `$.state`. */
type Kept = { attachment?: SitrepAttachment; activity?: SitrepActivity }

/**
 * What a reload finds in `$.state`: each value an earlier load left there,
 * until this load writes it, read at version 0, as never written, so this
 * load's first write lands.
 */
const keptInState = (on: On, kept: Kept) => {
  const written = new Set<string>()

  on('state.set', { plugin: 'sitrep' }, ($, e, next) => {
    written.add(e.key)

    return next(e)
  })
  on('state.get', { plugin: 'sitrep' }, ($, e, next) => {
    const value = kept[e.key as keyof Kept]

    return value === undefined || written.has(e.key)
      ? next(e)
      : ({ value: { value, version: 0 } } as never)
  })
}

/** The session an earlier load held, ATTACHED, filed as it left it: its paths. */
const heldBefore = (w: World) => {
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)

  w.put(paths.meta, metaText(META))

  return paths
}

const ATTACHED: SitrepAttachment = {
  project: PROJECT.key,
  session: META.id,
  writer: W1,
  attachedAt: T0,
}

test('after a reload mid-turn, the window says the state $.state kept, and goes on from it', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = heldBefore(w)

  keptInState(on, {
    attachment: ATTACHED,
    activity: {
      turnAt: T0 + 10_000,
      tools: [{ call: 'toolu_kept', tool: { name: 'Bash', subject: 'bun test' } }],
      asked: [],
      stops: [],
      watches: [],
    },
  })
  await $.session.start(CONVERSATION)

  expect(stateIn(w, paths)).toEqual({
    is: 'working',
    since: T0 + 10_000,
    tool: { name: 'Bash', subject: 'bun test' },
  })

  await w.turnEnds()
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 60_000 })
})

test('what an earlier load kept in another shape is read field by field, and the window goes on from what reads', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = heldBefore(w)
  const older = { turnAt: T0 + 10_000, tools: [{ call: 'toolu_kept', tool: { name: 'Bash' } }] }

  keptInState(on, { attachment: ATTACHED, activity: older as SitrepActivity })
  await $.session.start(CONVERSATION)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 + 10_000, tool: { name: 'Bash' } })

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  expect(stateIn(w, paths)?.is).toBe('permission')

  pr.finish('ok')
  await pr.done
  await w.turnEnds()
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 60_000 + STATE_MS })
  expect(w.logs.filter(line => line.includes('failed'))).toEqual([])
})

test('a new process starts with nothing heard: your turn since it attached, until its next event', async ($, on) => {
  const w = world($, on, { now: T0 + 60_000 })
  const paths = heldBefore(w)

  keptInState(on, { attachment: ATTACHED })
  await $.session.start(CONVERSATION)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 })

  await w.turnStarts('Carry on.')
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 + 60_000 })
})

test('a failure keeping the state in $.state is logged, the turn, the call and its check go on as they came, and the heartbeat still says it', async ($, on) => {
  let isFull = false

  on('state.set', { plugin: 'sitrep', key: 'activity' }, ($, e, next) =>
    isFull ? { deny: 'the store is full' } : next(e),
  )

  const w = world($, on)
  const { paths } = await w.begin()

  isFull = true
  await later(w)

  const started = await $.turn.start({ text: 'Open the PR.', turnId: 'turn-9' })
  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true })

  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + STATE_MS,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  })

  pr.finish({ stdout: 'https://github.com/me/sitrep/pull/8' })

  const checked = await $.tool.check({ tool: 'Bash', input: PR_CREATE, tool_use_id: 'toolu_9' })

  expect(started).toEqual({ turnId: 'turn-9' })
  expect((await pr.done).result).toEqual({ stdout: 'https://github.com/me/sitrep/pull/8' })
  expect(checked.decision).toBe('ask')
  expect(w.logs.length).toBeGreaterThan(0)
  expect(
    w.logs.filter(
      line =>
        !line.startsWith("sitrep: recording the window's state failed") &&
        !line.startsWith('sitrep: stop '),
    ),
  ).toEqual([])
})

test('a heartbeat that cannot be written for the state is logged, and the call goes on as it came', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  w.refuseWrites(path => path === paths.heartbeat(W1))
  await w.turnStarts('Carry on.')

  const bash = w.calls('Bash', BUN_TEST, { verdict: 'ask' })

  await later(w)
  bash.finish('ok')

  expect((await bash.done).result).toBe('ok')
  expect(w.logs).toContainEqual(
    expect.stringContaining("sitrep: writing the window's state failed"),
  )
})

test("sitrep's own tools answer as ever under the hook over every call", async ($, on) => {
  const w = world($, on)

  await w.begin()
  await w.turnStarts('Carry on.')

  const parked = await w.call('park', { title: 'Drew round 1' })

  expect(String(parked.result)).toMatch(/^Parked [0-9a-z]{4}\.$/)
  expect(w.state.board?.parked.map(item => item.title)).toEqual(['Drew round 1'])
})

test("a background subagent's open prompt outlives the window's turns: it stops the window until it is answered, or that subagent's turn ends", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Spawn the reviewers.')
  await w.clock.advance(1_000)

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', isShown: true, agentId: AGENT })
  const permission = {
    is: 'permission',
    since: T0 + 1_000,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  }

  await later(w)

  expect(stateIn(w, paths)).toEqual(permission)

  await w.turnEnds()
  await later(w)

  expect(stateIn(w, paths), "the window's turn ending").toEqual(permission)

  await w.turnStarts('')
  await later(w)

  expect(stateIn(w, paths), 'another agent finishing starts a turn').toEqual(permission)

  await w.turnEnds({ agentId: AGENT })
  await later(w)

  expect(stateIn(w, paths)?.is, 'its own turn ending').toBe('working')

  pr.refuse('The agent was stopped.')
  await pr.done
})

test("a subagent's call put to Lee just before the window's turn ends is still the one its dialog is for", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Spawn the reviewer.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask', agentId: AGENT })

  await w.clock.settle()
  await w.turnEnds()
  await w.clock.advance(2_000)
  await $.classic.PermissionRequest({
    tool_name: 'Bash',
    tool_input: { command: PR_CREATE.command },
    agent_id: AGENT,
  })
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'permission',
    since: T0 + 2_000,
    tool: { name: 'Bash', subject: 'gh pr create --fill' },
  })

  pr.finish()
  await pr.done
})

test("a dialog whose input lacks an argument the check carried, or carries one it lacked, is still the call's", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Ship it.')

  const pr = w.calls('Bash', PR_CREATE, { verdict: 'ask' })
  const push = w.calls('Bash', { command: 'git push' }, { verdict: 'ask' })

  await w.clock.settle()
  await $.classic.PermissionRequest({
    tool_name: 'Bash',
    tool_input: { command: PR_CREATE.command },
  })
  await $.classic.PermissionRequest({
    tool_name: 'Bash',
    tool_input: { command: 'git push', description: 'Push the branch', timeout: 60_000 },
  })
  await later(w)

  expect(stateIn(w, paths)?.tool?.subject).toBe('gh pr create --fill')
  expect(w.logs.filter(line => line.includes('matched no call'))).toEqual([])

  pr.finish()
  await pr.done
  await later(w)

  expect(stateIn(w, paths)?.tool?.subject).toBe('git push')

  push.finish()
  await push.done
})

test('a change is written at once, or once a second has passed since the last; while a rewrite waits, not again until a second past its time, when it is taken never to have fired', () => {
  expect(rewriteAt(T0, -Infinity)).toBe(T0)
  expect(rewriteAt(T0 + STATE_MS, T0)).toBe(T0 + STATE_MS)
  expect(rewriteAt(T0 + 300, T0)).toBe(T0 + STATE_MS)
  expect(rewriteAt(T0 + 300, T0, T0 + STATE_MS)).toBeUndefined()
  expect(rewriteAt(T0 + 2 * STATE_MS, T0, T0 + STATE_MS)).toBeUndefined()
  expect(rewriteAt(T0 + 2 * STATE_MS + 1, T0, T0 + STATE_MS)).toBe(T0 + 2 * STATE_MS + 1)
})

test('the beat says the state as it stands, so a state write that failed is put right within a beat', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  w.refuseWrites(path => path === paths.heartbeat(W1))
  await w.turnStarts('Carry on.')
  await later(w)
  w.refuseWrites()

  expect(stateIn(w, paths)?.is).toBe('yourTurn')

  await w.clock.advance(HEARTBEAT_MS)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })
})

test("a new conversation starts with nothing heard: after a /clear, your turn since it attaches, not since the last conversation's turn", async ($, on) => {
  const w = world($, on)
  const { id } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.advance(5_000)
  await w.turnEnds()
  await $.session.end({ reason: 'clear', sessionId: W1, resume: { id: W1 } })
  w.become({ conversation: W2 })
  await w.clock.advance(60_000)
  await w.call('join', { session: id })

  const joined = sessionPaths(ROOT, PROJECT.key, id).heartbeat(W2)

  expect(parsePresence(w.text(joined), W2)?.state).toEqual({
    is: 'yourTurn',
    since: T0 + 65_000,
  })
})

/** A background agent, as a Stop lists it. */
const REVIEWING = {
  id: 'a1b2',
  type: 'subagent',
  status: 'running',
  description: 'Review the diff',
  agent_type: 'general-purpose',
}

/** What the window is on, once its turn has stopped leaving REVIEWING running. */
const ON_ITS_WORK = {
  is: 'onItsWork',
  since: T0 + 9_000,
  work: { agents: { count: 1, first: 'Review the diff' } },
}

test("a Stop listing a background agent before the turn's end: working until the end, then on its own work since then", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.stops({ background_tasks: [REVIEWING], session_crons: [] })
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: T0 })

  await w.turnEnds()
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual(ON_ITS_WORK)
})

test("a background subagent woken after the window's turn, its run starting and ending, leaves the window on its own work, never working", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.stops({ background_tasks: [REVIEWING], session_crons: [] })
  await w.turnEnds()
  await later(w)

  expect(stateIn(w, paths)).toEqual(ON_ITS_WORK)

  await w.clock.advance(60_000)
  await w.agentRunStarts(AGENT)
  await later(w)

  expect(stateIn(w, paths), 'its run started').toEqual(ON_ITS_WORK)

  await w.turnEnds({ agentId: AGENT })
  await later(w)

  expect(stateIn(w, paths), 'its run ended').toEqual(ON_ITS_WORK)
})

test("a Stop after the turn's end turns your turn to on its own work, and the heartbeat says so", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })

  const before = beats(w, paths)

  await w.stops({ background_tasks: [REVIEWING], session_crons: [] })
  await later(w)

  expect(stateIn(w, paths)).toEqual(ON_ITS_WORK)
  expect(beats(w, paths)).toBe(before + 1)
})

test('a Stop the settings hooks beneath block goes on with the turn: nothing pending is heard, and its answer goes on as it came', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const block = { block: 'The tests are still failing: fix them first.' }

  w.answerStops(block)
  await w.turnStarts('Fix the tests.')
  await w.clock.advance(9_000)

  expect(await w.stops({ background_tasks: [REVIEWING] })).toEqual(block)

  await w.turnEnds()
  await w.clock.settle()

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })
  expect(w.logs).toContain(
    'sitrep: a settings hook blocked the Stop, so the turn goes on: nothing pending heard',
  )
})

test("a Stop that blocks yet stops the session all the same is the turn's end: what it lists is heard", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  w.answerStops({ block: 'Keep going.', preventContinuation: true })
  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.stops({ background_tasks: [REVIEWING] })
  await later(w)

  expect(stateIn(w, paths)).toEqual(ON_ITS_WORK)
})

test("a Stop saying a subagent's id is not the window's, and changes nothing", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.stops({ background_tasks: [REVIEWING], agent_id: AGENT })
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })
})

test("the latest Stop's list stands, an empty one clearing it; the next turn's start clears it, as the agent's end wakes the window, and a turn stopped with Esc, which lists nothing, is your turn", async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  await w.turnStarts('Review it in the background.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.stops({ background_tasks: [REVIEWING] })
  await w.stops({ background_tasks: [], session_crons: [] })
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })

  await w.stops({ background_tasks: [REVIEWING] })
  await later(w)

  expect(stateIn(w, paths)).toEqual(ON_ITS_WORK)

  await w.clock.advance(60_000)

  const woke = w.clock.now()

  await w.turnStarts('')
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'working', since: woke })

  await w.turnEnds({ isAborted: true })
  await later(w)

  expect(stateIn(w, paths)?.is).toBe('yourTurn')
})

test('a monitor the turn started counts as one, though its Stop lists it as a shell; a persistent one never ends, so it counts for nothing', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const watch = (description: string, command: string) =>
    w.calls('Monitor', { description, timeout_ms: 300_000, command })
  const listed = (id: string, description: string, command: string) => ({
    id,
    type: 'shell',
    status: 'running',
    description,
    command,
  })
  const every = listed('bm1', 'Every deploy', 'gh run watch --exit-status')
  const one = listed('bm2', 'This deploy', 'gh run watch 42 --exit-status')

  await w.turnStarts('Watch the deploys.')

  const standing = watch(every.description, every.command)

  standing.finish({ taskId: every.id, timeoutMs: 0, persistent: true })
  await standing.done

  const once = watch(one.description, one.command)

  once.finish({ taskId: one.id, timeoutMs: 300_000 })
  await once.done
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.stops({ background_tasks: [every, one] })
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'onItsWork',
    since: T0 + 9_000,
    work: { monitors: { count: 1, first: 'This deploy' } },
  })

  await w.stops({ background_tasks: [every] })
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })
})

test('a recurring cron never ends and counts for nothing; a one-off wake puts the window on its own work until it is due', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  // The mod reads the clock across awaits, after `inZone` would have put the real `Date`
  // back, so this world test runs in the Mac's own zone, and writes the wake's schedule in it.
  const due = new Date(new Date(T0 + 30 * 60_000).setSeconds(0, 0))
  const wake = {
    id: 'c1',
    schedule: `${due.getMinutes()} ${due.getHours()} * * *`,
    recurring: false,
    prompt: 'Check the build',
  }
  const loop = { id: 'c2', schedule: '*/10 * * * *', recurring: true, prompt: '/loop check' }

  await w.turnStarts('Check the build in half an hour.')
  await w.clock.advance(9_000)
  await w.turnEnds()
  await w.stops({ background_tasks: [], session_crons: [loop] })
  await later(w)

  expect(stateIn(w, paths)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })

  await w.stops({ background_tasks: [], session_crons: [loop, wake] })
  await later(w)

  expect(stateIn(w, paths)).toEqual({
    is: 'onItsWork',
    since: T0 + 9_000,
    work: { wakes: { count: 1, at: due.getTime() } },
  })
})
