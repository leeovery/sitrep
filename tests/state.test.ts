import { expect, test } from 'claude-code/testing'
import {
  agentTurnEnded,
  attach,
  digestOf,
  digestsOf,
  heartbeat,
  jsonOf,
  leave,
  parseActivity,
  parsePresence,
  permissionShown,
  presenceText,
  QUIET,
  questionShown,
  SHOWN_LENGTH,
  stateOf,
  toolAsked,
  toolEnded,
  toolShown,
  toolStarted,
  turnEnded,
  turnStarted,
  turnStopped,
  wakeAt,
  watchOf,
  workOf,
  type Activity,
  type Pending,
  type PendingTask,
  type ToolCall,
  type WindowState,
} from '../core'
import { T0, W1 } from './support'

const PERMISSION: WindowState = {
  is: 'permission',
  since: T0 + 5_000,
  tool: { name: 'Bash', subject: 'gh pr create' },
}

/** A heartbeat file holding `state` as given, its times good. */
const fileWith = (state: unknown) =>
  JSON.stringify({ writer: W1, attachedAt: T0, seenAt: T0, state })

const stateRead = (state: unknown) => parsePresence(fileWith(state), W1)?.state

const bash = (id: string, command: string, agentId?: string): ToolCall => ({
  id,
  tool: 'Bash',
  input: { command },
  agentId,
})

const question = (id: string, agentId?: string): ToolCall => ({
  id,
  tool: 'AskUserQuestion',
  input: { questions: [{ question: 'Left or right?' }, { question: 'Once or twice?' }] },
  agentId,
})

/** A turn running since T0, with the changes given applied in order, each at its own time. */
const during = (...changes: ((activity: Activity) => Activity)[]) =>
  changes.reduce((activity, change) => change(activity), turnStarted(QUIET, T0))

test("each file tool's subject is its path, Bash's its command, a search's its pattern, a fetch's its URL, an agent's its description", () => {
  for (const [tool, input, subject] of [
    ['Read', { file_path: '/repo/DESIGN.md', offset: 10 }, '/repo/DESIGN.md'],
    [
      'Edit',
      { file_path: '/repo/core/state.ts', old_string: 'a', new_string: 'b' },
      '/repo/core/state.ts',
    ],
    ['Write', { file_path: '/repo/core/subject.ts', content: '…' }, '/repo/core/subject.ts'],
    ['NotebookEdit', { notebook_path: '/repo/look.ipynb', new_source: 'x' }, '/repo/look.ipynb'],
    ['Bash', { command: 'gh pr create', description: 'Open the PR' }, 'gh pr create'],
    ['Grep', { pattern: 'stateOf', path: '/repo' }, 'stateOf'],
    ['Glob', { pattern: '**/*.ts' }, '**/*.ts'],
    ['WebFetch', { url: 'https://example.com/a', prompt: 'Sum it up' }, 'https://example.com/a'],
    ['WebSearch', { query: 'liquid glass notch' }, 'liquid glass notch'],
    ['Agent', { description: 'Review the diff', prompt: 'Review it.' }, 'Review the diff'],
  ] as const) {
    expect(toolShown(tool, input), tool).toEqual({ name: tool, subject })
  }
})

test('an MCP tool, and any tool without a subject, shows by its name alone', () => {
  expect(toolShown('mcp__sitrep__note', { text: 'Drew round 1' })).toEqual({
    name: 'mcp__sitrep__note',
  })
  expect(toolShown('TodoWrite', { todos: [] })).toEqual({ name: 'TodoWrite' })
  expect(toolShown('constructor', {})).toEqual({ name: 'constructor' })
})

test('a subject that is missing, empty or not text is left out, the name kept', () => {
  for (const input of [{}, { command: '' }, { command: '   ' }, { command: 7 }, null, 'ls']) {
    expect(toolShown('Bash', input), JSON.stringify(input)).toEqual({ name: 'Bash' })
  }
})

test('a subject is one line, and one too long is cut short with an ellipsis', () => {
  const long = 'x'.repeat(SHOWN_LENGTH + 50)

  expect(toolShown('Bash', { command: 'cd /repo &&\n  bun test\tcore' }).subject).toBe(
    'cd /repo && bun test core',
  )
  expect(toolShown('Bash', { command: 'x'.repeat(SHOWN_LENGTH) }).subject).toHaveLength(
    SHOWN_LENGTH,
  )
  expect(toolShown('Bash', { command: long }).subject).toBe(`${'x'.repeat(SHOWN_LENGTH - 1)}…`)
  expect(
    Array.from(toolShown('Bash', { command: '😀'.repeat(SHOWN_LENGTH + 1) }).subject ?? ''),
  ).toHaveLength(SHOWN_LENGTH)
})

test('a question shows its first question, one line, and how many there are', () => {
  expect(
    questionShown({
      questions: [{ question: 'Which edge\nshould it sit on?' }, { question: 'Twice?' }, {}],
    }),
  ).toEqual({ text: 'Which edge should it sit on?', count: 3 })
})

test('a question with no first question to show shows none', () => {
  for (const input of [
    {},
    { questions: [] },
    { questions: [{ header: 'Edge' }] },
    { questions: 'x' },
    null,
  ]) {
    expect(questionShown(input), JSON.stringify(input)).toBeUndefined()
  }
})

