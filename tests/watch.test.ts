import { expect, test } from './kit'
import type { Io } from '../cli/io'
import { EXIT, main } from '../cli/main'
import { OFF_BOARD_MS, POLL_MS } from '../cli/watch'
import {
  append,
  metaText,
  projectPaths,
  projectsDir,
  STALE_MS,
  type Body,
  type Presence,
  type SessionPaths,
  type Where,
  type WindowState,
} from '../core'
import {
  beat,
  delivered,
  file,
  finish,
  kindAsk,
  META,
  MIN,
  note,
  park,
  reply,
  SLOW,
  snoozeSession,
  snoozeTurn,
  status,
  T0,
  unfinish,
  W1,
  W2,
  W3,
  wakeSession,
  yesAsk,
  type Line,
} from './support'
import { CLI_VERSION, MANIFEST, manifestText, NOW, terminal } from './terminal'
import { ELSEWHERE, PROJECT, REPO, ROOT, WHERE } from './world'

type Terminal = ReturnType<typeof terminal>

/** A session's board as a watch line carries it: the fields the tests look at. */
type Board = {
  v: number
  project: { key: string }
  session: { id: string; name: string; isOpen: boolean }
  log: { id: string | null; text: string }[]
}

const HOUR = 60 * MIN

/** Another session of Northwind's, no window holding it. */
const LOBBY = { ...META, id: 'sr-bbbbbb', name: 'Lobby' }

/**
 * What a test does at one of the watch's waits: to the files, or to its
 * standard input, once the wait's time has passed; or, `atOnce`, as the wait
 * is under way, before any of its time passes, the wait then going on
 * unless what it did cut it short.
 */
type Step = (() => void) | { atOnce: () => void }

/** A watch line, as read back: the fields the tests look at. */
type Printed = {
  at: number
  version: string | null
  head: { needYou: number; sessions: number }
  rows: {
    session: string
    section: string
    isAway: boolean
    lines: { key: string; is: string; first: { lead: string } }[]
  }[]
  snoozed: { session: string; lines: { key: string }[]; wakesAt: number }[]
  projects: {
    sessions: {
      id: string
      name: string
      isOpen: boolean
      state: string
      asks: { reply: unknown; snoozedUntil: number | null }[]
    }[]
  }[]
  windows: {
    writer: string
    version: string | null
    needsReload: boolean
    where: unknown
    state: { is: string } | null
    jumpOrder: number | null
  }[]
  new: string[]
  boards: Record<string, Board | null>
}

const still = () => {}

/** Steps that change nothing, a look each. */
const looks = (count: number) => Array.from({ length: count }, () => still)

/** A wait that never ends: one cancelled, as the shell's never ends once cancelled, or the last. */
const never = () => new Promise<void>(() => {})

/**
 * `sitrep watch` over the terminal's files, `fs` standing in for any of its
 * file system's calls and `ending` for the listening for its end, the steps
 * taken in turn, one at each wait, and then its standard output closed, the
 * wait under way then never ending unless cancelled. What its standard input
 * held comes in at each wait, before its step, as a pipe's does on a turn
 * after the run began to listen; a wait it cuts short takes no step. How it
 * ended, what it told on standard error, each line it printed, read back,
 * and whether it left that wait holding the run.
 */
const watched = async (
  t: Terminal,
  steps: readonly Step[],
  { fs = {}, ending = t.io.ending }: { fs?: Partial<Io['fs']>; ending?: Io['ending'] } = {},
) => {
  const queue = [...steps]
  let out = ''
  let err = ''
  let last: { isCancelled: boolean } | undefined
  const waited = async (ms: number, waiting: { isCancelled: boolean }) => {
    await Promise.resolve()
    t.arrives()

    if (waiting.isCancelled) {
      return never()
    }

    const step = queue.shift()

    if (step !== undefined && 'atOnce' in step) {
      step.atOnce()

      if (waiting.isCancelled) {
        return never()
      }
    }

    await t.io.wait(ms)

    if (step === undefined) {
      last = waiting
      t.close()

      return never()
    }

    if (typeof step === 'function') {
      step()
    }

    return waiting.isCancelled ? never() : undefined
  }
  const io: Io = {
    ...t.io,
    fs: { ...t.io.fs, ...fs },
    ending,
    out: text => {
      out += text
    },
    err: text => {
      err += text
    },
    wait: ms => {
      const waiting = { isCancelled: false }

      return Object.assign(waited(ms, waiting), {
        cancel: () => {
          waiting.isCancelled = true
        },
      })
    },
  }
  const exit = await main(['watch'], io)
  const lines = out
    .split('\n')
    .filter(line => line !== '')
    .map(line => JSON.parse(line) as Printed)

  return { exit, err, lines, isWaitHeld: last !== undefined && !last.isCancelled }
}

/** Lines a writer appends to its file at `path`, as the clock stands. */
const appendTo = (t: Terminal, path: string, ...bodies: Body[]) => {
  const now = t.io.now()

  t.files.set(path, { text: append(t.files.get(path)?.text ?? '', bodies, now).text, mtimeMs: now })
}

/** Lines the CLI appends to the session's file, as the clock stands. */
const post = (t: Terminal, paths: SessionPaths, ...bodies: Body[]) =>
  appendTo(t, paths.log('cli'), ...bodies)

/** A window's heartbeat rewritten as the clock stands, saying `state`: attached at T0 and seen now, on the CLI's version, unless `times` says otherwise. */
const beatOn = (
  t: Terminal,
  paths: SessionPaths,
  writer: string,
  state?: WindowState,
  times: Partial<Omit<Presence, 'writer' | 'state'>> = {},
) => {
  const now = t.io.now()

  t.files.set(paths.heartbeat(writer), {
    text: beat(writer, { attachedAt: T0, seenAt: now, version: CLI_VERSION, state, ...times }),
    mtimeMs: now,
  })
}

/** The keys of a watch line's lines, its rows' in order. */
const keys = (line: Printed | undefined) =>
  line?.rows.flatMap(row => row.lines.map(each => each.key))

/** A watch line's first row's first line. */
const firstLine = (line: Printed | undefined) => line?.rows[0]?.lines[0]

/** The app following these sessions, a line on the watch's standard input. */
const follow = (t: Terminal, ...ids: string[]) => t.send(`${JSON.stringify({ follow: ids })}\n`)

/** The sessions whose boards a watch line carries. */
const carried = (line: Printed | undefined) => Object.keys(line?.boards ?? {})

