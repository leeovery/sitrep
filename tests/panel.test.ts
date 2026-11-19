import { drained, expect, test } from './kit'
import type { Io, Ran, Signal, Terminal } from '../cli/io'
import { EXIT, main } from '../cli/main'
import type { Size } from '../cli/panel/cells'
import { paintOf } from '../cli/panel/colours'
import { DEFAULTS, PS_MS } from '../cli/panel/edge'
import { ESC_MS, HOLD_MS } from '../cli/panel/panel'
import { repaint } from '../cli/panel/screen'
import { append, clockOf, projectsDir, type Body, type SessionMeta, type Where } from '../core'
import { HOME, META, PROJECT, REPO, ROOT, T0, W1 } from './data'
import { beat, yesAsk } from './lines'
import { defaultsOf } from './plist'
import { WHERE } from './world'
import { ENV, HANDED, NO_PROCESS, NOW, STOPPED, terminal, tty } from './terminal'

/** The writes that ask the colours, enter the screen and leave it, byte for byte. */
const QUERY = '\x1b]10;?\x07\x1b]11;?\x07\x1b[c'
const ENTER = '\x1b[?1049h\x1b[?25l\x1b[?7l\x1b[?1000h\x1b[?1006h\x1b[?2004h'
const LEAVE = '\x1b[?2004l\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l'

const SIZE: Size = { width: 40, height: 10 }

/** A wait under way: when it is due, what ends it, and whether it has ended, fired or cancelled. */
type Timer = { at: number; fire: () => void; isDone: boolean }

/** A latch: a promise, and what opens it. */
const latch = () => {
  let open = () => {}
  const opened = new Promise<void>(resolve => {
    open = resolve
  })

  return { opened, open }
}

type Opened = {
  size?: Size
  env?: Io['env']
  answer?: string | Promise<string>
  /** Each call of the file system's, as the board reads it, told first; one that throws fails the look. */
  fs?: (call: string, path: string) => Promise<void> | void
  /** The terminal as the panel gets it. */
  wrap?: (terminal: Terminal) => Terminal
  /** The session, as its meta says it. */
  meta?: SessionMeta
  /** Where the session's window is, and the folder its Claude runs in. */
  where?: Where
  directory?: string
  /** The resume command SitRep's defaults save; none saved unless given. */
  command?: string
  /** How `ps` answers, as it settles. */
  ps?: () => Promise<Ran>
}

/**
 * Bare `sitrep` on the fake terminal, over the CLI's memory world: Northwind's
 * session asking k1 since T0, its window seen now, in Ghostty unless told
 * otherwise, its device there, the login shell zsh. Its clock moves only as the test passes
 * time, each wait firing in turn as the clock reaches it.
 */
const opened = ({
  size = SIZE,
  env = { NO_COLOR: '1' },
  answer,
  fs,
  wrap = each => each,
  meta = META,
  where = WHERE,
  directory,
  command,
  ps = async () => NO_PROCESS,
}: Opened = {}) => {
  let clock = NOW
  let err = ''
  const timers: Timer[] = []
  const screen = tty({ size, ran: ps, ...(answer === undefined ? {} : { answer }) })
  const t = terminal({
    now: () => clock,
    uptime: () => clock - NOW,
    env: { ...ENV, SHELL: '/bin/zsh', ...env },
    terminal: wrap(screen.terminal),
  })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(meta, { lines: [[T0, yesAsk('k1', 'Review round 1')]] })

  t.files.set(paths.heartbeat(W1), { text: beat(W1, { attachedAt: NOW, seenAt: NOW, where, directory }), mtimeMs: NOW })

  if (where.device !== undefined) {
    t.files.set(where.device, { text: '', mtimeMs: T0 })
  }

  if (command !== undefined) {
    t.files.set(`${HOME}/${DEFAULTS}`, { text: '', bytes: defaultsOf({ app: { resume: command } }), mtimeMs: T0 })
  }

  const told = (call: string) => async (path: string) => fs?.(call, path)
  const io: Io = {
    ...t.io,
    fs: {
      ...t.io.fs,
      list: async dir => (await told('list')(dir), t.io.fs.list(dir)),
      stat: async path => (await told('stat')(path), t.io.fs.stat(path)),
    },
    err: text => {
      err += text
    },
    wait: ms => {
      const timer: Timer = { at: clock + ms, fire: () => {}, isDone: false }
      const waited = new Promise<void>(resolve => {
        timer.fire = resolve
      })

      timers.push(timer)

      return Object.assign(waited, {
        cancel: () => {
          timer.isDone = true
        },
      })
    },
  }
  const due = (until: number) => timers.filter(each => !each.isDone && each.at <= until).sort((a, b) => a.at - b.at)[0]
  const ran = main([], io)

  /** The clock moved on `ms`, each wait due on the way fired in turn, its work done before the next. */
  const passing = async (ms: number) => {
    const until = clock + ms

    await drained()

    for (let next = due(until); next !== undefined; next = due(until)) {
      clock = next.at
      next.isDone = true
      next.fire()
      await drained()
    }

    clock = until
    await drained()
  }

  /** The writes from here on. */
  const writesFrom = () => {
    const from = screen.writes.length

    return () => screen.writes.slice(from)
  }

  return {
    screen,
    t,
    paths,
    passing,
    writesFrom,
    ended: async () => ({ exit: await ran, err }),
    /** How many waits the run set that are neither fired nor let go. */
    waits: () => timers.filter(each => !each.isDone).length,
    type: async (bytes: string) => {
      screen.type(bytes)
      await drained()
    },
    signal: async (signal: Signal) => {
      screen.signal(signal)
      await drained()
    },
    now: () => clock,
  }
}