test('a window that has heard nothing is your turn since it attached; after a turn, since the turn ended', () => {
  expect(stateOf(QUIET, T0)).toEqual({ is: 'yourTurn', since: T0 })
  expect(stateOf(turnEnded(QUIET, T0 + 9_000), T0)).toEqual({ is: 'yourTurn', since: T0 + 9_000 })
})

test("a turn is working since it began, with its own loop's latest tool still running", () => {
  const two = during(
    activity => toolStarted(activity, bash('t1', 'bun test'), T0 + 1_000),
    activity =>
      toolStarted(activity, { id: 't2', tool: 'Read', input: { file_path: '/a' } }, T0 + 2_000),
  )

  expect(stateOf(turnStarted(QUIET, T0), T0 - 1)).toEqual({ is: 'working', since: T0 })
  expect(stateOf(two, T0)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Read', subject: '/a' },
  })
  expect(stateOf(toolEnded(two, 't2'), T0).tool).toEqual({ name: 'Bash', subject: 'bun test' })
  expect(stateOf(toolEnded(toolEnded(two, 't2'), 't1'), T0)).toEqual({ is: 'working', since: T0 })
})

test("a subagent's tool does not show", () => {
  const inside = during(activity => toolStarted(activity, bash('t1', 'ls', 'agent-1'), T0 + 1_000))

  expect(inside).toEqual(turnStarted(QUIET, T0))
})

/** A permission dialog about to show for Bash running `command`. */
const dialogFor = (command: string) => ({ tool: 'Bash', input: { command } })

test("a check that puts a call to the mode's decider stops nothing: the classifier may settle it", () => {
  const call = bash('t1', 'gh pr create')
  const asked = during(
    activity => toolStarted(activity, call, T0 + 1_000),
    activity => toolAsked(activity, call),
  )

  expect(stateOf(asked, T0)).toEqual({
    is: 'working',
    since: T0,
    tool: { name: 'Bash', subject: 'gh pr create' },
  })
  expect(asked.stops).toEqual([])
})

test("the dialog shown for a call put to Lee is a permission prompt since then, its own or a subagent's, and its end ends it", () => {
  for (const agentId of [undefined, 'agent-1']) {
    const call = bash('t1', 'gh pr create', agentId)
    const shown = during(
      activity => toolStarted(activity, call, T0 + 1_000),
      activity => toolAsked(activity, call),
      activity => permissionShown(activity, { ...dialogFor('gh pr create'), agentId }, T0 + 5_000),
    )

    expect(stateOf(shown, T0), String(agentId)).toEqual(PERMISSION)
    expect(shown.asked, String(agentId)).toEqual([])
    expect(stateOf(toolEnded(shown, 't1'), T0).is, String(agentId)).toBe('working')
  }
})

test('a dialog is matched to the call by its tool and an equal input, whatever order its keys come in', () => {
  const push = { id: 't1', tool: 'Bash', input: { command: 'git push', description: 'Push' } }
  const pr = { id: 't2', tool: 'Bash', input: { command: 'gh pr create', description: 'PR' } }
  const asked = during(
    activity => toolAsked(activity, push),
    activity => toolAsked(activity, pr),
  )
  const shown = permissionShown(
    asked,
    { tool: 'Bash', input: { description: 'PR', command: 'gh pr create' } },
    T0 + 5_000,
  )

  expect(shown.stops.map(stop => stop.call)).toEqual(['t2'])
  expect(shown.asked.map(each => each.call)).toEqual(['t1'])
})

test("of two calls put to Lee in one loop with one tool and one input, the dialog is the older one's, then the other's", () => {
  const asked = during(
    activity => toolAsked(activity, bash('t1', 'gh pr create')),
    activity => toolAsked(activity, bash('t2', 'gh pr create')),
  )
  const first = permissionShown(asked, dialogFor('gh pr create'), T0 + 5_000)
  const second = permissionShown(first, dialogFor('gh pr create'), T0 + 6_000)

  expect(first.stops.map(stop => stop.call)).toEqual(['t1'])
  expect(second.stops.map(stop => stop.call)).toEqual(['t1', 't2'])
})

test("a dialog is its own loop's: one saying no subagent takes only the window's own call, one saying a subagent only that subagent's", () => {
  const asked = during(
    activity => toolAsked(activity, bash('t1', 'gh pr create', 'agent-1')),
    activity => toolAsked(activity, bash('t2', 'gh pr create')),
    activity => toolAsked(activity, bash('t3', 'gh pr create', 'agent-2')),
  )
  const stopped = (agentId?: string) =>
    permissionShown(asked, { ...dialogFor('gh pr create'), agentId }, T0 + 5_000).stops

  expect(stopped()).toMatchObject([{ call: 't2', agentId: undefined }])
  expect(stopped('agent-1')).toMatchObject([{ call: 't1', agentId: 'agent-1' }])
  expect(stopped('agent-2')).toMatchObject([{ call: 't3', agentId: 'agent-2' }])
  expect(
    permissionShown(
      during(activity => toolAsked(activity, bash('t1', 'gh pr create', 'agent-1'))),
      dialogFor('gh pr create'),
      T0 + 5_000,
    ).stops,
    "the window's own dialog takes no subagent's call",
  ).toEqual([])
})