/** Northwind, living in REPO, and the session under test there holding `lines`, its window W1 on screen and on your turn. */
const held = (lines: Line[] = [], options: Parameters<typeof terminal>[0] = {}) => {
  const t = terminal(options)

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, { lines })

  beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { seenAt: NOW, where: WHERE })

  return { t, paths }
}

test('the first line is the board as every surface shows it, with nothing new, no board while nothing is followed, and no load stamp', async () => {
  const t = terminal()

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, {
    lines: [
      [T0, status(['Drawing Inbox'])],
      [T0, yesAsk('k1', 'Review round 1')],
    ],
  })

  beatOn(
    t,
    paths,
    W1,
    {
      is: 'working',
      since: T0,
      tool: { name: 'Read', subject: `${REPO}/src/Mail/MessageQueue.php` },
    },
    { seenAt: NOW, where: WHERE, directory: REPO, loadedAt: T0 },
  )

  const { exit, err, lines } = await watched(t, [])

  expect({ exit, err }).toEqual({ exit: EXIT.done, err: '' })
  expect(lines).toEqual([
    {
      v: 3,
      at: NOW,
      version: CLI_VERSION,
      head: { needYou: 1, sessions: 1 },
      rows: [
        {
          session: META.id,
          section: 'needsYou',
          isAway: false,
          project: PROJECT.key,
          name: 'Help desk redesign',
          projectName: 'Northwind',
          letters: 'No',
          lines: [
            {
              key: `ask:${META.id}:k1`,
              is: 'ask',
              ask: 'k1',
              writer: null,
              first: { lead: 'Review round 1', mono: null, subject: null, more: null, until: null },
              since: T0,
            },
          ],
          second: 'Northwind · Help desk redesign',
          since: T0,
        },
      ],
      snoozed: [],
      projects: [
        {
          key: PROJECT.key,
          name: PROJECT.name,
          directory: REPO,
          open: 1,
          waiting: 1,
          snoozed: 0,
          parked: 0,
          updatedAt: T0,
          sessions: [
            {
              id: META.id,
              name: META.name,
              summary: META.summary,
              now: ['Drawing Inbox'],
              next: null,
              isOpen: true,
              waiting: 1,
              snoozed: 0,
              parked: 0,
              created: META.created,
              updatedAt: T0,
              state: 'needsYou',
              since: T0,
              doing: {
                is: 'working',
                line: {
                  lead: 'Reading',
                  mono: 'src/Mail/MessageQueue.php',
                  subject: null,
                  more: null,
                  until: null,
                },
                since: T0,
              },
              asks: [
                {
                  id: 'k1',
                  wants: 'yes',
                  yes: 'Approve',
                  title: 'Review round 1',
                  where: null,
                  options: [],
                  recommended: null,
                  needs: null,
                  ref: null,
                  state: 'waiting',
                  at: T0,
                  reply: null,
                  snoozedUntil: null,
                  untilItMoves: false,
                },
              ],
              parkedItems: [],
              lastWindow: null,
            },
          ],
        },
      ],
      windows: [
        {
          writer: W1,
          session: META.id,
          name: META.name,
          project: PROJECT.name,
          version: CLI_VERSION,
          needsReload: false,
          where: { device: WHERE.device, terminal: WHERE.terminal, tmux: null, zmx: null },
          directory: REPO,
          state: {
            is: 'working',
            since: T0,
            tool: { name: 'Read', subject: `${REPO}/src/Mail/MessageQueue.php` },
            question: null,
          },
          attachedAt: T0,
          jumpOrder: 0,
        },
      ],
      new: [],
      boards: {},
    },
  ])
})

test("a window on its own work is a row of that kind after working, its line saying what it waits on, a wake's by when it is due, which the app counts down to", async () => {
  const { t, paths } = held()
  const lobby = t.seed(LOBBY)
  const wakesAt = NOW + 12 * MIN

  beatOn(
    t,
    paths,
    W1,
    { is: 'onItsWork', since: T0, work: { agents: { count: 3, first: 'Review the diff' } } },
    { seenAt: NOW },
  )
  beatOn(
    t,
    lobby,
    W2,
    { is: 'onItsWork', since: T0 + MIN, work: { wakes: { count: 1, at: wakesAt } } },
    { seenAt: NOW },
  )

  const [line] = (await watched(t, [])).lines
  const printed = line as unknown as {
    rows: { session: string; section: string; lines: { is: string; first: unknown }[] }[]
    projects: { sessions: { state: string; doing: { is: string; line: unknown } }[] }[]
  }

  expect(
    printed.rows.map(row => [row.session, row.section, row.lines.map(each => [each.is, each.first])]),
  ).toEqual([
    [
      LOBBY.id,
      'working',
      [['onItsWork', { lead: 'Wakes', mono: null, subject: null, more: null, until: wakesAt }]],
    ],
    [
      META.id,
      'working',
      [
        [
          'onItsWork',
          { lead: 'Waiting on', mono: null, subject: '3 agents', more: null, until: null },
        ],
      ],
    ],
  ])
  expect(printed.projects[0]?.sessions.map(each => [each.state, each.doing.is])).toEqual([
    ['onItsWork', 'onItsWork'],
    ['onItsWork', 'onItsWork'],
  ])
  expect(line?.windows.map(window => window.state?.is)).toEqual(['onItsWork', 'onItsWork'])
})

test('every session on a line carries what it parked, as board --json lists it, and when it started, though no board is followed', async () => {
  const { t } = held([[T0 + MIN, park('p1', 'A priority badge')]])

  t.seed(
    { ...LOBBY, created: T0 - HOUR },
    {
      lines: [
        [
          T0 + 2 * MIN,
          park('p1', 'Retry the export', { where: 'After the release', ref: 'PR #82' }),
        ],
      ],
    },
  )

  const [line] = (await watched(t, [])).lines
  const printed = line as unknown as {
    projects: { sessions: { id: string; created: number; parkedItems: unknown[] }[] }[]
    boards: Record<string, unknown>
  }

  expect(printed.boards).toEqual({})
  expect(
    printed.projects[0]?.sessions.map(each => [each.id, each.created, each.parkedItems]),
  ).toEqual([
    [
      META.id,
      META.created,
      [{ id: 'p1', title: 'A priority badge', where: null, ref: null, at: T0 + MIN }],
    ],
    [
      LOBBY.id,
      T0 - HOUR,
      [
        {
          id: 'p1',
          title: 'Retry the export',
          where: 'After the release',
          ref: 'PR #82',
          at: T0 + 2 * MIN,
        },
      ],
    ],
  ])
})

