/**
 * The CLI's world, for its tests: a file system in memory (the mod's test
 * world's own, when a test shares it), the folder the CLI runs in, the
 * environment, the clock, which only waiting moves, random bytes, what it
 * prints, and a fake tmux, `ps`, lsappinfo, `open` and Ghostty behind the
 * programs it runs and the devices it writes to. Nothing touches a real
 * folder, terminal or window.
 */
import { BRING_FORWARD, FRONT, GHOSTTY_BUNDLE } from '../cli/front'
import { FIND_AND_FOCUS, FOCUS, LIST } from '../cli/ghostty'
import type { Env, Io, Listed, Ran } from '../cli/io'
import { main } from '../cli/main'
import { CLIENTS, PANES, PS } from '../cli/screen'
import {
  metaText,
  projectPaths,
  projectText,
  sessionPaths,
  type ProjectFile,
  type Random,
  type Where,
  type SessionMeta,
  type SessionPaths,
} from '../core'
import { beat, file, MIN, scripted, T0, type Line } from './support'
import { HOME, PROJECT, REPO, ROOT, STATE_HOME } from './world'

type File = { text: string; mtimeMs: number }

/** How a run ended, and what it printed to standard output and error. */
export type Run = { exit: number; out: string; err: string }

export const ENV: Env = { XDG_STATE_HOME: STATE_HOME, HOME }

/** When a run happens, unless a test says otherwise: a minute after the session under test was started. */
export const NOW = T0 + MIN

/** The item ids a terminal's runs draw, unless a test says otherwise: this, then the next ever after. */
export const FIRST_ID = '1234'
export const NEXT_ID = '5678'

/** A tmux client, as the fake tmux holds it: its device, the tmux window it shows, and the commands of its process's ancestors, its parent's first. */
export type FakeClient = { tty: string; window: string; from: readonly string[] }

/** A tmux server: each pane with its tmux window, a pane once for each session the window is in, and its clients. */
export type FakeServer = { panes: [pane: string, window: string][]; clients: FakeClient[] }

/**
 * A Ghostty terminal: its id, the device it is on, and the working directory
 * it reports. One `isLate` takes a report only once the next Ghostty program
 * has answered, as a terminal slower than the find would.
 */
export type FakeTerminal = { id: string; device: string; directory: string; isLate?: boolean }

/** The tmux server's socket a window runs under, unless a test says otherwise. */
export const SOCKET = '/private/tmp/tmux-501/default'

/** Ghostty's own program, as `ps` gives it. */
export const GHOSTTY_APP = '/Applications/Ghostty.app/Contents/MacOS/ghostty'

/** A Ghostty window of this Mac on `tty`, showing tmux's `window`: `tmux < zsh < login < ghostty`. */
export const ghosttyClient = (tty: string, window: string): FakeClient => ({
  tty,
  window,
  from: ['-zsh', '/usr/bin/login', GHOSTTY_APP, '/sbin/launchd'],
})

/** Lee's phone or iPad showing tmux's `window`: `tmux < zsh < mosh-server`. */
export const phoneClient = (tty: string, window: string): FakeClient => ({
  tty,
  window,
  from: ['-zsh', '/opt/homebrew/bin/mosh-server', '/sbin/launchd'],
})

/** A Ghostty on another Mac showing tmux's `window` over ssh: it gives xterm-ghostty, but descends from sshd. */
export const sshClient = (tty: string, window: string): FakeClient => ({
  tty,
  window,
  from: ['-zsh', '/usr/libexec/sshd-session', '/usr/sbin/sshd', '/sbin/launchd'],
})

/** A report written to a device, as the fake reads one back: OSC 7, its host `localhost`, its path percent-encoded. */
const REPORT = /^\x1b\]7;file:\/\/localhost(\/[^\x07]*)\x07$/

/** Processes in every snapshot, whatever the clients: one a command with spaces. */
const OTHER_PROCESSES = [
  '    1     0 /sbin/launchd',
  ' 4168     1 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
]

const printed = (lines: readonly string[]): Ran => ({
  exitCode: 0,
  stdout: `${lines.join('\n')}\n`,
  stderr: '',
})

const isWords = (words: readonly string[], expected: readonly string[]) =>
  words.join('\0') === expected.join('\0')

const processLine = (pid: number, parent: number, command: string) =>
  `${String(pid).padStart(5)} ${String(parent).padStart(5)} ${command}`

