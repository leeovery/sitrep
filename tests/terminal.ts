/**
 * The CLI's world, for its tests: a file system in memory (the mod's test
 * world's own, when a test shares it), the folder the CLI runs in, the
 * environment, the clocks, which only waiting moves, random bytes, its
 * standard input, what it prints and its closing, the plugin's manifest,
 * and a fake tmux, `ps`, lsappinfo, `open` and Ghostty behind the programs
 * it runs. Nothing touches a real folder, terminal or window.
 */
import { FRONT, GHOSTTY_BUNDLE } from '../cli/front'
import { FOCUS, FOCUSED } from '../cli/ghostty'
import { TimedOut, type Env, type Io, type Listed, type Ran } from '../cli/io'
import { main } from '../cli/main'
import { PS } from '../cli/screen'
import { CLIENTS, PANES } from '../cli/tmux'
import {
  digestOf,
  metaText,
  projectPaths,
  projectText,
  sessionPaths,
  type ProjectFile,
  type Random,
  type Where,
  type SessionMeta,
  type SessionPaths,
  type WindowState,
} from '../core'
import { beat, file, MIN, scripted, T0, type Line } from './support'
import { HOME, PROJECT, REPO, ROOT, STATE_HOME } from './world'

type File = { text: string; mtimeMs: number }

/** How a run ended, and what it printed to standard output and error. */
export type Run = { exit: number; out: string; err: string }

export const ENV: Env = { XDG_STATE_HOME: STATE_HOME, HOME }

/** When a run happens, unless a test says otherwise: a minute after the session under test was started. */
export const NOW = T0 + MIN

/** The version the CLI's plugin manifest says, unless a test says otherwise. */
export const CLI_VERSION = '0.2.0'

/** Where the plugin the CLI runs from keeps its manifest. */
export const MANIFEST = `${HOME}/.claude/plugins/sitrep/.claude-plugin/plugin.json`

/** The plugin's manifest saying `version`. */
export const manifestText = (version: string) => JSON.stringify({ name: 'sitrep', version })

/** The item ids a terminal's runs draw, unless a test says otherwise: this, then the next ever after. */
export const FIRST_ID = '1234'
export const NEXT_ID = '5678'

/**
 * A tmux client, as the fake tmux holds it: its device, the tmux window it
 * shows, the commands of its process's ancestors, its parent's first, and
 * the tmux session it is attached to, unless a test says otherwise the one
 * named for its window, as each of Lee's tmux sessions has one window.
 */
export type FakeClient = { tty: string; window: string; from: readonly string[]; session?: string }

/**
 * A tmux server: each pane with its tmux window and tmux session, a pane
 * once for each session the window is in, the session the one named for its
 * window unless a test says otherwise; and its clients.
 */
export type FakeServer = {
  panes: [pane: string, window: string, session?: string][]
  clients: FakeClient[]
}

/** The tmux session named for a tmux window: `$45` for `@45`. */
const sessionFor = (window: string) => `$${window.slice(1)}`

/** A tmux server as the fake holds it while it runs: each pane in its session, and each client attached to its own, a select changing the window it shows. */
type HeldServer = {
  panes: { pane: string; window: string; session: string }[]
  clients: Required<FakeClient>[]
}

/** A Ghostty terminal: its id, and the device it is on. */
export type FakeTerminal = { id: string; device: string }


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

/** Terminal's own program, as `ps` gives it: an app with no driver. */
export const TERMINAL_APP = '/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal'

/** A window of another terminal app on `tty`, showing tmux's `window`: `tmux < zsh < login < the app's program`. */
export const appClient = (tty: string, window: string, program: string): FakeClient => ({
  tty,
  window,
  from: ['-zsh', '/usr/bin/login', program, '/sbin/launchd'],
})

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

const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

/** The files and folders directly in `dir`, as the files under it imply them. */
const entriesIn = (files: ReadonlyMap<string, File>, dir: string): Listed[] => {
  const entries = new Map<string, Listed['kind']>()
  const under = (path: string) => path.slice(dir.length + 1).split('/')

  for (const path of [...files.keys()].filter(each => isUnder(dir, each))) {
    const [name = '', ...deeper] = under(path)

    entries.set(name, deeper.length > 0 ? 'dir' : 'file')
  }

  return [...entries].map(([name, kind]) => ({ name, kind }))
}