test("a line's projects count every item parked in them, finished and idle sessions' included, each session's parkedItems its own; one with only parked items is carried, its sessions empty, dated by the sessions holding them", async () => {
  const { t } = held([[T0 + MIN, park('p1', 'A priority badge')]])
  const old = T0 - 8 * 24 * HOUR

  t.seed(LOBBY, {
    lines: [
      [T0, park('p1', 'Theme the lobby')],
      [T0 + MIN, finish('lee')],
    ],
  })
  t.seed(
    { ...LOBBY, id: 'sr-cccccc', name: 'An old idea', project: 'stale', created: old },
    { project: 'stale', lines: [[old, park('p1', 'Export the ledger as CSV')]] },
  )

  const [line] = (await watched(t, [])).lines
  const printed = line as unknown as {
    projects: {
      key: string
      parked: number
      updatedAt: number
      sessions: { id: string; parked: number; parkedItems: { title: string }[] }[]
    }[]
  }

  expect(printed.projects).toMatchObject([
    {
      key: PROJECT.key,
      parked: 2,
      sessions: [
        { id: META.id, parked: 1, parkedItems: [{ title: 'A priority badge' }] },
      ],
    },
    { key: 'stale', parked: 1, sessions: [], updatedAt: old },
  ])
})

test('a post is a line at the next look, its board carried; a new ask is new on that line alone', async () => {
  const { t, paths } = held()

  follow(t, META.id)

  const { lines } = await watched(t, [
    () => post(t, paths, yesAsk('k2', 'Try it on the iPad', 'It works')),
    still,
    () => post(t, paths, note('n1', 'Round 3 drawn')),
  ])

  expect(lines.map(line => [line.at, keys(line), line.new, carried(line)])).toEqual([
    [NOW, [`turn:${META.id}`], [], []],
    [NOW, [`turn:${META.id}`], [], [META.id]],
    [NOW + POLL_MS, [`ask:${META.id}:k2`], [`ask:${META.id}:k2`], [META.id]],
    [NOW + 3 * POLL_MS, [`ask:${META.id}:k2`], [], [META.id]],
  ])
})

test("an answer going into the session's inbox is a line, its ask on its way, needing Lee no more, and its board carried; the window's mark is another, the ask gone", async () => {
  const { t, paths } = held([[T0, yesAsk('k1', 'Give the go for stage 3', 'Go')]])

  follow(t, META.id)

  const { lines } = await watched(t, [
    () => appendTo(t, paths.letters('cli'), reply('r1', 'k1', 'yes')),
    still,
    () => appendTo(t, paths.log(W1), delivered('r1')),
  ])
  const replies = lines.map(line =>
    line.projects
      .flatMap(project => project.sessions)
      .flatMap(session => session.asks.map(ask => ask.reply)),
  )

  expect(lines.map(line => [line.at, keys(line), line.head, carried(line)])).toEqual([
    [NOW, [`ask:${META.id}:k1`], { needYou: 1, sessions: 1 }, []],
    [NOW, [`ask:${META.id}:k1`], { needYou: 1, sessions: 1 }, [META.id]],
    [NOW + POLL_MS, [`turn:${META.id}`], { needYou: 0, sessions: 1 }, [META.id]],
    [NOW + 3 * POLL_MS, [`turn:${META.id}`], { needYou: 0, sessions: 1 }, [META.id]],
  ])
  expect(replies).toEqual([
    [null],
    [null],
    [{ is: 'onItsWay', isAnswer: true, words: '→ Go', since: NOW + POLL_MS }],
    [],
  ])
})

test("watch's isAnswer is the bar's own fact: an old decide's comment on its way is its answer, and only a comment once an edit makes it want a yes", async () => {
  const { t, paths } = held([
    [T0, kindAsk('k7', 'decide', 'Keep the ledger 400 days, or forever?')],
  ])
  const { lines } = await watched(t, [
    () => appendTo(t, paths.letters('cli'), reply('r1', 'k7', 'comment', { note: 'Forever' })),
    still,
    () => appendTo(t, paths.log(W1), { type: 'edit', item: 'k7', changes: { wants: 'yes' } }),
  ])
  const replies = lines.map(line =>
    line.projects
      .flatMap(project => project.sessions)
      .flatMap(session => session.asks.map(ask => ask.reply)),
  )

  expect(replies).toMatchObject([
    [null],
    [{ is: 'onItsWay', isAnswer: true, words: 'answer: “Forever”' }],
    [{ is: 'onItsWay', isAnswer: false, words: 'comment: “Forever”' }],
  ])
})

test('nothing changed is no line: a heartbeat beating on, saying what it said, prints nothing', async () => {
  const { t, paths } = held()
  const beatAgain = () => beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { where: WHERE })
  const { lines } = await watched(t, [
    ...looks(29),
    beatAgain,
    ...looks(29),
    beatAgain,
    ...looks(5),
  ])

  expect(lines.map(line => line.at)).toEqual([NOW])
})

test(
  'a heartbeat going stale is a line the moment it does, though no file changed',
  SLOW,
  async () => {
    const { t } = held()

    follow(t, META.id)

    const { lines } = await watched(t, looks(100))

    expect(
      lines.map(line => [
        line.at,
        keys(line),
        line.projects[0]?.sessions[0]?.state,
        line.windows.map(window => window.writer),
        carried(line),
      ]),
    ).toEqual([
      [NOW, [`turn:${META.id}`], 'yourTurn', [W1], []],
      [NOW, [`turn:${META.id}`], 'yourTurn', [W1], [META.id]],
      [NOW + STALE_MS + 1, [], 'away', [], [META.id]],
    ])
  },
)

/** The keys of a watch line's Snoozed lines, its rows' in order. */
const asleep = (line: Printed | undefined) =>
  line?.snoozed.flatMap(row => row.lines.map(each => each.key))