test('a dialog is for a call whose input carries arguments it lacks, and the reverse: only the arguments both carry are compared', () => {
  const bare = { id: 't1', tool: 'Bash', input: { command: 'gh pr create' } }
  const full = {
    id: 't2',
    tool: 'Bash',
    input: { command: 'git push', description: 'Push', timeout: 60_000 },
  }
  const asked = during(
    activity => toolAsked(activity, bare),
    activity => toolAsked(activity, full),
  )

  expect(
    permissionShown(
      asked,
      { tool: 'Bash', input: { command: 'gh pr create', description: 'PR', timeout: 5 } },
      T0 + 5_000,
    ).stops.map(stop => stop.call),
  ).toEqual(['t1'])
  expect(
    permissionShown(asked, dialogFor('git push'), T0 + 5_000).stops.map(stop => stop.call),
  ).toEqual(['t2'])
})

test('a dialog for no call put to Lee stops nothing: another tool, another loop, an argument both carry differing, none shared, or never asked', () => {
  const asked = during(activity => toolAsked(activity, bash('t1', 'gh pr create')))

  for (const request of [
    dialogFor('gh pr merge'),
    { tool: 'Write', input: { command: 'gh pr create' } },
    { ...dialogFor('gh pr create'), agentId: 'agent-2' },
    { tool: 'Bash', input: { timeout: 5 } },
    { tool: 'Bash', input: {} },
  ]) {
    expect(permissionShown(asked, request, T0 + 5_000), JSON.stringify(request)).toEqual(asked)
  }

  expect(permissionShown(turnStarted(QUIET, T0), dialogFor('ls'), T0 + 1)).toEqual(
    turnStarted(QUIET, T0),
  )
})

test('two inputs with no arguments at all are for each other', () => {
  const asked = during(activity =>
    toolAsked(activity, { id: 'p1', tool: 'ExitPlanMode', input: {} }),
  )

  expect(
    permissionShown(asked, { tool: 'ExitPlanMode', input: {} }, T0 + 1_000).stops,
  ).toMatchObject([{ call: 'p1', is: 'permission', tool: { name: 'ExitPlanMode' } }])
})

test("a candidate keeps each argument as a short digest, never the argument itself: a Write's whole file is a few characters", () => {
  const content = 'x'.repeat(100_000)
  const asked = during(activity =>
    toolAsked(activity, { id: 'w1', tool: 'Write', input: { file_path: '/repo/a.ts', content } }),
  )
  const [candidate] = asked.asked

  expect(Object.keys(candidate?.input ?? {})).toEqual(['file_path', 'content'])
  expect(Object.values(candidate?.input ?? {}).every(digest => digest.length <= 11)).toBe(true)
  expect(JSON.stringify(asked).length).toBeLessThan(200)
  expect(digestOf('a')).not.toBe(digestOf('b'))
  expect(digestsOf({ b: [2, 1], a: undefined })).toEqual({ b: digestOf(jsonOf([2, 1])) })
})

test("as JSON, inputs are equal whatever their keys' order and with a key left undefined; lists keep their order", () => {
  expect(jsonOf({ b: 1, a: { d: [1, 2], c: null } })).toBe(
    jsonOf({ a: { c: null, d: [1, 2] }, b: 1 }),
  )
  expect(jsonOf({ a: 1, b: undefined })).toBe(jsonOf({ a: 1 }))
  expect(jsonOf([1, 2])).not.toBe(jsonOf([2, 1]))
  expect(jsonOf(undefined)).toBe('')
})

test("a question is a question since it was asked, its own or a subagent's; its check and a dialog for it leave it a question", () => {
  for (const agentId of [undefined, 'agent-1']) {
    const call = question('q1', agentId)
    const asked = during(
      activity => toolStarted(activity, call, T0 + 3_000),
      activity => toolAsked(activity, call),
      activity =>
        permissionShown(activity, { tool: call.tool, input: call.input, agentId }, T0 + 3_001),
    )

    expect(stateOf(asked, T0), String(agentId)).toEqual({
      is: 'question',
      since: T0 + 3_000,
      question: { text: 'Left or right?', count: 2 },
    })
    expect(asked.stops, String(agentId)).toHaveLength(1)
    expect(stateOf(toolEnded(asked, 'q1'), T0), String(agentId)).toEqual({
      is: 'working',
      since: T0,
    })
  }
})

test('a question with nothing to show is a question all the same', () => {
  const asked = during(activity =>
    toolStarted(activity, { id: 'q1', tool: 'AskUserQuestion', input: {} }, T0 + 1_000),
  )

  expect(stateOf(asked, T0)).toEqual({ is: 'question', since: T0 + 1_000 })
})

test('of several calls waiting on Lee, the oldest shows', () => {
  const both = during(
    activity => toolAsked(activity, bash('t1', 'gh pr create')),
    activity => permissionShown(activity, dialogFor('gh pr create'), T0 + 5_000),
    activity => toolStarted(activity, question('q1'), T0 + 6_000),
  )

  expect(stateOf(both, T0)).toEqual(PERMISSION)
  expect(stateOf(toolEnded(both, 't1'), T0).is).toBe('question')
})

test('a call that settles before its dialog shows is no longer a candidate', () => {
  const settled = during(
    activity => toolAsked(activity, bash('t1', 'gh pr create')),
    activity => toolEnded(activity, 't1'),
  )

  expect(settled.asked).toEqual([])
  expect(permissionShown(settled, dialogFor('gh pr create'), T0 + 5_000).stops).toEqual([])
})

