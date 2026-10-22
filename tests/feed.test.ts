import { expect, test } from 'claude-code/testing'
import {
  replyState,
  brief,
  CURRENT_MS,
  doingOf,
  feedOf,
  FORGET_MS,
  foldSession,
  headOf,
  inPanelOrder,
  lettersOf,
  manifestVersion,
  metaText,
  needsReload,
  newRows,
  nextExpiry,
  rowOf,
  sessionState,
  STALE_MS,
  type Feed,
  type Presence,
  type Project,
  type ProjectRead,
  type Row,
  type RowKind,
  type Session,
  type SessionFiles,
  type SessionMeta,
  type ToolShown,
  type WindowState,
  type Work,
} from '../core'
import {
  beat,
  CLI,
  file,
  finish,
  META,
  MIN,
  park,
  reopen,
  reply,
  resolve,
  status,
  T0,
  W1,
  W2,
  W3,
  yesAsk,
  type Line,
} from './support'

const NOW = T0 + 60 * MIN

const SWITCHBOARD: Project = {
  key: 'switchboard',
  name: 'Switchboard',
  directory: '/Users/lee/Code/switchboard',
}

const GOOSEMATES: Project = { key: 'goosemates', name: 'Goosemates' }

const working = (since: number, tool?: ToolShown): WindowState => ({ is: 'working', since, tool })

const yourTurn = (since: number): WindowState => ({ is: 'yourTurn', since })

const onItsWork = (since: number, work?: Work): WindowState => ({ is: 'onItsWork', since, work })

const permission = (since: number, name: string, subject?: string): WindowState => ({
  is: 'permission',
  since,
  tool: { name, subject },
})

const question = (since: number, text: string, count: number): WindowState => ({
  is: 'question',
  since,
  question: { text, count },
})

/** A window's heartbeat, attached at T0 and seen at NOW unless the times say otherwise. */
const windowOn = (
  writer: string,
  state?: WindowState,
  times: Partial<Omit<Presence, 'writer' | 'state'>> = {},
) => ({
  [writer]: beat(writer, { attachedAt: T0, seenAt: NOW, version: '0.2.0', state, ...times }),
})

/** A session folded at `now` from its meta, the lines its window wrote, the letters in its inbox, and the heartbeats given. */
const sessionOf = (
  {
    meta = {},
    lines = [],
    inbox = {},
    presence = {},
  }: {
    meta?: Partial<SessionMeta>
    lines?: Line[]
    inbox?: SessionFiles['inbox']
    presence?: SessionFiles['presence']
  } = {},
  now = NOW,
): Session => {
  const session = foldSession(
    { meta: metaText({ ...META, ...meta }), logs: { [W1]: file(...lines) }, inbox, presence },
    now,
  )

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const rowFor = (session: Session, project = SWITCHBOARD, now = NOW) =>
  rowOf(project, session, now)

/** The lines of a session's row; none where it has no row. */
const lines = (session: Session, project = SWITCHBOARD) => rowFor(session, project)?.lines ?? []

const firstLines = (session: Session) => lines(session).map(line => line.first)

test("a session's state: away with no live window, your turn, working, needing Lee, or finished", () => {
  expect(sessionState(sessionOf(), NOW)).toBe('away')
  expect(sessionState(sessionOf({ presence: windowOn(W1, yourTurn(T0)) }), NOW)).toBe('yourTurn')
  expect(sessionState(sessionOf({ presence: windowOn(W1, working(T0)) }), NOW)).toBe('working')
  expect(
    sessionState(sessionOf({ presence: windowOn(W1, permission(T0, 'Bash', 'ls')) }), NOW),
  ).toBe('needsYou')
  expect(sessionState(sessionOf({ presence: windowOn(W1, question(T0, 'Left?', 1)) }), NOW)).toBe(
    'needsYou',
  )
  expect(
    sessionState(
      sessionOf({ lines: [[T0, yesAsk('k1', 'Review it')]], presence: windowOn(W1, working(T0)) }),
      NOW,
    ),
  ).toBe('needsYou')
  expect(
    sessionState(
      sessionOf({
        lines: [
          [T0, yesAsk('k1', 'Review it')],
          [T0 + MIN, finish('claude')],
        ],
        presence: windowOn(W1, permission(T0, 'Bash', 'ls')),
      }),
      NOW,
    ),
  ).toBe('finished')
})

test('an ask needs Lee while no window holds its session; a stale or left window holds nothing', () => {
  const ask: Line = [T0, yesAsk('k1', 'Review it')]

  expect(sessionState(sessionOf({ lines: [ask] }), NOW)).toBe('needsYou')
  expect(
    sessionState(
      sessionOf({ presence: windowOn(W1, working(T0), { seenAt: NOW - STALE_MS - 1 }) }),
      NOW,
    ),
  ).toBe('away')
  expect(
    sessionState(sessionOf({ presence: windowOn(W1, working(T0), { leftAt: NOW }) }), NOW),
  ).toBe('away')
})

test('a window on a version before heartbeats said its state reads as your turn since it attached', () => {
  const session = sessionOf({
    presence: windowOn(W1, undefined, { attachedAt: T0 + 5 * MIN, version: undefined }),
  })

  expect(sessionState(session, NOW)).toBe('yourTurn')
  expect(lines(session).map(line => [line.is, line.writer, line.since])).toEqual([
    ['yourTurn', W1, T0 + 5 * MIN],
  ])
})

test('of several windows on a session the most needing wins: a stop, then working, then on its own work, then your turn', () => {
  const both = (a: WindowState, b: WindowState) =>
    sessionState(sessionOf({ presence: { ...windowOn(W1, a), ...windowOn(W2, b) } }), NOW)
  const agents = onItsWork(T0, { agents: { count: 2, first: 'Review the diff' } })

  expect(sessionState(sessionOf({ presence: windowOn(W1, agents) }), NOW)).toBe('onItsWork')
  expect(both(yourTurn(T0), permission(T0, 'Bash', 'ls'))).toBe('needsYou')
  expect(both(working(T0), question(T0, 'Left?', 1))).toBe('needsYou')
  expect(both(agents, question(T0, 'Left?', 1))).toBe('needsYou')
  expect(both(yourTurn(T0), working(T0))).toBe('working')
  expect(both(agents, working(T0))).toBe('working')
  expect(both(yourTurn(T0 + MIN), agents)).toBe('onItsWork')
  expect(both(yourTurn(T0), yourTurn(T0 + MIN))).toBe('yourTurn')
})

test('a session with an ask is a row in Needs you, the ask a line of it, its title and its posting; its project and session under it; dimmed while away, saying no window holds it', () => {
  const held = sessionOf({
    lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]],
    presence: windowOn(W1, working(T0)),
  })
  const away = sessionOf({ lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]] })

  expect(rowFor(held)).toEqual({
    session: META.id,
    section: 'needsYou',
    isAway: false,
    project: 'switchboard',
    letters: 'Sw',
    lines: [
      {
        key: `ask:${META.id}:k1`,
        is: 'ask',
        ask: 'k1',
        first: { lead: 'Review round 1' },
        since: T0 + MIN,
      },
    ],
    second: 'Switchboard · Dashboard redesign',
    since: T0 + MIN,
  })
  expect(rowFor(away)).toMatchObject({
    isAway: true,
    lines: [{ key: `ask:${META.id}:k1` }],
    second: 'No window holds it. Carry it on in Claude.',
  })
})