/** The files and folders directly in `dir`, as the files under it imply them. */
const entriesIn = (files: ReadonlyMap<string, File>, dir: string): Listed[] => {
  const entries = new Map<string, Listed['kind']>()

  for (const path of files.keys()) {
    if (path.startsWith(`${dir}/`)) {
      const [name = '', ...deeper] = path.slice(dir.length + 1).split('/')

      entries.set(name, deeper.length > 0 ? 'dir' : 'file')
    }
  }

  return [...entries].map(([name, kind]) => ({ name, kind }))
}

type Options = {
  files?: Map<string, File>
  cwd?: string
  env?: Env
  now?: () => number
  random?: Random
  /** tmux's servers, by socket; a socket missing has none running. */
  tmux?: Record<string, FakeServer>
  /** Ghostty's terminals; with none given, Ghostty is not running. */
  ghostty?: FakeTerminal[]
  /** What osascript says as it fails its run of this count, from 1, as when macOS refuses it control of Ghostty; undefined while it runs. */
  refused?: (run: number) => string | undefined
  /** What changes Ghostty's terminals during each listing, the first's first, between its read of the ids and of the directories. */
  changes?: ((terminals: FakeTerminal[]) => void)[]
  /** Programs not on PATH. */
  missing?: string[]
  /** Programs that never answer: a run with a limit is killed at it. */
  slow?: string[]
  /** Devices gone, a write to which fails as a closed pty's does. */
  closed?: string[]
  /**
   * The bundle id of the app in front at each of lsappinfo's looks, the
   * first's first and the last's ever after: Ghostty's unless a test says
   * otherwise. An empty one is a look lsappinfo gives no ASN for.
   */
  front?: readonly string[]
}

/** What lsappinfo says of an ASN it knows no app by. */
const NO_BUNDLE = '"CFBundleIdentifier"=[ NULL ] '

/** The ASN lsappinfo gives the app at this place among those it has named. */
const asnAt = (place: number) => `ASN:0x0-0x${(place + 1).toString(16)}:`

const ASN = /^ASN:0x0-0x([0-9a-f]+):$/

/** A promise, and what settles it. */
const latch = () => {
  let open = () => {}
  const opened = new Promise<void>(resolve => {
    open = resolve
  })

  return { opened, open }
}

/**
 * tmux, `ps`, lsappinfo, `open` and Ghostty as the CLI's programs find
 * them: what each run prints, what is written to each device, and which
 * terminals are focused. A report written to a device sets the directory of
 * the terminal on it, and of no other.
 */