test('a snooze running out is a line the moment it does, though no file changed: its ask back in Needs you and new, its board carried', async () => {
  const wakes = NOW + 2_500
  const { t } = held([
    [T0, yesAsk('k1', 'Review round 1')],
    [T0 + MIN, snoozeSession(wakes, 'k1')],
  ])

  follow(t, META.id)

  const { lines } = await watched(t, looks(4))
  const k1 = `ask:${META.id}:k1`
  const turn = `turn:${META.id}`

  expect(lines.map(line => [line.at, keys(line), asleep(line), line.new, carried(line)])).toEqual([
    [NOW, [], [k1, turn], [], []],
    [NOW, [], [k1, turn], [], [META.id]],
    [wakes, [k1], [], [k1], [META.id]],
  ])
  expect(lines[0]?.snoozed, "the row as DESIGN's example prints it").toEqual([
    {
      session: META.id,
      isAway: false,
      project: PROJECT.key,
      name: META.name,
      projectName: PROJECT.name,
      letters: 'No',
      lines: [
        {
          key: k1,
          is: 'ask',
          ask: 'k1',
          first: { lead: 'Review round 1', mono: null, subject: null, more: null, until: null },
          since: T0,
          wakesAt: wakes,
        },
        {
          key: turn,
          is: 'yourTurn',
          ask: null,
          first: { lead: META.summary, mono: null, subject: null, more: null, until: null },
          since: T0,
          wakesAt: wakes,
        },
      ],
      second: 'Northwind · Help desk redesign',
      wakesAt: wakes,
    },
  ])
  expect(lines.map(line => line.projects[0]?.sessions[0]?.asks[0]?.snoozedUntil)).toEqual([
    wakes,
    wakes,
    null,
  ])
})

test('a snooze posted is a line, its ask and its turn in Snoozed and nothing new; woken by Lee, it is back in Needs you, nothing new either', async () => {
  const { t, paths } = held([[T0, yesAsk('k1', 'Review round 1')]])

  follow(t, META.id)

  const { lines } = await watched(t, [
    () => post(t, paths, snoozeSession(NOW + 9 * HOUR, 'k1')),
    still,
    () => post(t, paths, wakeSession()),
  ])
  const k1 = `ask:${META.id}:k1`

  expect(lines.map(line => [line.at, keys(line), asleep(line), line.new, carried(line)])).toEqual([
    [NOW, [k1], [], [], []],
    [NOW, [k1], [], [], [META.id]],
    [NOW + POLL_MS, [], [k1, `turn:${META.id}`], [], [META.id]],
    [NOW + 3 * POLL_MS, [k1], [], [], [META.id]],
  ])
})

test("a session at its turn snoozed is a line, its row leaving the rows for Snoozed, nothing new; working, it is in Working, and the window's next turn ending leaves it in Snoozed", async () => {
  const { t, paths } = held()
  const turn = `turn:${META.id}`
  const { lines } = await watched(t, [
    () => post(t, paths, snoozeSession(NOW + 9 * HOUR)),
    () => beatOn(t, paths, W1, { is: 'working', since: NOW + 2 * POLL_MS }),
    () => beatOn(t, paths, W1, { is: 'yourTurn', since: NOW + 3 * POLL_MS }),
  ])

  expect(
    lines.map(line => [line.rows.map(row => row.section), keys(line), asleep(line), line.new]),
  ).toEqual([
    [['yourTurn'], [turn], [], []],
    [[], [], [turn], []],
    [['working'], [turn], [], []],
    [[], [], [turn], []],
  ])
})

test("an old line's snooze of a turn is a line, its row leaving the rows for Snoozed, nothing new; the window's next turn ends it, back in the rows", async () => {
  const { t, paths } = held()
  const turn = `turn:${META.id}`
  const { lines } = await watched(t, [
    () => post(t, paths, snoozeTurn(T0)),
    () => beatOn(t, paths, W1, { is: 'working', since: NOW + 2 * POLL_MS }),
    () => beatOn(t, paths, W1, { is: 'yourTurn', since: NOW + 3 * POLL_MS }),
  ])

  expect(
    lines.map(line => [line.rows.map(row => row.section), keys(line), asleep(line), line.new]),
  ).toEqual([
    [['yourTurn'], [turn], [], []],
    [[], [], [turn], []],
    [['working'], [turn], [], []],
    [['yourTurn'], [turn], [], []],
  ])
  expect(lines[1]?.snoozed, 'a turn snoozed until it moves, as DESIGN prints it').toEqual([
    {
      session: META.id,
      isAway: false,
      project: PROJECT.key,
      name: META.name,
      projectName: PROJECT.name,
      letters: 'No',
      lines: [
        {
          key: turn,
          is: 'yourTurn',
          ask: null,
          first: { lead: META.summary, mono: null, subject: null, more: null, until: null },
          since: T0,
          wakesAt: null,
        },
      ],
      second: 'Northwind · Help desk redesign',
      wakesAt: null,
    },
  ])
})

test('a window stopping on Lee is new once; its prompt answered, the window working, is new no more', async () => {
  const { t, paths } = held()
  const { lines } = await watched(t, [
    () =>
      beatOn(t, paths, W1, {
        is: 'permission',
        since: NOW + POLL_MS,
        tool: { name: 'Bash', subject: 'gh pr create' },
      }),
    () =>
      beatOn(t, paths, W1, {
        is: 'working',
        since: NOW,
        tool: { name: 'Bash', subject: 'gh pr create' },
      }),
  ])
  const stop = `stop:${META.id}:${W1}:${NOW + POLL_MS}`

  expect(lines.map(line => [keys(line), firstLine(line)?.first.lead, line.new])).toEqual([
    [[`turn:${META.id}`], META.summary, []],
    [[stop], 'Allow Bash', [stop]],
    [[`turn:${META.id}`], 'Running', []],
  ])
})

test('a heartbeat caught torn is passed over: the window stands as last read until its file reads whole', async () => {
  const { t, paths } = held()
  const torn = () => {
    const now = t.io.now()

    t.files.set(paths.heartbeat(W1), { text: '{"attachedAt":1760000000000,"seen', mtimeMs: now })
  }
  const { lines } = await watched(t, [
    torn,
    still,
    () => beatOn(t, paths, W1, { is: 'working', since: NOW }, { where: WHERE }),
  ])

  expect(lines.map(line => [line.at, keys(line), firstLine(line)?.is])).toEqual([
    [NOW, [`turn:${META.id}`], 'yourTurn'],
    [NOW + 3 * POLL_MS, [`turn:${META.id}`], 'working'],
  ])
})

test('a mod’s file caught mid-rewrite, holding only the start of its lines, is passed over: no ask drops off, and none comes back as new', async () => {
  const { t, paths } = held([
    [T0, yesAsk('k1', 'Review round 1')],
    [T0, yesAsk('k2', 'Run the apply', 'Done')],
  ])
  const whole = t.text(paths.log(W1))
  const rewrite = (text: string) => () => t.files.set(paths.log(W1), { text, mtimeMs: t.io.now() })
  const added = file(
    [T0, yesAsk('k1', 'Review round 1')],
    [T0, yesAsk('k2', 'Run the apply', 'Done')],
    [NOW, yesAsk('k3', 'Try it')],
  )
  const { lines } = await watched(t, [
    rewrite(whole.slice(0, whole.indexOf('\n') + 1)),
    rewrite(''),
    rewrite(added),
  ])

  expect(lines.map(line => [keys(line), line.new])).toEqual([
    [[`ask:${META.id}:k1`, `ask:${META.id}:k2`], []],
    [[`ask:${META.id}:k3`, `ask:${META.id}:k1`, `ask:${META.id}:k2`], [`ask:${META.id}:k3`]],
  ])
})