test("a session with several asks is one row, a line for each, the oldest first; the row's time is its oldest line's", () => {
  const session = sessionOf({
    lines: [
      [T0 + 3 * MIN, yesAsk('k3', 'Approve the second fix batch')],
      [T0 + MIN, yesAsk('k1', 'Approve the first fix batch')],
      [T0 + 2 * MIN, yesAsk('k2', 'Choose the release branch')],
    ],
    presence: windowOn(W1, working(T0)),
  })
  const row = rowFor(session, { key: 'harness', name: 'Harness' })

  expect(row?.lines.map(line => [line.key, line.first.lead, line.since])).toEqual([
    [`ask:${META.id}:k1`, 'Approve the first fix batch', T0 + MIN],
    [`ask:${META.id}:k2`, 'Choose the release branch', T0 + 2 * MIN],
    [`ask:${META.id}:k3`, 'Approve the second fix batch', T0 + 3 * MIN],
  ])
  expect(row).toMatchObject({
    session: META.id,
    section: 'needsYou',
    second: 'Harness · Dashboard redesign',
    since: T0 + MIN,
  })
})

test('a session with an ask and a window stopped on a permission prompt is one row of two lines, the oldest first', () => {
  const session = sessionOf({
    lines: [[T0 + 2 * MIN, yesAsk('k1', 'Review round 1')]],
    presence: windowOn(W1, permission(T0 + MIN, 'Bash', 'gh pr create')),
  })

  expect(
    lines(session).map(line => [line.key, line.is, line.ask, line.writer, line.first]),
  ).toEqual([
    [
      `stop:${META.id}:${W1}:${T0 + MIN}`,
      'permission',
      undefined,
      W1,
      { lead: 'Allow Bash', mono: 'gh pr create' },
    ],
    [`ask:${META.id}:k1`, 'ask', 'k1', undefined, { lead: 'Review round 1' }],
  ])
  expect(rowFor(session)?.since).toBe(T0 + MIN)
})

test('a reopened ask waits since its reopening; a closed one is no row', () => {
  const session = sessionOf({
    lines: [
      [T0, yesAsk('k1', 'Review round 1')],
      [T0 + MIN, yesAsk('k2', 'Try it')],
      [T0 + 2 * MIN, resolve('k1')],
      [T0 + 3 * MIN, reopen('k1')],
      [T0 + 4 * MIN, resolve('k2')],
    ],
  })

  expect(lines(session).map(line => [line.ask, line.since])).toEqual([['k1', T0 + 3 * MIN]])
})

