import { drained, expect, test } from './kit'
import type { Io, Signal, Terminal } from '../cli/io'
import { EXIT, main } from '../cli/main'
import type { Size } from '../cli/panel/cells'
import { paintOf } from '../cli/panel/colours'
import { repaint } from '../cli/panel/screen'
import { append, clockOf, projectsDir, type Body } from '../core'
import { META, PROJECT, REPO, ROOT, T0, W1 } from './data'
import { yesAsk } from './lines'
import { WHERE } from './world'
import { ENV, NOW, terminal, tty } from './terminal'

/** The writes that ask the colours, enter the screen and leave it, byte for byte. */
const QUERY = '\x1b]10;?\x07\x1b]11;?\x07\x1b[c'
const ENTER = '\x1b[?1049h\x1b[?25l\x1b[?7l\x1b[?1000h\x1b[?1006h'
const LEAVE = '\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l'

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
}

/**
 * Bare `sitrep` on the fake terminal, over the CLI's memory world: Northwind's
 * session asking k1 since T0, its window seen now. Its clock moves only as the
 * test passes time, each wait firing in turn as the clock reaches it.
 */
const opened = ({ size = SIZE, env = { NO_COLOR: '1' }, answer, fs, wrap = each => each }: Opened = {}) => {
  let clock = NOW
  let err = ''
  const timers: Timer[] = []
  const screen = tty({ size, ...(answer === undefined ? {} : { answer }) })
  const t = terminal({ now: () => clock, uptime: () => clock - NOW, env: { ...ENV, ...env }, terminal: wrap(screen.terminal) })

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, { lines: [[T0, yesAsk('k1', 'Review round 1')]], seenAt: NOW, where: WHERE })
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

test('every way out gives the terminal back and stops every listening: q and Ctrl-C as done, SIGTERM as terminated, SIGHUP as hung up', async () => {
  const ways: [string, (run: ReturnType<typeof opened>) => Promise<void>, number][] = [
    ['q', run => run.type('q'), EXIT.done],
    ['Ctrl-C', run => run.type('\x03'), EXIT.done],
    ['SIGTERM', run => run.signal('SIGTERM'), 143],
    ['SIGHUP', run => run.signal('SIGHUP'), 129],
  ]

  for (const [name, leave, exit] of ways) {
    const run = opened()

    await run.passing(0)
    await leave(run)

    expect(await run.ended(), name).toEqual({ exit, err: '' })
    expect(run.screen.writes.at(-1), name).toBe(LEAVE)
    expect([run.screen.isReading(), run.screen.listening()], name).toEqual([false, 0])
  }
})

test('SIGTERM while the colour query waits ends the panel before it takes the screen, the terminal left as it was', async () => {
  const answer = latch()
  const run = opened({ answer: answer.opened.then(() => '') })

  await run.passing(0)
  await run.signal('SIGTERM')
  answer.open()

  expect(await run.ended()).toEqual({ exit: 143, err: '' })
  expect(run.screen.writes).toEqual([QUERY])
  expect([run.screen.isReading(), run.screen.listening()]).toEqual([false, 0])
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
  expect([run.screen.isReading(), run.screen.listening()]).toEqual([false, 0])
})

test('Ctrl-Z gives the terminal back and stops; SIGCONT takes it again, raw mode and all, and draws afresh', async () => {
  const run = opened()

  await run.passing(0)

  const shown = run.writesFrom()

  await run.type('j')
  await run.type('\x1a')

  expect(shown().slice(1)).toEqual([LEAVE])
  expect([run.screen.suspends(), run.screen.isReading()]).toEqual([1, false])

  const back = run.writesFrom()

  await run.signal('SIGCONT')

  expect(back()[0]).toBe(ENTER)
  expect(back()[1]?.startsWith('\x1b[?2026h\x1b[2J')).toBe(true)
  expect(screenOf(back())[3]).toBe(' ● Help desk redesign                1m')
  expect(back()[1]).toContain('\x1b[0;7m')
  expect(run.screen.isReading()).toBe(true)

  await run.type('q')

  expect((await run.ended()).exit).toBe(EXIT.done)
})

test('a resize draws afresh at the new size; a terminal that says no size is laid out at 80×24', async () => {
  const run = opened()

  await run.passing(0)

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
  await run.passing(49)

  const before = run.screen.writes.length

  await run.passing(1)

  expect(banded).toBe(' ↑↓ move  ⏎ open  q quit')
  expect(run.screen.writes.length).toBe(before + 1)
  expect(screenOf(run.screen.writes)[9]).toBe(' ↑↓ pick  q quit')
  await run.type('q')
})

test("the first draw waits up to 300 ms for the first look, then says it's looking; the board, once read, replaces it", async () => {
  const first = latch()
  const run = opened({ fs: call => (call === 'list' ? first.opened : undefined) })

  await run.passing(299)

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