test('at rest a look lists no folder: one is listed again only once an entry is made or removed in it, so a session started shows at the next look', async () => {
  const { t } = held()
  const listed: string[] = []
  const list: Io['fs']['list'] = async dir => {
    listed.push(dir)

    return t.io.fs.list(dir)
  }
  const counts: number[] = []
  const count = () => {
    counts.push(listed.length)
  }
  const { lines } = await watched(t, [still, count, still, still, count, () => t.seed(LOBBY)], {
    fs: { list },
  })

  expect(counts[1]).toBe(counts[0])
  expect(
    lines.map(line => [line.at, line.projects[0]?.sessions.map(session => session.id)]),
  ).toEqual([
    [NOW, [META.id]],
    [NOW + 6 * POLL_MS, [META.id, LOBBY.id]],
  ])
})

test('a session off the board is read again every 10 seconds: a finished one joined again shows at the first such look', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [
      [T0, yesAsk('k1', 'Review round 1')],
      [T0, finish('claude')],
    ],
  })
  const join = () => {
    post(t, paths, unfinish())
    beatOn(t, paths, W2, { is: 'yourTurn', since: t.io.now() }, { attachedAt: t.io.now() })
  }
  const { lines } = await watched(t, [join, ...looks(12)])

  expect(lines.map(line => [line.at, keys(line), line.new])).toEqual([
    [NOW, [], []],
    [NOW + OFF_BOARD_MS, [`ask:${META.id}:k1`], [`ask:${META.id}:k1`]],
  ])
})

test('a folder it cannot look in ends the watch with a sitrep: line, for the app to start it again', async () => {
  const { t } = held()
  const projects = projectsDir(ROOT)
  let stats = 0
  const stat: Io['fs']['stat'] = async path => {
    stats += path === projects ? 1 : 0

    if (stats > 3) {
      throw new Error(`EACCES: permission denied, stat '${path}'`)
    }

    return t.io.fs.stat(path)
  }
  const { exit, err, lines } = await watched(t, looks(10), { fs: { stat } })

  expect(exit).toBe(EXIT.refused)
  expect(err).toBe(`sitrep: EACCES: permission denied, stat '${projects}'\n`)
  expect(lines.length).toBe(1)
})

test('a file it cannot read is passed over for the look, its last whole text standing; never fatal', async () => {
  const { t, paths } = held()
  const heartbeat = paths.heartbeat(W1)
  let isLocked = false
  const read: Io['fs']['read'] = async path =>
    isLocked && path === heartbeat
      ? Promise.reject(new Error(`EACCES: permission denied, open '${path}'`))
      : t.io.fs.read(path)
  const { exit, err, lines } = await watched(
    t,
    [
      () => {
        isLocked = true
        beatOn(t, paths, W1, { is: 'working', since: NOW }, { where: WHERE })
      },
      still,
      () => {
        isLocked = false
      },
    ],
    { fs: { read } },
  )

  expect({ exit, err }).toEqual({ exit: EXIT.done, err: '' })
  expect(lines.map(line => [line.at, firstLine(line)?.is])).toEqual([
    [NOW, 'yourTurn'],
    [NOW + 3 * POLL_MS, 'working'],
  ])
})

test('watch takes nothing but --help, which says what it prints', async () => {
  const t = terminal()

  expect(await t.run('watch', 'now')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: It takes nothing, not "now". sitrep watch --help says more.\n',
  })
  expect((await t.run('watch', '--help')).out).toContain('Usage: sitrep watch\n')
})

/** W1 stopped on a permission prompt since NOW, as its heartbeat says. */
const PROMPT: WindowState = {
  is: 'permission',
  since: NOW,
  tool: { name: 'Bash', subject: 'gh pr create' },
}

const STOP = `stop:${META.id}:${W1}:${NOW}`

test(
  'a stop gone stale and beating again, saying what it said, is not new again: the watch has shown it',
  SLOW,
  async () => {
    const { t, paths } = held()

    beatOn(t, paths, W1, PROMPT, { seenAt: NOW, where: WHERE })

    const { lines } = await watched(t, [
      ...looks(STALE_MS / POLL_MS + 1),
      () => beatOn(t, paths, W1, PROMPT, { where: WHERE }),
    ])

    expect(lines.map(line => [line.at, keys(line), line.new])).toEqual([
      [NOW, [STOP], []],
      [NOW + STALE_MS + 1, [], []],
      [NOW + STALE_MS + 1 + POLL_MS, [STOP], []],
    ])
  },
)

test(
  'the Mac asleep past a heartbeat’s time, the wall clock moving and the uptime not, ages it not: its stop stands through the wake, and goes stale only once the rest of its time has run after',
  SLOW,
  async () => {
    let slept = 0
    const { t, paths } = held([], { now: () => NOW + slept })

    beatOn(t, paths, W1, PROMPT, { seenAt: NOW, where: WHERE })

    const { lines } = await watched(t, [
      () => {
        slept = HOUR
      },
      ...looks(STALE_MS / POLL_MS + 1),
    ])

    expect(lines.map(line => [line.at, keys(line), line.new])).toEqual([
      [NOW, [STOP], []],
      [NOW + HOUR + STALE_MS + 1, [], []],
    ])
  },
)

test(
  'looks held back over and over, as App Nap would, both clocks moving alike, age a heartbeat as ever: a window gone goes stale at the first look past its time',
  SLOW,
  async () => {
    let stalled = 0
    const { t } = held([], { now: () => NOW + stalled, uptime: () => stalled })
    const stall = () => {
      stalled += 5_000
    }
    const { lines } = await watched(
      t,
      Array.from({ length: 20 }, () => stall),
    )

    expect(lines.map(line => [line.at, keys(line)])).toEqual([
      [NOW, [`turn:${META.id}`]],
      [NOW + STALE_MS + 1 + 5_000, []],
    ])
  },
)

