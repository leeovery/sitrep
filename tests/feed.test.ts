import { expect, test } from './kit'
import {
  ASLEEP,
  boardText,
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
  nextBoardChange,
  nextExpiry,
  nextFoldChange,
  rejoinable,
  rowOf,
  sessionState,
  snoozedRowOf,
  snoozedTurnOf,
  STALE_MS,
  toldSummary,
  windowsOf,
  type Feed,
  type LastWindow,
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
import { CLI, META, MIN, T0, W1, W2, W3 } from './data'
import {
  beat,
  delivered,
  file,
  finish,
  park,
  reopen,
  reply,
  resolve,
  snooze,
  snoozeSession,
  snoozeTurn,
  status,
  wake,
  wakeSession,
  wakeTurn,
  yesAsk,
  type Line,
} from './lines'

const NOW = T0 + 60 * MIN

const NORTHWIND: Project = {
  key: 'northwind',
  name: 'Northwind',
  directory: '/Users/me/Code/northwind',
}

const CONTOSO: Project = { key: 'contoso', name: 'Contoso' }

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

const rowFor = (session: Session, project = NORTHWIND, now = NOW) =>
  rowOf(project, session, now)

/** The lines of a session's row; none where it has no row. */
const lines = (session: Session, project = NORTHWIND) => rowFor(session, project)?.lines ?? []

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

test("a session with an ask is a row in Needs you, the ask a line of it, its title and its posting; the session's name and its project's of their own, and both under it; dimmed while away, saying no window holds it", () => {
  const held = sessionOf({
    lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]],
    presence: windowOn(W1, working(T0)),
  })
  const away = sessionOf({ lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]] })

  expect(rowFor(held)).toEqual({
    session: META.id,
    section: 'needsYou',
    isAway: false,
    project: 'northwind',
    name: 'Help desk redesign',
    projectName: 'Northwind',
    letters: 'No',
    lines: [
      {
        key: `ask:${META.id}:k1`,
        is: 'ask',
        ask: 'k1',
        first: { lead: 'Review round 1' },
        since: T0 + MIN,
      },
    ],
    second: 'Northwind · Help desk redesign',
    since: T0 + MIN,
  })
  expect(rowFor(away)).toMatchObject({
    isAway: true,
    name: 'Help desk redesign',
    projectName: 'Northwind',
    lines: [{ key: `ask:${META.id}:k1` }],
    second: 'No window holds it. Carry it on in Claude.',
  })
})

test("a session with several asks is one row, a line for each, the newest first; the row's time is its newest line's", () => {
  const session = sessionOf({
    lines: [
      [T0 + 3 * MIN, yesAsk('k3', 'Approve the second copy edit')],
      [T0 + MIN, yesAsk('k1', 'Approve the first copy edit')],
      [T0 + 2 * MIN, yesAsk('k2', 'Choose the release branch')],
    ],
    presence: windowOn(W1, working(T0)),
  })
  const row = rowFor(session, { key: 'fabrikam', name: 'Fabrikam' })

  expect(row?.lines.map(line => [line.key, line.first.lead, line.since])).toEqual([
    [`ask:${META.id}:k3`, 'Approve the second copy edit', T0 + 3 * MIN],
    [`ask:${META.id}:k2`, 'Choose the release branch', T0 + 2 * MIN],
    [`ask:${META.id}:k1`, 'Approve the first copy edit', T0 + MIN],
  ])
  expect(row).toMatchObject({
    session: META.id,
    section: 'needsYou',
    name: 'Help desk redesign',
    projectName: 'Fabrikam',
    second: 'Fabrikam · Help desk redesign',
    since: T0 + 3 * MIN,
  })
})

test('a session with an ask and a window stopped on a permission prompt is one row of two lines, the newest first', () => {
  const session = sessionOf({
    lines: [[T0 + 2 * MIN, yesAsk('k1', 'Review round 1')]],
    presence: windowOn(W1, permission(T0 + MIN, 'Bash', 'gh pr create')),
  })

  expect(
    lines(session).map(line => [line.key, line.is, line.ask, line.writer, line.first]),
  ).toEqual([
    [`ask:${META.id}:k1`, 'ask', 'k1', undefined, { lead: 'Review round 1' }],
    [
      `stop:${META.id}:${W1}:${T0 + MIN}`,
      'permission',
      undefined,
      W1,
      { lead: 'Allow Bash', mono: 'gh pr create' },
    ],
  ])
  expect(rowFor(session)?.since).toBe(T0 + 2 * MIN)
})

test("a session at Lee's turn with asks waiting is one row, in Needs you, counted by its asks: its turn adds no row, no line and no count", () => {
  const session = sessionOf({
    lines: [
      [T0 + MIN, yesAsk('k1', 'Review round 1')],
      [T0 + 2 * MIN, yesAsk('k2', 'Ship it')],
    ],
    presence: windowOn(W1, yourTurn(T0)),
  })
  const feed = feedAt(NOW, session)

  expect(feed.rows.map(row => [row.session, row.section, row.lines.map(each => each.key)])).toEqual([
    [META.id, 'needsYou', [`ask:${META.id}:k2`, `ask:${META.id}:k1`]],
  ])
  expect(feed.head).toEqual({ needYou: 2, sessions: 1 })
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
    ['question', W3],
    ['permission', W2],
    ['ask', undefined],
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
  const lineFor = (tool: ToolShown, project = NORTHWIND) =>
    lines(sessionOf({ presence: windowOn(W1, working(T0, tool)) }), project)[0]?.first

  expect(
    lineFor({ name: 'Read', subject: '/Users/me/Code/northwind/src/Mail/MessageQueue.php' }),
  ).toEqual({
    lead: 'Reading',
    mono: 'src/Mail/MessageQueue.php',
  })
  expect(lineFor({ name: 'Edit', subject: '/Users/me/Code/northwind-old/a.php' })).toEqual({
    lead: 'Editing',
    mono: '/Users/me/Code/northwind-old/a.php',
  })
  expect(
    lineFor({ name: 'Read', subject: '/Users/me/Code/northwind/a.php' }, CONTOSO),
  ).toEqual({
    lead: 'Reading',
    mono: '/Users/me/Code/northwind/a.php',
  })
  expect(lineFor({ name: 'Bash', subject: 'cat /Users/me/Code/northwind/a.php' })).toEqual({
    lead: 'Running',
    mono: 'cat /Users/me/Code/northwind/a.php',
  })
  expect(
    lines(
      sessionOf({
        presence: windowOn(W1, permission(T0, 'Write', '/Users/me/Code/northwind/b.ts')),
      }),
    )[0]?.first,
  ).toEqual({ lead: 'Allow Write', mono: 'b.ts' })
})