test("the window's turn starting or ending clears its own tools, candidates and stops, and keeps a subagent's", () => {
  const busy = during(
    activity => toolStarted(activity, bash('t1', 'bun test'), T0 + 1_000),
    activity => toolAsked(activity, bash('t2', 'gh pr create', 'agent-1')),
    activity => toolAsked(activity, bash('t3', 'git push')),
    activity => toolAsked(activity, bash('t4', 'ls', 'agent-1')),
    activity =>
      permissionShown(activity, { ...dialogFor('gh pr create'), agentId: 'agent-1' }, T0 + 2_000),
    activity => toolStarted(activity, question('q1'), T0 + 3_000),
  )
  const ended = turnEnded(busy, T0 + 9_000)
  const next = turnStarted(ended, T0 + 10_000)
  const theAgents = {
    asked: [expect.objectContaining({ call: 't4', agentId: 'agent-1' })],
    stops: [expect.objectContaining({ call: 't2', agentId: 'agent-1' })],
  }

  expect(busy.stops.map(stop => stop.call)).toEqual(['t2', 'q1'])
  expect(ended).toEqual({ endedAt: T0 + 9_000, tools: [], ...theAgents, watches: [] })
  expect(next).toEqual({ turnAt: T0 + 10_000, tools: [], ...theAgents, watches: [] })
  expect(stateOf(next, T0)).toEqual({ ...PERMISSION, since: T0 + 2_000 })
})

test("a subagent's turn ending clears what it left, though its calls were never heard to end, and nothing of another loop's", () => {
  const busy = during(
    activity => toolAsked(activity, bash('t1', 'gh pr create', 'agent-1')),
    activity =>
      permissionShown(activity, { ...dialogFor('gh pr create'), agentId: 'agent-1' }, T0 + 2_000),
    activity => toolAsked(activity, bash('t2', 'ls', 'agent-1')),
    activity => toolAsked(activity, bash('t3', 'git push', 'agent-2')),
    activity => toolStarted(activity, question('q1'), T0 + 3_000),
  )
  const ended = agentTurnEnded(busy, 'agent-1')

  expect(ended.asked.map(asked => asked.call)).toEqual(['t3'])
  expect(ended.stops.map(stop => stop.call)).toEqual(['q1'])
  expect(ended.turnAt).toBe(T0)
})

test('a heartbeat reads back with its state, through every beat; letting go drops it', () => {
  const beat = heartbeat(attach(W1, T0, { state: PERMISSION }), T0 + 30_000)
  const left = leave(beat, T0 + 40_000)

  expect(parsePresence(presenceText(beat), W1)?.state).toEqual(PERMISSION)
  expect(JSON.parse(presenceText(left))).not.toHaveProperty('state')
  expect(parsePresence(presenceText(left), W1)?.state).toBeUndefined()
})

test('a heartbeat written before windows said their state reads as it always did', () => {
  const read = parsePresence('{"writer":"w","attachedAt":1,"seenAt":2,"version":"0.1.0"}\n', W1)

  expect(read).toEqual({ writer: W1, attachedAt: 1, seenAt: 2, version: '0.1.0' })
  expect(read?.state).toBeUndefined()
})

test('a bad state, or one of a kind this reader does not know, is dropped and the heartbeat kept', () => {
  for (const state of [
    'working',
    5,
    null,
    [],
    {},
    { is: 'working' },
    { is: 'working', since: '1760000000000' },
    { is: 'asleep', since: T0 },
    { is: '', since: T0 },
  ]) {
    const read = parsePresence(fileWith(state), W1)

    expect(read, JSON.stringify(state)).toEqual({ writer: W1, attachedAt: T0, seenAt: T0 })
    expect(read?.state, JSON.stringify(state)).toBeUndefined()
  }
})

test('a bad tool or question of a state is dropped, the state kept, and keys it does not know ignored', () => {
  const working = { is: 'working', since: T0 }

  expect(stateRead({ ...working, tool: { name: 'Bash', subject: 'ls' }, mood: 'calm' })).toEqual({
    ...working,
    tool: { name: 'Bash', subject: 'ls' },
  })
  expect(stateRead({ ...working, tool: { name: 'Bash', subject: 7 } })).toEqual({
    ...working,
    tool: { name: 'Bash' },
  })

  for (const tool of ['Bash', { subject: 'ls' }, { name: '' }, { name: 3 }]) {
    expect(stateRead({ ...working, tool }), JSON.stringify(tool)).toEqual(working)
  }

  const asked = { is: 'question', since: T0 }

  expect(stateRead({ ...asked, question: { text: 'Left?', count: 2 } })).toEqual({
    ...asked,
    question: { text: 'Left?', count: 2 },
  })

  for (const bad of [
    { text: 'Left?' },
    { text: '', count: 1 },
    { text: 'Left?', count: 0 },
    { text: 'Left?', count: 1.5 },
    'Left?',
  ]) {
    expect(stateRead({ ...asked, question: bad }), JSON.stringify(bad)).toEqual(asked)
  }
})

test('what the window heard reads back from $.state as it was kept', () => {
  const busy = during(
    activity => toolStarted(activity, bash('t1', 'bun test'), T0 + 1_000),
    activity => toolAsked(activity, bash('t2', 'gh pr create', 'agent-1')),
    activity => toolAsked(activity, bash('t3', 'git push')),
    activity => permissionShown(activity, dialogFor('git push'), T0 + 2_000),
    activity => toolStarted(activity, question('q1'), T0 + 3_000),
  )
  const ended = turnEnded(busy, T0 + 9_000)

  for (const activity of [QUIET, busy, ended]) {
    expect(parseActivity(JSON.parse(JSON.stringify(activity)))).toEqual(activity)
  }
})

