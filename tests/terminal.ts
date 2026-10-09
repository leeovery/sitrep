/**
 * The CLI's world, for its tests: a file system in memory (the mod's test
 * world's own, when a test shares it), the folder the CLI runs in, the
 * environment, the clock, random bytes, and what it prints. Nothing touches
 * a real folder.
 */
import type { Env, Io, Listed } from '../cli/io'
import { main } from '../cli/main'
import {
  metaText,
  projectPaths,
  projectText,
  workPaths,
  type ProjectFile,
  type Random,
  type WorkMeta,
} from '../core'
import { file, MIN, scripted, seen, T0, type Line } from './support'
import { HOME, PROJECT, REPO, ROOT, STATE_HOME } from './world'

type File = { text: string; mtimeMs: number }

/** How a run ended, and what it printed to standard output and error. */
export type Run = { exit: number; out: string; err: string }

export const ENV: Env = { XDG_STATE_HOME: STATE_HOME, HOME }

/** When a run happens, unless a test says otherwise: a minute after the work under test was started. */
export const NOW = T0 + MIN

/** The item ids a terminal's runs draw, unless a test says otherwise: this, then the next ever after. */
export const FIRST_ID = '1234'
export const NEXT_ID = '5678'

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
}

export function terminal(options: Options = {}) {
  const files = options.files ?? new Map<string, File>()
  const now = options.now ?? (() => NOW)
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
    random: options.random ?? scripted([1, 2, 3, 4], [5, 6, 7, 8]),
    out: text => {
      printed.out += text
    },
    err: text => {
      printed.err += text
    },
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
   * A piece of work as the mod leaves it, filed under `project`: its
   * work.json, the lines its window wrote, and, given `seenAt`, that
   * window's heartbeat.
   */
  const seed = (
    meta: WorkMeta,
    {
      project = PROJECT.key,
      lines = [],
      seenAt,
    }: { project?: string; lines?: Line[]; seenAt?: number } = {},
  ) => {
    const paths = workPaths(ROOT, project, meta.id)

    files.set(paths.meta, { text: metaText(meta), mtimeMs: meta.created })
    files.set(paths.log(meta.by), { text: file(...lines), mtimeMs: meta.created })

    if (seenAt !== undefined) {
      files.set(paths.heartbeat(meta.by), { text: seen(meta.by, seenAt), mtimeMs: seenAt })
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
    let arrive = () => {}
    let open = () => {}
    const arrived = new Promise<void>(resolve => {
      arrive = resolve
    })
    const opened = new Promise<void>(resolve => {
      open = resolve
    })
    let held = 0

    gate = async () => {
      held += 1

      if (held === count) {
        arrive()
      }

      await opened
    }

    return {
      arrived,
      release: () => {
        gate = undefined
        open()
      },
    }
  }

  return { files, io, run, text, seed, project, holdAppends }
}
