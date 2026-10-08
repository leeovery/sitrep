/**
 * The engine beneath the mod, for its tests: a file system in memory, a
 * repository git knows, the session, the environment and the clock, the
 * display, and a record of what the mod puts in `$.state` and submits.
 * Nothing touches a real folder.
 */
import type { On, PluginState, PromptSubmitInput, RenderPropsOf } from 'claude-code'
import { mock, type Engine } from 'claude-code/testing'
import {
  metaText,
  presenceText,
  projectOf,
  workPaths,
  type Body,
  type Presence,
  type WorkMeta,
  type WorkPaths,
} from '../core'
import { PANE } from '../hooks/pane'
import { file, T0, W1, W2, type Line } from './support'

type Sitrep = PluginState['sitrep']

export const STATE_HOME = '/state'
export const ROOT = `${STATE_HOME}/sitrep`

/** The repository the session works in, a worktree of it, and a folder outside git. */
export const REPO = '/Users/lee/Code/switchboard'
export const WORKTREE = '/Users/lee/Code/switchboard-wt'
export const LOOSE = '/Users/lee/notes'

export const PROJECT = projectOf(`${REPO}/.git`)

/** Another project, with a work of its own. */
export const ELSEWHERE = projectOf('/Users/lee/Code/goosemates/.git')

export const SESSION = { cwd: REPO, surface: 'terminal' as const, isInteractive: true }

export const DASHBOARD = {
  name: 'Dashboard redesign',
  summary: 'Redesign the dashboard, area by area',
}

export const PROMPT = { text: 'Carry on.', wait: false, origin: { kind: 'composer' as const } }

/** The board pane as a fullscreen terminal docks it, and as the main screen draws it inline. */
export const DOCKED: RenderPropsOf['Pane'] = {
  title: 'sitrep',
  isFocused: false,
  bodyColumns: 56,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 30 },
  view: {},
}

export const INLINE: RenderPropsOf['Pane'] = { ...DOCKED, placement: 'inline' }

/** The band above the prompt, 100 columns across. */
export const BAND: RenderPropsOf['AbovePrompt'] = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 6,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 6 },
  view: {},
}

/** The surfaces that draw the board, the band and a field. */
export const SURFACES = ['terminal', 'desktop'] as const

type Surface = (typeof SURFACES)[number]

/** What a test calls a tool with: its short name and its arguments. */
type Args = { [key: string]: unknown }

type File = { text: string; mtimeMs: number }

const MISSING = (path: string) => ({ deny: `ENOENT: no such file or directory, ${path}` })

const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

/** What reaches the model as a prompt: the text, what rode beside it, and whose it is. */
type Submitted = Pick<PromptSubmitInput, 'text' | 'context' | 'origin'>

/**
 * The display beneath the mod: the panes it opens, as placed or waiting;
 * its toasts, sounds and command; and the prompts it submits, which can be
 * dropped or held back as a running turn holds them.
 */
function display(on: On) {
  const panes = new Map<string, boolean>()
  const toasts: string[] = []
  /** How long each toast stays, in the order shown. */
  const toastsMs: (number | undefined)[] = []
  const sounds: string[] = []
  const commands: string[] = []
  const prompts: Submitted[] = []
  const submitted: string[] = []
  let unplaced: string | undefined
  let dropping: string | undefined
  let holding: { arrive: () => void; turn: Promise<void> } | undefined

  on('ui.open', ($, e) => {
    panes.set(e.id, unplaced === undefined)

    return {
      value: unplaced === undefined ? { isPlaced: true } : { isPlaced: false, reason: unplaced },
    }
  })

  on('ui.close', ($, e) => {
    panes.delete(e.id)

    return { value: undefined }
  })

  on('ui.panes', () => ({
    value: [...panes].map(([id, isPlaced]) => ({
      id,
      title: id,
      isShown: true,
      isFocused: false,
      isPlaced,
    })),
  }))

  on('ui.toast', ($, e) => {
    toasts.push(e.text)
    toastsMs.push(e.timeoutMs)

    return { value: undefined }
  })

  on('audio.play', ($, e) => {
    sounds.push(e.clip.asset ?? '')

    return { value: undefined }
  })

  on('command.register', ($, e) => {
    commands.push(e.name)

    return { value: { command: e.name } }
  })

  on('prompt.submit', async ($, e) => {
    submitted.push(e.text)

    if (holding !== undefined) {
      holding.arrive()
      await holding.turn
    }

    if (dropping !== undefined) {
      return { drop: dropping }
    }

    prompts.push({ text: e.text, context: e.context, origin: e.origin })

    return { text: e.text, context: e.context, origin: e.origin }
  })

  return {
    panes,
    toasts,
    toastsMs,
    sounds,
    commands,
    prompts,
    /** Every prompt submitted, entered or not, as it was submitted. */
    submitted,
    /** Panes opened from here on wait undrawn, for that reason; or, given none, are placed again. */
    unplacePanes: (reason?: string) => {
      unplaced = reason
    },
    /** Prompts from here on do not enter, for that reason; or, given none, they enter again. */
    dropPrompts: (reason?: string) => {
      dropping = reason
    },
    /**
     * Prompts from here on wait, as behind a running turn: `arrived` once
     * one is submitted; `end()` ends the turn, letting them in; and `lose()`
     * lets later prompts through while those waiting never go in, nor hear
     * back, as a prompt deleted from the queue or a load reloaded away.
     */
    holdPrompts: () => {
      let end = () => {}
      let arrive = () => {}
      const arrived = new Promise<void>(resolve => {
        arrive = resolve
      })

      holding = {
        arrive: () => arrive(),
        turn: new Promise(resolve => {
          end = resolve
        }),
      }

      return {
        arrived,
        end: () => {
          holding = undefined
          end()
        },
        lose: () => {
          holding = undefined
        },
      }
    },
  }
}