test("what an earlier load kept in another shape reads field by field: a field that does not read is QUIET's, an entry that does not is dropped", () => {
  for (const raw of [undefined, null, 'busy', 7, []]) {
    expect(parseActivity(raw), JSON.stringify(raw)).toEqual(QUIET)
  }

  const running = { call: 't1', tool: { name: 'Bash', subject: 'bun test' } }

  expect(parseActivity({ turnAt: T0, tools: [running] }), 'no candidates nor stops').toEqual({
    turnAt: T0,
    tools: [running],
    asked: [],
    stops: [],
    watches: [],
  })
  expect(
    parseActivity({
      turnAt: null,
      endedAt: '1',
      tools: {},
      asked: 'x',
      stops: 3,
      work: { agents: { count: 0, first: 'x' } },
      watches: 'Monitor',
    }),
  ).toEqual(QUIET)

  const asked = { call: 't2', tool: 'Bash', input: { command: digestOf('"ls"') } }
  const stop = { call: 't3', at: T0, is: 'question', question: { text: 'Left?', count: 1 } }

  expect(
    parseActivity({
      tools: [running, { call: 't9' }, { tool: { name: 'Bash' } }, 'Bash'],
      asked: [
        asked,
        { ...asked, input: { command: 'ls', check: 7 } },
        { ...asked, input: 'ls' },
        { ...asked, agentId: 5 },
        { tool: 'Bash', input: {} },
      ],
      stops: [
        stop,
        { ...stop, at: null },
        { ...stop, is: 'asleep' },
        { call: 't4', at: T0, is: 'permission' },
        { call: 't5', at: T0, is: 'permission', tool: { name: 'Bash' }, agentId: 'agent-1' },
      ],
    }),
  ).toEqual({
    tools: [running],
    asked: [asked],
    stops: [
      stop,
      { call: 't5', at: T0, is: 'permission', tool: { name: 'Bash' }, agentId: 'agent-1' },
    ],
    watches: [],
  })

  const watch = { task: 'bm1', isPersistent: true }

  expect(
    parseActivity({
      ...QUIET,
      work: { shells: { count: 1, first: 'bun test' }, monitors: { count: 1 }, wakes: 'soon' },
      watches: [watch, { task: 'bm2' }, { task: '', isPersistent: false }, 'bm3'],
    }),
  ).toEqual({ ...QUIET, work: { shells: { count: 1, first: 'bun test' } }, watches: [watch] })
})

test('a time heard before the clock first answered, which has none, reads as when the window attached', () => {
  const unstamped = toolStarted(QUIET, question('q1'), -Infinity)

  expect(stateOf(unstamped, T0)).toEqual({
    is: 'question',
    since: T0,
    question: { text: 'Left or right?', count: 2 },
  })
  expect(stateOf(turnStarted(QUIET, -Infinity), T0)).toEqual({ is: 'working', since: T0 })
  expect(stateOf(turnEnded(QUIET, -Infinity), T0)).toEqual({ is: 'yourTurn', since: T0 })
})

/** A task as a Stop lists it, with any of the engine's fields for its type. */
const task = (
  id: string,
  type: string,
  description: string,
  more: { [field: string]: string } = {},
): PendingTask => ({ id, type, description, ...more })

const REVIEW = task('a1', 'subagent', 'Review the diff', { agent_type: 'general-purpose' })

const TESTS = task('b1', 'shell', 'Run the tests', { command: 'bun test' })

/** A time in local time, as a wake's schedule names it. */
const local = (year: number, month: number, day: number, hour: number, minute: number) =>
  new Date(year, month - 1, day, hour, minute).getTime()

/** Thursday 22 October 2026, 14:30 and 25 seconds, local time. */
const NOW = local(2026, 10, 22, 14, 30) + 25_000

/** A turn begun at T0 and ended at T0 + 9s, its Stop listing `pending` before its end or after it. */
const stopped = (pending: Pending, order: 'stop first' | 'end first') =>
  order === 'stop first'
    ? turnEnded(turnStopped(turnStarted(QUIET, T0), pending, T0 + 9_000), T0 + 9_000)
    : turnStopped(turnEnded(turnStarted(QUIET, T0), T0 + 9_000), pending, T0 + 9_000)

test("a Stop listing what the turn left pending puts the window on its own work since the turn ended, whichever of the Stop and the turn's end comes first", () => {
  const pending = { tasks: [REVIEW], crons: [] }
  const onItsWork: WindowState = {
    is: 'onItsWork',
    since: T0 + 9_000,
    work: { agents: { count: 1, first: 'Review the diff' } },
  }

  expect(stateOf(stopped(pending, 'stop first'), T0)).toEqual(onItsWork)
  expect(stateOf(stopped(pending, 'end first'), T0)).toEqual(onItsWork)
  expect(stopped(pending, 'stop first')).toEqual(stopped(pending, 'end first'))
})

test('until the turn ends it is working, its Stop heard first or not', () => {
  const early = turnStopped(turnStarted(QUIET, T0), { tasks: [TESTS] }, T0 + 9_000)

  expect(stateOf(early, T0)).toEqual({ is: 'working', since: T0 })
})