test("with no tool running, working and your turn read the board's now, else its summary, else its name", () => {
  const lineOf = (state: WindowState, lines: Line[]) =>
    firstLines(sessionOf({ lines, presence: windowOn(W1, state) }))[0]

  for (const state of [working(T0), yourTurn(T0)]) {
    expect(lineOf(state, [[T0, status(['Drawing Inbox', 'Then Macros'])]])).toEqual({
      lead: 'Drawing Inbox',
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
        lines: [[T0, status(['Drawing Inbox'])]],
        presence: windowOn(W1, onItsWork(T0)),
      }),
    ),
  ).toEqual([{ lead: 'Drawing Inbox' }])
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
    doingOf(NORTHWIND, sessionOf({ lines, presence }), NOW)

  expect(
    doing({
      ...windowOn(W1, working(T0)),
      ...windowOn(W2, question(T0 + 2 * MIN, 'Left?', 2)),
      ...windowOn(W3, permission(T0 + MIN, 'Bash', 'ls')),
    }),
  ).toEqual({ is: 'permission', line: { lead: 'Allow Bash', mono: 'ls' }, since: T0 + MIN })
  expect(
    doing({
      ...windowOn(W1, working(T0, { name: 'Read', subject: '/Users/me/Code/northwind/a.ts' })),
      ...windowOn(W2, yourTurn(T0 + MIN)),
    }),
  ).toEqual({ is: 'working', line: { lead: 'Reading', mono: 'a.ts' }, since: T0 })
  expect(doing(windowOn(W1, yourTurn(T0 + MIN)), [[T0, status(['Drawing Inbox'])]])).toEqual({
    is: 'yourTurn',
    line: { lead: 'Drawing Inbox' },
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
  expect(doing({}, [[T0 + 5 * MIN, status(['Drawing Inbox'])]])).toEqual({
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
  expect(doingOf(NORTHWIND, session, NOW)).toEqual({
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
  const feed = feedOf([{ project: NORTHWIND, sessions: [away] }], NOW)

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
  const [watched] = feedOf([{ project: NORTHWIND, sessions: [session] }], NOW).projects

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

/** A session's row in its section, of lines of the kind given at these times, its time the newest's; the rest made up. */
const row = (session: string, is: RowKind, since: number | number[], isAway = false): Row => {
  const times = [since].flat()

  return {
    session,
    section: SECTIONS[is],
    isAway,
    project: 'p',
    name: 's',
    projectName: 'P',
    letters: 'Pp',
    lines: times.map(at => ({ key: `${is}:${session}:${at}`, is, first: { lead: session }, since: at })),
    second: 'P · s',
    since: Math.max(...times),
  }
}

test('the rows in order: needs you newest first, away ones last; then your turn, newest first; then working, longest running first; then on its own work, soonest to wake first, else oldest first', () => {
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
    'ask-new',
    'question',
    'permission-old',
    'away-new',
    'away-old',
    'turn-new',
    'turn-old',
    'working-old',
    'working-new',
    'wakes-soon',
    'wakes-later',
    'own-old',
    'own-new',
  ])
})

test("Needs you's rows in order by their newest lines, whatever their older ones, away sessions last, newest first among them", () => {
  expect(
    inPanelOrder([
      row('older', 'ask', [T0 + MIN, T0 + 2 * MIN]),
      row('away-older', 'ask', [T0 - 9 * MIN, T0 + 3 * MIN], true),
      row('newer', 'ask', [T0 + 9 * MIN, T0]),
      row('away-newer', 'ask', [T0 + 4 * MIN], true),
    ]).map(each => each.session),
  ).toEqual(['newer', 'older', 'away-newer', 'away-older'])
})

test('the head counts the lines needing Lee, away ones among them, and the rows, a session each', () => {
  expect(
    headOf([
      row('asking', 'ask', [T0, T0 + MIN, T0 + 2 * MIN]),
      row('away', 'ask', T0, true),
      row('stopped', 'permission', T0),
      row('working', 'working', T0),
    ]),
  ).toEqual({ needYou: 5, sessions: 4 })
  expect(headOf([row('turn', 'yourTurn', T0)])).toEqual({ needYou: 0, sessions: 1 })
})

test("a project's two letters: its capitals where it has two, else its first two", () => {
  expect(
    ['SitRep', 'BlueYonder', 'Northwind', 'contoso', 'Adventure Works', 'Wingtip 2'].map(lettersOf),
  ).toEqual(['SR', 'BY', 'No', 'co', 'AW', 'Wi'])
})

/** Three sessions of Northwind and one of Contoso, each in a state of its own. */
const board = (now = NOW): ProjectRead[] => [
  {
    project: NORTHWIND,
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
    project: CONTOSO,
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
    ['contoso', 1, 1, [['sr-dddddd', 'needsYou', T0 + 10 * MIN, 'yourTurn', ['k2']]]],
    [
      'northwind',
      0,
      1,
      [
        ['sr-aaaaaa', 'working', T0, 'working', []],
        ['sr-bbbbbb', 'away', T0 + 30 * MIN, 'away', []],
      ],
    ],
  ])
})

/** The last window the feed carries for the session, folded at `now`. */
const lastWindowIn = (session: Session, now = NOW) =>
  feedOf([{ project: NORTHWIND, sessions: [session] }], now).projects[0]?.sessions[0]?.lastWindow

/** A last window as the feed carries it: where it was, its device its conversation's, unless said. */
const lastWindow = (
  writer: string,
  { where, directory, ownsDevice = true }: Partial<LastWindow> = {},
): LastWindow => ({ writer, where, directory, ownsDevice })

test('an away session carries the window it was last in, by its heartbeat last seen, a /clear moving it on: its writer, where it was and its folder', () => {
  const directory = `${NORTHWIND.directory}/.claude/worktrees/lobby`
  const session = sessionOf({
    lines: [[T0, yesAsk('k1', 'Review round 1')]],
    presence: {
      ...windowOn(W1, yourTurn(T0), {
        seenAt: T0 + 10 * MIN,
        leftAt: T0 + 10 * MIN,
        ...whereFor('s041'),
      }),
      ...windowOn(W2, working(T0), { seenAt: T0 + 20 * MIN, directory, ...whereFor('s042') }),
      ...windowOn(W3, yourTurn(T0), { seenAt: T0 + 5 * MIN, ...whereFor('s043') }),
    },
  })

  expect(sessionState(session, NOW)).toBe('needsYou')
  expect(lastWindowIn(session)).toEqual(lastWindow(W2, { directory, ...whereFor('s042') }))
})

test("an away session's last window on a build before heartbeats said their folder carries none, and one saying no where none either", () => {
  const session = sessionOf({ presence: windowOn(W1, yourTurn(T0), { seenAt: T0 + 10 * MIN }) })

  expect(sessionState(session, NOW)).toBe('away')
  expect(lastWindowIn(session)).toEqual(lastWindow(W1))
})

test('a session a live window holds carries no last window, though another window of it is gone; nor does one no window ever held', () => {
  const held = sessionOf({
    presence: {
      ...windowOn(W1, yourTurn(T0), { directory: '/Users/me/Code/northwind' }),
      ...windowOn(W2, working(T0), { seenAt: T0 + 50 * MIN, leftAt: T0 + 50 * MIN }),
    },
  })

  expect(lastWindowIn(held)).toBeUndefined()
  expect(lastWindowIn(held, NOW + STALE_MS + 1)).toEqual(
    lastWindow(W1, { directory: '/Users/me/Code/northwind' }),
  )
  expect(lastWindowIn(sessionOf({ lines: [[T0, yesAsk('k1', 'Review round 1')]] }))).toBeUndefined()
})

/** The last window the feed carries for each session given, by its id, the board read at `now`. */
const lastWindowsOf = (sessions: Session[], now = NOW) =>
  Object.fromEntries(
    feedOf([{ project: NORTHWIND, sessions }], now).projects.flatMap(project =>
      project.sessions.map(each => [each.id, each.lastWindow]),
    ),
  )

/** A session of its own id, an ask waiting in it so it stays current, with the heartbeats given. */
const another = (id: string, presence: SessionFiles['presence'], lines: Line[] = []) =>
  sessionOf({ meta: { id, name: id }, lines: [[T0, yesAsk('k1', 'Review round 1')], ...lines], presence })

/** W1 held A, then joined B, letting go of A, its heartbeat in B seen at `seenAt`. */
const movedOn = (seenAt: number, lines: Line[] = []) => ({
  left: another('sr-aaaaaa', windowOn(W1, yourTurn(T0), { seenAt: T0 + 50 * MIN, leftAt: T0 + 50 * MIN })),
  joined: another('sr-bbbbbb', windowOn(W1, yourTurn(T0), { attachedAt: T0 + 50 * MIN, seenAt }), lines),
})

test('a session its last window let go of for another carries no last window, live there or gone: resumed, its conversation takes up the other, which carries it', () => {
  const { left, joined } = movedOn(NOW)

  expect(lastWindowsOf([left, joined])).toEqual({ 'sr-aaaaaa': undefined, 'sr-bbbbbb': undefined })
  expect(lastWindowsOf([left, joined], NOW + STALE_MS + 1)).toEqual({
    'sr-aaaaaa': undefined,
    'sr-bbbbbb': lastWindow(W1),
  })
})

test('a session its last window let go of for one since finished carries no last window, as its conversation, resumed, takes up neither', () => {
  const { left, joined } = movedOn(T0 + 55 * MIN, [[T0 + 55 * MIN, finish('claude')]])

  expect(lastWindowsOf([left, joined])).toEqual({ 'sr-aaaaaa': undefined })
})

test("a /clear moving a window on to another session leaves the last one its conversation's to carry on, as the conversation after is another", () => {
  const left = another('sr-aaaaaa', windowOn(W1, yourTurn(T0), { seenAt: T0 + 50 * MIN, leftAt: T0 + 50 * MIN }))
  const next = another('sr-bbbbbb', windowOn(W2, yourTurn(T0), { attachedAt: T0 + 50 * MIN, seenAt: T0 + 55 * MIN }))

  expect(lastWindowsOf([left, next])).toEqual({ 'sr-aaaaaa': lastWindow(W1), 'sr-bbbbbb': lastWindow(W2) })
})

test("a last window's device is always given, for a click to look for a Claude there; it is its conversation's only while no later conversation was seen on it, and not where its Claude went on into the next", () => {
  const last = (livesOn?: true) =>
    another('sr-aaaaaa', windowOn(W1, yourTurn(T0), { seenAt: T0 + 10 * MIN, leftAt: T0 + 10 * MIN, livesOn, ...whereFor('s041') }))
  const later = another('sr-bbbbbb', windowOn(W2, yourTurn(T0), { seenAt: T0 + 20 * MIN, ...whereFor('s041') }))
  const earlier = another('sr-bbbbbb', windowOn(W2, yourTurn(T0), { seenAt: T0 + 5 * MIN, ...whereFor('s041') }))
  const ownsOf = (sessions: Session[]) => {
    const window = lastWindowsOf(sessions)['sr-aaaaaa']

    return [window?.where?.device, window?.ownsDevice]
  }

  expect(ownsOf([last()])).toEqual(['/dev/ttys041', true])
  expect(ownsOf([last(), earlier])).toEqual(['/dev/ttys041', true])
  expect(ownsOf([last(), later])).toEqual(['/dev/ttys041', false])
  expect(ownsOf([last(true)])).toEqual(['/dev/ttys041', false])
})

test('a last window is the one last seen as a resume ranks them, by when it let go, else its latest beat: one that let go after another stopped beating is last, though it beat before', () => {
  const session = another('sr-aaaaaa', {
    ...windowOn(W1, yourTurn(T0), { seenAt: T0 + 18 * MIN, leftAt: T0 + 20 * MIN }),
    ...windowOn(W2, yourTurn(T0), { seenAt: T0 + 19 * MIN }),
  })

  expect(lastWindowsOf([session])['sr-aaaaaa']?.writer).toBe(W1)
  expect(rejoinable([session], W1)).toBe('sr-aaaaaa')
})

test("a Needs you row's time is its newest line's, while its session's state still counts from its oldest, as its first line came", () => {
  const feed = feedOf(
    [
      {
        project: NORTHWIND,
        sessions: [
          sessionOf({
            lines: [
              [T0 + MIN, yesAsk('k1', 'Review round 1')],
              [T0 + 4 * MIN, yesAsk('k2', 'Try it')],
            ],
            presence: windowOn(W1, permission(T0 + 2 * MIN, 'Bash', 'ls')),
          }),
        ],
      },
    ],
    NOW,
  )

  expect(feed.rows[0]?.since, "the row's shown time, and what orders it").toBe(T0 + 4 * MIN)
  expect(feed.projects[0]?.sessions[0]?.since, 'how long the session has needed Lee').toBe(T0 + MIN)
})

test('every session in the feed carries what it parked, oldest first, and when it started, whether or not it has a row', () => {
  const read: ProjectRead[] = [
    {
      project: NORTHWIND,
      sessions: [
        sessionOf({
          meta: { id: 'sr-aaaaaa', name: 'Working', created: T0 - 90 * MIN },
          lines: [[T0 + MIN, park('p1', 'A priority badge')]],
          presence: windowOn(W1, working(T0)),
        }),
        sessionOf({ meta: { id: 'sr-bbbbbb', name: 'Quiet', created: T0 - 30 * MIN } }),
      ],
    },
    {
      project: CONTOSO,
      sessions: [
        sessionOf({
          meta: { id: 'sr-dddddd', name: 'Away' },
          lines: [
            [T0 + 2 * MIN, park('p1', 'Tidy the copy')],
            [T0 + 5 * MIN, park('p2', 'Retry the export', { where: 'After the release' })],
          ],
        }),
      ],
    },
  ]
  const sessions = feedOf(read, NOW).projects.flatMap(project => project.sessions)

  expect(
    sessions.map(session => [
      session.id,
      session.created,
      session.parkedItems.map(parked => [parked.id, parked.title, parked.where, parked.at]),
    ]),
  ).toEqual([
    ['sr-aaaaaa', T0 - 90 * MIN, [['p1', 'A priority badge', undefined, T0 + MIN]]],
    ['sr-bbbbbb', T0 - 30 * MIN, []],
    [
      'sr-dddddd',
      T0,
      [
        ['p1', 'Tidy the copy', undefined, T0 + 2 * MIN],
        ['p2', 'Retry the export', 'After the release', T0 + 5 * MIN],
      ],
    ],
  ])
})

test("an item picked up or closed leaves the feed's parked items, and its count", () => {
  const session = sessionOf({
    lines: [
      [T0, park('p1', 'A priority badge')],
      [T0, park('p2', 'Retry the export')],
      [T0, park('p3', 'Tidy the copy')],
      [T0 + MIN, reply('r1', 'p1', 'pickup')],
      [T0 + MIN, delivered('r1')],
      [T0 + 2 * MIN, resolve('p2')],
    ],
  })
  const [fed] = feedOf([{ project: NORTHWIND, sessions: [session] }], NOW).projects.flatMap(
    project => project.sessions,
  )

  expect([fed?.parked, fed?.parkedItems.map(parked => parked.id)]).toEqual([1, ['p3']])
})

test('the feed lists every live window, the longest attached first, those behind the CLI needing a reload', () => {
  const feed = feedOf(board(), NOW, '0.2.0')

  expect(feed.windows).toEqual([
    {
      writer: W1,
      session: 'sr-aaaaaa',
      name: 'Working',
      project: 'Northwind',
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
      project: 'Contoso',
      version: undefined,
      needsReload: true,
      where: undefined,
      state: yourTurn(T0 + 20 * MIN),
      attachedAt: T0,
    },
  ])
  expect(feedOf(board(), NOW + STALE_MS + 1, '0.2.0').windows).toEqual([])
})

test("each window in the feed carries the folder its Claude runs in, a held session's {dir}; none where its heartbeat says none", () => {
  const directory = `${NORTHWIND.directory}/.claude/worktrees/lobby`
  const session = sessionOf({
    presence: {
      ...windowOn(W1, working(T0), { directory }),
      ...windowOn(W2, yourTurn(T0), { attachedAt: T0 + MIN }),
    },
  })
  const windows = feedOf([{ project: NORTHWIND, sessions: [session] }], NOW).windows

  expect(windows.map(each => [each.writer, each.directory])).toEqual([
    [W1, directory],
    [W2, undefined],
  ])
})

/** A window's whereabouts, by its writer: a device of its own. */
const whereFor = (writer: string) => ({ where: { device: `/dev/tty${writer}`, terminal: 'ghostty' } })

/** Each live window in the feed's order, by writer: its session and its place in the order a jump tries the session's windows. */
const jumpPlaces = (read: ProjectRead[]) =>
  feedOf(read, NOW).windows.map(each => [each.writer, each.session, each.jumpOrder])

test("each window in the feed carries its place in the order a jump tries its session's windows: stopped on Lee, working, on its own work, then the rest; the windows still the longest attached first", () => {
  const session = sessionOf({
    presence: {
      ...windowOn('rest', yourTurn(T0 + 50 * MIN), whereFor('rest')),
      ...windowOn('own', onItsWork(T0 + 10 * MIN), { ...whereFor('own'), attachedAt: T0 + MIN }),
      ...windowOn('busy', working(T0 + 5 * MIN), { ...whereFor('busy'), attachedAt: T0 + 2 * MIN }),
      ...windowOn('stop', question(T0 + MIN, 'Which?', 1), {
        ...whereFor('stop'),
        attachedAt: T0 + 3 * MIN,
      }),
    },
  })

  expect(jumpPlaces([{ project: NORTHWIND, sessions: [session] }])).toEqual([
    ['rest', META.id, 3],
    ['own', META.id, 2],
    ['busy', META.id, 1],
    ['stop', META.id, 0],
  ])
})

test('within a rank the window whose state began last goes first, then the one attached last; one saying no state goes by its attach', () => {
  const session = sessionOf({
    presence: {
      ...windowOn('a', working(T0 + 10 * MIN), whereFor('a')),
      ...windowOn('b', working(T0 + 20 * MIN), whereFor('b')),
      ...windowOn('c', yourTurn(T0 + 30 * MIN), whereFor('c')),
      ...windowOn('d', yourTurn(T0 + 30 * MIN), { ...whereFor('d'), attachedAt: T0 + MIN }),
      ...windowOn('e', undefined, { ...whereFor('e'), attachedAt: T0 + 40 * MIN }),
      ...windowOn('f', permission(T0 + 5 * MIN, 'Bash'), whereFor('f')),
      ...windowOn('g', permission(T0 + 15 * MIN, 'Bash'), whereFor('g')),
    },
  })
  const orders = Object.fromEntries(
    jumpPlaces([{ project: NORTHWIND, sessions: [session] }]).map(([writer, , order]) => [
      writer,
      order,
    ]),
  )

  expect(orders).toEqual({ g: 0, f: 1, b: 2, a: 3, e: 4, d: 5, c: 6 })
})

test('a window saying no `where` has no place in the order, which no jump tries; those after it close up', () => {
  const session = sessionOf({
    presence: {
      ...windowOn('stop', permission(T0 + 5 * MIN, 'Bash')),
      ...windowOn('busy', working(T0 + MIN), whereFor('busy')),
      ...windowOn('rest', yourTurn(T0 + 2 * MIN), whereFor('rest')),
    },
  })

  expect(jumpPlaces([{ project: NORTHWIND, sessions: [session] }])).toEqual([
    ['busy', META.id, 0],
    ['rest', META.id, 1],
    ['stop', META.id, undefined],
  ])
})

test("each session's windows are ordered among themselves alone, another session's never counted", () => {
  const read: ProjectRead[] = [
    {
      project: NORTHWIND,
      sessions: [
        sessionOf({
          meta: { id: 'sr-aaaaaa' },
          presence: {
            ...windowOn('a1', yourTurn(T0 + 10 * MIN), whereFor('a1')),
            ...windowOn('a2', working(T0 + 20 * MIN), { ...whereFor('a2'), attachedAt: T0 + MIN }),
          },
        }),
      ],
    },
    {
      project: CONTOSO,
      sessions: [
        sessionOf({
          meta: { id: 'sr-bbbbbb' },
          presence: {
            ...windowOn('b1', permission(T0 + 30 * MIN, 'Bash'), {
              ...whereFor('b1'),
              attachedAt: T0 + 2 * MIN,
            }),
            ...windowOn('b2', yourTurn(T0 + 40 * MIN), { ...whereFor('b2'), attachedAt: T0 + 3 * MIN }),
          },
        }),
      ],
    },
  ]

  expect(jumpPlaces(read)).toEqual([
    ['a1', 'sr-aaaaaa', 1],
    ['a2', 'sr-aaaaaa', 0],
    ['b1', 'sr-bbbbbb', 0],
    ['b2', 'sr-bbbbbb', 1],
  ])
})

test("a window's place in the feed is the jump's: the CLI's jump tries the session's windows in that order", () => {
  const session = sessionOf({
    presence: {
      ...windowOn('a', yourTurn(T0 + 10 * MIN), whereFor('a')),
      ...windowOn('b', question(T0 + 5 * MIN, 'Which?', 1), whereFor('b')),
      ...windowOn('c', working(T0 + 20 * MIN), whereFor('c')),
      ...windowOn('d', working(T0 + 30 * MIN)),
    },
  })
  const fed = feedOf([{ project: NORTHWIND, sessions: [session] }], NOW)
    .windows.filter(each => each.jumpOrder !== undefined)
    .sort((a, b) => (a.jumpOrder ?? 0) - (b.jumpOrder ?? 0))

  expect(fed.map(each => each.where)).toEqual(windowsOf(session, NOW))
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
        project: { key: 'litware', name: 'Litware' },
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
    `stop:sr-eeeeee:${W3}:${NOW}`,
    'ask:sr-eeeeee:k3',
  ])
})

test('a stop is new by its window and when it showed: the same stop again is not, a later one is; an answered ask is not', () => {
  const stopped = (since: number) =>
    feedOf(
      [
        {
          project: NORTHWIND,
          sessions: [sessionOf({ presence: windowOn(W1, permission(since, 'Bash', 'ls')) })],
        },
      ],
      NOW,
    )
  const asked = (...lines: Line[]) =>
    feedOf([{ project: NORTHWIND, sessions: [sessionOf({ lines })] }], NOW)
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
        project: NORTHWIND,
        sessions: [sessionOf({ presence: windowOn(W1, permission(T0, 'Bash', 'ls')) })],
      },
    ],
    NOW,
  )
  const off = feedOf([{ project: NORTHWIND, sessions: [sessionOf()] }], NOW)
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
  const read = (sessions: Session[]): ProjectRead[] => [{ project: NORTHWIND, sessions }]

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