test('a manifest caught torn as the watch starts gives no version until it reads whole, which is then the one it runs, not a move', async () => {
  const { t } = held([], { manifest: '{"name":"sitrep","vers' })
  const rewrite = (version: string) => () =>
    t.files.set(MANIFEST, { text: manifestText(version), mtimeMs: t.io.now() })
  const { exit, lines } = await watched(t, [
    rewrite(CLI_VERSION),
    still,
    rewrite('0.3.0'),
    ...looks(3),
  ])

  expect({ exit, waits: t.waits.length }).toEqual({ exit: EXIT.done, waits: 3 })
  expect(lines.map(line => [line.at, line.version])).toEqual([
    [NOW, null],
    [NOW + POLL_MS, CLI_VERSION],
  ])
})

test('a session gone, and then its project, nothing else changing, is gone from the next line', async () => {
  const { t } = held()
  const lobby = t.seed(LOBBY)
  const gone = (dir: string) => () => {
    for (const path of [...t.files.keys()].filter(each => each.startsWith(`${dir}/`))) {
      t.files.delete(path)
    }
  }
  const { lines } = await watched(t, [gone(lobby.dir), gone(projectPaths(ROOT, PROJECT.key).dir)])

  expect(
    lines.map(line => [line.at, line.projects.map(each => each.sessions.map(({ id }) => id))]),
  ).toEqual([
    [NOW, [[META.id, LOBBY.id]]],
    [NOW + POLL_MS, [[META.id]]],
    [NOW + 2 * POLL_MS, []],
  ])
})

test('a file rewritten at the same size within the same second is read again: its time moved', async () => {
  const { t, paths } = held()
  const before = t.files.get(paths.meta)
  const renamed = metaText({ ...META, name: 'Help desk reframed' })

  expect(renamed.length).toBe(before?.text.length)

  const { lines } = await watched(t, [
    () => t.files.set(paths.meta, { text: renamed, mtimeMs: (before?.mtimeMs ?? 0) + 400 }),
  ])

  expect(lines.map(line => [line.at, line.projects[0]?.sessions[0]?.name])).toEqual([
    [NOW, META.name],
    [NOW + POLL_MS, 'Help desk reframed'],
  ])
})

test('a manifest come to say another version ends the watch, exit 0, printing nothing more; one rewritten saying the same goes on', async () => {
  const { t, paths } = held()
  const rewrite = (version: string) => () =>
    t.files.set(MANIFEST, { text: manifestText(version), mtimeMs: t.io.now() })
  const { exit, err, lines } = await watched(t, [
    rewrite(CLI_VERSION),
    () => {
      rewrite('0.3.0')()
      post(t, paths, yesAsk('k2', 'Try it'))
    },
    ...looks(5),
  ])

  expect({ exit, err, waits: t.waits.length }).toEqual({ exit: EXIT.done, err: '', waits: 2 })
  expect(lines.map(line => [line.at, line.version])).toEqual([[NOW, CLI_VERSION]])
})

test('the run’s end is listened for once, not at each wait: a long watch holds nothing more for it', async () => {
  const { t } = held()
  let listens = 0
  const ending = () => {
    const { ended, stop } = t.io.ending()
    const heard = ended.then(() => {})
    const then = heard.then.bind(heard)

    Object.defineProperty(heard, 'then', {
      value: (...args: Parameters<typeof then>) => {
        listens += 1

        return then(...args)
      },
    })

    return { ended: heard, stop }
  }

  expect(await watched(t, looks(30), { ending })).toMatchObject({ exit: EXIT.done, err: '' })
  expect(listens).toBe(1)
})

test('however the watch ends, it stops listening for its end and lets its wait go, either of which would hold the run open: its end come, another version, a failure', async () => {
  const ended = held()
  const updated = held()
  const failing = held()
  const stat: Io['fs']['stat'] = async path => {
    if (path === projectsDir(ROOT)) {
      throw new Error(`EACCES: permission denied, stat '${path}'`)
    }

    return failing.t.io.fs.stat(path)
  }

  const runs = [
    await watched(ended.t, looks(2)),
    await watched(updated.t, [
      () => updated.t.files.set(MANIFEST, { text: manifestText('0.3.0'), mtimeMs: NOW }),
    ]),
    await watched(failing.t, looks(2), { fs: { stat } }),
  ]

  expect(runs.map(({ exit, isWaitHeld }) => ({ exit, isWaitHeld }))).toEqual([
    { exit: EXIT.done, isWaitHeld: false },
    { exit: EXIT.done, isWaitHeld: false },
    { exit: EXIT.refused, isWaitHeld: false },
  ])
  expect([ended, updated, failing].map(({ t }) => t.listening())).toEqual([0, 0, 0])
})

test('a state folder not there yet, as before any Claude window has written, is an empty board, not a failure: what comes into it shows', async () => {
  const t = terminal()
  const { exit, err, lines } = await watched(t, [
    () => {
      t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })
      t.seed(META)
    },
  ])

  expect({ exit, err }).toEqual({ exit: EXIT.done, err: '' })
  expect(
    lines.map(line => [line.at, line.projects.map(each => each.sessions.map(({ id }) => id))]),
  ).toEqual([
    [NOW, []],
    [NOW + POLL_MS, [[META.id]]],
  ])
})

test('a finished session’s live window is heard at each look, not with the sessions off the board', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: [[T0, finish('claude')]] })

  beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { seenAt: NOW })

  const { lines } = await watched(t, [
    () => beatOn(t, paths, W1, { is: 'working', since: t.io.now() }),
  ])

  expect(lines.map(line => [line.at, line.windows.map(window => window.state?.is)])).toEqual([
    [NOW, ['yourTurn']],
    [NOW + POLL_MS, ['working']],
  ])
})

/** A session's board as `board --json` prints it, as the clock stands. */
const boardJsonOf = async (t: Terminal, id: string) =>
  JSON.parse((await t.run('board', '--json', '--session', id)).out) as Board

/** The name on a session's board a watch line carries: null where it carries null, undefined where it carries none. */
const nameIn = (line: Printed | undefined, id: string) => {
  const board = line?.boards[id]

  return board === null ? null : board?.session.name
}

/** The texts of the log lines of a session's board a watch line carries. */
const logOf = (line: Printed | undefined, id: string) =>
  line?.boards[id]?.log.map(each => each.text)

test("the boards of the sessions followed as the watch starts come on the line their follow line's look prints: standard input is heard only after the first look, so the first line carries none", async () => {
  const { t } = held()
  const board = await boardJsonOf(t, META.id)

  follow(t, META.id)

  const { lines } = await watched(t, [])

  expect(lines.map(line => [line.at, line.boards])).toEqual([
    [NOW, {}],
    [NOW, { [META.id]: board }],
  ])
})