test('a permission prompt reads "Allow" and its tool, the subject in mono, since it showed', () => {
  const session = sessionOf({
    presence: windowOn(W1, permission(T0 + 5 * MIN, 'Bash', 'gh pr create --draft')),
  })

  expect(lines(session)).toEqual([
    {
      key: `stop:${META.id}:${W1}:${T0 + 5 * MIN}`,
      is: 'permission',
      writer: W1,
      first: { lead: 'Allow Bash', mono: 'gh pr create --draft' },
      since: T0 + 5 * MIN,
    },
  ])
  expect(rowFor(session)).toMatchObject({ section: 'needsYou', isAway: false })
  expect(
    firstLines(sessionOf({ presence: windowOn(W1, permission(T0, 'mcp__paper__write_html')) })),
  ).toEqual([{ lead: 'Allow mcp__paper__write_html', mono: undefined }])
})

test('a question reads as itself, "+N" for the rest when there are several', () => {
  expect(
    firstLines(sessionOf({ presence: windowOn(W1, question(T0, 'Which store?', 3)) })),
  ).toEqual([{ lead: 'Which store?', more: '+2' }])
  expect(
    firstLines(sessionOf({ presence: windowOn(W1, question(T0, 'Which store?', 1)) })),
  ).toEqual([{ lead: 'Which store?', more: undefined }])
  expect(firstLines(sessionOf({ presence: windowOn(W1, { is: 'question', since: T0 }) }))).toEqual([
    { lead: 'Claude asks a question', more: undefined },
  ])
})

test("each stopped window is a line; a session needing Lee shows only its waiting lines, never its working one", () => {
  const session = sessionOf({
    lines: [[T0, yesAsk('k1', 'Review it')]],
    presence: {
      ...windowOn(W1, working(T0, { name: 'Read', subject: '/tmp/a' })),
      ...windowOn(W2, permission(T0 + MIN, 'Bash', 'ls')),
      ...windowOn(W3, question(T0 + 2 * MIN, 'Left?', 1)),
    },
  })

  expect(lines(session).map(line => [line.is, line.writer])).toEqual([
    ['ask', undefined],
    ['permission', W2],
    ['question', W3],
  ])
})

test('while a tool runs, a working row leads with its verb, the subject after in mono; a task by its description; any other tool by its name', () => {
  const lineFor = (tool: ToolShown) =>
    firstLines(sessionOf({ presence: windowOn(W1, working(T0, tool)) }))[0]

  for (const [name, verb] of [
    ['Read', 'Reading'],
    ['Edit', 'Editing'],
    ['MultiEdit', 'Editing'],
    ['NotebookEdit', 'Editing'],
    ['Write', 'Writing'],
    ['Bash', 'Running'],
    ['Grep', 'Searching'],
    ['WebSearch', 'Searching'],
    ['Glob', 'Finding'],
    ['WebFetch', 'Fetching'],
    ['Skill', 'Using'],
    ['LSP', 'Checking'],
  ] as const) {
    expect(lineFor({ name, subject: 'it' })).toEqual({ lead: verb, mono: 'it' })
    expect(lineFor({ name })).toEqual({ lead: verb, mono: undefined })
  }

  for (const name of ['Agent', 'Task', 'Monitor']) {
    expect(lineFor({ name, subject: 'Review the diff' })).toEqual({ lead: 'Review the diff' })
    expect(lineFor({ name })).toEqual({ lead: name })
  }

  expect(lineFor({ name: 'mcp__paper__get_screenshot' })).toEqual({
    lead: 'mcp__paper__get_screenshot',
  })
})

test("a file tool's path shows from the project's directory where it lies under it; any other subject as it is", () => {
  const lineFor = (tool: ToolShown, project = SWITCHBOARD) =>
    lines(sessionOf({ presence: windowOn(W1, working(T0, tool)) }), project)[0]?.first

  expect(
    lineFor({ name: 'Read', subject: '/Users/lee/Code/switchboard/src/Limiter/Dispatcher.php' }),
  ).toEqual({
    lead: 'Reading',
    mono: 'src/Limiter/Dispatcher.php',
  })
  expect(lineFor({ name: 'Edit', subject: '/Users/lee/Code/switchboard-old/a.php' })).toEqual({
    lead: 'Editing',
    mono: '/Users/lee/Code/switchboard-old/a.php',
  })
  expect(
    lineFor({ name: 'Read', subject: '/Users/lee/Code/switchboard/a.php' }, GOOSEMATES),
  ).toEqual({
    lead: 'Reading',
    mono: '/Users/lee/Code/switchboard/a.php',
  })
  expect(lineFor({ name: 'Bash', subject: 'cat /Users/lee/Code/switchboard/a.php' })).toEqual({
    lead: 'Running',
    mono: 'cat /Users/lee/Code/switchboard/a.php',
  })
  expect(
    lines(
      sessionOf({
        presence: windowOn(W1, permission(T0, 'Write', '/Users/lee/Code/switchboard/b.ts')),
      }),
    )[0]?.first,
  ).toEqual({ lead: 'Allow Write', mono: 'b.ts' })
})