type Options = {
  files?: Map<string, File>
  cwd?: string
  env?: Env
  /** The wall clock, waits aside: NOW unless a test says otherwise, moving it on as the Mac sleeping does. */
  now?: () => number
  /** The uptime, waits aside: 0 unless a test says otherwise, moving it on with the wall clock as a stall does. */
  uptime?: () => number
  random?: Random
  /** tmux's servers, by socket; a socket missing has none running. */
  tmux?: Record<string, FakeServer>
  /** Ghostty's terminals; with none given, Ghostty is not running. */
  ghostty?: FakeTerminal[]
  /** A Ghostty from before its terminals said their device, or before it could be scripted at all; one that knows `tty` unless a test says otherwise. */
  ghosttyBefore?: 'tty' | 'scripting'
  /** What osascript says as it fails its run of this count, from 1, as when macOS refuses it control of Ghostty; undefined while it runs. */
  refused?: (run: number) => string | undefined
  /** Programs not on PATH. */
  missing?: string[]
  /** Programs that never answer: a run with a limit is killed at it. */
  slow?: string[]
  /** osascript's runs that never end, by their count from 1, as under heavy load: one with a limit is killed at it. */
  stalls?: (run: number) => boolean
  /** How tmux answers a select: in these words, as it refuses one, or never, as a select that hangs; done, unless a test says otherwise. */
  select?: { said: string } | 'slow'
  /**
   * The bundle id of the app in front at each of lsappinfo's looks, the
   * first's first and the last's ever after: Ghostty's unless a test says
   * otherwise. An empty one is a look lsappinfo gives no ASN for.
   */
  front?: readonly string[]
  /** The bundle ids of the apps running, as lsappinfo finds them: none unless a test says otherwise. */
  running?: readonly string[]
  /** The plugin's manifest's text; with none given, one saying CLI_VERSION. */
  manifest?: string
}

/** What lsappinfo says of an ASN it knows no app by. */
const NO_BUNDLE = '"CFBundleIdentifier"=[ NULL ] '

/** The ASN lsappinfo gives the app at this place among those it has named. */
const asnAt = (place: number) => `ASN:0x0-0x${(place + 1).toString(16)}:`

const ASN = /^ASN:0x0-0x([0-9a-f]+):$/

/** What a run that never ends comes to: killed at its limit, or, with none, a run that would hang the test. */
const unended = (name: string, limitMs: number | undefined) =>
  limitMs === undefined ? new Error(`${name} would hang this test`) : new TimedOut(name, limitMs)

/** A promise that never settles: a wait cancelled, as the shell's. */
const never = () => new Promise<void>(() => {})

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
 * them: what each run prints, and which terminals are focused.
 */
