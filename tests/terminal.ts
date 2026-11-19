/**
 * The CLI's world, for its tests: a file system in memory (the mod's test
 * world's own, when a test shares it), the folder the CLI runs in, the
 * environment, the clocks, which only waiting moves, random bytes, its
 * standard input, what it prints and its closing, the plugin's manifest,
 * and, for the panel, a terminal it runs on. Nothing touches a real folder
 * or a real terminal.
 */
import type { Env, Io, Listed, Signal, Terminal } from '../cli/io'
import { main } from '../cli/main'
import type { Size } from '../cli/panel/cells'
import {
  digestOf,
  folderKey,
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
import { HOME, MIN, PLUGIN_VERSION, PROJECT, REPO, ROOT, STATE_HOME, T0 } from './data'
import { beat, file, scripted, type Line } from './lines'
import { entriesIn, textIn, type File } from './fs'

/** How a run ended, and what it printed to standard output and error. */
export type Run = { exit: number; out: string; err: string }

export const ENV: Env = { XDG_STATE_HOME: STATE_HOME, HOME }

/** When a run happens, unless a test says otherwise: a minute after the session under test was started. */
export const NOW = T0 + MIN

/** Where the plugin the CLI runs from keeps its manifest. */
export const MANIFEST = `${HOME}/.claude/plugins/sitrep/.claude-plugin/plugin.json`

/** The plugin's manifest saying `version`. */
export const manifestText = (version: string) => JSON.stringify({ name: 'sitrep', version })

/** The item ids a terminal's runs draw, unless a test says otherwise: this, then the next ever after. */
export const FIRST_ID = '1234'
export const NEXT_ID = '5678'

/** The files and folders directly in `dir`, as the CLI lists them. */
const listed = (files: ReadonlyMap<string, File>, dir: string): Listed[] =>
  entriesIn(files, dir).map(({ name, entry }) => ({ name, kind: entry === 'dir' ? 'dir' : 'file' }))

type Options = {
  files?: Map<string, File>
  cwd?: string
  env?: Env
  /** The wall clock, waits aside: NOW unless a test says otherwise, moving it on as the Mac sleeping does. */
  now?: () => number
  /** The uptime, waits aside: 0 unless a test says otherwise, moving it on with the wall clock as a stall does. */
  uptime?: () => number
  random?: Random
  /** The plugin's manifest's text; with none given, one saying PLUGIN_VERSION. */
  manifest?: string
  /** The terminal the CLI runs on; none unless given, as off a terminal. */
  terminal?: Terminal
}

/** What a terminal answers the panel's colour query with, before DA1's answer: Nordfox's ink and ground, as the golden frames are drawn on. */
export const NORDFOX = '\x1b]10;rgb:cdcd/cece/cfcf\x07\x1b]11;rgb:2e2e/3434/4040\x07'

/** What the fake terminal keeps among its writes where the run stopped, as the shell took the terminal. */
export const STOPPED = '<stopped>'

/**
 * A terminal for the panel's runs: the size it says, keys typed into it,
 * resizes and signals as a test scripts them, the colour query answered
 * with `answer`, once it settles where it is a promise, and every write
 * kept, the query among them, with STOPPED where the run stopped. A stop
 * returns at once, as one the shell has already brought back. Its keys are
 * read only while the panel listens, in raw mode: a key typed otherwise is
 * the shell's.
 */
export const tty = ({ size = { width: 39, height: 27 }, answer = NORDFOX }: { size?: Size; answer?: string | Promise<string> } = {}) => {
  let said: Size | undefined = size
  let reading: ((bytes: string) => void) | undefined
  let listens = 0
  const writes: string[] = []
  const listeners: Record<Signal | 'resize', Set<() => void>> = {
    resize: new Set(),
    SIGHUP: new Set(),
    SIGINT: new Set(),
    SIGQUIT: new Set(),
    SIGTERM: new Set(),
    SIGCONT: new Set(),
  }

  const listen = (on: Signal | 'resize', heard: () => void) => {
    listeners[on].add(heard)

    return () => void listeners[on].delete(heard)
  }

  const terminal: Terminal = {
    size: () => said,
    onResize: heard => listen('resize', heard),
    keys: heard => {
      reading = heard
      listens += 1

      return () => {
        reading = reading === heard ? undefined : reading
      }
    },
    write: text => void writes.push(text),
    ask: async query => {
      writes.push(query)

      return answer
    },
    onSignal: listen,
    suspend: () => void writes.push(STOPPED),
  }

  return {
    terminal,
    writes,
    /** Types the bytes, heard at once while the panel listens to its keys. */
    type: (bytes: string) => reading?.(bytes),
    /** The terminal resized: to `size`, or to saying none; with `isHeard` false, unheard, as a resize made while the run is stopped goes to the shell. */
    resize: (size: Size | undefined, { isHeard = true } = {}) => {
      said = size

      if (isHeard) {
        listeners.resize.forEach(heard => heard())
      }
    },
    signal: (signal: Signal) => listeners[signal].forEach(heard => heard()),
    /** Whether the panel listens to its keys, raw mode on. */
    isReading: () => reading !== undefined,
    /** How many times the panel began listening to its keys, raw mode set each time. */
    listens: () => listens,
    /** How many listen to its resizes and signals. */
    listening: () => Object.values(listeners).reduce((sum, each) => sum + each.size, 0),
  }
}

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

export function terminal(options: Options = {}) {
  const files = options.files ?? new Map<string, File>()
  const clock = options.now ?? (() => NOW)
  const awake = options.uptime ?? (() => 0)

  files.set(MANIFEST, { text: options.manifest ?? manifestText(PLUGIN_VERSION), mtimeMs: T0 })
  /** Every wait, in order. */
  const waits: number[] = []
  const waited = () => waits.reduce((sum, ms) => sum + ms, 0)
  const now = () => clock() + waited()
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
    const names = listed(files, dir).map(entry => `${entry.kind}:${entry.name}`)

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
      list: async dir => listed(files, dir),
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
    ...(options.terminal === undefined ? {} : { terminal: options.terminal }),
  }

  /** Runs the CLI on these words: how it ended, and what it printed. */
  const run = async (...words: string[]): Promise<Run> => {
    printed = { out: '', err: '' }

    const exit = await main(words, io)

    return { exit, ...printed }
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
    const paths = sessionPaths(ROOT, folderKey(project), meta.id)

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
    /** The text of a file, failing the test when it is not there. */
    text: (path: string) => textIn(files, path),
    seed,
    window,
    project,
    holdAppends,
    waits,
  }
}