test("with no tool running, working and your turn read the board's now, else its summary, else its name", () => {
  const lineOf = (state: WindowState, lines: Line[]) =>
    firstLines(sessionOf({ lines, presence: windowOn(W1, state) }))[0]

  for (const state of [working(T0), yourTurn(T0)]) {
    expect(lineOf(state, [[T0, status(['Drawing Usage', 'Then Runway'])]])).toEqual({
      lead: 'Drawing Usage',
    })
    expect(lineOf(state, [[T0, status([])]])).toEqual({ lead: META.summary })
    expect(lineOf(state, [[T0, status([], { summary: '' })]])).toEqual({ lead: META.name })
  }
})

test('a session is a row of one line while its windows work or wait on Lee: the latest started working, else the latest to end its turn', () => {
  const both = (a: WindowState, b: WindowState) => {
    const row = rowFor(sessionOf({ presence: { ...windowOn(W1, a), ...windowOn(W2, b) } }))

    return [
      row?.section,
      row?.since,
      row?.lines.map(line => [line.key, line.is, line.writer, line.since]),
    ]
  }

  expect(both(working(T0), working(T0 + MIN))).toEqual([
    'working',
    T0 + MIN,
    [[`turn:${META.id}`, 'working', W2, T0 + MIN]],
  ])
  expect(both(working(T0 + MIN), yourTurn(T0 + 2 * MIN))).toEqual([
    'working',
    T0 + MIN,
    [[`turn:${META.id}`, 'working', W1, T0 + MIN]],
  ])
  expect(both(yourTurn(T0 + 2 * MIN), yourTurn(T0 + MIN))).toEqual([
    'yourTurn',
    T0 + 2 * MIN,
    [[`turn:${META.id}`, 'yourTurn', W1, T0 + 2 * MIN]],
  ])
})

test('on its own work, a row says the first of what it waits on: agents by their count or the one, a workflow, a shell in mono, a monitor, any other task, else its wake, counted down by the app', () => {
  const lineFor = (work: Work) =>
    firstLines(sessionOf({ presence: windowOn(W1, onItsWork(T0, work)) }))[0]
  const all: Work = {
    agents: { count: 3, first: 'Review the diff' },
    workflows: { count: 1, first: 'release' },
    shells: { count: 2, first: 'bun test --watch' },
    monitors: { count: 1, first: 'CI on main' },
    others: { count: 1, first: 'Designer' },
    wakes: { count: 1, at: T0 + 90 * MIN },
  }
  const noAgents = { ...all, agents: undefined }
  const noWorkflows = { ...noAgents, workflows: undefined }
  const noShells = { ...noWorkflows, shells: undefined }
  const noMonitors = { ...noShells, monitors: undefined }

  expect(lineFor(all)).toEqual({ lead: 'Waiting on', subject: '3 agents' })
  expect(lineFor({ agents: { count: 1, first: 'Review the diff' } })).toEqual({
    lead: 'Waiting on',
    subject: 'Review the diff',
  })
  expect(lineFor(noAgents)).toEqual({ lead: 'Running', subject: 'release' })
  expect(lineFor(noWorkflows)).toEqual({ lead: 'Running', mono: 'bun test --watch' })
  expect(lineFor(noShells)).toEqual({ lead: 'Watching', subject: 'CI on main' })
  expect(lineFor(noMonitors)).toEqual({ lead: 'Waiting on', subject: 'Designer' })
  expect(lineFor({ ...noMonitors, others: undefined })).toEqual({
    lead: 'Wakes',
    until: T0 + 90 * MIN,
  })
  expect(lineFor({ wakes: { count: 1 } })).toEqual({ lead: 'Wakes' })
})

test("on its own work, a row is in Working, its time counting from the turn's end; it carries its soonest wake for its order, whatever its line says", () => {
  const waiting = (work: Work) => {
    const row = rowFor(sessionOf({ presence: windowOn(W1, onItsWork(T0 + MIN, work)) }))

    return [
      row?.section,
      row?.since,
      row?.wakeAt,
      row?.lines.map(line => [line.key, line.is, line.writer, line.since]),
    ]
  }
  const own = [[`turn:${META.id}`, 'onItsWork', W1, T0 + MIN]]

  expect(
    waiting({ agents: { count: 1, first: 'Review the diff' }, wakes: { count: 2, at: NOW + MIN } }),
  ).toEqual(['working', T0 + MIN, NOW + MIN, own])
  expect(waiting({ agents: { count: 1, first: 'Review the diff' } })).toEqual([
    'working',
    T0 + MIN,
    undefined,
    own,
  ])
})

test("on its own work with nothing to say of what it waits on, as a heartbeat whose work did not read, reads the board's now", () => {
  expect(
    firstLines(
      sessionOf({
        lines: [[T0, status(['Drawing Usage'])]],
        presence: windowOn(W1, onItsWork(T0)),
      }),
    ),
  ).toEqual([{ lead: 'Drawing Usage' }])
})