/** When the snoozes under test wake: two hours after NOW, and three. */
const WAKES = NOW + 120 * MIN
const WAKES_LATER = NOW + 180 * MIN

/** The review, posted at T0, and its session snoozed a minute after. */
const SNOOZED_REVIEW: Line[] = [
  [T0, yesAsk('k1', 'Review round 1')],
  [T0 + MIN, snoozeSession(WAKES, 'k1')],
]

const feedAt = (now: number, ...sessions: Session[]) =>
  feedOf([{ project: NORTHWIND, sessions }], now)

/** The keys of a feed's rows' lines, and of its Snoozed rows'. */
const placed = (feed: Feed) => ({
  rows: feed.rows.flatMap(row => row.lines.map(each => each.key)),
  snoozed: feed.snoozed.flatMap(row => row.lines.map(each => each.key)),
})

const K1 = `ask:${META.id}:k1`
const K2 = `ask:${META.id}:k2`
const K3 = `ask:${META.id}:k3`
const TURN_KEY = `turn:${META.id}`

/** The turn under test: W1's, ended at TURN, what Claude left Lee on the board. */
const TURN = T0 + 10 * MIN
const LEFT: Line = [T0, status(['Pick the palette'])]

/** W1 on its turn, ended at `since`, its heartbeat seen at `seenAt`. */
const onTurn = (since = TURN, seenAt = NOW) => windowOn(W1, yourTurn(since), { seenAt })