test('a Stop with nothing pending, or listing nothing at all, leaves it your turn, in either order', () => {
  for (const pending of [{ tasks: [], crons: [] }, {}]) {
    for (const order of ['stop first', 'end first'] as const) {
      expect(stateOf(stopped(pending, order), T0), `${JSON.stringify(pending)}, ${order}`).toEqual(
        { is: 'yourTurn', since: T0 + 9_000 },
      )
    }
  }
})

test("the latest Stop's list replaces the one before it whole, and an empty one clears it", () => {
  const first = turnStopped(turnStarted(QUIET, T0), { tasks: [REVIEW, TESTS] }, T0 + 5_000)
  const second = turnStopped(first, { tasks: [TESTS] }, T0 + 8_000)
  const cleared = turnStopped(second, { tasks: [], crons: [] }, T0 + 9_000)

  expect(first.work).toEqual({
    agents: { count: 1, first: 'Review the diff' },
    shells: { count: 1, first: 'bun test' },
  })
  expect(second.work).toEqual({ shells: { count: 1, first: 'bun test' } })
  expect(cleared.work).toBeUndefined()
  expect(stateOf(turnEnded(cleared, T0 + 9_000), T0)).toEqual({
    is: 'yourTurn',
    since: T0 + 9_000,
  })
})

test("the next turn's start clears what was pending: working, then your turn at its end, as with Esc or an API error, which list nothing", () => {
  const waiting = stopped({ tasks: [REVIEW] }, 'stop first')
  const woken = turnStarted(waiting, T0 + 60_000)
  const interrupted = turnEnded(woken, T0 + 70_000)

  expect(woken.work).toBeUndefined()
  expect(stateOf(woken, T0)).toEqual({ is: 'working', since: T0 + 60_000 })
  expect(stateOf(interrupted, T0)).toEqual({ is: 'yourTurn', since: T0 + 70_000 })
})

test("a stop on Lee comes before what is pending, and a subagent's turn ending keeps it", () => {
  const waiting = stopped({ tasks: [REVIEW] }, 'end first')
  const asking = toolStarted(waiting, question('q1', 'agent-1'), T0 + 20_000)

  expect(stateOf(asking, T0)).toEqual({
    is: 'question',
    since: T0 + 20_000,
    question: { text: 'Left or right?', count: 2 },
  })
  expect(stateOf(toolEnded(asking, 'q1'), T0).is).toBe('onItsWork')
  expect(agentTurnEnded(waiting, 'agent-1').work).toEqual(waiting.work)
})

test("what is pending is summed up by kind, each kind's count and its first as its line says it: an agent's description, a workflow's name, a shell's command", () => {
  expect(
    workOf(
      {
        tasks: [
          REVIEW,
          task('a2', 'subagent', 'Draw round 2'),
          task('w1', 'workflow', 'Ship the release', { name: 'release' }),
          task('w2', 'workflow', 'Nightly'),
          TESTS,
          task('m1', 'monitor', 'CI on main', { server: 'github', tool: 'watch' }),
          task('t1', 'teammate', 'Designer'),
          task('x1', 'cloud session', 'Port the tests'),
        ],
      },
      [{ task: 'm1', isPersistent: false }],
      NOW,
    ),
  ).toEqual({
    agents: { count: 2, first: 'Review the diff' },
    workflows: { count: 2, first: 'release' },
    shells: { count: 1, first: 'bun test' },
    monitors: { count: 1, first: 'CI on main' },
    others: { count: 2, first: 'Designer' },
  })
})

test('a workflow with no name is its description, a shell with no command its description, and a task with neither its type; each one line, cut short', () => {
  const long = 'x'.repeat(SHOWN_LENGTH)

  expect(
    workOf(
      {
        tasks: [
          task('w1', 'workflow', 'Nightly'),
          task('b1', 'shell', 'Watch the build'),
          task('o1', 'MCP task', ''),
          task('a1', 'subagent', `Review\n  the ${long}`),
        ],
      },
      [],
      NOW,
    ),
  ).toEqual({
    agents: { count: 1, first: `Review the ${'x'.repeat(SHOWN_LENGTH - 12)}…` },
    workflows: { count: 1, first: 'Nightly' },
    shells: { count: 1, first: 'Watch the build' },
    others: { count: 1, first: 'MCP task' },
  })
})

test('a task that says nothing of itself is "a task", never an empty word, so its summary reads back as written', () => {
  const work = workOf({ tasks: [task('x', '', '')] }, [], NOW)
  const waiting = turnStopped(turnEnded(turnStarted(QUIET, T0), T0 + 9_000), { tasks: [task('x', '', '')] }, NOW)
  const state = stateOf(waiting, T0)

  expect(work).toEqual({ others: { count: 1, first: 'a task' } })
  expect(state).toEqual({ is: 'onItsWork', since: T0 + 9_000, work })
  expect(stateRead(JSON.parse(JSON.stringify(state)))).toEqual(state)
  expect(parseActivity(JSON.parse(JSON.stringify(waiting)))).toEqual(waiting)
})

test("a persistent monitor never ends, and the engine's ambient tasks never wake the window: none of them counts", () => {
  const watching = task('m1', 'monitor', 'Deploys', { server: 'github', tool: 'watch' })
  const ambient = [
    task('d1', 'dream', 'dreaming'),
    task('s1', 'auto-mode scan', 'scanning for auto-mode setup'),
    task('i1', 'memory import', 'importing memory'),
  ]

  expect(
    workOf({ tasks: [watching, ...ambient] }, [{ task: 'm1', isPersistent: true }], NOW),
  ).toBeUndefined()
})

