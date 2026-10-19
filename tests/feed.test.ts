import { expect, test } from 'claude-code/testing'
import {
  CURRENT_MS,
  feedOf,
  foldSession,
  headOf,
  inPanelOrder,
  lettersOf,
  manifestVersion,
  metaText,
  needsReload,
  newRows,
  nextExpiry,
  rowsOf,
  sessionState,
  STALE_MS,
  type Presence,
  type Project,
  type ProjectRead,
  type Row,
  type Session,
  type SessionFiles,
  type SessionMeta,
  type ToolShown,
  type WindowState,
} from '../core'
import {
  beat,
  file,
  finish,
  META,
  MIN,
  park,
  reopen,
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

/** A session folded at `now` from its meta, the lines its window wrote, and the heartbeats given. */
const sessionOf = (
  {
    meta = {},
    lines = [],
    presence = {},
  }: { meta?: Partial<SessionMeta>; lines?: Line[]; presence?: SessionFiles['presence'] } = {},
  now = NOW,
): Session => {
  const session = foldSession(
    { meta: metaText({ ...META, ...meta }), logs: { [W1]: file(...lines) }, presence },
    now,
  )

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const rows = (session: Session, project = SWITCHBOARD, now = NOW) => rowsOf(project, session, now)

const firstLines = (session: Session) => rows(session).map(row => row.first)

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
  expect(rows(session).map(row => [row.is, row.writer, row.since])).toEqual([
    ['yourTurn', W1, T0 + 5 * MIN],
  ])
})

test('of several windows on a session the most needing wins: a stop, then working, then your turn', () => {
  const both = (a: WindowState, b: WindowState) =>
    sessionState(sessionOf({ presence: { ...windowOn(W1, a), ...windowOn(W2, b) } }), NOW)

  expect(both(yourTurn(T0), permission(T0, 'Bash', 'ls'))).toBe('needsYou')
  expect(both(working(T0), question(T0, 'Left?', 1))).toBe('needsYou')
  expect(both(yourTurn(T0), working(T0))).toBe('working')
  expect(both(yourTurn(T0), yourTurn(T0 + MIN))).toBe('yourTurn')
})

test('an ask is a row of its own: its title, its project and session, its posting, dimmed while away', () => {
  const held = sessionOf({
    lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]],
    presence: windowOn(W1, working(T0)),
  })
  const away = sessionOf({ lines: [[T0 + MIN, yesAsk('k1', 'Review round 1')]] })

  expect(rows(held)).toEqual([
    {
      key: `ask:${META.id}:k1`,
      is: 'ask',
      isAway: false,
      session: META.id,
      project: 'switchboard',
      letters: 'Sw',
      ask: 'k1',
      first: { lead: 'Review round 1' },
      second: 'Switchboard · Dashboard redesign',
      since: T0 + MIN,
    },
  ])
  expect(rows(away).map(row => [row.key, row.isAway])).toEqual([[`ask:${META.id}:k1`, true]])
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

  expect(rows(session).map(row => [row.ask, row.since])).toEqual([['k1', T0 + 3 * MIN]])
})