test('a follow line prints the boards of the sessions new to the set at once, as board --json gives them; a line is whole at its newline, however it comes', async () => {
  const { t } = held()

  t.seed(LOBBY)

  const helpDesk = await boardJsonOf(t, META.id)
  const lobby = await boardJsonOf(t, LOBBY.id)
  const { lines } = await watched(t, [
    {
      atOnce: () => {
        t.send('{"follow":')
        t.send(`["${META.id}"]}\n`)
      },
    },
    { atOnce: () => follow(t, META.id, LOBBY.id) },
  ])

  expect(lines.map(line => [line.at, line.boards])).toEqual([
    [NOW, {}],
    [NOW, { [META.id]: helpDesk }],
    [NOW, { [LOBBY.id]: lobby }],
  ])
})

test('several follow lines heard at once wake one look, the last one’s set standing', async () => {
  const { t } = held()
  const projects = projectsDir(ROOT)
  const looksBefore: number[] = []
  let looked = 0
  const stat: Io['fs']['stat'] = async path => {
    looked += path === projects ? 1 : 0

    return t.io.fs.stat(path)
  }

  t.seed(LOBBY)

  const { lines } = await watched(
    t,
    [
      {
        atOnce: () =>
          t.send(
            `${JSON.stringify({ follow: [META.id] })}\n${JSON.stringify({ follow: [LOBBY.id] })}\n`,
          ),
      },
      () => looksBefore.push(looked),
    ],
    { fs: { stat } },
  )

  expect(lines.map(line => [line.at, carried(line)])).toEqual([
    [NOW, []],
    [NOW, [LOBBY.id]],
  ])
  expect(looksBefore, 'the first look, and the one the lines woke').toEqual([2])
})

test('a session two projects file under one id is carried as board --json gives it: the first project’s', async () => {
  const { t } = held()

  t.project(ELSEWHERE.key, { name: ELSEWHERE.name, created: T0, by: W1 })
  t.seed({ ...META, name: 'A copy elsewhere' }, { project: ELSEWHERE.key })

  const board = await boardJsonOf(t, META.id)

  follow(t, META.id)

  const { lines } = await watched(t, [])

  expect([board.project.key, board.session.name]).toEqual([PROJECT.key, META.name])
  expect(lines[1]?.boards[META.id]).toEqual(board)
})

test("a followed session's board changing is printed though the board every surface shows does not; an unfollowed one's changing prints nothing", async () => {
  const { t, paths } = held()
  const lobby = t.seed(LOBBY)
  /** A note dated as its session's last line, so that its board changes and nothing else does. */
  const noted = (at: SessionPaths) => () =>
    t.files.set(at.log('cli'), {
      text: append('', [note('n1', 'Round 3 drawn')], T0).text,
      mtimeMs: t.io.now(),
    })

  follow(t, META.id)

  const { lines } = await watched(t, [noted(lobby), noted(paths)])

  expect(lines.map(line => [line.at, carried(line), logOf(line, META.id)])).toEqual([
    [NOW, [], undefined],
    [NOW, [META.id], []],
    [NOW + 2 * POLL_MS, [META.id], ['Round 3 drawn']],
  ])
})

test(
  'a carried board is folded as the line is, no heartbeat aged by the Mac’s sleep: after a sleep it agrees with the line’s own session, where board --json run then does not',
  SLOW,
  async () => {
    let slept = 0
    const { t, paths } = held([], { now: () => NOW + slept })

    follow(t, META.id)

    const { lines } = await watched(t, [
      () => {
        slept = HOUR
      },
      () => post(t, paths, note('n1', 'After the sleep')),
    ])
    const woken = lines.at(-1)
    const run = await boardJsonOf(t, META.id)

    expect([
      woken?.at,
      logOf(woken, META.id)?.[0],
      woken?.boards[META.id]?.session.isOpen,
      woken?.projects[0]?.sessions[0]?.isOpen,
      run.session.isOpen,
    ]).toEqual([NOW + HOUR + 2 * POLL_MS, 'After the sleep', true, true, false])
  },
)

test('a followed session the watch finds none of is null, printed once: one no project files, or one whose session.json does not fold; once it folds, its board', async () => {
  const { t } = held()
  const lobby = t.seed(LOBBY)
  const whole = t.text(lobby.meta)
  const unknown = 'sr-zzzzzz'

  t.files.set(lobby.meta, { text: whole.slice(0, 10), mtimeMs: T0 })

  const { lines } = await watched(t, [
    { atOnce: () => follow(t, unknown, LOBBY.id) },
    still,
    () => t.files.set(lobby.meta, { text: whole, mtimeMs: t.io.now() }),
  ])

  expect(lines.map(line => [line.at, nameIn(line, unknown), nameIn(line, LOBBY.id)])).toEqual([
    [NOW, undefined, undefined],
    [NOW, null, null],
    [NOW + 2 * POLL_MS, undefined, LOBBY.name],
  ])
})

test('a followed session gone is null, printed once', async () => {
  const { t } = held()
  const lobby = t.seed(LOBBY)
  const gone = () => {
    for (const path of [...t.files.keys()].filter(each => each.startsWith(`${lobby.dir}/`))) {
      t.files.delete(path)
    }
  }

  follow(t, LOBBY.id)

  const { lines } = await watched(t, [gone, ...looks(2)])

  expect(lines.map(line => [line.at, carried(line), nameIn(line, LOBBY.id)])).toEqual([
    [NOW, [], undefined],
    [NOW, [LOBBY.id], LOBBY.name],
    [NOW + POLL_MS, [LOBBY.id], null],
  ])
})

test('a follow line heard while a look is under way, too late for it, has the next look come at once', async () => {
  const { t } = held()
  const projects = projectsDir(ROOT)
  let stats = 0
  const stat: Io['fs']['stat'] = async path => {
    stats += path === projects ? 1 : 0

    if (path === projects && stats === 2) {
      follow(t, LOBBY.id)
    }

    return t.io.fs.stat(path)
  }

  t.seed(LOBBY)

  const { lines } = await watched(t, looks(2), { fs: { stat } })

  expect(lines.map(line => [line.at, carried(line)])).toEqual([
    [NOW, []],
    [NOW + POLL_MS, [LOBBY.id]],
  ])
})

test("a follow line naming the set it had wakes a look at once: the board a write of the app's own changed is printed then, not a second later", async () => {
  const { t, paths } = held()

  follow(t, META.id)

  const { lines } = await watched(t, [
    {
      atOnce: () => {
        post(t, paths, note('n1', 'Merged'))
        follow(t, META.id)
      },
    },
  ])

  expect(lines.map(line => [line.at, logOf(line, META.id)])).toEqual([
    [NOW, undefined],
    [NOW, []],
    [NOW, ['Merged']],
  ])
})