/** The review's session at Lee's turn, snoozed, then the lines given, held as `presence` says. */
const asleepWith = (more: Line[] = [], presence = onTurn(), inbox: SessionFiles['inbox'] = {}) =>
  sessionOf({ lines: [LEFT, ...SNOOZED_REVIEW, ...more], presence, inbox })

test('a session Lee snoozed needs Lee no more: its asks and its turn are one row in Snoozed, with no line in Needs you, no count and nothing in the head; it stands at your turn still', () => {
  const held = asleepWith()
  const feed = feedAt(NOW, held)

  expect([held.waiting, sessionState(held, NOW), rowFor(held)]).toEqual([0, 'yourTurn', undefined])
  expect([feed.rows, feed.head]).toEqual([[], { needYou: 0, sessions: 0 }])
  expect(feed.projects).toMatchObject([
    { waiting: 0, snoozed: 1, sessions: [{ waiting: 0, snoozed: 1, asks: [{ id: 'k1' }] }] },
  ])
  expect(feed.snoozed).toEqual([
    {
      session: META.id,
      isAway: false,
      project: NORTHWIND.key,
      name: META.name,
      projectName: 'Northwind',
      letters: 'No',
      lines: [
        {
          key: K1,
          is: 'ask',
          ask: 'k1',
          first: { lead: 'Review round 1' },
          since: T0,
          wakesAt: WAKES,
        },
        {
          key: TURN_KEY,
          is: 'yourTurn',
          first: { lead: 'Pick the palette' },
          since: TURN,
          wakesAt: WAKES,
        },
      ],
      second: 'Northwind · Help desk redesign',
      wakesAt: WAKES,
    },
  ])
  expect(snoozedTurnOf(held, NOW)).toEqual({ wakesAt: WAKES, end: TURN })
})