function screen(options: Options) {
  const terminals = options.ghostty?.map(each => ({ ...each }))
  const late = new Map<FakeTerminal, string>()
  const clients = Object.values(options.tmux ?? {}).flatMap(server => server.clients)
  /** Every program run, by its words. */
  const ran: string[][] = []
  /** Every program run, by its name, with the time it was given. */
  const limits: { name: string; limitMs?: number }[] = []
  /** Every write to a device, in order. */
  const written: { device: string; text: string }[] = []
  /** The id of every terminal focused, in order. */
  const focused: string[] = []
  /** The apps lsappinfo has named, each one's ASN its place here. */
  const apps: string[] = []
  /** Programs whose runs wait, by name, until the test lets them answer. */
  const holds = new Map<string, { arrive: () => void; released: Promise<void> }>()

  const pidOf = (client: FakeClient) => 1000 + clients.indexOf(client)

  /** Late terminals take the reports they were given. */
  const settle = () => {
    for (const [terminal, directory] of late) {
      terminal.directory = directory
    }

    late.clear()
  }

  const tmux = (socket: string, words: readonly string[]): Ran => {
    const server = options.tmux?.[socket]

    if (server === undefined) {
      return {
        exitCode: 1,
        stdout: '',
        stderr: `error connecting to ${socket} (No such file or directory)\n`,
      }
    }

    if (isWords(words, PANES)) {
      return printed(server.panes.map(([pane, window]) => `${pane}\t${window}`))
    }

    if (isWords(words, CLIENTS)) {
      return printed(server.clients.map(each => `${each.tty}\t${pidOf(each)}\t${each.window}`))
    }

    throw new Error(`the fake tmux knows no ${words.join(' ')}`)
  }

  /** Every client's process and its ancestors, each ancestor's id its place in the chain past the client's. */
  const ps = (words: readonly string[]): Ran => {
    if (!isWords(words, PS.slice(1))) {
      throw new Error(`the fake ps knows no ${words.join(' ')}`)
    }

    return printed([
      ...OTHER_PROCESSES,
      ...clients.flatMap(client => {
        const chain = [pidOf(client), ...client.from.map((_, i) => pidOf(client) * 10 + i)]

        return ['tmux', ...client.from].map((command, i) =>
          processLine(chain[i] ?? 0, chain[i + 1] ?? 0, command),
        )
      }),
    ])
  }

  /** The program as it runs: the ids, then the directories, then the ids again, a change of the run's between the first two. */
  const list = (): string[] => {
    const held = terminals ?? []
    const change = options.changes?.[ran.filter(words => words[2] === LIST).length - 1]
    const ids = held.map(each => each.id)

    change?.(held)

    const places = held.map(each => each.directory)
    const rows = places.length === ids.length ? ids.map((id, i) => `${id}\t${places[i]}`) : []

    return [held.map(each => each.id).join('\t'), ...rows]
  }

  /** The app in front at this look, by its ASN. */
  const front = () => {
    const looks = ran.filter(words => isWords(words, FRONT)).length
    const bundles = options.front ?? [GHOSTTY_BUNDLE]
    const bundle = bundles[Math.min(looks, bundles.length) - 1] ?? ''

    if (bundle === '') {
      return printed([])
    }

    if (!apps.includes(bundle)) {
      apps.push(bundle)
    }

    return printed([asnAt(apps.indexOf(bundle))])
  }

  const lsappinfo = (words: readonly string[]): Ran => {
    if (isWords(words, FRONT.slice(1))) {
      return front()
    }

    if (!isWords(words.slice(0, -1), ['info', '-only', 'bundleid'])) {
      throw new Error(`the fake lsappinfo knows no ${words.join(' ')}`)
    }

    const place = ASN.exec(words.at(-1) ?? '')?.[1]
    const bundle = place === undefined ? undefined : apps[Number.parseInt(place, 16) - 1]

    return printed([bundle === undefined ? NO_BUNDLE : `"CFBundleIdentifier"="${bundle}"`])
  }

  /** `open -b`, bringing Ghostty forward, the one app the CLI ever opens. */
  const open = (words: readonly string[]): Ran => {
    if (!isWords(words, BRING_FORWARD.slice(1))) {
      throw new Error(`the fake open knows no ${words.join(' ')}`)
    }

    return printed([])
  }

  /** The terminal with the id focused, its id printed; nothing for an id no terminal has. */
  const focus = (id: string | undefined) => {
    const found = terminals?.find(each => each.id === id)

    if (found !== undefined) {
      focused.push(found.id)
    }

    return found === undefined ? [] : [found.id]
  }

  const find = (marker: string | undefined) => {
    const found = terminals?.find(each => each.directory === marker)

    if (found !== undefined) {
      focused.push(found.id)
    }

    return found === undefined ? [] : [found.id]
  }

  /** What Ghostty prints for each program, given its argument. */
  const answerTo = (program: string | undefined, arg: string | undefined) => {
    switch (program) {
      case LIST:
        return list()
      case FIND_AND_FOCUS:
        return find(arg)
      case FOCUS:
        return focus(arg)
      default:
        throw new Error('the fake Ghostty knows no such program')
    }
  }

  const osascript = (program: string | undefined, args: readonly string[]): Ran => {
    const refusal = options.refused?.(ran.filter(([name]) => name === 'osascript').length)

    if (refusal !== undefined) {
      return { exitCode: 1, stdout: '', stderr: `${refusal}\n` }
    }

    if (terminals === undefined) {
      return printed([])
    }

    const answer = printed(answerTo(program, args.at(0)))

    settle()

    return answer
  }

  const run = async ([name = '', ...words]: readonly string[], limitMs?: number): Promise<Ran> => {
    ran.push([name, ...words])
    limits.push({ name, limitMs })

    const held = holds.get(name)

    if (held !== undefined) {
      held.arrive()
      await held.released
    }

    if (options.missing?.includes(name)) {
      throw new Error(`Executable not found in $PATH: "${name}"`)
    }

    if (options.slow?.includes(name)) {
      throw new Error(
        limitMs === undefined
          ? `${name} would hang this test`
          : `${name} did not end within ${limitMs}ms`,
      )
    }

    if (name === 'tmux' && words[0] === '-S') {
      return tmux(words[1] ?? '', words.slice(2))
    }

    if (name === 'ps') {
      return ps(words)
    }

    if (name === 'lsappinfo') {
      return lsappinfo(words)
    }

    if (name === 'open') {
      return open(words)
    }

    if (name === 'osascript' && words[0] === '-e') {
      return osascript(words[1], words.slice(2))
    }

    throw new Error(`Executable not found in $PATH: "${name}"`)
  }

  const writeTo = async (device: string, text: string) => {
    const path = REPORT.exec(text)?.[1]

    if (path === undefined) {
      throw new Error(`a write to ${device} that is not a working directory report`)
    }

    if (options.closed?.includes(device)) {
      throw new Error(`ENXIO: no such device or address, open '${device}'`)
    }

    written.push({ device, text })

    for (const terminal of (terminals ?? []).filter(each => each.device === device)) {
      if (terminal.isLate === true) {
        late.set(terminal, decodeURIComponent(path))
      } else {
        terminal.directory = decodeURIComponent(path)
      }
    }
  }

  /** Each terminal's id and directory once every report has landed. */
  const directories = () => {
    settle()

    return Object.fromEntries((terminals ?? []).map(each => [each.id, each.directory]))
  }

  /** Runs of the program from here on wait until `release()`; `arrived` once one has begun. */
  const hold = (name: string) => {
    const arrival = latch()
    const release = latch()

    holds.set(name, { arrive: arrival.open, released: release.opened })

    return {
      arrived: arrival.opened,
      release: () => {
        holds.delete(name)
        release.open()
      },
    }
  }

  return { run, writeTo, ran, limits, written, focused, directories, hold }
}

