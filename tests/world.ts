/**
 * The engine beneath the mod, for its tests: a file system in memory, the
 * conversation, the environment and the clock, the display, and a record of
 * what the mod puts in `$.state` and submits. Nothing touches a real
 * folder.
 */
import type {
  ClassicEventOf,
  ClassicResultOf,
  ElementTable,
  On,
  PluginState,
  PromptSubmitInput,
  RenderElement,
  RenderPropsOf,
  RenderViewport,
  TurnStartInput,
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
import { keptFlights } from '../hooks/deliver'
import { takeBackKey } from '../hooks/draw/ready'
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
export const PLUGIN_VERSION = '0.2.0'

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

/** A permission check's verdict, as the engine's rules and mode give it. */
type Verdict = 'allow' | 'ask' | 'deny'

/** How a built-in tool's call ends beneath the mod: answered, or refused. */
type Ending = { result: unknown } | { deny: string }

/** A built-in tool's call as a test runs it: what it settles to, and its ending, the test's to give. */
export type Calling = {
  done: Promise<{ result?: unknown; deny?: string; isError?: true }>
  /** The tool answers, as once it has run. */
  finish: (result?: unknown) => void
  /** The call is refused, as at a prompt Lee said no to, or one Lee stopped. */
  refuse: (why: string) => void
}

type File = { text: string; mtimeMs: number }

/** The kinds of look the mod takes at a path. */
type Look = 'read' | 'exists' | 'list'

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
  /** Every folder the mod listed, in the order listed. */
  const listed: string[] = []
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
  /** What happens once, right after the mod's next look of a kind at a path is answered. */
  const afterwards: { look: Look; path: string; act: () => void | Promise<void> }[] = []

  /** Answers the mod's look at `path`, once whatever was to happen right after it has. */
  const answered = async <T>(look: Look, path: string, answer: T) => {
    const at = afterwards.findIndex(each => each.look === look && each.path === path)

    if (at !== -1) {
      await afterwards.splice(at, 1)[0]?.act()
    }

    return answer
  }

  /** Every path the mod wrote, in the order written. */
  const written: string[] = []
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

    return answered('read', e.path, text === undefined ? MISSING(e.path) : { value: text })
  })

  on('fs.write', ($, e) => {
    if (isRefused?.(e.path)) {
      return { deny: `EIO: i/o error, write ${e.path}` }
    }

    files.set(e.path, { text: e.text, mtimeMs: clock.now() })
    written.push(e.path)

    return { value: undefined }
  })

  /**
   * The built-in tools' calls the engine runs beneath the mod, by the tool
   * and its arguments: a verdict to check them by, if any, whether an "ask"
   * shows Lee its dialog, their ending, and whether the engine's own check
   * of it has been let through.
   */
  const beneath = new Map<
    string,
    { verdict?: Verdict; isShown: boolean; ending: Promise<Ending>; isPrechecked?: boolean }
  >()

  const callKey = (tool: string, args: Args) => JSON.stringify({ tool, ...args })

  // As the engine runs one: its permission check, then the tool, until the
  // test ends it. Claude Code 2.1.308's harness runs its own check of the call
  // before this hook, its dialog answered at once by a headless decider that
  // denies, so that check is passed with `allow` (below) and the test's
  // verdict and dialog are replayed here, as the call's own.
  on('tool.call', async ($, e, next) => {
    const { tool, tool_use_id, agentId, ...args } = e as Args & {
      tool: string
      tool_use_id: string
      agentId?: string
    }
    const call = beneath.get(callKey(tool, args))

    if (call === undefined) {
      return next(e)
    }

    if (call.verdict !== undefined) {
      await engine.tool.check({ tool, input: args, tool_use_id, agentId })
    }

    if (call.verdict === 'ask' && call.isShown) {
      await engine.classic.PermissionRequest({
        tool_name: tool,
        tool_input: args,
        ...(agentId === undefined ? {} : { agent_id: agentId }),
      })
    }

    return (await call.ending) as never
  })

  /** What the settings hooks beneath answer a permission request: nothing, so the dialog shows, unless a test says otherwise. */
  let requestAnswer: ClassicResultOf['classic.PermissionRequest'] = {}

  on('classic.PermissionRequest', () => requestAnswer)

  /** The settings hooks beneath answer every permission request from here on with `answer`, as one that allows or denies in the dialog's place. */
  const answerRequests = (answer: ClassicResultOf['classic.PermissionRequest']) => {
    requestAnswer = answer
  }

  /** What the settings hooks beneath answer a turn's Stop: nothing, so the turn stops, unless a test says otherwise. */
  let stopAnswer: ClassicResultOf['classic.Stop'] = {}

  on('classic.Stop', () => stopAnswer)

  /** The settings hooks beneath answer every Stop from here on with `answer`, as one that blocks it to go on with the turn. */
  const answerStops = (answer: ClassicResultOf['classic.Stop']) => {
    stopAnswer = answer
  }

  /** The main conversation's turn stopping, its Stop listing what it leaves pending, or a subagent's id where given: the classic event's answer. */
  const stops = (
    pending: Pick<ClassicEventOf['classic.Stop'], 'background_tasks' | 'session_crons' | 'agent_id'>,
  ) => engine.classic.Stop({ stop_hook_active: false, ...pending })

  on('tool.check', ($, e) => {
    const call = beneath.get(callKey(e.tool, e.input as Args))

    if (call !== undefined && e.tool_use_id !== undefined && call.isPrechecked !== true) {
      call.isPrechecked = true

      return { decision: 'allow' as const }
    }

    return { decision: call?.verdict ?? 'allow' }
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

  on('fs.exists', ($, e) =>
    answered('exists', e.path, {
      value: files.has(e.path) || [...files.keys()].some(path => isUnder(e.path, path)),
    }),
  )

  on('fs.list', ($, e) => {
    listed.push(e.path)

    return answered('list', e.path, listing(e.path))
  })

  /** A folder's listing, as the engine gives it. */
  const listing = (dir: string) => {
    const under = [...files.entries()].filter(([path]) => isUnder(dir, path))

    if (under.length === 0) {
      unlisted.push(dir)

      return MISSING(dir)
    }

    const entries = new Map<string, { kind: 'file' | 'dir'; size: number; mtimeMs: number }>()

    for (const [path, file] of under) {
      const [name = '', ...deeper] = path.slice(dir.length + 1).split('/')

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
  }

  /** Runs `act` once, right after the mod's next look of the kind at `path` is answered: as another writer writing at that moment. */
  const after = (look: Look, path: string, act: () => void | Promise<void>) =>
    afterwards.push({ look, path, act })

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

  /** A session started by another window, filed under `project`: its paths. */
  const seed = (meta: SessionMeta, project = PROJECT.key) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    put(paths.meta, metaText(meta))

    return paths
  }

  /** A project's file, as a start or the project tool writes it. */
  const project = (key: string, file: ProjectFile) =>
    put(projectPaths(ROOT, key).file, projectText(file))

  /** Another window's heartbeat on a session. */
  const beat = (id: string, presence: Presence, project = PROJECT.key) =>
    put(sessionPaths(ROOT, project, id).heartbeat(presence.writer), presenceText(presence))

  /** Another window's file in a session's folder: each call writes lines to it as that window does, at the time. */
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

  /**
   * A built-in tool called from the main conversation, or from a subagent
   * given its id: checked first where given a verdict, its dialog shown to
   * Lee where an "ask" `isShown` (in auto mode, where the classifier hands
   * it to Lee), then running until the test finishes or refuses it. The
   * engine's own check of it, which its harness runs before the call's hook,
   * is passed with `allow`; the call's hook then replays the check and the
   * dialog with the test's verdict.
   */
  const calls = (
    tool: string,
    args: Args = {},
    options: { verdict?: Verdict; isShown?: boolean; agentId?: string } = {},
  ): Calling => {
    let end: (ending: Ending) => void = () => {}
    const ending = new Promise<Ending>(resolve => {
      end = resolve
    })

    beneath.set(callKey(tool, args), {
      verdict: options.verdict,
      isShown: options.isShown ?? false,
      ending,
    })

    return {
      done: engine.tool.call({
        tool,
        ...args,
        ...(options.agentId === undefined ? {} : { agentId: options.agentId }),
      } as never) as Calling['done'],
      finish: (result = 'done') => end({ result }),
      refuse: why => end({ deny: why }),
    }
  }

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

  /** A run of a subagent's loop starting, as Claude Code 2.1.318 raises one: a turn's start carrying the subagent's id. */
  const agentRunStarts = async (agentId: string) => {
    const start: TurnStartInput & { agentId: string } = {
      text: 'Review the change on this branch.',
      turnId: `${agentId}-run`,
      agentId,
    }

    await engine.turn.start(start)
  }

  /** The main conversation's turn ending, its answer given; or stopped by Lee; or a subagent's turn, given its id. */
  const turnEnds = (how: { isAborted?: boolean; agentId?: string } = {}) =>
    engine.turn.complete({
      answer: 'Done.',
      durationMs: 1_000,
      isAborted: how.isAborted ?? false,
      turnId: `turn-${turns}`,
      reason: how.isAborted === true ? 'aborted' : 'answer',
      ...(how.agentId === undefined ? {} : { agentId: how.agentId }),
    })

  /** The board pane drawn on a surface, as a docked pane unless told otherwise. */
  const pane = (surface: Surface = 'terminal', props: RenderPropsOf['Pane'] = DOCKED) =>
    engine.ui.mount({ plugin: 'sitrep', surface, component: 'Pane', requestId: PANE, props })

  /** An item's address on the board, as its buttons are keyed (`pick:<address>`): in the held session, unless another is named. */
  const item = (id: string, session = state.attachment?.session ?? '') => itemKey(session, id)

  /** The window's messages in flight, in the order claimed, however `$.state` keeps them. */
  const flights = () => keptFlights(state.inFlight ?? null)

  /** The key of the take-back of the window's message in flight at `at`, the first unless told otherwise. */
  const takeBack = (at = 0) => {
    const send = flights()[at]

    if (send === undefined) {
      throw new Error(`no message in flight at ${at}`)
    }

    return takeBackKey(send)
  }

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
    listed,
    unlisted,
    runs,
    written,
    registered,
    ...shown,
    put,
    text,
    refuseWrites,
    walkGives,
    manifestGives,
    after,
    leaveUnread,
    seed,
    project,
    beat,
    writer,
    elsewhere,
    call,
    calls,
    answerRequests,
    answerStops,
    stops,
    begin,
    become,
    turnStarts,
    agentRunStarts,
    turnEnds,
    opened,
    pane,
    band,
    item,
    flights,
    takeBack,
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