function screen(options: Options) {
  const terminals = options.ghostty
  /** tmux's servers as they stand, a select changing which window a client shows. */
  const servers = new Map<string, HeldServer>(
    Object.entries(options.tmux ?? {}).map(([socket, server]) => [
      socket,
      {
        panes: server.panes.map(([pane, window, session = sessionFor(window)]) => ({
          pane,
          window,
          session,
        })),
        clients: server.clients.map(client => ({
          ...client,
          session: client.session ?? sessionFor(client.window),
        })),
      },
    ]),
  )
  const clients = [...servers.values()].flatMap(server => server.clients)
  /** Every program run, by its words. */
  const ran: string[][] = []
  /** Every program run, by its name, with the time it was given. */
  const limits: { name: string; limitMs?: number }[] = []
  /** The id of every terminal focused, in order. */
  const focused: string[] = []
  /** The apps lsappinfo has named, each one's ASN its place here. */
  const apps: string[] = []
  /** Programs whose runs wait, by name, until the test lets them answer. */
  const holds = new Map<string, { arrive: () => void; released: Promise<void> }>()

  const pidOf = (client: Required<FakeClient>) => 1000 + clients.indexOf(client)

  /** Makes the window current in the session, for every client attached to it; refused for a session not holding it. */
  const select = (server: HeldServer, words: readonly string[], limitMs?: number): Ran => {
    const [session, window] = (words[2] ?? '').split(':')

    if (options.select === 'slow') {
      throw unended('tmux', limitMs)
    }

    if (options.select !== undefined) {
      return { exitCode: 1, stdout: '', stderr: `${options.select.said}\n` }
    }

    if (!server.panes.some(each => each.window === window && each.session === session)) {
      return { exitCode: 1, stdout: '', stderr: `can't find window: ${window}\n` }
    }

    for (const client of server.clients.filter(each => each.session === session)) {
      client.window = window ?? ''
    }

    return printed([])
  }

  const tmux = (socket: string, words: readonly string[], limitMs?: number): Ran => {
    const server = servers.get(socket)

    if (server === undefined) {
      return {
        exitCode: 1,
        stdout: '',
        stderr: `error connecting to ${socket} (No such file or directory)\n`,
      }
    }

    if (isWords(words, PANES)) {
      return printed(server.panes.map(each => `${each.pane}\t${each.window}\t${each.session}`))
    }

    if (isWords(words, CLIENTS)) {
      return printed(
        server.clients.map(each => `${each.tty}\t${pidOf(each)}\t${each.window}\t${each.session}`),
      )
    }

    if (words[0] === 'select-window' && words[1] === '-t' && words.length === 3) {
      return select(server, words, limitMs)
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

    const found = /^bundleid=(.+)$/.exec(words[0] === 'find' ? (words[1] ?? '') : '')?.[1]

    if (found !== undefined) {
      return printed([options.running?.includes(found) === true ? asnAt(99) : ''])
    }

    if (!isWords(words.slice(0, -1), ['info', '-only', 'bundleid'])) {
      throw new Error(`the fake lsappinfo knows no ${words.join(' ')}`)
    }

    const place = ASN.exec(words.at(-1) ?? '')?.[1]
    const bundle = place === undefined ? undefined : apps[Number.parseInt(place, 16) - 1]

    return printed([bundle === undefined ? NO_BUNDLE : `"CFBundleIdentifier"="${bundle}"`])
  }

  /** `open`, bringing an app forward by its bundle id (`-b`) or its path (`-a`). */
  const open = (words: readonly string[]): Ran => {
    if (words.length !== 2 || !['-b', '-a'].includes(words[0] ?? '')) {
      throw new Error(`the fake open knows no ${words.join(' ')}`)
    }

    return printed([])
  }

  /** The terminal on the device focused, and FOCUSED printed; nothing for a device no terminal is on. */
  const focus = (device: string | undefined) => {
    const found = terminals?.find(each => each.device === device)

    if (found !== undefined) {
      focused.push(found.id)
    }

    return found === undefined ? [] : [FOCUSED]
  }

  /** What osascript says of the program to a Ghostty that does not know its terms: one with no dictionary as it compiles, whether Ghostty runs or not; one with no `tty` as the lookup runs. */
  const unknownTerms = (): string | undefined => {
    if (options.ghosttyBefore === 'scripting') {
      return 'focus.applescript:8: error: Expected end of line, etc. but found class name. (-2741)'
    }

    return options.ghosttyBefore === 'tty' && terminals !== undefined
      ? '179:183: execution error: The variable tty is not defined. (-2753)'
      : undefined
  }

  /** How many times osascript has run, this run included. */
  const osascriptRuns = () => ran.filter(([name]) => name === 'osascript').length

  const isStalled = () => options.stalls?.(osascriptRuns()) === true

  const osascript = (program: string | undefined, args: readonly string[]): Ran => {
    if (program !== FOCUS) {
      throw new Error('the fake Ghostty knows no such program')
    }

    const refusal = unknownTerms() ?? options.refused?.(osascriptRuns())

    if (refusal !== undefined) {
      return { exitCode: 1, stdout: '', stderr: `${refusal}\n` }
    }

    return printed(terminals === undefined ? [] : focus(args.at(0)))
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

    if (options.slow?.includes(name) || (name === 'osascript' && isStalled())) {
      throw unended(name, limitMs)
    }

    if (name === 'tmux') {
      // As a tmux 3.8 server does for a client with no UTF-8 locale and no `$TMUX`, as SitRep runs the CLI: a
      // format's tabs come back as `_` unless the client says it takes UTF-8.
      const isUtf8 = words[0] === '-u'
      const [flag, socket = '', ...rest] = isUtf8 ? words.slice(1) : words

      if (flag === '-S') {
        const ran = tmux(socket, rest, limitMs)

        return isUtf8 ? ran : { ...ran, stdout: ran.stdout.replaceAll('\t', '_') }
      }
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

  return { run, ran, limits, focused, hold }
}

export function terminal(options: Options = {}) {
  const files = options.files ?? new Map<string, File>()
  const clock = options.now ?? (() => NOW)
  const awake = options.uptime ?? (() => 0)

  files.set(MANIFEST, { text: options.manifest ?? manifestText(CLI_VERSION), mtimeMs: T0 })
  /** Every wait, in order. */
  const waits: number[] = []
  const waited = () => waits.reduce((sum, ms) => sum + ms, 0)
  const now = () => clock() + waited()
  const shown = screen(options)
  let printed = { out: '', err: '' }
  let gate: (() => Promise<void>) | undefined
  /** Standard output closing, as the app that started a run quitting closes it. */
  const closing = latch()
  /** How many listenings for the run's end are not yet stopped. */
  let listening = 0
  /** Standard input: what was written to it that nothing has heard yet, as a pipe holds it, and what hears it now. */
  const stdin: { held: string[]; heard?: (text: string) => void } = { held: [] }

  /**
   * A folder's stat, as a real one's moves: its time stands for the names in
   * it, so it moves only as an entry is made, removed or renamed there.
   * Undefined for a folder not there.
   */
  const folderStat = (dir: string) => {
    const names = entriesIn(files, dir).map(entry => `${entry.kind}:${entry.name}`)

    return names.length > 0
      ? { size: names.length, mtimeMs: Number.parseInt(digestOf(names.sort().join('/')), 36) }
      : undefined
  }

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
      stat: async path => {
        const held = files.get(path)

        return held === undefined
          ? folderStat(path)
          : { size: held.text.length, mtimeMs: held.mtimeMs }
      },
      append: async (path, text) => {
        await gate?.()
        files.set(path, { text: (files.get(path)?.text ?? '') + text, mtimeMs: now() })
      },
    },
    env: options.env ?? ENV,
    cwd: options.cwd ?? REPO,
    now,
    uptime: () => awake() + waited(),
    wait: ms => {
      let isCancelled = false

      waits.push(ms)

      return Object.assign(
        Promise.resolve().then(() => (isCancelled ? never() : undefined)),
        {
          cancel: () => {
            isCancelled = true
          },
        },
      )
    },
    random: options.random ?? scripted([1, 2, 3, 4], [5, 6, 7, 8]),
    input: heard => {
      stdin.heard = heard

      return () => {
        stdin.heard = undefined
      }
    },
    out: text => {
      printed.out += text
    },
    err: text => {
      printed.err += text
    },
    ending: () => {
      let isStopped = false

      listening += 1

      return {
        ended: closing.opened,
        stop: () => {
          listening -= isStopped ? 0 : 1
          isStopped = true
        },
      }
    },
    manifest: MANIFEST,
    run: shown.run,
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

  /**
   * A window's heartbeat on a session: attached at `at`, seen then, `where`
   * it is, and saying the `version` it runs and its `state`, if any.
   */
  const window = (
    paths: SessionPaths,
    writer: string,
    at: number,
    where?: Where,
    version?: string,
    state?: WindowState,
  ) =>
    files.set(paths.heartbeat(writer), {
      text: beat(writer, { attachedAt: at, seenAt: at, where, version, state }),
      mtimeMs: at,
    })

  /**
   * A session as the mod leaves it, filed under `project`: its meta, the
   * lines its window wrote, and, given `seenAt`, that window's heartbeat,
   * saying `where` it is and the `version` it runs.
   */
  const seed = (
    meta: SessionMeta,
    {
      project = PROJECT.key,
      lines = [],
      seenAt,
      where,
      version,
    }: {
      project?: string
      lines?: Line[]
      seenAt?: number
      where?: Where
      version?: string
    } = {},
  ) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    files.set(paths.meta, { text: metaText(meta), mtimeMs: meta.created })
    files.set(paths.log(meta.by), { text: file(...lines), mtimeMs: meta.created })

    if (seenAt !== undefined) {
      window(paths, meta.by, seenAt, where, version)
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

  return {
    files,
    io,
    run,
    close: closing.open,
    listening: () => listening,
    /** Writes to the run's standard input, as the app does: heard at once while it listens, else held until it does and `arrives` gives it. */
    send: (text: string) => {
      if (stdin.heard === undefined) {
        stdin.held.push(text)

        return
      }

      stdin.heard(text)
    },
    /** What standard input held comes to what listens to it: as a pipe gives it, on a turn after the listening began, never in the call that began it. */
    arrives: () => {
      const { heard } = stdin

      if (heard !== undefined) {
        stdin.held.splice(0).forEach(heard)
      }
    },
    /** Whether anything listens to standard input. */
    isHearing: () => stdin.heard !== undefined,
    text,
    seed,
    window,
    project,
    holdAppends,
    waits,
    screen: shown,
  }
}