test('an away session Lee snoozed has no row, and its row in Snoozed, its asks alone, says no window holds it', () => {
  const away = sessionOf({ lines: SNOOZED_REVIEW })

  expect([sessionState(away, NOW), rowFor(away)]).toEqual(['away', undefined])
  expect(feedAt(NOW, away).snoozed).toMatchObject([
    { isAway: true, second: 'No window holds it. Carry it on in Claude.', lines: [{ key: K1 }] },
  ])
})

test('a session at its turn alone snoozes the same: its turn leaves Needs you for Snoozed, its time among the instants the board next changes by, and back at its time on the same end', () => {
  const asleep = (now: number) =>
    sessionOf(
      { lines: [LEFT, [TURN + MIN, snoozeSession(WAKES)]], presence: onTurn(TURN, now) },
      now,
    )
  const before = WAKES - 30_000

  expect(placed(feedAt(before, asleep(before)))).toEqual({ rows: [], snoozed: [TURN_KEY] })
  expect(nextBoardChange(asleep(before), before)).toBe(WAKES)
  expect(placed(feedAt(WAKES, asleep(WAKES)))).toEqual({ rows: [TURN_KEY], snoozed: [] })
  expect(rowFor(asleep(WAKES), NORTHWIND, WAKES)).toMatchObject({
    section: 'yourTurn',
    since: TURN,
  })
})

test("its turn ending alone never wakes it, however the turn began: working or on its own work, the session is in Working, its asks asleep beside it, and the next turn's end goes back to Snoozed", () => {
  const busy = asleepWith([], windowOn(W1, working(T0 + 30 * MIN)))
  const onItsOwn = asleepWith([], windowOn(W1, onItsWork(T0 + 40 * MIN)))
  const ended = asleepWith([], onTurn(T0 + 50 * MIN))

  expect(placed(feedAt(NOW, busy))).toEqual({ rows: [TURN_KEY], snoozed: [K1] })
  expect(rowFor(busy)?.section).toBe('working')
  expect(placed(feedAt(NOW, onItsOwn))).toEqual({ rows: [TURN_KEY], snoozed: [K1] })
  expect(placed(feedAt(NOW, ended))).toEqual({ rows: [], snoozed: [K1, TURN_KEY] })
  expect(feedAt(NOW, ended).snoozed[0]?.lines[1]).toMatchObject({
    since: T0 + 50 * MIN,
    wakesAt: WAKES,
  })
})