test('a monitor watching a command is listed as a shell, and counts as a monitor by the task its call started', () => {
  const tailing = task('b2', 'shell', 'Errors in the log', {
    command: 'tail -f app.log | grep ERROR',
  })

  expect(workOf({ tasks: [tailing] }, [{ task: 'b2', isPersistent: false }], NOW)).toEqual({
    monitors: { count: 1, first: 'Errors in the log' },
  })
  expect(workOf({ tasks: [tailing] }, [{ task: 'b2', isPersistent: true }], NOW)).toBeUndefined()
  expect(workOf({ tasks: [tailing] }, [], NOW), 'a shell that never ends counts').toEqual({
    shells: { count: 1, first: 'tail -f app.log | grep ERROR' },
  })
})

/** Claude Code's own watch on a published artifact: a monitor no Monitor call started, which never ends. */
const ARTIFACT_WATCH = task(
  'bx1',
  'monitor',
  'live updates for artifact https://claude.ai/artifact/abc (re-armed on session resume)',
)

test('a monitor the mod never heard start may never end, so it counts for nothing and its Stop leaves the window your turn', () => {
  expect(workOf({ tasks: [ARTIFACT_WATCH] }, [], NOW)).toBeUndefined()
  expect(stateOf(stopped({ tasks: [ARTIFACT_WATCH] }, 'end first'), T0)).toEqual({
    is: 'yourTurn',
    since: T0 + 9_000,
  })
})

test('a monitor heard started, and not persistent, counts', () => {
  const watching = task('m1', 'monitor', 'CI on main', { server: 'github', tool: 'watch' })

  expect(workOf({ tasks: [watching] }, [{ task: 'm1', isPersistent: false }], NOW)).toEqual({
    monitors: { count: 1, first: 'CI on main' },
  })
})

test('a shell never heard started counts as a shell, as a Monitor running a command cannot be told from a background shell', () => {
  expect(workOf({ tasks: [TESTS] }, [], NOW)).toEqual({ shells: { count: 1, first: 'bun test' } })
})

test("a Stop listing Claude Code's watch on an artifact beside a background shell is on its own work by the shell alone", () => {
  expect(stateOf(stopped({ tasks: [ARTIFACT_WATCH, TESTS] }, 'end first'), T0)).toEqual({
    is: 'onItsWork',
    since: T0 + 9_000,
    work: { shells: { count: 1, first: 'bun test' } },
  })
})

test('a recurring cron never ends and counts for nothing; one-off wakes count, with the soonest time that reads', () => {
  const cron = (schedule: string, recurring: boolean) => ({
    id: schedule,
    schedule,
    recurring,
    prompt: 'Check the build',
  })

  expect(
    workOf({ crons: [cron('*/5 * * * *', true), cron('0 9 * * 1-5', true)] }, [], NOW),
  ).toBeUndefined()
  expect(
    workOf(
      {
        crons: [
          cron('0 17 * * *', false),
          cron('45 14 * * *', false),
          cron('*/5 * * * *', false),
          cron('0 9 * * 1-5', true),
        ],
      },
      [],
      NOW,
    ),
  ).toEqual({ wakes: { count: 3, at: local(2026, 10, 22, 14, 45) } })
  expect(workOf({ crons: [cron('*/5 * * * *', false)] }, [], NOW)).toEqual({ wakes: { count: 1 } })
  expect(
    workOf({ crons: [cron('45 14 * * *', false), cron('15 14 * * *', false)] }, [], NOW),
    'one whose minute just passed is due first',
  ).toEqual({ wakes: { count: 2, at: local(2026, 10, 22, 14, 15) } })
})

test("a one-off wake's schedule fires at the next time it names, in local time, from the start of the minute, where that is nearer than the last", () => {
  for (const [schedule, at] of [
    ['45 14 * * *', local(2026, 10, 22, 14, 45)],
    ['31 14 * * *', local(2026, 10, 22, 14, 31)],
    ['30 14 * * *', local(2026, 10, 22, 14, 30)],
    ['5 9 1 1 *', local(2027, 1, 1, 9, 5)],
    [' 0  18  22  10  * ', local(2026, 10, 22, 18, 0)],
    ['0 9 * * 5', local(2026, 10, 23, 9, 0)],
    ['0 9 * * 7', local(2026, 10, 25, 9, 0)],
    ['0 9 23 * 1', local(2026, 10, 23, 9, 0)],
    ['0 9 1 * 5', local(2026, 10, 23, 9, 0)],
    ['0 9 29 2 *', local(2028, 2, 29, 9, 0)],
  ] as const) {
    expect(wakeAt(schedule, NOW), schedule).toBe(at)
  }
})

test('a one-off still listed has not fired: where the last time it names is nearer than its next, it is due then, in the past, not a day or a year away', () => {
  for (const [schedule, at] of [
    ['29 14 * * *', local(2026, 10, 22, 14, 29)],
    ['15 14 * * *', local(2026, 10, 22, 14, 15)],
    ['30 14 22 10 *', local(2026, 10, 22, 14, 30)],
    ['29 14 22 10 *', local(2026, 10, 22, 14, 29)],
    ['0 12 22 10 *', local(2026, 10, 22, 12, 0)],
    ['0 9 * * 1', local(2026, 10, 19, 9, 0)],
  ] as const) {
    expect(wakeAt(schedule, NOW), schedule).toBe(at)
  }
})