/** Lines the CLI appends to the session's file, as the clock stands. */
const post = (run: ReturnType<typeof opened>, ...bodies: Body[]) => {
  const path = run.paths.log('cli')
  const now = run.now()

  run.t.files.set(path, { text: append(run.t.files.get(path)?.text ?? '', bodies, now).text, mtimeMs: now })
}

/** The rows the writes leave on the screen, pens aside: cleared by `ESC [2J`, each row written whole from its first column. */
const screenOf = (writes: readonly string[], height = SIZE.height) => {
  const rows = Array.from({ length: height }, () => '')

  for (const write of writes) {
    const plain = write.replace(/\x1b\[[\d;]*m/g, '')

    if (plain.includes('\x1b[2J')) {
      rows.fill('')
    }

    for (const [, y = '', text = ''] of plain.matchAll(/\x1b\[(\d+);1H(.*?)\x1b\[K/g)) {
      rows[Number(y) - 1] = text
    }
  }

  return rows
}

/** The terminal rows a write rewrites, counted from 1. */
const rowsIn = (write: string | undefined) => [...(write ?? '').matchAll(/\x1b\[(\d+);1H/g)].map(([, y]) => Number(y))

/**
 * The board's first frame at 40×10, without colour, byte for byte: the
 * screen cleared, then each row that holds anything, from its first column,
 * cleared to its end, all in synchronized output.
 */
const FIRST_FRAME =
  '\x1b[?2026h\x1b[2J' +
  '\x1b[1;1H \x1b[0;1msitrep\x1b[0m\x1b[K' +
  '\x1b[3;1H NEEDS YOU ●\x1b[0;1m1\x1b[0m \x1b[0;2m───────────────────────\x1b[0m \x1b[0;2m▿\x1b[0m\x1b[K' +
  '\x1b[4;1H ● \x1b[0;1mHelp desk redesign\x1b[0m                \x1b[0;2m1m\x1b[0m\x1b[K' +
  '\x1b[5;1H   \x1b[0;2mNorthwind · \x1b[0mReview round 1\x1b[K' +
  '\x1b[10;1H \x1b[0;1m↑↓\x1b[0;2m pick\x1b[0m  \x1b[0;1mq\x1b[0;2m quit\x1b[0m\x1b[K' +
  '\x1b[?2026l'

/** `j`'s frame: only the rows it changed, the band's two in reverse video and the key line. */
const BANDED =
  '\x1b[?2026h' +
  '\x1b[4;1H \x1b[0;7m● \x1b[0;1;7mHelp desk redesign\x1b[0;7m                \x1b[0;2;7m1m\x1b[0m\x1b[K' +
  '\x1b[5;1H \x1b[0;7m  \x1b[0;2;7mNorthwind · \x1b[0;7mReview round 1          \x1b[0m\x1b[K' +
  '\x1b[10;1H \x1b[0;1m↑↓\x1b[0;2m move\x1b[0m  \x1b[0;1m⏎\x1b[0;2m open\x1b[0m  \x1b[0;1mq\x1b[0;2m quit\x1b[0m\x1b[K' +
  '\x1b[?2026l'

test('the panel asks the colours, takes the screen, draws the board whole, a key rewrites only the rows it changed, and q gives it all back', async () => {
  const run = opened()

  await run.passing(0)
  await run.type('j')
  await run.type('q')

  expect(await run.ended()).toEqual({ exit: EXIT.done, err: '' })
  expect(run.screen.writes).toEqual([QUERY, ENTER, FIRST_FRAME, BANDED, LEAVE])
})

type Run = ReturnType<typeof opened>

/** That the run gave the terminal back whole: nothing listened to, no raw mode, and no wait left set. */
const givenBack = (run: Run) => ({ isReading: run.screen.isReading(), listening: run.screen.listening(), waits: run.waits() })

const GIVEN_BACK = { isReading: false, listening: 0, waits: 0 }

/** Each way out, and the exit it ends with: `q` and Ctrl-C as done; each signal as 128 and its number. */
const WAYS: [string, (run: Run) => Promise<void>, number][] = [
  ['q', run => run.type('q'), EXIT.done],
  ['Ctrl-C', run => run.type('\x03'), EXIT.done],
  ['SIGHUP', run => run.signal('SIGHUP'), 129],
  ['SIGINT', run => run.signal('SIGINT'), 130],
  ['SIGQUIT', run => run.signal('SIGQUIT'), 131],
  ['SIGTERM', run => run.signal('SIGTERM'), 143],
]

test('every way out gives the terminal back, stops every listening and lets every wait go: q and Ctrl-C as done, SIGHUP, SIGINT, SIGQUIT and SIGTERM each as its own', async () => {
  for (const [name, leave, exit] of WAYS) {
    const run = opened()

    await run.passing(0)
    await leave(run)

    expect(await run.ended(), name).toEqual({ exit, err: '' })
    expect(run.screen.writes.at(-1), name).toBe(LEAVE)
    expect(givenBack(run), name).toEqual(GIVEN_BACK)
  }
})

test('a signal during the 300 ms hold ends the panel, the screen given back with nothing drawn on it', async () => {
  for (const [name, leave, exit] of WAYS.filter(([way]) => way.startsWith('SIG'))) {
    const first = latch()
    const run = opened({ fs: call => (call === 'list' ? first.opened : undefined) })

    await run.passing(HOLD_MS - 1)
    await leave(run)

    const waits = run.waits()

    first.open()

    expect(await run.ended(), name).toEqual({ exit, err: '' })
    expect(waits, `${name}: the hold let go as the panel closed, before the look under way came back`).toBe(0)
    expect(run.screen.writes, name).toEqual([QUERY, ENTER, LEAVE])
    expect(givenBack(run), name).toEqual(GIVEN_BACK)
  }
})

test('a signal while the colour query waits ends the panel before it takes the screen, the terminal left as it was', async () => {
  for (const [name, leave, exit] of WAYS.filter(([way]) => way.startsWith('SIG'))) {
    const answer = latch()
    const run = opened({ answer: answer.opened.then(() => '') })

    await run.passing(0)
    await leave(run)
    answer.open()

    expect(await run.ended(), name).toEqual({ exit, err: '' })
    expect(run.screen.writes, name).toEqual([QUERY])
    expect(givenBack(run), name).toEqual(GIVEN_BACK)
  }
})

test('the keys are heard while the colour query waits, raw mode on from before it asks: q then leaves before the screen is taken', async () => {
  const answer = latch()
  const run = opened({ answer: answer.opened.then(() => '') })

  await run.passing(0)

  expect(run.screen.isReading()).toBe(true)

  await run.type('q')
  answer.open()

  expect(await run.ended()).toEqual({ exit: EXIT.done, err: '' })
  expect(run.screen.writes).toEqual([QUERY])
  expect(givenBack(run)).toEqual(GIVEN_BACK)
})

test('a failure thrown in the panel gives the terminal back first, then is told, ending it as refused', async () => {
  let isBroken = false
  const run = opened({
    wrap: terminal => ({
      ...terminal,
      size: () => {
        if (isBroken) {
          throw new Error('the terminal gave no size')
        }

        return terminal.size()
      },
    }),
  })

  await run.passing(0)
  isBroken = true
  run.screen.resize({ width: 69, height: 46 })

  expect(await run.ended()).toEqual({ exit: EXIT.refused, err: 'sitrep: the terminal gave no size\n' })
  expect(run.screen.writes.at(-1)).toBe(LEAVE)
  expect(givenBack(run)).toEqual(GIVEN_BACK)
})

test("a failure thrown as a look is drawn gives the terminal back first, then is told, ending it as refused", async () => {
  const run = opened({
    wrap: terminal => ({
      ...terminal,
      write: text => {
        if (text.startsWith('\x1b[?2026h')) {
          throw new Error('the frame would not draw')
        }

        terminal.write(text)
      },
    }),
  })

  await run.passing(0)

  expect(await run.ended()).toEqual({ exit: EXIT.refused, err: 'sitrep: the frame would not draw\n' })
  expect(run.screen.writes).toEqual([QUERY, ENTER, LEAVE])
  expect(givenBack(run)).toEqual(GIVEN_BACK)
})

test('Ctrl-Z gives the terminal back before it stops, and takes it back as the stop returns, raw mode and all, drawn whole; the SIGCONT after does nothing', async () => {
  const run = opened()

  await run.passing(0)
  await run.type('j')

  const stopped = run.writesFrom()

  await run.type('\x1a')

  expect(stopped()).toEqual([LEAVE, STOPPED])
  expect(run.screen.isReading()).toBe(false)

  await run.passing(0)

  expect(stopped()[2]).toBe(ENTER)
  expect(stopped()[3]?.startsWith('\x1b[?2026h\x1b[2J')).toBe(true)
  expect(screenOf(stopped())[3]).toBe(' ● Help desk redesign                1m')
  expect(stopped()[3]).toContain('\x1b[0;7m')
  expect(run.screen.isReading()).toBe(true)

  const continued = run.writesFrom()

  await run.signal('SIGCONT')
  await run.passing(0)

  expect(continued()).toEqual([])
  await run.type('q')

  expect((await run.ended()).exit).toBe(EXIT.done)
})

test("Ctrl-Z's SIGCONT heard before the take-back it waits on takes the terminal back once, never twice", async () => {
  const run = opened()

  await run.passing(0)

  const stopped = run.writesFrom()

  await run.type('\x1a')
  await run.signal('SIGCONT')
  await run.passing(0)

  expect(stopped().filter(write => write === ENTER)).toHaveLength(1)
  expect(stopped().filter(write => write.includes('\x1b[2J'))).toHaveLength(1)
  expect(run.screen.isReading()).toBe(true)

  const later = run.writesFrom()

  await run.signal('SIGCONT')
  await run.passing(0)

  expect(later()[0], 'a SIGCONT that is no stop of its own takes the terminal back').toBe(ENTER)
  await run.type('q')
})

test('a SIGCONT after a stop from outside takes the terminal back, raw mode set afresh, drawn whole at the size the terminal has now', async () => {
  const run = opened()

  await run.passing(0)

  const listens = run.screen.listens()
  const back = run.writesFrom()

  run.screen.resize({ width: 69, height: 20 }, { isHeard: false })
  await run.signal('SIGCONT')
  await run.passing(0)

  expect(back()[0]).toBe(ENTER)
  expect(back()[1]?.startsWith('\x1b[?2026h\x1b[2J')).toBe(true)
  expect(screenOf(back(), 20)[19]).toBe(' ↑↓ pick  q quit')
  expect(run.screen.listens()).toBe(listens + 1)
  await run.type('q')
})

test('Ctrl-Z takes the terminal back at the size it has after the stop, a resize while stopped going to the shell', async () => {
  const run = opened()

  await run.passing(0)
  await run.type('\x1a')
  run.screen.resize({ width: 69, height: 20 }, { isHeard: false })
  await run.passing(0)

  expect(screenOf(run.screen.writes, 20)[19]).toBe(' ↑↓ pick  q quit')
  expect(screenOf(run.screen.writes, 20)[3]).toBe(' ● Help desk redesign                                             1m')
  await run.type('q')
})

test('a SIGTERM or SIGHUP sent with the SIGCONT, as zsh sends them to a stopped job, ends the panel before it takes the terminal back', async () => {
  const orders: [string, Signal[]][] = [
    ['SIGTERM, then SIGCONT', ['SIGTERM', 'SIGCONT']],
    ['SIGCONT, then SIGTERM', ['SIGCONT', 'SIGTERM']],
    ['SIGCONT, then SIGHUP', ['SIGCONT', 'SIGHUP']],
  ]

  for (const [name, signals] of orders) {
    const run = opened()

    await run.passing(0)
    await run.type('\x1a')
    signals.forEach(signal => run.screen.signal(signal))
    await run.passing(0)

    expect(run.screen.writes.slice(-2), `${name}, after Ctrl-Z`).toEqual([LEAVE, STOPPED])
    expect(givenBack(run), name).toEqual(GIVEN_BACK)

    const outside = opened()

    await outside.passing(0)

    const back = outside.writesFrom()

    signals.forEach(signal => outside.screen.signal(signal))
    await outside.passing(0)

    expect(back(), `${name}, after a stop from outside`).toEqual([LEAVE])
    expect(givenBack(outside), name).toEqual(GIVEN_BACK)
  }
})

test('a resize draws afresh at the new size; one to the size it had draws nothing; a terminal that says no size is laid out at 80×24', async () => {
  const run = opened()

  await run.passing(0)

  const same = run.writesFrom()

  run.screen.resize(SIZE)
  await run.passing(0)

  expect(same()).toEqual([])

  const grown = run.writesFrom()

  run.screen.resize({ width: 69, height: 20 })
  await run.passing(0)

  expect(grown()[0]?.startsWith('\x1b[?2026h\x1b[2J')).toBe(true)
  expect(screenOf(grown(), 20)[19]).toBe(' ↑↓ pick  q quit')
  expect(screenOf(grown(), 20)[3]).toBe(' ● Help desk redesign                                             1m')

  const unsized = run.writesFrom()

  run.screen.resize(undefined)
  await run.passing(0)

  expect(rowsIn(unsized()[0]).at(-1)).toBe(24)
  await run.type('q')
})

test('a sequence split across reads is read whole, and a lone ESC is esc once 50 ms pass with nothing more', async () => {
  const run = opened()

  await run.passing(0)
  await run.type('\x1b')
  await run.type('[B')

  const banded = screenOf(run.screen.writes)[9]

  await run.type('\x1b')
  await run.passing(ESC_MS - 1)

  const before = run.screen.writes.length

  await run.passing(1)

  expect(banded).toBe(' ↑↓ move  ⏎ open  q quit')
  expect(run.screen.writes.length).toBe(before + 1)
  expect(screenOf(run.screen.writes)[9]).toBe(' ↑↓ pick  q quit')
  await run.type('q')
})

test('a paste is never keys, however long its pieces take to come', async () => {
  const run = opened()

  await run.passing(0)

  const pasted = run.writesFrom()

  await run.type('\x1b[200~jj')
  await run.passing(ESC_MS * 4)
  await run.type('q\x03\x1b[2')
  await run.passing(ESC_MS * 4)
  await run.type('01~')

  expect(pasted()).toEqual([])

  await run.type('j')

  expect(screenOf(run.screen.writes)[9]).toBe(' ↑↓ move  ⏎ open  q quit')
  await run.type('q')
})

test("the first draw waits up to 300 ms for the first look, then says it's looking; the board, once read, replaces it", async () => {
  const first = latch()
  const run = opened({ fs: call => (call === 'list' ? first.opened : undefined) })

  await run.passing(HOLD_MS - 1)

  expect(run.screen.writes).toEqual([QUERY, ENTER])

  await run.passing(1)

  expect(screenOf(run.screen.writes).map(row => row.trim())).toContain('Looking for sessions…')

  first.open()
  await run.passing(0)

  expect(screenOf(run.screen.writes)[3]).toBe(' ● Help desk redesign                1m')
  await run.type('q')
})

test('a first look within 300 ms draws the board at once, never `Looking for sessions…`', async () => {
  const run = opened()

  await run.passing(0)
  await run.passing(1_000)

  expect(run.screen.writes.join('')).not.toContain('Looking')
  await run.type('q')
})

test("a look that fails before any board says the board can't be read, and why", async () => {
  const run = opened({
    size: { width: 69, height: 20 },
    fs: (call, path) => {
      if (call === 'stat' && path === projectsDir(ROOT)) {
        throw new Error(`EACCES: permission denied, stat '${path}'`)
      }
    },
  })

  await run.passing(0)

  const rows = screenOf(run.screen.writes, 20).map(row => row.trim())

  expect(rows).toContain("Can't read the board")
  expect(rows).toContain(`EACCES: permission denied, stat '${projectsDir(ROOT)}'.`)
  await run.type('q')

  expect((await run.ended()).exit).toBe(EXIT.done)
})

test("a look's failure reaches the screen made harmless, its control bytes dropped and its lines run together", async () => {
  const run = opened({
    size: { width: 69, height: 20 },
    fs: (call, path) => {
      if (call === 'stat' && path === projectsDir(ROOT)) {
        throw new Error('the board\x1b[2J went\n\taway\x07')
      }
    },
  })

  await run.passing(0)

  const drawn = run.screen.writes.slice(1).join('')

  expect(screenOf(run.screen.writes, 20).map(row => row.trim())).toContain('the board[2J went away.')
  expect([drawn.includes('board\x1b[2J'), drawn.includes('\x07')]).toEqual([false, false])
  await run.type('q')
})

test('a look that fails after a board keeps the board, as of when it was read, until a look reads again', async () => {
  let isFailing = false
  const run = opened({
    fs: (call, path) => {
      if (isFailing && call === 'stat' && path === projectsDir(ROOT)) {
        throw new Error('EACCES: permission denied')
      }
    },
  })

  await run.passing(0)
  isFailing = true
  await run.passing(1_000)

  const stale = screenOf(run.screen.writes)

  isFailing = false
  await run.passing(1_000)

  expect(stale[0]?.startsWith(' sitrep ')).toBe(true)
  expect(stale[0]?.endsWith(` as of ${clockOf(new Date(NOW))}`), 'at the right of the title row').toBe(true)
  expect(stale[0]?.length, 'ending at column W−2').toBe(SIZE.width - 1)
  expect(stale[3]).toBe(' ● Help desk redesign                1m')
  expect(screenOf(run.screen.writes)[0]).toBe(' sitrep')
  await run.type('q')
})

test('the times turn over with the minute, the board standing still, and nothing is written between', async () => {
  const run = opened()

  await run.passing(0)

  const ticking = run.writesFrom()

  await run.passing(59_999)

  expect(ticking()).toEqual([])

  await run.passing(1)

  expect(ticking().map(rowsIn)).toEqual([[4]])
  expect(screenOf(run.screen.writes)[3]).toBe(' ● Help desk redesign                2m')
  await run.type('q')
})

test("a new ask's row is marked new and washed for two seconds from the frame that showed it, the wash ending on time without a look", async () => {
  let isHeld = false
  const looks = latch()
  const run = opened({
    env: { COLORTERM: 'truecolor' },
    fs: call => (isHeld && call === 'list' ? looks.opened : undefined),
  })

  await run.passing(0)
  post(run, yesAsk('k2', 'Ship it'))
  await run.passing(1_000)

  const arrived = run.screen.writes.at(-1) ?? ''

  isHeld = true
  await run.passing(1_999)

  const before = run.screen.writes.length

  await run.passing(1)

  expect(screenOf([arrived])[3]).toBe(' ◉ Help desk redesign 2             now')
  expect(arrived).toContain('48;2;83;67;69')
  expect(run.screen.writes.length).toBe(before + 1)
  expect(screenOf(run.screen.writes)[3]).toBe(' ● Help desk redesign 2             now')
  expect(run.screen.writes.at(-1)).not.toContain('48;2;83;67;69')
  looks.open()
  await run.type('q')
})

test('the level comes from the environment: the band at 24-bit, at 256 colours, and in reverse video without colour', async () => {
  const bands = []

  for (const env of [{ COLORTERM: 'truecolor' }, { TERM: 'xterm-256color' }, { NO_COLOR: '1' }]) {
    const run = opened({ env })

    await run.passing(0)
    await run.type('j')
    bands.push(run.screen.writes.at(-1) ?? '')
    await run.type('q')
  }

  expect(bands[0]).toContain('48;2;62;74;91')
  expect(bands[1]).toContain('48;5;239')
  expect(bands[2]).toContain('\x1b[0;7m')
})

test("the terminal's colours read from its answers, each channel scaled to 8 bits, whichever ends them; what it doesn't answer is left out", () => {
  expect(paintOf('truecolor', '\x1b]10;rgb:cdcd/cece/cfcf\x07\x1b]11;rgb:2e/34/40\x1b\\')).toEqual({
    level: 'truecolor',
    fg: [205, 206, 207],
    bg: [46, 52, 64],
  })
  expect(paintOf('256', '\x1b]11;rgb:f/8/0\x07')).toEqual({ level: '256', bg: [255, 136, 0] })
  expect(paintOf('16', '')).toEqual({ level: '16' })
})

test('a frame rewrites only the rows that changed, a row emptied cleared to its end; where the screen is unknown, every row that holds anything after a clear; nothing where nothing changed', () => {
  expect(repaint(['a', 'b', 'c'], ['a', 'B', 'c'])).toBe('\x1b[?2026h\x1b[2;1HB\x1b[K\x1b[?2026l')
  expect(repaint(['a', 'b'], ['a', ''])).toBe('\x1b[?2026h\x1b[2;1H\x1b[K\x1b[?2026l')
  expect(repaint(undefined, ['a', '', 'c'])).toBe('\x1b[?2026h\x1b[2J\x1b[1;1Ha\x1b[K\x1b[3;1Hc\x1b[K\x1b[?2026l')
  expect(repaint(['a', 'b'], ['a', 'b'])).toBe('')
})

/** A window in a zmx session, on the device Ghostty's would be on. */
const IN_ZMX: Where = { ...WHERE, zmx: { session: 'northwind · help-desk' } }

/** The user's own resume command, naming every placeholder. */
const OWN = 'attach {tty} {dir} {claude}'

/** The login shell's words for the session, by the user's command: no Claude on its device, so `{tty}` empty. */
const OWN_LINE = ['/bin/zsh', '-l', '-c', `attach '' '${REPO}' '${W1}'`]

const WIDE: Size = { width: 69, height: 20 }

/** The panel at 69×20, its session's window in zmx, the user's command saved: the band put on the session, then ⏎. */
const picking = async (given: Opened = {}) => {
  const run = opened({ size: WIDE, where: IN_ZMX, directory: REPO, command: OWN, ...given })

  await run.passing(0)
  await run.type('j')

  const writes = run.writesFrom()

  await run.type('\r')

  return { run, writes }
}

/** The rows the writes leave on the screen at 69×20, their trailing blanks aside. */
const rowsOf = (writes: readonly string[]) => screenOf(writes, WIDE.height).map(row => row.trimEnd())

test("a pick hands the terminal over: the screen left, keys no more read, ps asked of the window's device, the login shell handed the line", async () => {
  const { run, writes } = await picking()

  expect(writes()).toEqual([LEAVE, HANDED])
  expect(run.screen.isReading()).toBe(false)
  expect(run.screen.runs()).toEqual([{ argv: ['/bin/ps', '-t', '/dev/ttys001', '-o', 'stat=,comm='], ms: PS_MS }])
  expect(run.screen.handed()).toEqual([OWN_LINE])
  run.screen.end(0)
  await run.type('q')
})

test('as the program ends, the terminal is taken back, raw mode set afresh, drawn whole, the band where it was, nothing more to say', async () => {
  const { run, writes } = await picking()
  const listens = run.screen.listens()

  await run.passing(3_000)
  run.screen.end(0)
  await run.passing(0)

  const [left, handed, entered, frame = ''] = writes()
  const rows = rowsOf(writes())

  expect([left, handed, entered, writes().length]).toEqual([LEAVE, HANDED, ENTER, 4])
  expect(frame.startsWith('\x1b[?2026h\x1b[2J')).toBe(true)
  expect(frame).toContain('\x1b[0;7m')
  expect(rows[3]).toBe(' ● Help desk redesign                                             1m')
  expect(rows.some(row => row.startsWith(' !'))).toBe(false)
  expect(rows[19]).toBe(' ↑↓ move  ⏎ open  q quit')
  expect([run.screen.isReading(), run.screen.listens()]).toEqual([true, listens + 1])
  await run.type('q')

  expect(await run.ended()).toEqual({ exit: EXIT.done, err: '' })
})

test('a command that ends non-zero within 2 seconds leaves its answer above the key line; one ending later, none', async () => {
  const quick = await picking()

  await quick.run.passing(1_999)
  quick.run.screen.end(1)
  await quick.run.passing(0)

  const slow = await picking()

  await slow.run.passing(2_000)
  slow.run.screen.end(1)
  await slow.run.passing(0)

  expect(rowsOf(quick.writes()).slice(17)).toEqual(['', ' ! The resume command ended with 1 for Help desk redesign.', ' ↑↓ move  ⏎ open  q quit'])
  expect(rowsOf(slow.writes()).some(row => row.startsWith(' !'))).toBe(false)
  await quick.run.type('q')
  await slow.run.type('q')
})

test("a login shell that can't start leaves its own answer, the terminal taken back", async () => {
  const { run, writes } = await picking()

  run.screen.unstarted(new Error("ENOENT: no such file or directory, posix_spawn '/bin/zsh'"))
  await run.passing(0)

  expect(writes().slice(0, 3)).toEqual([LEAVE, HANDED, ENTER])
  expect(rowsOf(writes())[18]).toBe(" ! sitrep couldn't start your login shell, /bin/zsh.")
  await run.type('q')
})

test('a pick refused says why above the key line and hands nothing over; Ctrl-Z, stepped first, drops the answer', async () => {
  const { run, writes } = await picking({ command: undefined })

  expect(run.screen.handed()).toEqual([])
  expect(writes().some(write => write === LEAVE)).toBe(false)
  expect(rowsOf(run.screen.writes)[17]).toBe(" ! Help desk redesign's window has just stopped answering: try again")
  expect(rowsOf(run.screen.writes)[18]).toBe('   in a moment.')

  const stopped = run.writesFrom()

  await run.type('\x1a')
  await run.passing(0)

  expect(stopped().slice(0, 3)).toEqual([LEAVE, STOPPED, ENTER])
  expect(rowsOf(stopped()).some(row => row.startsWith(' !'))).toBe(false)
  await run.type('q')
})

test('a pick the feed alone refuses asks ps nothing, as a window in no multiplexer; any key then drops the answer', async () => {
  const { run } = await picking({ where: WHERE })

  expect(run.screen.runs()).toEqual([])
  expect(rowsOf(run.screen.writes).slice(17, 19)).toEqual([" ! Help desk redesign can't be opened here: its terminal has no tmux", '   or zmx.'])
  await run.type('j')

  expect(rowsOf(run.screen.writes).some(row => row.startsWith(' !'))).toBe(false)
  await run.type('q')
})

test("a pick's answer reaches the screen made harmless, a name's control bytes dropped", async () => {
  const { run } = await picking({ where: WHERE, meta: { ...META, name: 'Help desk\x1b[2J redesign' } })
  const drawn = run.screen.writes.slice(1).join('')

  expect(rowsOf(run.screen.writes)[17]).toBe(" ! Help desk[2J redesign can't be opened here: its terminal has no")
  expect(drawn.includes('desk\x1b[2J')).toBe(false)
  await run.type('q')
})

test("SIGINT and SIGQUIT are the program's while it has the terminal, as is a SIGCONT; taken back, SIGINT ends the panel again", async () => {
  const { run, writes } = await picking()

  await run.signal('SIGINT')
  await run.signal('SIGQUIT')
  await run.signal('SIGCONT')
  await run.passing(0)

  expect(writes()).toEqual([LEAVE, HANDED])
  run.screen.end(130)
  await run.passing(0)
  await run.signal('SIGINT')

  expect(await run.ended()).toEqual({ exit: 130, err: '' })
  expect(writes().at(-1)).toBe(LEAVE)
})

test('SIGTERM and SIGHUP still end the panel while a program has the terminal, writing nothing more, every listening and wait let go', async () => {
  for (const [signal, exit] of [['SIGTERM', 143], ['SIGHUP', 129]] as const) {
    const { run, writes } = await picking()

    await run.signal(signal)

    expect(await run.ended(), signal).toEqual({ exit, err: '' })
    run.screen.end(0)
    await run.passing(0)

    expect(writes(), signal).toEqual([LEAVE, HANDED])
    expect(givenBack(run), signal).toEqual(GIVEN_BACK)
  }
})

test('a Ctrl-Z pressed while a pick is readied gives the terminal back, and nothing takes it back while the program the pick runs has it', async () => {
  let answer: (ran: Ran) => void = () => {}
  const run = opened({ size: WIDE, where: IN_ZMX, directory: REPO, command: OWN, ps: () => new Promise(resolve => (answer = resolve)) })

  await run.passing(0)
  await run.type('j')

  const writes = run.writesFrom()

  await run.type('\r\x1a')
  answer(NO_PROCESS)
  await run.passing(0)

  expect(writes()).toEqual([LEAVE, STOPPED, HANDED])
  expect(run.screen.isReading()).toBe(false)

  run.screen.end(0)
  await run.passing(0)

  expect(writes().slice(0, 4)).toEqual([LEAVE, STOPPED, HANDED, ENTER])
  expect(run.screen.isReading()).toBe(true)
  await run.type('q')
})

test('a SIGTERM or SIGHUP sent to the whole job as the program ends, as `kill %1` sends it, ends the panel before it takes the terminal back', async () => {
  for (const [signal, exit] of [['SIGTERM', 143], ['SIGHUP', 129]] as const) {
    const { run, writes } = await picking()

    run.screen.end(128 + (signal === 'SIGTERM' ? 15 : 1))
    await drained()
    run.screen.signal(signal)
    await run.passing(0)

    expect(await run.ended(), signal).toEqual({ exit, err: '' })
    expect(writes(), signal).toEqual([LEAVE, HANDED])
    expect(givenBack(run), signal).toEqual(GIVEN_BACK)
  }
})

test('the board is looked at while a program has the terminal, drawing nothing; taken back, it is drawn from the latest board, at the size the terminal has now', async () => {
  const { run, writes } = await picking()

  post(run, yesAsk('k2', 'Ship it'))
  run.screen.resize({ width: 73, height: 20 })
  await run.passing(1_000)

  expect(writes()).toEqual([LEAVE, HANDED])
  run.screen.end(0)
  await run.passing(0)

  expect(screenOf(writes(), 20)[3]).toBe(' ◉ Help desk redesign 2                                              now')
  await run.type('q')
})

test('one pick at a time: ⏎ again while ps answers asks nothing more; q meanwhile leaves, and nothing is handed over after', async () => {
  let answer: (ran: Ran) => void = () => {}
  const ps = () =>
    new Promise<Ran>(resolve => {
      answer = resolve
    })
  const { run } = await picking({ ps })

  await run.type('\r')

  expect(run.screen.runs()).toHaveLength(1)
  await run.type('q')
  answer(NO_PROCESS)
  await run.passing(0)

  expect(await run.ended()).toEqual({ exit: EXIT.done, err: '' })
  expect(run.screen.handed()).toEqual([])
  expect(run.screen.writes.at(-1)).toBe(LEAVE)
})