test('a window joining wakes nothing: on a turn ended later, the session stays in Snoozed, its turn the later one', () => {
  const joined = asleepWith([], {
    ...onTurn(),
    ...windowOn(W2, yourTurn(T0 + 40 * MIN), { attachedAt: T0 + 40 * MIN }),
  })

  expect(placed(feedAt(NOW, joined))).toEqual({ rows: [], snoozed: [K1, TURN_KEY] })
  expect(feedAt(NOW, joined).snoozed[0]?.lines[1]?.since).toBe(T0 + 40 * MIN)
})

test("a new ask wakes it, and so do an ask's reopening and Lee's reply to one of its asks: back in Needs you, the asks it put off with it; a window's stop shows in Needs you beside it, never snoozed", () => {
  const both: Line[] = [
    LEFT,
    [T0, yesAsk('k1', 'Review round 1')],
    [T0, yesAsk('k2', 'Ship it')],
    [T0 + MIN, snoozeSession(WAKES, 'k1', 'k2')],
  ]
  const at = (more: Line[], inbox: SessionFiles['inbox'] = {}) =>
    placed(feedAt(NOW, sessionOf({ lines: [...both, ...more], presence: onTurn(), inbox })))
  const stopped = asleepWith([], windowOn(W1, permission(T0 + 30 * MIN, 'Bash', 'git push')))

  expect(at([]), 'asleep, k2 posted before it').toEqual({ rows: [], snoozed: [K1, K2, TURN_KEY] })
  expect(at([[T0 + 2 * MIN, yesAsk('k3', 'Tag it')]]), 'an ask posted').toEqual({
    rows: [K3, K1, K2],
    snoozed: [],
  })
  expect(
    at([
      [T0 + 2 * MIN, resolve('k2')],
      [T0 + 3 * MIN, reopen('k2')],
    ]),
    'an ask reopened',
  ).toEqual({ rows: [K2, K1], snoozed: [] })
  expect(
    at([], { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k2', 'yes')]) }),
    'Lee replying to one',
  ).toEqual({ rows: [K1], snoozed: [] })
  expect(placed(feedAt(NOW, stopped))).toEqual({
    rows: [`stop:${META.id}:${W1}:${T0 + 30 * MIN}`],
    snoozed: [K1],
  })
})

test("Lee's wake ends it before its time, back as it was; a snooze again stands in place of the last", () => {
  expect(placed(feedAt(NOW, asleepWith([[T0 + 2 * MIN, wakeSession()]])))).toEqual({
    rows: [K1],
    snoozed: [],
  })
  expect(
    feedAt(NOW, asleepWith([[T0 + 2 * MIN, snoozeSession(WAKES_LATER, 'k1')]])).snoozed[0]?.wakesAt,
  ).toBe(WAKES_LATER)
})

test("Snoozed's rows go soonest to wake first, those snoozed until they move last, then the oldest, whatever their ids, and so do a row's lines; a row wakes as its soonest line; a finished session has none", () => {
  const sessions = [
    sessionOf({
      meta: { id: 'sr-bbbbbb' },
      lines: [
        [T0, yesAsk('k1', 'Oldest')],
        [T0 + 2 * MIN, yesAsk('k2', 'Newest')],
        [T0 + MIN, yesAsk('k3', 'Between')],
        [T0 + 3 * MIN, snoozeSession(WAKES, 'k1', 'k2', 'k3')],
      ],
    }),
    sessionOf({
      meta: { id: 'sr-aaaaaa' },
      lines: [
        [T0 + 5 * MIN, yesAsk('k1', 'Newer row')],
        [T0 + 6 * MIN, snoozeSession(WAKES, 'k1')],
      ],
    }),
    sessionOf({
      meta: { id: 'sr-cccccc' },
      lines: [
        [T0 + 9 * MIN, yesAsk('k1', 'Soonest')],
        [T0 + 9 * MIN, snoozeSession(NOW + MIN, 'k1')],
      ],
    }),
    sessionOf({
      meta: { id: 'sr-dddddd' },
      lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, finish('lee')]],
    }),
    sessionOf({
      meta: { id: 'sr-eeeeee' },
      lines: [[T0 + 21 * MIN, snoozeTurn(T0 + 20 * MIN)]],
      presence: windowOn(W1, yourTurn(T0 + 20 * MIN)),
    }),
    sessionOf({
      meta: { id: 'sr-ffffff' },
      lines: [[T0 + 21 * MIN, snoozeSession(WAKES_LATER)]],
      presence: windowOn(W1, yourTurn(T0 + 20 * MIN)),
    }),
    sessionOf({
      meta: { id: 'sr-gggggg' },
      lines: [[T0 + 21 * MIN, snoozeSession(undefined)]],
      presence: windowOn(W1, yourTurn(T0 + 20 * MIN)),
    }),
  ]
  const snoozed = feedAt(NOW, ...sessions).snoozed

  expect(
    snoozed.map(row => [row.session, row.wakesAt, row.lines.map(each => each.ask ?? each.is)]),
  ).toEqual([
    ['sr-cccccc', NOW + MIN, ['k1']],
    ['sr-bbbbbb', WAKES, ['k1', 'k3', 'k2']],
    ['sr-aaaaaa', WAKES, ['k1']],
    ['sr-ffffff', WAKES_LATER, ['yourTurn']],
    ['sr-eeeeee', undefined, ['yourTurn']],
    ['sr-gggggg', undefined, ['yourTurn']],
  ])
  expect(snoozedRowOf(NORTHWIND, sessions[3]!, NOW)).toBeUndefined()
})

test("a Snoozed line counts from its ask's posting or reopening, as in Needs you", () => {
  const session = sessionOf({
    lines: [
      [T0, yesAsk('k1', 'Review round 1')],
      [T0 + MIN, resolve('k1')],
      [T0 + 5 * MIN, reopen('k1')],
      [T0 + 6 * MIN, snoozeSession(WAKES, 'k1')],
    ],
  })

  expect(snoozedRowOf(NORTHWIND, session, NOW)?.lines.map(each => each.since)).toEqual([
    T0 + 5 * MIN,
  ])
})
test('an ask back from its snooze at its time is a line in Needs you again, carrying when it woke; one Lee woke carries none', () => {
  const woke = sessionOf({ lines: SNOOZED_REVIEW }, WAKES)
  const woken = sessionOf({ lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, wakeSession()]] })

  expect(lines(woke)).toEqual([
    {
      key: `ask:${META.id}:k1`,
      is: 'ask',
      ask: 'k1',
      first: { lead: 'Review round 1' },
      since: T0,
      woke: WAKES,
    },
  ])
  expect(lines(woken)[0]).not.toHaveProperty('woke')
})

