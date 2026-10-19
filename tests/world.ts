/**
 * The engine beneath the mod, for its tests: a file system in memory, the
 * conversation, the environment and the clock, the display, and a record of
 * what the mod puts in `$.state` and submits. Nothing touches a real
 * folder.
 */
import type {
  ElementTable,
  On,
  PluginState,
  PromptSubmitInput,
  RenderElement,
  RenderPropsOf,
  RenderViewport,
} from 'claude-code'
import { mock, type Engine, type Mounted } from 'claude-code/testing'
import {
  metaText,
  presenceText,
  projectPaths,
  projectText,
  sessionPaths,
  type Body,
  type Presence,
  type Project,
  type ProjectFile,
  type Where,
  type SessionMeta,
  type SessionPaths,
} from '../core'
import { PANE } from '../hooks/pane'
import { itemKey } from '../hooks/places'
import { MANIFEST } from '../hooks/version'
import { file, T0, W1, W2, type Line } from './support'

type Sitrep = PluginState['sitrep']

export const STATE_HOME = '/state'
export const ROOT = `${STATE_HOME}/sitrep`

/** The folder the window starts in: Switchboard's repository, though that decides nothing. */
export const REPO = '/Users/lee/Code/switchboard'

/** Lee's home folder, which a window may start in to talk of any project. */
export const HOME = '/Users/lee'

/** The sitrep version the plugin's manifest gives, unless a test says otherwise. */
export const PLUGIN_VERSION = '0.1.0'

/** The plugin's manifest, giving `version`. */
export const manifestOf = (version: unknown) =>
  `${JSON.stringify({ name: 'sitrep', version, description: 'A small window onto a session' })}\n`

/** The terminal Claude Code is on, as the walk up its processes prints it. */
export const TTY = 'ttys001'

/** Where the world's window is unless told otherwise: a Ghostty window outside tmux. */
export const WHERE: Where = { device: `/dev/${TTY}`, terminal: 'ghostty' }

/** What the walk up Claude Code's processes for its terminal gives: what it printed and how it exited, or why it could not run. */
export type Walk = { stdout: string; exitCode?: number } | { refused: string }

/** The project the sessions under test are on: named so by Claude as it starts one, its key the name's slug. */
export const PROJECT: Project = { key: 'switchboard', name: 'Switchboard' }

/** Another project, with a session of its own. */
export const ELSEWHERE: Project = { key: 'goosemates', name: 'Goosemates' }

export const CONVERSATION = { cwd: REPO, surface: 'terminal' as const, isInteractive: true }

export const DASHBOARD = {
  name: 'Dashboard redesign',
  summary: 'Redesign the dashboard, area by area',
  project: PROJECT.name,
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

/** The cells the docked board draws a row across, inside the column it keeps free each side. */
export const ACROSS = DOCKED.bodyColumns - 2

export const INLINE: RenderPropsOf['Pane'] = { ...DOCKED, placement: 'inline' }

/** The board docked beside a 150-column terminal, as it measured live: room for every tab's full label, counts and all. */
export const WIDE: RenderPropsOf['Pane'] = { ...DOCKED, bodyColumns: 67 }

/** The band above the prompt, 100 columns across. */
export const BAND: RenderPropsOf['AbovePrompt'] = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 6,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 6 },
  view: {},
}

/** A drawing above the prompt that stands beneath the band. */
type Beneath = (els: ElementTable, props: RenderPropsOf['AbovePrompt']) => RenderElement

