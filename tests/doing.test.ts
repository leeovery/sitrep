import type { On } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import { HEARTBEAT_MS, metaText, parsePresence, sessionPaths, type SessionPaths } from '../core'
import { rewriteAt, STATE_MS } from '../hooks/doing'
import type { SitrepActivity, SitrepAttachment } from '../types'
import { META, T0, W1, W2 } from './support'
import { CONVERSATION, DASHBOARD, PROJECT, ROOT, startedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

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

/** A subagent's loop. */
const AGENT = 'a1b2c3d4'

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
  const w = world($, on)
  const { paths } = await w.begin()
  const allowed = { decision: { behavior: 'allow' as const } }

  w.answerRequests(allowed)
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

  const id = startedId(await w.call('start', DASHBOARD))
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

  pr.finish({ stdout: 'https://github.com/leeovery/sitrep/pull/8' })

  const checked = await $.tool.check({ tool: 'Bash', input: PR_CREATE, tool_use_id: 'toolu_9' })

  expect(started).toEqual({ turnId: 'turn-9' })
  expect((await pr.done).result).toEqual({ stdout: 'https://github.com/leeovery/sitrep/pull/8' })
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

  const noted = await w.call('note', { text: 'Drew round 1' })

  expect(String(noted.result)).toMatch(/^Logged note [0-9a-z]{4}\.$/)
  expect(w.state.board?.log.map(line => line.text)).toEqual(['Drew round 1'])
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