test('a line in Snoozed is kept as shown however long it sleeps, its absence never making it new: woken at its time it is new, woken by Lee it is not', () => {
  const key = `ask:${META.id}:k1`
  const waiting = feedAt(NOW, sessionOf({ lines: [[T0, yesAsk('k1', 'Review round 1')]] }))
  const asleep = feedAt(NOW, sessionOf({ lines: SNOOZED_REVIEW }))
  const woke = feedAt(WAKES, sessionOf({ lines: SNOOZED_REVIEW }, WAKES))
  const woken = feedAt(
    NOW,
    sessionOf({ lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, wakeSession()]] }),
  )
  const shown = newRows(newRows(undefined, waiting, 0).shown, asleep, 0)
  const slept = newRows(shown.shown, asleep, 9 * FORGET_MS).shown

  expect([shown.news, [...shown.shown]]).toEqual([[], [[key, ASLEEP]]])
  expect([...slept]).toEqual([[key, ASLEEP]])
  expect(newRows(slept, woke, 9 * FORGET_MS).news).toEqual([key])
  expect(newRows(slept, woken, 9 * FORGET_MS).news).toEqual([])
  expect(
    newRows(newRows(undefined, asleep, 0).shown, woke, FORGET_MS).news,
    'asleep since the watch began',
  ).toEqual([key])
  expect(newRows(newRows(slept, woke, 0).shown, woke, 0).news, 'new once').toEqual([])
})

test('an ask Lee replied to while asleep, waking its session, leaves Snoozed as a line gone; back in Needs you as its snooze ran out, it comes as shown, not new', () => {
  const key = `ask:${META.id}:k1`
  const answered = { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) }
  const asleep = feedAt(NOW, sessionOf({ lines: SNOOZED_REVIEW }))
  const onItsWay = feedAt(NOW, sessionOf({ lines: SNOOZED_REVIEW, inbox: answered }))
  const takenBack = feedAt(WAKES, sessionOf({ lines: SNOOZED_REVIEW }, WAKES))
  const gone = newRows(newRows(undefined, asleep, 0).shown, onItsWay, MIN)

  expect([onItsWay.rows, onItsWay.snoozed, gone.news, [...gone.shown]]).toEqual([
    [],
    [],
    [],
    [[key, MIN]],
  ])
  expect(newRows(gone.shown, takenBack, 2 * MIN).news).toEqual([])
})

test('a snooze running out changes the board by time alone: its time is among the instants it next changes, but once Lee replied to an ask there, waking it, or in a finished session', () => {
  const read = (...sessions: Session[]): ProjectRead[] => [{ project: NORTHWIND, sessions }]

  expect(nextExpiry(read(sessionOf({ lines: SNOOZED_REVIEW })), NOW)).toBe(WAKES)
  expect(
    nextExpiry(
      read(
        sessionOf({ lines: SNOOZED_REVIEW }),
        sessionOf({
          meta: { id: 'sr-bbbbbb' },
          lines: [
            [T0, yesAsk('k1', 'Sooner')],
            [T0, snoozeSession(NOW + MIN, 'k1')],
          ],
        }),
      ),
      NOW,
    ),
  ).toBe(NOW + MIN)
  expect(
    nextExpiry(
      read(
        sessionOf({
          lines: SNOOZED_REVIEW,
          presence: windowOn(W1, yourTurn(T0), { seenAt: NOW - MIN }),
        }),
      ),
      NOW,
    ),
    'a heartbeat going stale first',
  ).toBe(NOW - MIN + STALE_MS + 1)
  expect(
    nextExpiry(
      read(
        sessionOf({
          lines: SNOOZED_REVIEW,
          inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) },
        }),
      ),
      NOW,
    ),
  ).toBeUndefined()
  expect(
    nextExpiry(read(sessionOf({ lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, finish('lee')]] })), NOW),
  ).toBeUndefined()
})

test("a session's part of the board next changes by time alone at the first of its own instants, and the board's at the first session's", () => {
  const stale = sessionOf({
    lines: SNOOZED_REVIEW,
    presence: windowOn(W1, yourTurn(T0), { seenAt: NOW - MIN }),
  })
  const idle = sessionOf({ meta: { id: 'sr-bbbbbb' }, lines: [[T0 + MIN, status(['Idle'])]] })
  const finished = sessionOf({ lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, finish('lee')]] })

  expect(nextBoardChange(stale, NOW), 'its heartbeat going stale, before its snooze').toBe(
    NOW - MIN + STALE_MS + 1,
  )
  expect(nextBoardChange(sessionOf({ lines: SNOOZED_REVIEW }), NOW)).toBe(WAKES)
  expect(nextBoardChange(idle, NOW)).toBe(T0 + MIN + CURRENT_MS + 1)
  expect(nextBoardChange(finished, NOW)).toBeUndefined()
  expect(nextExpiry([{ project: NORTHWIND, sessions: [idle, stale, finished] }], NOW)).toBe(
    NOW - MIN + STALE_MS + 1,
  )
})

test("a session's fold next changes by time alone as its board does, and as Lee's snooze standing on its asks runs out, as in a finished session, whose board leaves it out", () => {
  const finished = (now: number) =>
    sessionOf({ lines: [...SNOOZED_REVIEW, [T0 + 2 * MIN, finish('lee')]] }, now)
  const stale = sessionOf({
    lines: SNOOZED_REVIEW,
    presence: windowOn(W1, yourTurn(T0), { seenAt: NOW - MIN }),
  })

  expect(nextBoardChange(finished(NOW), NOW)).toBeUndefined()
  expect(nextFoldChange(finished(NOW), NOW)).toBe(WAKES)
  expect(finished(WAKES - 1), 'folded the same until then').toEqual(finished(NOW))
  expect(finished(WAKES), 'folded otherwise then').not.toEqual(finished(NOW))
  expect(nextFoldChange(stale, NOW), 'its board changing first').toBe(NOW - MIN + STALE_MS + 1)
  expect(nextFoldChange(sessionOf({ lines: [[T0, yesAsk('k1', 'Keep me')]] }), NOW)).toBeUndefined()
})

/** The session at `now`, Claude's board as LEFT says it, then Lee's lines, held as `presence` says. */
const turnAt = (now: number, snoozes: Line[], presence = onTurn(TURN, now)) =>
  sessionOf({ lines: [LEFT, ...snoozes], presence }, now)

/** Both asks put off by old lines, written together, and the session at its turn. */
const OLD_ROW: Line[] = [
  LEFT,
  [T0, yesAsk('k1', 'Review round 1')],
  [T0, yesAsk('k2', 'Ship it')],
  [T0 + MIN, snooze('k1', WAKES)],
  [T0 + MIN, snooze('k2', WAKES_LATER)],
]

test("old lines' snoozes of every ask waiting on Lee put its turn off with them, in one row, until the first wakes or closes; an ask left showing leaves its row in Needs you", () => {
  const then = (now: number, lines: Line[]) =>
    placed(feedAt(now, sessionOf({ lines, presence: onTurn(TURN, now) }, now)))

  expect(then(NOW, OLD_ROW)).toEqual({ rows: [], snoozed: [K1, TURN_KEY, K2] })
  expect(
    snoozedTurnOf(sessionOf({ lines: OLD_ROW, presence: onTurn() }), NOW),
    'waking as the first does',
  ).toEqual({ wakesAt: WAKES, end: TURN })
  expect(then(WAKES, OLD_ROW), 'the first woken').toEqual({ rows: [K1], snoozed: [K2] })
  expect(then(NOW, [...OLD_ROW, [T0 + 2 * MIN, resolve('k1')]]), 'the first resolved').toEqual({
    rows: [TURN_KEY],
    snoozed: [K2],
  })
  expect(then(NOW, [...OLD_ROW, [T0 + 2 * MIN, wake('k1')]]), 'the first woken by Lee').toEqual({
    rows: [K1],
    snoozed: [K2],
  })
  expect(then(NOW, OLD_ROW.slice(0, -1)), 'k2 left showing').toEqual({ rows: [K2], snoozed: [K1] })
})

