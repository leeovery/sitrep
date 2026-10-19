import { expect, test } from 'claude-code/testing'
import type { Io } from '../cli/io'
import { EXIT, main } from '../cli/main'
import { MOVE_MS, OFF_BOARD_MS, POLL_MS, watch } from '../cli/watch'
import {
  append,
  metaText,
  projectPaths,
  projectsDir,
  STALE_MS,
  type Body,
  type Presence,
  type SessionPaths,
  type WindowState,
} from '../core'
import {
  beat,
  file,
  finish,
  META,
  MIN,
  note,
  SLOW,
  status,
  T0,
  unfinish,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'
import { CLI_VERSION, MANIFEST, manifestText, NOW, terminal } from './terminal'
import { PROJECT, REPO, ROOT, WHERE } from './world'

type Terminal = ReturnType<typeof terminal>

const HOUR = 60 * MIN

/** Another session of Switchboard's, no window holding it. */
const LOBBY = { ...META, id: 'sr-bbbbbb', name: 'Lobby' }

/** What a test does to the files at one of the watch's waits. */
type Step = () => void

/** A watch line, as read back: the fields the tests look at. */
type Printed = {
  at: number
  version: string | null
  rows: { key: string; is: string; isAway: boolean; first: { lead: string } }[]
  projects: { sessions: { id: string; name: string; state: string }[] }[]
  windows: {
    writer: string
    version: string | null
    needsReload: boolean
    state: { is: string } | null
  }[]
  new: string[]
  changed: string[]
}

const still: Step = () => {}

/** Steps that change nothing, a look each. */
const looks = (count: number): Step[] => Array.from({ length: count }, () => still)

/**
 * `sitrep watch` over the terminal's files, `fs` standing in for any of its
 * file system's calls, `ending` for the listening for its end and `move` for
 * its move of the old layout, the steps taken in turn, one at each wait, and
 * then its standard output closed, the wait under way then never ending
 * unless cancelled: how it ended, what it told on standard error, each line
 * it printed, read back, and whether it left that wait holding the run.
 */
const watched = async (
  t: Terminal,
  steps: readonly Step[],
  {
    fs = {},
    ending = t.io.ending,
    move,
  }: { fs?: Partial<Io['fs']>; ending?: Io['ending']; move?: () => Promise<void> } = {},
) => {
  const queue = [...steps]
  let out = ''
  let err = ''
  let last: { isCancelled: boolean } | undefined
  const waited = async (ms: number, waiting: { isCancelled: boolean }) => {
    await t.io.wait(ms)

    const step = queue.shift()

    if (step === undefined) {
      last = waiting
      t.close()

      return new Promise<void>(() => {})
    }

    step()
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
  const exit = move === undefined ? await main(['watch'], io) : (await watch(io, move), EXIT.done)
  const lines = out
    .split('\n')
    .filter(line => line !== '')
    .map(line => JSON.parse(line) as Printed)

  return { exit, err, lines, isWaitHeld: last !== undefined && !last.isCancelled }
}

/** Lines the CLI appends to the session's file, as the clock stands. */
const post = (t: Terminal, paths: SessionPaths, ...bodies: Body[]) => {
  const path = paths.log('cli')
  const now = t.io.now()

  t.files.set(path, { text: append(t.files.get(path)?.text ?? '', bodies, now).text, mtimeMs: now })
}

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

const keys = (line: Printed | undefined) => line?.rows.map(row => row.key)

/** Switchboard, living in REPO, and the session under test there holding `lines`, its window W1 on screen and on your turn. */
const held = (lines: Line[] = [], options: Parameters<typeof terminal>[0] = {}) => {
  const t = terminal(options)

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, { lines })

  beatOn(t, paths, W1, { is: 'yourTurn', since: T0 }, { seenAt: NOW, where: WHERE })

  return { t, paths }
}

test('the first line is the board as every surface shows it, with nothing new and nothing changed, and no load stamp', async () => {
  const t = terminal()

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, {
    lines: [
      [T0, status(['Drawing Usage'])],
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
      tool: { name: 'Read', subject: `${REPO}/src/Limiter/Dispatcher.php` },
    },
    { seenAt: NOW, where: WHERE, loadedAt: T0 },
  )

  const { exit, err, lines } = await watched(t, [])

  expect({ exit, err }).toEqual({ exit: EXIT.done, err: '' })
  expect(lines).toEqual([
    {
      v: 1,
      at: NOW,
      version: CLI_VERSION,
      head: { needYou: 1, sessions: 1 },
      rows: [
        {
          key: `ask:${META.id}:k1`,
          is: 'ask',
          isAway: false,
          session: META.id,
          project: PROJECT.key,
          letters: 'Sw',
          ask: 'k1',
          writer: null,
          first: { lead: 'Review round 1', mono: null, more: null },
          second: 'Switchboard · Dashboard redesign',
          since: T0,
        },
      ],
      projects: [
        {
          key: PROJECT.key,
          name: PROJECT.name,
          directory: REPO,
          open: 1,
          waiting: 1,
          parked: 0,
          updatedAt: T0,
          sessions: [
            {
              id: META.id,
              name: META.name,
              summary: META.summary,
              now: ['Drawing Usage'],
              next: null,
              isOpen: true,
              waiting: 1,
              parked: 0,
              updatedAt: T0,
              state: 'needsYou',
              since: T0,
              asks: [
                {
                  id: 'k1',
                  wants: 'yes',
                  yes: 'Approve',
                  title: 'Review round 1',
                  where: null,
                  options: [],
                  needs: null,
                  ref: null,
                  state: 'waiting',
                  at: T0,
                },
              ],
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
          where: { device: WHERE.device, terminal: WHERE.terminal, tmux: null },
          state: {
            is: 'working',
            since: T0,
            tool: { name: 'Read', subject: `${REPO}/src/Limiter/Dispatcher.php` },
            question: null,
          },
          attachedAt: T0,
        },
      ],
      new: [],
      changed: [],
    },
  ])
})

test('a post is a line at the next look, its session changed; a new ask is new on that line alone', async () => {
  const { t, paths } = held()
  const { lines } = await watched(t, [
    () => post(t, paths, yesAsk('k2', 'Try it on the iPad', 'It works')),
    still,
    () => post(t, paths, note('n1', 'Round 3 drawn')),
  ])

  expect(lines.map(line => [line.at, keys(line), line.new, line.changed])).toEqual([
    [NOW, [`turn:${META.id}`], [], []],
    [NOW + POLL_MS, [`ask:${META.id}:k2`], [`ask:${META.id}:k2`], [META.id]],
    [NOW + 3 * POLL_MS, [`ask:${META.id}:k2`], [], [META.id]],
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
    const { lines } = await watched(t, looks(100))

    expect(
      lines.map(line => [
        line.at,
        keys(line),
        line.projects[0]?.sessions[0]?.state,
        line.windows.map(window => window.writer),
        line.changed,
      ]),
    ).toEqual([
      [NOW, [`turn:${META.id}`], 'yourTurn', [W1], []],
      [NOW + STALE_MS + 1, [], 'away', [], [META.id]],
    ])
  },
)

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

  expect(lines.map(line => [keys(line), line.rows[0]?.first.lead, line.new])).toEqual([
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

  expect(lines.map(line => [line.at, keys(line), line.rows[0]?.is])).toEqual([
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
    [[`ask:${META.id}:k1`, `ask:${META.id}:k2`, `ask:${META.id}:k3`], [`ask:${META.id}:k3`]],
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

test(
  'watch moves the old layout every 10 minutes, once no window still writes it, and the board reads the same',
  SLOW,
  async () => {
    const t = terminal()
    const paths = t.seed(META, { isOld: true, seenAt: NOW })
    const reloaded = () => beatOn(t, paths, W1, undefined, { attachedAt: NOW })
    /** When each look after the first ended, and whether the old layout still held the session then. */
    const probed: [at: number, isOld: boolean][] = []
    const probe = () => {
      probed.push([t.io.now(), t.files.has(paths.old.meta)])
    }
    const { lines } = await watched(t, [
      reloaded,
      ...Array.from({ length: MOVE_MS / POLL_MS + 5 }, () => probe),
    ])

    expect(probed.filter(([at, isOld]) => at <= NOW + MOVE_MS && !isOld)).toEqual([])
    expect(probed.at(-1)).toEqual([expect.any(Number), false])
    expect(t.text(paths.meta)).toContain(META.id)
    expect(
      lines.map(line => [line.at, line.windows.map(window => window.needsReload), line.changed]),
    ).toEqual([
      [NOW, [true], []],
      [NOW + POLL_MS, [false], []],
      [NOW + POLL_MS + STALE_MS + 1, [], [META.id]],
    ])
  },
)

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
  expect(lines.map(line => [line.at, line.rows[0]?.is])).toEqual([
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

test(
  'a look after a slow move is at the instant the move ended, not the one before it',
  SLOW,
  async () => {
    let moved = 0
    const t = terminal({ now: () => NOW + moved, uptime: () => moved })

    t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

    const paths = t.seed(META)
    const move = async () => {
      moved += 3_000
      post(t, paths, yesAsk('k2', 'Try it'))
    }
    const { lines } = await watched(t, looks(MOVE_MS / POLL_MS + 1), { move })

    expect(lines.map(line => [line.at, keys(line)])).toEqual([
      [NOW, []],
      [NOW + MOVE_MS + 3_000, [`ask:${META.id}:k2`]],
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
  const renamed = metaText({ ...META, name: 'Dashboard reframed' })

  expect(renamed.length).toBe(before?.text.length)

  const { lines } = await watched(t, [
    () => t.files.set(paths.meta, { text: renamed, mtimeMs: (before?.mtimeMs ?? 0) + 400 }),
  ])

  expect(lines.map(line => [line.at, line.projects[0]?.sessions[0]?.name])).toEqual([
    [NOW, META.name],
    [NOW + POLL_MS, 'Dashboard reframed'],
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