test('a schedule that names no single time, or none at all, has none: its minute or hour not a number, or its day, month or weekday a range, a list, a step, a name or out of range', () => {
  for (const schedule of [
    '',
    '0 9 * *',
    '0 9 * * * 2026',
    '* 9 * * *',
    '*/5 * * * *',
    '0 9 1-5 * *',
    '0 9 1,15 * *',
    '0 9 * */2 *',
    '0 9 * JAN *',
    '0 9 * * MON',
    '0 9 * * 1-5',
    '60 9 * * *',
    '0 24 * * *',
    '0 9 0 * *',
    '0 9 32 * *',
    '0 9 * 13 *',
    '0 9 * * 8',
    '0 9 31 2 *',
    '-1 9 * * *',
    '1.5 9 * * *',
  ]) {
    expect(wakeAt(schedule, NOW), schedule).toBeUndefined()
  }
})

test('a Monitor call says the task it started and whether it is persistent, by its `persistent` or a `timeoutMs` of 0; any other call, or one naming no task, says none', () => {
  expect(watchOf('Monitor', { taskId: 'bm1', timeoutMs: 300_000 })).toEqual({
    task: 'bm1',
    isPersistent: false,
  })
  expect(watchOf('Monitor', { taskId: 'bm1', timeoutMs: 300_000, persistent: false })).toEqual({
    task: 'bm1',
    isPersistent: false,
  })

  for (const result of [
    { taskId: 'bm2', timeoutMs: 0, persistent: true },
    { taskId: 'bm2', timeoutMs: 300_000, persistent: true },
    { taskId: 'bm2', timeoutMs: 0 },
  ]) {
    expect(watchOf('Monitor', result), JSON.stringify(result)).toEqual({
      task: 'bm2',
      isPersistent: true,
    })
  }

  for (const [tool, result] of [
    ['Bash', { taskId: 'bm1' }],
    ['Monitor', 'done'],
    ['Monitor', { taskId: '' }],
    ['Monitor', undefined],
  ] as const) {
    expect(watchOf(tool, result), `${tool}: ${JSON.stringify(result)}`).toBeUndefined()
  }
})

test('a call that started a monitor is heard as it ends; a Stop keeps the monitors it lists still running, all of them where it lists no tasks', () => {
  const monitor: ToolCall = { id: 'c1', tool: 'Monitor', input: { description: 'Deploys' } }
  const started = toolEnded(toolStarted(turnStarted(QUIET, T0), monitor, T0 + 1_000), 'c1', {
    tool: 'Monitor',
    result: { taskId: 'bm1', timeoutMs: 0, persistent: true },
  })
  const listed = task('bm1', 'shell', 'Deploys', { command: 'gh run watch' })

  expect(started.watches).toEqual([{ task: 'bm1', isPersistent: true }])
  expect(turnStopped(started, { tasks: [listed] }, T0 + 9_000)).toEqual({
    turnAt: T0,
    tools: [],
    asked: [],
    stops: [],
    watches: [{ task: 'bm1', isPersistent: true }],
  })
  expect(turnStopped(started, {}, T0 + 9_000).watches).toEqual(started.watches)
  expect(turnStopped(started, { tasks: [] }, T0 + 9_000).watches).toEqual([])
  expect(turnStarted(turnEnded(started, T0 + 9_000), T0 + 10_000).watches).toEqual(
    started.watches,
  )
})

test('on its own work reads back from a heartbeat, and what the window heard from $.state, as each was kept', () => {
  const waiting = turnStopped(
    turnEnded(turnStarted(QUIET, T0), T0 + 9_000),
    { tasks: [REVIEW, TESTS], crons: [{ schedule: '45 14 * * *', recurring: false }] },
    NOW,
  )
  const state = stateOf(waiting, T0)

  expect(state).toEqual({
    is: 'onItsWork',
    since: T0 + 9_000,
    work: {
      agents: { count: 1, first: 'Review the diff' },
      shells: { count: 1, first: 'bun test' },
      wakes: { count: 1, at: local(2026, 10, 22, 14, 45) },
    },
  })
  expect(stateRead(state)).toEqual(state)
  expect(parseActivity(JSON.parse(JSON.stringify(waiting)))).toEqual(waiting)
})

test('of what is pending in a heartbeat, a kind that does not read is dropped and the state kept', () => {
  const onItsWork = { is: 'onItsWork', since: T0 }

  expect(
    stateRead({
      ...onItsWork,
      work: {
        agents: { count: 2, first: 'Review the diff' },
        shells: { count: 0, first: 'bun test' },
        monitors: { count: 1, first: '' },
        others: 'Designer',
        wakes: { count: 1, at: 'soon' },
        tasks: { count: 1, first: 'x' },
      },
    }),
  ).toEqual({
    ...onItsWork,
    work: { agents: { count: 2, first: 'Review the diff' }, wakes: { count: 1 } },
  })

  for (const work of [undefined, {}, 'agents', { wakes: { count: 0 } }]) {
    expect(stateRead({ ...onItsWork, work }), JSON.stringify(work)).toEqual(onItsWork)
  }
})