export function terminal(options: Options = {}) {
  const files = options.files ?? new Map<string, File>()
  const clock = options.now ?? (() => NOW)
  /** Every wait, in order. */
  const waits: number[] = []
  const now = () => clock() + waits.reduce((sum, ms) => sum + ms, 0)
  const shown = screen(options)
  let printed = { out: '', err: '' }
  let gate: (() => Promise<void>) | undefined

  const io: Io = {
    fs: {
      read: async path => {
        const held = files.get(path)

        if (held === undefined) {
          throw new Error(`ENOENT: no such file or directory, open '${path}'`)
        }

        return held.text
      },
      list: async dir => entriesIn(files, dir),
      append: async (path, text) => {
        await gate?.()
        files.set(path, { text: (files.get(path)?.text ?? '') + text, mtimeMs: now() })
      },
    },
    env: options.env ?? ENV,
    cwd: options.cwd ?? REPO,
    now,
    wait: async ms => {
      waits.push(ms)
    },
    random: options.random ?? scripted([1, 2, 3, 4], [5, 6, 7, 8]),
    out: text => {
      printed.out += text
    },
    err: text => {
      printed.err += text
    },
    run: shown.run,
    writeTo: shown.writeTo,
  }

  /** Runs the CLI on these words: how it ended, and what it printed. */
  const run = async (...words: string[]): Promise<Run> => {
    printed = { out: '', err: '' }

    const exit = await main(words, io)

    return { exit, ...printed }
  }

  /** The text of a file, failing the test when it is not there. */
  const text = (path: string) => {
    const held = files.get(path)

    if (held === undefined) {
      throw new Error(`no file at ${path}`)
    }

    return held.text
  }

  /** A window's heartbeat on a session: attached at `at`, seen then, and `where` it is. */
  const window = (paths: SessionPaths, writer: string, at: number, where?: Where) =>
    files.set(paths.heartbeat(writer), {
      text: beat(writer, { attachedAt: at, seenAt: at, where }),
      mtimeMs: at,
    })

  /**
   * A session as the mod leaves it, filed under `project`: its
   * work.json, the lines its window wrote, and, given `seenAt`, that
   * window's heartbeat, saying `where` it is.
   */
  const seed = (
    meta: SessionMeta,
    {
      project = PROJECT.key,
      lines = [],
      seenAt,
      where,
    }: { project?: string; lines?: Line[]; seenAt?: number; where?: Where } = {},
  ) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    files.set(paths.meta, { text: metaText(meta), mtimeMs: meta.created })
    files.set(paths.log(meta.by), { text: file(...lines), mtimeMs: meta.created })

    if (seenAt !== undefined) {
      window(paths, meta.by, seenAt, where)
    }

    return paths
  }

  /** A project's file, as a start or the project tool writes it. */
  const project = (key: string, held: ProjectFile) =>
    files.set(projectPaths(ROOT, key).file, { text: projectText(held), mtimeMs: held.created })

  /**
   * Appends from here on wait until `count` of them do, as runs at once
   * that each read the file before either wrote; `release()` lets them in.
   */
  const holdAppends = (count: number) => {
    const arrival = latch()
    const release = latch()
    let held = 0

    gate = async () => {
      held += 1

      if (held === count) {
        arrival.open()
      }

      await release.opened
    }

    return {
      arrived: arrival.opened,
      release: () => {
        gate = undefined
        release.open()
      },
    }
  }

  return { files, io, run, text, seed, window, project, holdAppends, waits, screen: shown }
}