test('a permission prompt reads "Allow" and its tool, the subject in mono, since it showed', () => {
  const session = sessionOf({
    presence: windowOn(W1, permission(T0 + 5 * MIN, 'Bash', 'gh pr create --draft')),
  })

  expect(rows(session)).toEqual([
    {
      key: `stop:${META.id}:${W1}:${T0 + 5 * MIN}`,
      is: 'permission',
      isAway: false,
      session: META.id,
      project: 'switchboard',
      letters: 'Sw',
      writer: W1,
      first: { lead: 'Allow Bash', mono: 'gh pr create --draft' },
      second: 'Switchboard · Dashboard redesign',
      since: T0 + 5 * MIN,
    },
  ])
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

test('each stopped window is a row; a session needing Lee shows only those rows, never its working one', () => {
  const session = sessionOf({
    lines: [[T0, yesAsk('k1', 'Review it')]],
    presence: {
      ...windowOn(W1, working(T0, { name: 'Read', subject: '/tmp/a' })),
      ...windowOn(W2, permission(T0 + MIN, 'Bash', 'ls')),
      ...windowOn(W3, question(T0 + 2 * MIN, 'Left?', 1)),
    },
  })

  expect(rows(session).map(row => [row.is, row.writer])).toEqual([
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
    rows(sessionOf({ presence: windowOn(W1, working(T0, tool)) }), project)[0]?.first

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
    rows(
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

test('a session is one row while its windows work or wait on Lee: the latest started working, else the latest to end its turn', () => {
  const rowOf = (a: WindowState, b: WindowState) =>
    rows(sessionOf({ presence: { ...windowOn(W1, a), ...windowOn(W2, b) } })).map(row => [
      row.key,
      row.is,
      row.writer,
      row.since,
    ])

  expect(rowOf(working(T0), working(T0 + MIN))).toEqual([
    [`turn:${META.id}`, 'working', W2, T0 + MIN],
  ])
  expect(rowOf(working(T0 + MIN), yourTurn(T0 + 2 * MIN))).toEqual([
    [`turn:${META.id}`, 'working', W1, T0 + MIN],
  ])
  expect(rowOf(yourTurn(T0 + 2 * MIN), yourTurn(T0 + MIN))).toEqual([
    [`turn:${META.id}`, 'yourTurn', W1, T0 + 2 * MIN],
  ])
})

test('an away session with nothing waiting has no row, nor has a finished one, whatever it holds', () => {
  expect(rows(sessionOf({ lines: [[T0, park('p1', 'Later')]] }))).toEqual([])
  expect(
    rows(
      sessionOf({
        lines: [
          [T0, yesAsk('k1', 'Review it')],
          [T0 + MIN, finish('lee')],
        ],
        presence: windowOn(W1, question(T0, 'Left?', 2)),
      }),
    ),
  ).toEqual([])
})

/** A row of the kind given, its time and away-ness, the rest made up. */
const row = (key: string, is: Row['is'], since: number, isAway = false): Row => ({
  key,
  is,
  isAway,
  session: key,
  project: 'p',
  letters: 'Pp',
  first: { lead: key },
  second: 'P · s',
  since,
})

test('the rows in order: needs you oldest first, away ones last; then your turn, newest first; then working, longest running first', () => {
  const shuffled = [
    row('working-new', 'working', T0 + 5 * MIN),
    row('turn-old', 'yourTurn', T0 + MIN),
    row('away-new', 'ask', T0 + 4 * MIN, true),
    row('ask-new', 'ask', T0 + 3 * MIN),
    row('working-old', 'working', T0 + MIN),
    row('away-old', 'ask', T0, true),
    row('permission-old', 'permission', T0 + MIN),
    row('turn-new', 'yourTurn', T0 + 6 * MIN),
    row('question', 'question', T0 + 2 * MIN),
  ]

  expect(inPanelOrder(shuffled).map(each => each.key)).toEqual([
    'permission-old',
    'question',
    'ask-new',
    'away-old',
    'away-new',
    'turn-new',
    'turn-old',
    'working-old',
    'working-new',
  ])
})

test('the head counts the rows needing Lee, away ones among them, and the sessions the rows hold', () => {
  expect(
    headOf([
      { ...row('a', 'ask', T0), session: 's1' },
      { ...row('b', 'ask', T0, true), session: 's2' },
      { ...row('c', 'permission', T0), session: 's1' },
      { ...row('d', 'working', T0), session: 's3' },
    ]),
  ).toEqual({ needYou: 3, sessions: 3 })
  expect(headOf([row('d', 'yourTurn', T0)])).toEqual({ needYou: 0, sessions: 1 })
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
  expect(feed.rows.map(each => each.key)).toEqual(['ask:sr-dddddd:k2', 'turn:sr-aaaaaa'])
  expect(
    feed.projects.map(project => [
      project.key,
      project.waiting,
      project.open,
      project.sessions.map(session => [
        session.id,
        session.state,
        session.since,
        session.asks.map(ask => ask.id),
      ]),
    ]),
  ).toEqual([
    ['goosemates', 1, 1, [['sr-dddddd', 'needsYou', T0 + 10 * MIN, ['k2']]]],
    [
      'switchboard',
      0,
      1,
      [
        ['sr-aaaaaa', 'working', T0, []],
        ['sr-bbbbbb', 'away', T0 + 30 * MIN, []],
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

test('what is new: a row needing Lee the board before had not; nothing on the first board, nor a working or your turn row', () => {
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

  expect(newRows(undefined, before)).toEqual([])
  expect(newRows(before, before)).toEqual([])
  expect(newRows(before, after)).toEqual(['ask:sr-eeeeee:k3', `stop:sr-eeeeee:${W3}:${NOW}`])
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

  expect(newRows(stopped(T0), stopped(T0))).toEqual([])
  expect(newRows(stopped(T0), stopped(T0 + MIN))).toEqual([`stop:${META.id}:${W1}:${T0 + MIN}`])
  expect(
    newRows(
      asked([T0, yesAsk('k1', 'Review it')]),
      asked([T0, yesAsk('k1', 'Review it')], [T0 + MIN, resolve('k1')]),
    ),
  ).toEqual([])
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
})