export function world(engine: Engine, on: On, options: { now?: number; cwd?: string } = {}) {
  const clock = mock.clock(on, { now: options.now ?? T0 })
  const files = new Map<string, File>()
  const state: Partial<Sitrep> = {}
  const boards: (Sitrep['board'] | null)[] = []
  /** How many times each of the mod's values was put in `$.state`. */
  const writes: Partial<Record<keyof Sitrep, number>> = {}
  const logs: string[] = []
  const registered: { name: string; isDeferred?: boolean }[] = []
  const shown = display(on)
  let session = W1
  let cwd = options.cwd ?? REPO
  let isRefused: ((path: string) => boolean) | undefined

  mock.env(on, { XDG_STATE_HOME: STATE_HOME, HOME: '/Users/lee' })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('classic.SessionStart', () => ({}))
  on('prompt.context', ($, e) => ({ blocks: e.blocks }))
  on('session.id', () => ({ value: session }))
  on('session.cwd', () => ({ value: cwd }))

  on('tool.register', ($, e) => {
    registered.push({ name: e.name, isDeferred: e.isDeferred })

    return { value: { tool: `mcp__sitrep__${e.name}` } }
  })

  on('ui.log', ($, e) => {
    logs.push(e.text)

    return { value: undefined }
  })

  on('process.run', ($, e) => {
    const where = e.init?.cwd ?? cwd
    const isRepo = where === REPO || where === WORKTREE

    return {
      value: {
        exitCode: isRepo ? 0 : 128,
        stdout: isRepo ? `${REPO}/.git\n` : '',
        stderr: isRepo ? '' : 'fatal: not a git repository',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })

  on('state.set', ($, e, next) => {
    Object.assign(state, { [e.key]: e.value })
    writes[e.key as keyof Sitrep] = (writes[e.key as keyof Sitrep] ?? 0) + 1

    if (e.key === 'board') {
      boards.push(e.value as Sitrep['board'])
    }

    return next(e)
  })

  on('fs.read', ($, e) => {
    const file = files.get(e.path)

    return file === undefined ? MISSING(e.path) : { value: file.text }
  })

  on('fs.write', ($, e) => {
    if (isRefused?.(e.path)) {
      return { deny: `EIO: i/o error, write ${e.path}` }
    }

    files.set(e.path, { text: e.text, mtimeMs: clock.now() })

    return { value: undefined }
  })

  /** Writes from here on to a path `test` picks fail, as a full disk fails them; given none, they land again. */
  const refuseWrites = (test?: (path: string) => boolean) => {
    isRefused = test
  }

  on('fs.exists', ($, e) => ({
    value: files.has(e.path) || [...files.keys()].some(path => isUnder(e.path, path)),
  }))

  on('fs.list', ($, e) => {
    const under = [...files.entries()].filter(([path]) => isUnder(e.path, path))

    if (under.length === 0) {
      return MISSING(e.path)
    }

    const entries = new Map<string, { kind: 'file' | 'dir'; size: number; mtimeMs: number }>()

    for (const [path, file] of under) {
      const [name = '', ...deeper] = path.slice(e.path.length + 1).split('/')

      entries.set(
        name,
        deeper.length > 0
          ? { kind: 'dir', size: 0, mtimeMs: 0 }
          : {
              kind: 'file',
              size: new TextEncoder().encode(file.text).length,
              mtimeMs: file.mtimeMs,
            },
      )
    }

    return { value: [...entries].map(([name, entry]) => ({ name, ...entry, isLink: false })) }
  })

  /** Writes a file as another writer would: a window elsewhere, the CLI, Lee's board. */
  const put = (path: string, text: string) => files.set(path, { text, mtimeMs: clock.now() })

  /** The text of a file, failing the test when it is not there. */
  const text = (path: string) => {
    const file = files.get(path)

    if (file === undefined) {
      throw new Error(`no file at ${path}`)
    }

    return file.text
  }

  /** A work started by another window, filed under `project`. */
  const seed = (meta: WorkMeta, project = PROJECT.key) =>
    put(workPaths(ROOT, project, meta.id).meta, metaText(meta))

  /** Another window's heartbeat on a work. */
  const beat = (id: string, presence: Presence, project = PROJECT.key) =>
    put(workPaths(ROOT, project, id).heartbeat(presence.writer), presenceText(presence))

  /** Another window's file in a work: each call writes lines to it as that window does, at the time. */
  const writer = (paths: WorkPaths, name = W2) => {
    const lines: Line[] = []

    return (...bodies: Body[]) => {
      lines.push(...bodies.map((body): Line => [clock.now(), body]))
      put(paths.log(name), file(...lines))
    }
  }

  /**
   * Another piece of work, started by the window `by` names and filed under
   * `project`: its paths, that window's lines as it writes them, and its
   * heartbeat as of now, attached at `attachedAt`.
   */
  const elsewhere = (meta: WorkMeta, project = PROJECT.key, by = meta.by) => {
    const paths = workPaths(ROOT, project, meta.id)

    seed(meta, project)

    return {
      paths,
      write: writer(paths, by),
      beat: (attachedAt = clock.now()) =>
        put(paths.heartbeat(by), presenceText({ writer: by, attachedAt, seenAt: clock.now() })),
    }
  }

  /** Calls one of sitrep's tools from the main conversation, or from a subagent given its id. */
  const call = (name: string, args: Args = {}, agentId?: string) =>
    engine.tool.call({
      tool: `mcp__sitrep__${name}`,
      ...args,
      ...(agentId === undefined ? {} : { agentId }),
    } as never) as Promise<{ result?: unknown; deny?: string }>

  /** The session started, and a piece of work started in it: its id and its folder's paths. */
  const begin = async () => {
    await engine.session.start(SESSION)

    const id = startedId(await call('start', DASHBOARD))

    return { id, paths: workPaths(ROOT, PROJECT.key, id) }
  }

  /** The session from here on: another id, as after a /clear, or another folder. */
  const become = (next: { session?: string; cwd?: string }) => {
    session = next.session ?? session
    cwd = next.cwd ?? cwd
  }

  /** The board opened by /sitrep, as Lee opens it, then drawn docked. */
  const opened = async () => {
    await engine.command.run({
      command: 'sitrep',
      args: '',
      origin: { kind: 'composer' },
      presentation: { isFullscreen: true, columns: 160 },
    })

    return pane()
  }

  /** A turn of the main conversation starting with `text`, as the engine starts one. */
  let turns = 0
  const turnStarts = async (text: string) => {
    turns += 1
    await engine.turn.start({ text, turnId: `turn-${turns}` })
  }

  /** The main conversation's turn ending, its answer given. */
  const turnEnds = () =>
    engine.turn.complete({
      answer: 'Done.',
      durationMs: 1_000,
      isAborted: false,
      turnId: `turn-${turns}`,
      reason: 'answer',
    })

  /** The board pane drawn on a surface, as a docked pane unless told otherwise. */
  const pane = (surface: Surface = 'terminal', props: RenderPropsOf['Pane'] = DOCKED) =>
    engine.ui.mount({ plugin: 'sitrep', surface, component: 'Pane', requestId: PANE, props })

  /** The band drawn on a surface, `columns` across. */
  const band = (surface: Surface = 'terminal', columns = BAND.bodyColumns) =>
    engine.ui.mount({
      plugin: 'sitrep',
      surface,
      component: 'AbovePrompt',
      props: { ...BAND, bodyColumns: columns },
    })

  return {
    clock,
    files,
    state,
    boards,
    writes,
    logs,
    registered,
    ...shown,
    put,
    text,
    refuseWrites,
    seed,
    beat,
    writer,
    elsewhere,
    call,
    begin,
    become,
    turnStarts,
    turnEnds,
    opened,
    pane,
    band,
  }
}

/** The work id a start's answer names. */
export const startedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/\bsr-[0-9a-z]+/)?.[0]

  if (id === undefined) {
    throw new Error(`no work id in ${String(answer.result)}`)
  }

  return id
}

/** The item id an answer names, after the words given. */
export const postedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/ ([0-9a-z]{4,})\.$/)?.[1]

  if (id === undefined) {
    throw new Error(`no item id in ${String(answer.result)}`)
  }

  return id
}