/** The surfaces the tests draw the board and the band on. */
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

  /** What draws above the prompt beneath the mod: Claude Code, which draws nothing there outside a survey, unless a test stands another drawing there. */
  let beneathBand: Beneath | undefined

  on('ui.render', { component: 'AbovePrompt' }, ($, e) =>
    beneathBand === undefined ? { type: 'engine', ref: 0 } : beneathBand($.ui.resolve(e), e.props),
  )

  on('audio.play', ($, e) => {
    sounds.push(e.clip.asset ?? '')

    return { value: undefined }
  })

  on('command.register', ($, e) => {
    commands.push(e.name)

    return { value: { command: e.name } }
  })

  /** Lee's prompt box: the draft as typed or pasted. */
  const box = { text: '' }

  on('prompt.read', () => ({ value: { text: box.text, cursor: box.text.length } }))

  on('prompt.fill', ($, e) => {
    box.text = e.mode === 'append' ? box.text + e.text : e.text

    return { isFilled: true }
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
    /** Lee's prompt box, which a test types or pastes into. */
    box,
    /** From here on, `draw` stands beneath the band: another plugin drawing above the prompt, or Claude Code itself. */
    drawBeneath: (draw: Beneath) => {
      beneathBand = draw
    },
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

/**
 * Knobs on the world: when it starts, the folder the window starts in, and
 * the environment beyond sitrep's own folders (a Ghostty window outside tmux
 * unless told otherwise).
 */
type Options = { now?: number; cwd?: string; env?: Readonly<Record<string, string>> }

export function world(engine: Engine, on: On, options: Options = {}) {
  const clock = mock.clock(on, { now: options.now ?? T0 })
  const files = new Map<string, File>()
  const state: Partial<Sitrep> = {}
  const boards: (Sitrep['board'] | null)[] = []
  /** How many times each of the mod's values was put in `$.state`. */
  const writes: Partial<Record<keyof Sitrep, number>> = {}
  const logs: string[] = []
  /** Every folder the mod listed that was not there: each a line in the engine's debug log. */
  const unlisted: string[] = []
  const registered: { name: string; isDeferred?: boolean }[] = []
  const shown = display(on)
  let conversation = W1
  let cwd = options.cwd ?? REPO
  let isRefused: ((path: string) => boolean) | undefined
  let isUnread = false
  /** The plugin's manifest; none, as one that cannot be read. */
  let manifest: string | undefined = manifestOf(PLUGIN_VERSION)

  /** The commands the mod ran, each as its argument vector. */
  const runs: (readonly string[])[] = []
  let walk: Walk = { stdout: `${TTY}\n` }

  mock.env(on, {
    XDG_STATE_HOME: STATE_HOME,
    HOME,
    ...(options.env ?? { TERM_PROGRAM: 'ghostty' }),
  })

  on('process.run', ($, e) => {
    runs.push(e.argv)

    return 'refused' in walk
      ? { deny: walk.refused }
      : {
          value: {
            exitCode: walk.exitCode ?? 0,
            stdout: walk.stdout,
            stderr: '',
            isStdoutTruncated: false,
            isStderrTruncated: false,
          },
        }
  })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('classic.SessionStart', () => ({}))
  on('prompt.context', ($, e) => ({ blocks: e.blocks }))
  on('session.id', () => ({ value: conversation }))
  on('session.cwd', () => ({ value: cwd }))

  on('tool.register', ($, e) => {
    registered.push({ name: e.name, isDeferred: e.isDeferred })

    return { value: { tool: `mcp__sitrep__${e.name}` } }
  })

  on('ui.log', ($, e) => {
    logs.push(e.text)

    return { value: undefined }
  })

  on('state.set', ($, input, next) => {
    const e = isUnread && input.key === 'others' ? { ...input, value: [] } : input

    Object.assign(state, { [e.key]: e.value })
    writes[e.key as keyof Sitrep] = (writes[e.key as keyof Sitrep] ?? 0) + 1

    if (e.key === 'board') {
      boards.push(e.value as Sitrep['board'])
    }

    return next(e)
  })

  /** What a read finds: the plugin's manifest in the plugin's own folder, wherever the test loads it from; else the file held there. */
  const textAt = (path: string) =>
    path.endsWith(`/${MANIFEST}`) ? manifest : files.get(path)?.text

  on('fs.read', ($, e) => {
    const text = textAt(e.path)

    return text === undefined ? MISSING(e.path) : { value: text }
  })

  on('fs.write', ($, e) => {
    if (isRefused?.(e.path)) {
      return { deny: `EIO: i/o error, write ${e.path}` }
    }

    files.set(e.path, { text: e.text, mtimeMs: clock.now() })

    return { value: undefined }
  })

  /** The walk for the terminal gives `next` from here on. */
  const walkGives = (next: Walk) => {
    walk = next
  }

  /** The plugin's manifest from here on is `text`; given none, it cannot be read. */
  const manifestGives = (text?: string) => {
    manifest = text
  }

  /** The other sessions the board reads in full, from here on, never land in `$.state`: as before the look reading one has, only their briefs are there. */
  const leaveUnread = () => {
    isUnread = true
  }

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
      unlisted.push(e.path)

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

  /** A session started by another window, filed under `project`. */
  const seed = (meta: SessionMeta, project = PROJECT.key) =>
    put(sessionPaths(ROOT, project, meta.id).meta, metaText(meta))

  /** A session started by a window on a version that filed it under the old layout, `works/<id>/work.json`: its paths. */
  const seedOld = (meta: SessionMeta, project = PROJECT.key) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    put(paths.old.meta, metaText(meta))

    return paths
  }

  /** A project's file, as a start or the project tool writes it. */
  const project = (key: string, file: ProjectFile) =>
    put(projectPaths(ROOT, key).file, projectText(file))

  /** Another window's heartbeat on a session. */
  const beat = (id: string, presence: Presence, project = PROJECT.key) =>
    put(sessionPaths(ROOT, project, id).heartbeat(presence.writer), presenceText(presence))

  /** Another window's file in a session: each call writes lines to it as that window does, at the time. */
  const writer = (paths: SessionPaths, name = W2) => {
    const lines: Line[] = []

    return (...bodies: Body[]) => {
      lines.push(...bodies.map((body): Line => [clock.now(), body]))
      put(paths.log(name), file(...lines))
    }
  }

  /**
   * Another session, started by the window `by` names and filed under
   * `project`: its paths, that window's lines as it writes them, and its
   * heartbeat as of now, attached at `attachedAt`.
   */
  const elsewhere = (meta: SessionMeta, project = PROJECT.key, by = meta.by) => {
    const paths = sessionPaths(ROOT, project, meta.id)

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

  /** The conversation started, and a session started in it: its id and its folder's paths. */
  const begin = async () => {
    await engine.session.start(CONVERSATION)

    const id = startedId(await call('start', DASHBOARD))

    return { id, paths: sessionPaths(ROOT, PROJECT.key, id) }
  }

  /** The conversation from here on: another id, as after a /clear, or another folder. */
  const become = (next: { conversation?: string; cwd?: string }) => {
    conversation = next.conversation ?? conversation
    cwd = next.cwd ?? cwd
  }

  /** The board opened by /sitrep, as Lee opens it, then drawn docked unless told otherwise. */
  const opened = async (props: RenderPropsOf['Pane'] = DOCKED) => {
    await engine.command.run({
      command: 'sitrep',
      args: '',
      origin: { kind: 'composer' },
      presentation: { isFullscreen: true, columns: 160 },
    })

    return pane('terminal', props)
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

  /** An item's address on the board, as its buttons are keyed (`pick:<address>`): in the held session, unless another is named. */
  const item = (id: string, session = state.attachment?.session ?? '') => itemKey(session, id)

  /** The band drawn on a surface, `columns` across, on a screen that measured as `viewport` where given. */
  const band = (
    surface: Surface = 'terminal',
    columns = BAND.bodyColumns,
    viewport?: RenderViewport,
  ) =>
    engine.ui.mount({
      plugin: 'sitrep',
      surface,
      component: 'AbovePrompt',
      props: { ...BAND, bodyColumns: columns },
      viewport,
    })

  return {
    clock,
    files,
    state,
    boards,
    writes,
    logs,
    unlisted,
    runs,
    registered,
    ...shown,
    put,
    text,
    refuseWrites,
    walkGives,
    manifestGives,
    leaveUnread,
    seed,
    seedOld,
    project,
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
    item,
  }
}

/** The board on a project's view, reached as Lee reaches it from the tabs: All projects, then the project. */
export const toProject = async (ui: Pick<Mounted, 'press'>, key = PROJECT.key) => {
  await ui.press({ key: 'tab:all' })
  await ui.press({ key: `proj:${key}` })
}

/** The session id a start's answer names. */
export const startedId = (answer: { result?: unknown }) => {
  const id = String(answer.result).match(/\bsr-[0-9a-z]+/)?.[0]

  if (id === undefined) {
    throw new Error(`no session id in ${String(answer.result)}`)
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
