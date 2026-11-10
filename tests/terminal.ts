/**
 * The CLI's world, for its tests: a file system in memory (the mod's test
 * world's own, when a test shares it), the folder the CLI runs in, the
 * environment, the clocks, which only waiting moves, random bytes, its
 * standard input, what it prints and its closing, and the plugin's
 * manifest. Nothing touches a real folder.
 */
import type { Env, Io, Listed } from '../cli/io'
import { main } from '../cli/main'
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
  /** The plugin's manifest's text; with none given, one saying CLI_VERSION. */
  manifest?: string
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

  files.set(MANIFEST, { text: options.manifest ?? manifestText(CLI_VERSION), mtimeMs: T0 })
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
  }
}