test('of several windows, the row is the one working, else the one on its own work whose turn ended last, else the one active last', () => {
  const both = (a: WindowState, b: WindowState) =>
    lines(sessionOf({ presence: { ...windowOn(W1, a), ...windowOn(W2, b) } })).map(line => [
      line.is,
      line.writer,
    ])
  const shell = { shells: { count: 1, first: 'bun test' } }

  expect(both(working(T0), onItsWork(T0 + MIN, shell))).toEqual([['working', W1]])
  expect(both(onItsWork(T0, shell), yourTurn(T0 + MIN))).toEqual([['onItsWork', W1]])
  expect(both(onItsWork(T0, shell), onItsWork(T0 + MIN, shell))).toEqual([['onItsWork', W2]])
})

test("what a session is doing: its stop shown first, else its turn row's window, each worded as its row; away, since its latest line, with no window", () => {
  const doing = (presence: SessionFiles['presence'], lines: Line[] = []) =>
    doingOf(SWITCHBOARD, sessionOf({ lines, presence }), NOW)

  expect(
    doing({
      ...windowOn(W1, working(T0)),
      ...windowOn(W2, question(T0 + 2 * MIN, 'Left?', 2)),
      ...windowOn(W3, permission(T0 + MIN, 'Bash', 'ls')),
    }),
  ).toEqual({ is: 'permission', line: { lead: 'Allow Bash', mono: 'ls' }, since: T0 + MIN })
  expect(
    doing({
      ...windowOn(W1, working(T0, { name: 'Read', subject: '/Users/lee/Code/switchboard/a.ts' })),
      ...windowOn(W2, yourTurn(T0 + MIN)),
    }),
  ).toEqual({ is: 'working', line: { lead: 'Reading', mono: 'a.ts' }, since: T0 })
  expect(doing(windowOn(W1, yourTurn(T0 + MIN)), [[T0, status(['Drawing Usage'])]])).toEqual({
    is: 'yourTurn',
    line: { lead: 'Drawing Usage' },
    since: T0 + MIN,
  })
  expect(
    doing({
      ...windowOn(W1, onItsWork(T0 + MIN, { monitors: { count: 1, first: 'CI on main' } })),
      ...windowOn(W2, yourTurn(T0 + 2 * MIN)),
    }),
  ).toEqual({
    is: 'onItsWork',
    line: { lead: 'Watching', subject: 'CI on main' },
    since: T0 + MIN,
  })
  expect(doing({}, [[T0 + 5 * MIN, status(['Drawing Usage'])]])).toEqual({
    is: 'away',
    line: { lead: 'No window holds it. Carry it on in Claude.' },
    since: T0 + 5 * MIN,
  })
})

test("a session needing Lee for its asks alone, which has no row of its windows', is doing what they do", () => {
  const session = sessionOf({
    lines: [[T0, yesAsk('k1', 'Review it')]],
    presence: windowOn(W1, working(T0 + MIN, { name: 'Bash', subject: 'bun test' })),
  })

  expect(lines(session).map(line => line.is)).toEqual(['ask'])
  expect(doingOf(SWITCHBOARD, session, NOW)).toEqual({
    is: 'working',
    line: { lead: 'Running', mono: 'bun test' },
    since: T0 + MIN,
  })
})