test('a line that does not read is passed over: the set stands, and it wakes nothing', async () => {
  const { t, paths } = held()
  const unread = [
    'not json',
    '',
    '[]',
    '{"follows":[]}',
    `{"follow":"${META.id}"}`,
    `{"follow":["${META.id}",7]}`,
  ]

  follow(t, META.id)

  const { lines } = await watched(t, [
    { atOnce: () => unread.forEach(line => t.send(`${line}\n`)) },
    () => post(t, paths, note('n1', 'Merged')),
  ])

  expect(lines.map(line => [line.at, logOf(line, META.id)])).toEqual([
    [NOW, undefined],
    [NOW, []],
    [NOW + 2 * POLL_MS, ['Merged']],
  ])
})

test('standard input ending changes nothing: the set last given stands, a piece with no newline after it passed over, and the watch runs on', async () => {
  const { t, paths } = held()

  follow(t, META.id)
  t.send('{"follow":[]}')

  const { exit, lines } = await watched(t, [
    ...looks(2),
    () => post(t, paths, note('n1', 'Merged')),
  ])

  expect(exit).toBe(EXIT.done)
  expect(lines.map(line => [line.at, logOf(line, META.id)])).toEqual([
    [NOW, undefined],
    [NOW, []],
    [NOW + 3 * POLL_MS, ['Merged']],
  ])
})

test('a followed session off the board is read at every look, not with the sessions off the board', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: [[T0, finish('claude')]] })

  follow(t, META.id)

  const { lines } = await watched(t, [() => post(t, paths, note('n1', 'After the finish'))])

  expect(lines.map(line => [line.at, carried(line), logOf(line, META.id)?.[0]])).toEqual([
    [NOW, [], undefined],
    [NOW, [META.id], undefined],
    [NOW + POLL_MS, [META.id], 'After the finish'],
  ])
})

test('a session dropped from the set and followed again is new, its board printed again, though dropped and followed again before a look', async () => {
  const { t } = held()

  follow(t, META.id)

  const { lines } = await watched(t, [
    { atOnce: () => follow(t) },
    { atOnce: () => follow(t, META.id) },
    {
      atOnce: () => {
        follow(t)
        follow(t, META.id)
      },
    },
  ])

  expect(lines.map(line => [line.at, carried(line)])).toEqual([
    [NOW, []],
    [NOW, [META.id]],
    [NOW, [META.id]],
    [NOW, [META.id]],
  ])
})

test('however the watch ends, it stops listening to its standard input, which would hold the run open: its end come, another version, a failure', async () => {
  const ended = held()
  const updated = held()
  const failing = held()
  const stat: Io['fs']['stat'] = async path => {
    if (path === projectsDir(ROOT)) {
      throw new Error(`EACCES: permission denied, stat '${path}'`)
    }

    return failing.t.io.fs.stat(path)
  }

  await watched(ended.t, looks(2))
  await watched(updated.t, [
    () => updated.t.files.set(MANIFEST, { text: manifestText('0.3.0'), mtimeMs: NOW }),
  ])
  await watched(failing.t, looks(2), { fs: { stat } })

  expect([ended, updated, failing].map(({ t }) => t.isHearing())).toEqual([false, false, false])
})

test("each window on a line says where it is, its tmux pane and its zmx session, or null for either it is not in", async () => {
  const inZmx = { ...WHERE, zmx: { session: 'litware · invoice-card' } }
  const inTmux = { ...WHERE, tmux: { socket: '/private/tmp/tmux-501/default', pane: '%12' } }
  const whereOn = async (where: Where) => {
    const t = terminal()
    const paths = t.seed(META)

    beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { seenAt: NOW, where })

    return (await watched(t, [])).lines[0]?.windows.map(window => window.where)
  }

  expect(await whereOn(inZmx)).toEqual([{ ...WHERE, tmux: null, zmx: inZmx.zmx }])
  expect(await whereOn(inTmux)).toEqual([{ ...WHERE, tmux: inTmux.tmux, zmx: null }])
})

test("an away session on a line carries the window it was last in, its where and its folder as heartbeats give them, null for what it said not", async () => {
  const { t, paths } = held([[T0, yesAsk('k1', 'Review round 1')]])
  const lobby = t.seed(LOBBY)

  const gone = T0 - 2 * MIN

  beatOn(t, paths, W1, { is: 'yourTurn', since: gone }, {
    attachedAt: gone,
    seenAt: gone,
    where: WHERE,
    directory: REPO,
  })
  beatOn(t, lobby, W2, { is: 'yourTurn', since: T0 }, { seenAt: NOW })

  const [line] = (await watched(t, [])).lines
  const printed = line as unknown as {
    projects: { sessions: { id: string; state: string; lastWindow: unknown }[] }[]
  }

  expect(printed.projects[0]?.sessions.map(each => [each.id, each.state, each.lastWindow])).toEqual([
    [
      META.id,
      'needsYou',
      {
        writer: W1,
        where: { device: WHERE.device, terminal: WHERE.terminal, tmux: null, zmx: null },
        ownsDevice: true,
        directory: REPO,
      },
    ],
    [LOBBY.id, 'yourTurn', null],
  ])
})

test("each window on a line carries the folder its Claude runs in, a held session's {dir}; null where its heartbeat says none", async () => {
  const t = terminal()
  const paths = t.seed(META)

  beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { where: WHERE, directory: REPO })
  beatOn(t, paths, W2, { is: 'working', since: T0 }, { attachedAt: T0 + MIN, where: WHERE })

  const printed = (await watched(t, [])).lines[0] as unknown as { windows: { writer: string; directory: unknown }[] }

  expect(printed.windows.map(window => [window.writer, window.directory])).toEqual([
    [W1, REPO],
    [W2, null],
  ])
})

test("each window on a line carries its place in the order a jump tries its session's windows, core's, not the list's; null for one saying no where", async () => {
  const t = terminal()
  const paths = t.seed(META)
  const working = { is: 'working', since: T0 } as const

  beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { where: WHERE })
  beatOn(t, paths, W2, working, { attachedAt: T0 + MIN, where: { ...WHERE, device: '/dev/ttys099' } })
  beatOn(t, paths, W3, working, { attachedAt: T0 + 2 * MIN })

  expect((await watched(t, [])).lines[0]?.windows.map(window => [window.writer, window.jumpOrder])).toEqual([
    [W1, 1],
    [W2, 0],
    [W3, null],
  ])
})
