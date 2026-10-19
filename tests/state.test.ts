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
  type Activity,
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
  expect(ended).toEqual({ endedAt: T0 + 9_000, tools: [], ...theAgents })
  expect(next).toEqual({ turnAt: T0 + 10_000, tools: [], ...theAgents })
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
  })
  expect(parseActivity({ turnAt: null, endedAt: '1', tools: {}, asked: 'x', stops: 3 })).toEqual(
    QUIET,
  )

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
  })
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