/** An ask, and Lee's answer to it in the session's inbox, on its way. */
const ANSWERED = {
  lines: [[T0, yesAsk('k1', 'Review it')]] satisfies Line[],
  inbox: { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
}

test("an ask with Lee's answer on its way needs Lee no more: no row, no count, nothing new, the session as its windows leave it, the ask still among its asks", () => {
  const away = sessionOf(ANSWERED)
  const held = sessionOf({ ...ANSWERED, presence: windowOn(W1, yourTurn(T0)) })
  const feed = feedOf([{ project: SWITCHBOARD, sessions: [away] }], NOW)

  expect(away.waiting).toBe(0)
  expect([sessionState(away, NOW), rowFor(away)]).toEqual(['away', undefined])
  expect(sessionState(held, NOW)).toBe('yourTurn')
  expect(lines(held).map(each => each.key)).toEqual([`turn:${META.id}`])
  expect(feed.head).toEqual({ needYou: 0, sessions: 0 })
  expect(feed.projects).toMatchObject([
    { waiting: 0, sessions: [{ state: 'away', waiting: 0, asks: [{ id: 'k1' }] }] },
  ])
  expect(newRows(new Map(), feed, NOW).news).toEqual([])
})

test("watch lists a session's asks as board --json does, a replied one among them, so Lee's answer to it shows on its way", () => {
  const session = sessionOf({
    lines: [
      [T0, yesAsk('k1', 'Review it')],
      [T0, yesAsk('k2', 'Ship it', 'Go')],
      [T0, yesAsk('k3', 'Tag it', 'Done')],
      [T0 + MIN, reply('r1', 'k2', 'comment', { note: 'Tighten the copy first' })],
      [T0 + MIN, { type: 'delivered', replies: ['r1'] }],
      [T0 + MIN, resolve('k3')],
    ],
    inbox: { [CLI]: file([T0 + 2 * MIN, reply('r2', 'k2', 'yes')]) },
  })
  const [watched] = feedOf([{ project: SWITCHBOARD, sessions: [session] }], NOW).projects

  expect(watched?.sessions[0]?.asks.map(each => each.id)).toEqual(['k1', 'k2'])
  expect(watched?.sessions[0]?.asks).toEqual(brief(session).asks)
  expect(replyState(session.asks[1]!)).toMatchObject({ is: 'onItsWay', reply: { id: 'r2' } })
})

test('an answer gone void, its ask edited under it, leaves the ask waiting on Lee again', () => {
  const edited: Line = [
    T0 + 2 * MIN,
    { type: 'edit', item: 'k1', changes: { wants: 'choice', options: ['Now', 'Later'] } },
  ]
  const session = sessionOf({ ...ANSWERED, lines: [...ANSWERED.lines, edited] })

  expect(session.waiting).toBe(1)
  expect([rowFor(session)?.isAway, lines(session).map(each => each.key)]).toEqual([
    true,
    [`ask:${META.id}:k1`],
  ])
})

test('an away session with nothing waiting has no row, nor has a finished one, whatever it holds', () => {
  expect(rowFor(sessionOf({ lines: [[T0, park('p1', 'Later')]] }))).toBeUndefined()
  expect(
    rowFor(
      sessionOf({
        lines: [
          [T0, yesAsk('k1', 'Review it')],
          [T0 + MIN, finish('lee')],
        ],
        presence: windowOn(W1, question(T0, 'Left?', 2)),
      }),
    ),
  ).toBeUndefined()
})

const SECTIONS: Record<RowKind, Row['section']> = {
  ask: 'needsYou',
  permission: 'needsYou',
  question: 'needsYou',
  working: 'working',
  onItsWork: 'working',
  yourTurn: 'yourTurn',
}

/** A session's row in its section, of lines of the kind given at these times, its time the oldest's; the rest made up. */
const row = (session: string, is: RowKind, since: number | number[], isAway = false): Row => {
  const times = [since].flat()

  return {
    session,
    section: SECTIONS[is],
    isAway,
    project: 'p',
    letters: 'Pp',
    lines: times.map(at => ({ key: `${is}:${session}:${at}`, is, first: { lead: session }, since: at })),
    second: 'P · s',
    since: Math.min(...times),
  }
}

test('the rows in order: needs you oldest first, away ones last; then working, longest running first; then on its own work, soonest to wake first, else oldest first; then your turn, newest first', () => {
  const shuffled = [
    row('working-new', 'working', T0 + 5 * MIN),
    row('turn-old', 'yourTurn', T0 + MIN),
    row('own-old', 'onItsWork', T0),
    { ...row('wakes-later', 'onItsWork', T0 + 2 * MIN), wakeAt: T0 + 90 * MIN },
    row('away-new', 'ask', T0 + 4 * MIN, true),
    row('ask-new', 'ask', T0 + 3 * MIN),
    row('own-new', 'onItsWork', T0 + 3 * MIN),
    row('working-old', 'working', T0 + MIN),
    { ...row('wakes-soon', 'onItsWork', T0 + 4 * MIN), wakeAt: T0 + 70 * MIN },
    row('away-old', 'ask', T0, true),
    row('permission-old', 'permission', T0 + MIN),
    row('turn-new', 'yourTurn', T0 + 6 * MIN),
    row('question', 'question', T0 + 2 * MIN),
  ]

  expect(inPanelOrder(shuffled).map(each => each.session)).toEqual([
    'permission-old',
    'question',
    'ask-new',
    'away-old',
    'away-new',
    'working-old',
    'working-new',
    'wakes-soon',
    'wakes-later',
    'own-old',
    'own-new',
    'turn-new',
    'turn-old',
  ])
})

test("Needs you's rows in order by their oldest lines, whatever their newer ones, away sessions last", () => {
  expect(
    inPanelOrder([
      row('newer', 'ask', [T0 + MIN, T0 + 2 * MIN]),
      row('away', 'ask', [T0 - MIN, T0 + 3 * MIN], true),
      row('older', 'ask', [T0 + 9 * MIN, T0]),
    ]).map(each => each.session),
  ).toEqual(['older', 'newer', 'away'])
})

test('the head counts the lines needing Lee, away ones among them, and the rows, a session each', () => {
  expect(
    headOf([
      row('harness', 'ask', [T0, T0 + MIN, T0 + 2 * MIN]),
      row('away', 'ask', T0, true),
      row('stopped', 'permission', T0),
      row('working', 'working', T0),
    ]),
  ).toEqual({ needYou: 5, sessions: 4 })
  expect(headOf([row('turn', 'yourTurn', T0)])).toEqual({ needYou: 0, sessions: 1 })
})

test("a project's two letters: its capitals where it has two, else its first two", () => {
  expect(
    ['SitRep', 'DocMan', 'Switchboard', 'agntc', 'Agentic Workflows', 'Kit 2'].map(lettersOf),
  ).toEqual(['SR', 'DM', 'Sw', 'ag', 'AW', 'Ki'])
})

/** Three sessions of Switchboard and one of Goosemates, each in a state of its own. */
const board = (now = NOW): ProjectRead[] => [
  {
    project: SWITCHBOARD,
    sessions: [
      sessionOf(
        { meta: { id: 'sr-aaaaaa', name: 'Working' }, presence: windowOn(W1, working(T0)) },
        now,
      ),
      sessionOf(
        { meta: { id: 'sr-bbbbbb', name: 'Quiet' }, lines: [[T0 + 30 * MIN, status(['Idle'])]] },
        now,
      ),
      sessionOf(
        {
          meta: { id: 'sr-cccccc', name: 'Done' },
          lines: [
            [T0, yesAsk('k1', 'Old')],
            [T0 + MIN, finish('claude')],
          ],
        },
        now,
      ),
    ],
  },
  {
    project: GOOSEMATES,
    sessions: [
      sessionOf(
        {
          meta: { id: 'sr-dddddd', name: 'Onboarding' },
          lines: [[T0 + 10 * MIN, yesAsk('k2', 'Try the flow')]],
          presence: windowOn(W2, yourTurn(T0 + 20 * MIN), { version: undefined }),
        },
        now,
      ),
    ],
  },
]

test('the feed: each project with its current sessions in the rows order, a finished one never, an away one after those with rows', () => {
  const feed = feedOf(board(), NOW, '0.2.0')

  expect(feed.head).toEqual({ needYou: 1, sessions: 2 })
  expect(feed.rows.map(each => [each.session, each.section])).toEqual([
    ['sr-dddddd', 'needsYou'],
    ['sr-aaaaaa', 'working'],
  ])
  expect(
    feed.projects.map(project => [
      project.key,
      project.waiting,
      project.open,
      project.sessions.map(session => [
        session.id,
        session.state,
        session.since,
        session.doing.is,
        session.asks.map(ask => ask.id),
      ]),
    ]),
  ).toEqual([
    ['goosemates', 1, 1, [['sr-dddddd', 'needsYou', T0 + 10 * MIN, 'yourTurn', ['k2']]]],
    [
      'switchboard',
      0,
      1,
      [
        ['sr-aaaaaa', 'working', T0, 'working', []],
        ['sr-bbbbbb', 'away', T0 + 30 * MIN, 'away', []],
      ],
    ],
  ])
})

test('the feed lists every live window, the longest attached first, those behind the CLI needing a reload', () => {
  const feed = feedOf(board(), NOW, '0.2.0')

  expect(feed.windows).toEqual([
    {
      writer: W1,
      session: 'sr-aaaaaa',
      name: 'Working',
      project: 'Switchboard',
      version: '0.2.0',
      needsReload: false,
      where: undefined,
      state: working(T0),
      attachedAt: T0,
    },
    {
      writer: W2,
      session: 'sr-dddddd',
      name: 'Onboarding',
      project: 'Goosemates',
      version: undefined,
      needsReload: true,
      where: undefined,
      state: yourTurn(T0 + 20 * MIN),
      attachedAt: T0,
    },
  ])
  expect(feedOf(board(), NOW + STALE_MS + 1, '0.2.0').windows).toEqual([])
})

test('a window needs a reload when it says no version, or one behind the CLI’s own, dotted part by part', () => {
  expect(needsReload(undefined, '0.2.0')).toBe(true)
  expect(needsReload('0.1.9', '0.2.0')).toBe(true)
  expect(needsReload('0.1.0', '0.2.0'), 'a window from before answers, against this release').toBe(
    true,
  )
  expect(needsReload('0.9.0', '0.10.0')).toBe(true)
  expect(needsReload('0.2', '0.2.1')).toBe(true)
  expect(needsReload('0.2.0', '0.2.0')).toBe(false)
  expect(needsReload('0.10.0', '0.9.0')).toBe(false)
  expect(needsReload('0.1.0', undefined)).toBe(false)
  expect(needsReload(undefined, undefined)).toBe(true)
})

test("the CLI's version is its manifest's; one torn or saying none gives none", () => {
  expect(manifestVersion('{"name":"sitrep","version":"0.2.0"}')).toBe('0.2.0')
  expect(manifestVersion('{"name":"sitrep"}')).toBeUndefined()
  expect(manifestVersion('{"name":"sitrep","version":')).toBeUndefined()
})

test('what is new: a line needing Lee the watch has not shown, by its key; nothing on the first board, nor a working or your turn line', () => {
  const before = feedOf(board(), NOW)
  const after = feedOf(
    [
      ...board(),
      {
        project: { key: 'kit', name: 'Kit' },
        sessions: [
          sessionOf({
            meta: { id: 'sr-eeeeee' },
            lines: [[T0, yesAsk('k3', 'Run it')]],
            presence: {
              ...windowOn(W3, permission(NOW, 'Bash', 'ls')),
              ...windowOn(W2, working(T0)),
            },
          }),
          sessionOf({ meta: { id: 'sr-ffffff' }, presence: windowOn('w5', working(T0)) }),
        ],
      },
    ],
    NOW,
  )

  const first = newRows(undefined, before, NOW)

  expect(first.news).toEqual([])
  expect(newRows(first.shown, before, NOW).news).toEqual([])
  expect(newRows(first.shown, after, NOW).news).toEqual([
    'ask:sr-eeeeee:k3',
    `stop:sr-eeeeee:${W3}:${NOW}`,
  ])
})

test('a stop is new by its window and when it showed: the same stop again is not, a later one is; an answered ask is not', () => {
  const stopped = (since: number) =>
    feedOf(
      [
        {
          project: SWITCHBOARD,
          sessions: [sessionOf({ presence: windowOn(W1, permission(since, 'Bash', 'ls')) })],
        },
      ],
      NOW,
    )
  const asked = (...lines: Line[]) =>
    feedOf([{ project: SWITCHBOARD, sessions: [sessionOf({ lines })] }], NOW)
  const shownWith = (feed: Feed) => newRows(undefined, feed, NOW).shown

  expect(newRows(shownWith(stopped(T0)), stopped(T0), NOW).news).toEqual([])
  expect(newRows(shownWith(stopped(T0)), stopped(T0 + MIN), NOW).news).toEqual([
    `stop:${META.id}:${W1}:${T0 + MIN}`,
  ])
  expect(
    newRows(
      shownWith(asked([T0, yesAsk('k1', 'Review it')])),
      asked([T0, yesAsk('k1', 'Review it')], [T0 + MIN, resolve('k1')]),
      NOW,
    ).news,
  ).toEqual([])
})

test('a line needing Lee gone and back is not new again until it has been gone more than a day of the watch’s time, counted from its going; one gone that long is let go', () => {
  const stop = `stop:${META.id}:${W1}:${T0}`
  const on = feedOf(
    [
      {
        project: SWITCHBOARD,
        sessions: [sessionOf({ presence: windowOn(W1, permission(T0, 'Bash', 'ls')) })],
      },
    ],
    NOW,
  )
  const off = feedOf([{ project: SWITCHBOARD, sessions: [sessionOf()] }], NOW)
  const shown = newRows(newRows(undefined, on, 0).shown, on, 2 * FORGET_MS).shown
  const gone = newRows(shown, off, 2 * FORGET_MS).shown

  expect(newRows(shown, on, 2 * FORGET_MS).news).toEqual([])
  expect([...gone]).toEqual([[stop, 2 * FORGET_MS]])
  expect(newRows(gone, on, 3 * FORGET_MS).news).toEqual([])
  expect(newRows(gone, on, 3 * FORGET_MS + 1).news).toEqual([stop])
  expect([...newRows(gone, off, 3 * FORGET_MS).shown]).toEqual([[stop, 2 * FORGET_MS]])
  expect([...newRows(gone, off, 3 * FORGET_MS + 1).shown]).toEqual([])
})

test('the board next changes by time alone as the first live heartbeat goes stale, or an idle session drops out of the views', () => {
  const read = (sessions: Session[]): ProjectRead[] => [{ project: SWITCHBOARD, sessions }]

  expect(
    nextExpiry(
      read([
        sessionOf({
          lines: [[T0, yesAsk('k1', 'Keep me')]],
          presence: windowOn(W1, working(T0), { seenAt: NOW - MIN }),
        }),
        sessionOf({
          lines: [[T0, park('p1', 'Keep me')]],
          presence: windowOn(W2, working(T0), { seenAt: NOW - 30_000 }),
        }),
        sessionOf({
          lines: [[T0, park('p2', 'Keep me')]],
          presence: windowOn(W3, working(T0), { leftAt: NOW }),
        }),
      ]),
      NOW,
    ),
  ).toBe(NOW - MIN + STALE_MS + 1)
  expect(nextExpiry(read([sessionOf({ lines: [[T0 + MIN, status(['Idle'])]] })]), NOW)).toBe(
    T0 + MIN + CURRENT_MS + 1,
  )
  expect(
    nextExpiry(
      read([
        sessionOf({
          lines: [
            [T0, yesAsk('k1', 'Keep me')],
            [T0, finish('lee')],
          ],
        }),
      ]),
      NOW,
    ),
  ).toBeUndefined()
  expect(
    nextExpiry(read([sessionOf({ lines: [[T0, yesAsk('k1', 'Keep me')]] })]), NOW),
  ).toBeUndefined()
  expect(
    nextExpiry(
      read([
        sessionOf({
          lines: [[T0, yesAsk('k1', 'Keep me')]],
          inbox: { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
        }),
      ]),
      NOW,
    ),
    'an answer on its way keeps its session current, as its ask did',
  ).toBeUndefined()
})