test('a row snoozed until it moves, its Claude still working, has no time to wake at, nor one the board next changes by; the wake its turn ending writes brings it back, the ask winning its row', () => {
  const moves: Line[] = [
    LEFT,
    [T0, yesAsk('k1', 'Review round 1')],
    [T0 + MIN, snoozeSession(undefined, 'k1')],
  ]
  const busy = windowOn(W1, working(T0 + 30 * MIN))
  const asleep = sessionOf({ lines: moves, presence: busy })
  const ended = (more: Line[]) =>
    placed(feedAt(NOW, sessionOf({ lines: [...moves, ...more], presence: onTurn(T0 + 50 * MIN) })))

  expect(placed(feedAt(NOW, asleep))).toEqual({ rows: [TURN_KEY], snoozed: [K1] })
  expect(feedAt(NOW, asleep).snoozed[0]).not.toHaveProperty('wakesAt')
  expect(nextBoardChange(asleep, NOW)).toBe(
    nextBoardChange(sessionOf({ lines: moves.slice(0, 2), presence: busy }), NOW),
  )
  expect(ended([[T0 + 50 * MIN, wakeSession()]])).toEqual({ rows: [K1], snoozed: [] })
  expect(ended([]), 'with no wake written, as by a window not reloaded').toEqual({
    rows: [],
    snoozed: [K1, TURN_KEY],
  })
})

const SNOOZED_TURN: Line[] = [[TURN + MIN, snoozeTurn(TURN, WAKES)]]

test("an old line's snooze of a turn holds as it always did: until its time, or with none until the session takes another turn, which comes back unsnoozed", () => {
  const before = WAKES - 30_000
  const untilItMoves: Line[] = [[TURN + MIN, snoozeTurn(TURN)]]
  const later = NOW + 30 * 24 * 60 * MIN

  expect(placed(feedAt(before, turnAt(before, SNOOZED_TURN)))).toEqual({
    rows: [],
    snoozed: [TURN_KEY],
  })
  expect(nextBoardChange(turnAt(before, SNOOZED_TURN), before)).toBe(WAKES)
  expect(placed(feedAt(WAKES, turnAt(WAKES, SNOOZED_TURN)))).toEqual({
    rows: [TURN_KEY],
    snoozed: [],
  })
  const [row] = feedAt(later, turnAt(later, untilItMoves)).snoozed

  expect(row?.lines.map(each => each.key)).toEqual([TURN_KEY])
  expect(row).not.toHaveProperty('wakesAt')
  expect(row?.lines[0]).not.toHaveProperty('wakesAt')
  expect(
    placed(feedAt(NOW, turnAt(NOW, untilItMoves, onTurn(T0 + 50 * MIN)))),
    'another turn ended',
  ).toEqual({
    rows: [TURN_KEY],
    snoozed: [],
  })
  expect(
    placed(
      feedAt(
        NOW,
        turnAt(NOW, untilItMoves, { ...onTurn(TURN), ...windowOn(W2, yourTurn(TURN + 7 * MIN)) }),
      ),
    ),
    'a window joining on a turn ended later',
  ).toEqual({ rows: [TURN_KEY], snoozed: [] })
})

test("an old line's snooze of a turn ends at Lee's wake of it, or of the session, at a new ask or his reply; Lee's snooze of the session stands in its place", () => {
  const then = (...lines: Line[]) => placed(feedAt(NOW, turnAt(NOW, [...SNOOZED_TURN, ...lines])))
  const back = { rows: [TURN_KEY], snoozed: [] }
  const shipIt: Line = [TURN + 2 * MIN, yesAsk('k2', 'Ship it')]

  expect(then([TURN + 2 * MIN, wakeTurn(TURN)])).toEqual(back)
  expect(then([TURN + 2 * MIN, wakeTurn(TURN - MIN)]), 'naming another turn').toEqual({
    rows: [],
    snoozed: [TURN_KEY],
  })
  expect(then([TURN + 2 * MIN, wakeSession()])).toEqual(back)
  expect(then(shipIt, [TURN + 3 * MIN, resolve('k2')]), 'an ask posted, then resolved').toEqual(
    back,
  )
  expect(
    turnAt(NOW, [...SNOOZED_TURN, [TURN + 2 * MIN, snoozeSession(WAKES_LATER)]]).turnSnooze,
  ).toBeUndefined()
  expect(
    snoozedTurnOf(
      turnAt(NOW, [...SNOOZED_TURN, [TURN + 2 * MIN, snoozeSession(WAKES_LATER)]]),
      NOW,
    ),
  ).toEqual({ wakesAt: WAKES_LATER, end: TURN })
})

test('a snooze of the session and an old one of its turn both holding, the turn wakes as the later does, none for one until it moves', () => {
  const both = (turn: Line) =>
    snoozedTurnOf(turnAt(NOW, [[T0 + MIN, snoozeSession(WAKES)], turn]), NOW)

  expect(both([TURN + MIN, snoozeTurn(TURN, WAKES_LATER)])).toEqual({
    wakesAt: WAKES_LATER,
    end: TURN,
  })
  expect(both([TURN + MIN, snoozeTurn(TURN, NOW + MIN)])).toEqual({ wakesAt: WAKES, end: TURN })
  expect(both([TURN + MIN, snoozeTurn(TURN)])).toEqual({ end: TURN })
})

test("Lee's snooze of a session at its turn alone is never told to Claude: its board text, its summary as Claude is told it and when it was last updated stand as with none, snoozed or woken", () => {
  const plain = turnAt(NOW, [])
  const snoozed: Line[] = [[TURN + MIN, snoozeSession(WAKES)]]

  for (const session of [
    turnAt(NOW, snoozed),
    turnAt(NOW, [...snoozed, [TURN + 2 * MIN, wakeSession()]]),
    turnAt(NOW, SNOOZED_TURN),
  ]) {
    expect(boardText(session)).toBe(boardText(plain))
    expect(toldSummary(session)).toEqual(toldSummary(plain))
    expect(session.updatedAt).toBe(plain.updatedAt)
  }
})

test('a turn in Snoozed is never a line needing Lee: never kept asleep among those shown, and never new as it comes back', () => {
  const snoozed: Line[] = [[TURN + MIN, snoozeSession(WAKES)]]
  const asleep = feedAt(NOW, turnAt(NOW, snoozed))
  const back = feedAt(WAKES, turnAt(WAKES, snoozed))
  const shown = newRows(newRows(undefined, asleep, 0).shown, asleep, MIN)

  expect([shown.news, [...shown.shown]]).toEqual([[], []])
  expect(newRows(shown.shown, back, 2 * MIN).news).toEqual([])
})
