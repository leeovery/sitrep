/**
 * sitrep — a small window onto where a session stands and what it
 * needs from Lee (DESIGN.md beside this folder).
 *
 * Claude starts or joins a session through the tools, and posts to its
 * board as it goes. The window then holds that session: it writes its own
 * file in the session's folder, keeps a heartbeat there, and watches the
 * folder, so the session's fold stays current in `$.state` for the board to
 * draw.
 *
 * Lee sees it on the board pane and the band above the prompt, answers its
 * asks there, writing words in the prompt box itself, which the board takes
 * as the answer, and sends the replies as Lee's own message, one message
 * submitted at a time, each held while Claude is mid-turn and written down
 * once Claude Code takes it. The board also reads the sessions around the held
 * one: its project's, and every project's, each a view of its own, where
 * Lee answers other sessions' asks too; those replies go into the other
 * session's inbox, and the window there submits them. What changed on the
 * board without Claude (another window, the CLI) rides into Claude's next
 * turn as context Lee does not see. A conversation starts knowing its
 * project's sessions; one resumed, in a new process or by /resume, takes
 * its session up again; one that ends lets go of its session. Its heartbeat
 * says what the window is doing, as hooks that only observe hear it:
 * working, with the tool it runs; stopped on Lee at a permission prompt or
 * a question; or Lee's turn.
 *
 * Every call on `$` is spelled here, in `hostOf`: the engine reads them off
 * this file's source, and refuses a module that hands `$` to an import.
 * The drawing lives in ./draw, pure functions of a surface's elements and
 * the scene.
 */
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { actionsOf } from './actions'
import { captured, heardSurvey } from './answering'
import { lookAround, lookEvery } from './around'
import { clipOf, heardRows, revealFocus, scrollList } from './clip'
import {
  carryOn,
  conversationEnded,
  heardInput,
  heardTurn,
  isBoardMessage,
  keptFlights,
  sendNow,
  storedFlights,
  takeUpDelivery,
} from './deliver'
import {
  heardAgentTurnEnd,
  heardCheck,
  heardConversationEnd,
  heardRequest,
  heardStop,
  heardTurnEnd,
  heardTurnStart,
  isWindowTurn,
  throughCall,
} from './doing'
import { BAND_ROWS, drawBand } from './draw/band'
import { drawPane } from './draw/board'
import { SEND_NOW } from './draw/ready'
import { drawToolResult, drawToolRow, toolLine } from './draw/tool-row'
import { logFailure, TOAST_MS, type Host } from './host'
import { loadedNow } from './load'
import {
  BAND_KEYS,
  boardClosed,
  heardPlacement,
  openBoard,
  PANE,
  pressBand,
  syncBoard,
} from './pane'
import { receiveEvery } from './receive'
import { heldSession, sceneOf, tickEvery } from './scene'
import { boardChange, markSeen } from './seen'
import { rejoin, startListing } from './start'
import { answerCall, nameKept, SPECS, TOOL_NAMES } from './tools'
import { MANIFEST, versionNow } from './version'
import { TTY_WALK, TTY_WALK_MS } from './where'
import { letGo, resume, serially } from './window'

/** The block of the conversation's first message that lists the project's sessions. */
const LISTING = 'sitrep'

const attachment = atom({ plugin: 'sitrep', key: 'attachment' } as const, null)
const board = atom({ plugin: 'sitrep', key: 'board' } as const, null)
const seen = atom({ plugin: 'sitrep', key: 'seen' } as const, null)
const projects = atom({ plugin: 'sitrep', key: 'projects' } as const, [])
const others = atom({ plugin: 'sitrep', key: 'others' } as const, [])
const queue = atom({ plugin: 'sitrep', key: 'queue' } as const, [])
const sent = atom({ plugin: 'sitrep', key: 'sent' } as const, [])
const inFlight = atom({ plugin: 'sitrep', key: 'inFlight' } as const, null)
const pane = atom({ plugin: 'sitrep', key: 'pane' } as const, {
  isOpen: false,
  place: null,
  selected: null,
  resolvedInFull: null,
  heldShown: null,
  placement: {},
})
const scroll = atom({ plugin: 'sitrep', key: 'scroll' } as const, null)
const answering = atom({ plugin: 'sitrep', key: 'answering' } as const, null)
const pulse = atom({ plugin: 'sitrep', key: 'pulse' } as const, { asks: [], frames: 0 })
const flash = atom({ plugin: 'sitrep', key: 'flash' } as const, 0)
const tick = atom({ plugin: 'sitrep', key: 'tick' } as const, 0)
const named = atom({ plugin: 'sitrep', key: 'named' } as const, [])

/** The host, as a hook's `$` reaches it. */
const hostOf = ($: EngineInterface): Host => ({
  fs: {
    read: path => $.fs.read(path),
    write: (path, text) => $.fs.write(path, text),
    list: dir => $.fs.list(dir),
    exists: path => $.fs.exists(path),
  },
  clock: {
    now: () => $.clock.now(),
    after: (ms, task) => $.clock.after(ms, task),
    every: (ms, task) => $.clock.every(ms, task),
  },
  conversation: {
    id: () => $.session.id(),
    cwd: () => $.session.cwd(),
  },
  env: async () => ({
    XDG_STATE_HOME: await $.env.get('XDG_STATE_HOME'),
    HOME: await $.env.get('HOME'),
  }),
  terminal: {
    env: async () => {
      const [TMUX, TMUX_PANE, TERM_PROGRAM] = await Promise.all([
        $.env.get('TMUX'),
        $.env.get('TMUX_PANE'),
        $.env.get('TERM_PROGRAM'),
      ])

      return { TMUX, TMUX_PANE, TERM_PROGRAM }
    },
    tty: () => $.process.run(['/bin/sh', '-c', TTY_WALK], { timeoutMs: TTY_WALK_MS }),
  },
  plugin: {
    manifest: () => $.fs.read(`${$.plugin.root}/${MANIFEST}`),
  },
  log: text => $.ui.log(text, { to: 'debug' }),
  ui: {
    toast: (text, options) => $.ui.toast(text, { timeoutMs: TOAST_MS, ...options }),
    open: args => $.ui.open(args),
    close: id => $.ui.close({ id }),
    panes: () => $.ui.panes(),
    redraw: () => $.ui.invalidate('ui.render'),
    toTop: () => $.ui.scroll({ in: PANE, to: 'start' }),
  },
  prompt: {
    submit: text => $.prompt.submit({ text, asUser: true }),
    read: async () => (await $.prompt.read()).text,
    fill: text => $.prompt.fill({ text, mode: 'replace' }),
    clear: () => $.prompt.fill({ text: '', mode: 'replace' }),
  },
  // Each slot spelled out: validate reads every atom's reads and writes off this
  // file, and refused them passed through a shared helper.
  state: {
    attachment: {
      read: () => read($, attachment),
      write: value => update($, attachment, () => value),
      update: change => update($, attachment, change),
    },
    board: {
      read: () => read($, board),
      write: value => update($, board, () => value),
      update: change => update($, board, change),
    },
    seen: {
      read: () => read($, seen),
      write: value => update($, seen, () => value),
      update: change => update($, seen, change),
    },
    projects: {
      read: () => read($, projects),
      write: value => update($, projects, () => value),
      update: change => update($, projects, change),
    },
    others: {
      read: () => read($, others),
      write: value => update($, others, () => value),
      update: change => update($, others, change),
    },
    queue: {
      read: () => read($, queue),
      write: value => update($, queue, () => value),
      update: change => update($, queue, change),
    },
    sent: {
      read: () => read($, sent),
      write: value => update($, sent, () => value),
      update: change => update($, sent, change),
    },
    inFlight: {
      read: async () => keptFlights(await read($, inFlight)),
      write: value => update($, inFlight, () => storedFlights(value)),
      update: change =>
        update($, inFlight, value => storedFlights(change(keptFlights(value)))),
    },
    pane: {
      read: () => read($, pane),
      write: value => update($, pane, () => value),
      update: change => update($, pane, change),
    },
    scroll: {
      read: () => read($, scroll),
      write: value => update($, scroll, () => value),
      update: change => update($, scroll, change),
    },
    answering: {
      read: () => read($, answering),
      write: value => update($, answering, () => value),
      update: change => update($, answering, change),
    },
    pulse: {
      read: () => read($, pulse),
      write: value => update($, pulse, () => value),
      update: change => update($, pulse, change),
    },
    flash: {
      read: () => read($, flash),
      write: value => update($, flash, () => value),
      update: change => update($, flash, change),
    },
    tick: {
      read: () => read($, tick),
      write: value => update($, tick, () => value),
      update: change => update($, tick, change),
    },
    named: {
      read: () => read($, named),
      write: value => update($, named, () => value),
      update: change => update($, named, change),
    },
    activity: {
      get: () => $.state.get({ plugin: 'sitrep', key: 'activity' }),
      set: (value, version) =>
        $.state.set({ plugin: 'sitrep', key: 'activity' }, value, { ifVersion: version }),
    },
  },
})

export const register: Register = on => {
  // Also the first hook a reload of this code runs, `$.state` still naming
  // the session the window held, and the board as Lee left it.
  on('session.start', async ($, e, next) => {
    const host = hostOf($)

    await loadedNow(host)
    await versionNow(host)

    for (const spec of SPECS) {
      await $.tool.register(spec)
    }

    await serially(() => resume(host)).catch(
      logFailure(host, 'taking the attached session up again'),
    )
    await serially(async () => rejoin(host, await host.conversation.id())).catch(
      logFailure(host, 'rejoining the last session'),
    )
    // The last load's timers are gone: what it had pulsing or flashing comes to rest.
    await host.state.pulse.write({ asks: [], frames: 0 })
    await host.state.flash.write(0)
    await takeUpDelivery(host).catch(logFailure(host, 'taking up the message in flight'))
    await $.command.register({
      name: 'sitrep',
      description: 'Open the sitrep board: where this session stands, and what waits on you.',
      immediate: true,
    })
    await syncBoard(host)
    tickEvery(host)
    lookEvery(host)
    receiveEvery(host)
    await lookAround(host)

    return next(e)
  })

  // Once per conversation: its first message says how to keep the board and
  // lists the project's sessions. A new process computes it before its
  // session.start runs (live), so a resumed conversation's rejoin comes first
  // here, for the listing to name it.
  on('prompt.context', async ($, e, next) => {
    const host = hostOf($)
    const listing = await serially(async () => {
      await rejoin(host, await host.conversation.id()).catch(
        logFailure(host, 'rejoining the last session'),
      )

      return startListing(host)
    })

    return next({ ...e, blocks: [...e.blocks, { name: LISTING, text: listing }] })
  }).catch(($, e, next) => next(e))

  // The main conversation's turn starting. A subagent's run raises one too,
  // which starts no turn of the window's and carries no message of its own.
  on('turn.start', async ($, e, next) => {
    if (isWindowTurn(e)) {
      const host = hostOf($)

      await heardTurnStart(host)
      await heardTurn(host, e.text)
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  // The main conversation's turn ending, however it ended, sends the message
  // the window held for it. A subagent's turn is not the window's: it ends
  // only what that subagent left.
  on('turn.complete', async ($, e, next) => {
    const host = hostOf($)

    if (e.agentId === undefined) {
      await heardTurnEnd(host)
      await carryOn(host)
    } else {
      await heardAgentTurnEnd(host, e.agentId)
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  // Every call, the window's own and its subagents', sitrep's among them,
  // heard as it starts and ends, and passed on as it came.
  on('tool.call', ($, e, next) =>
    throughCall(hostOf($), { id: e.tool_use_id, tool: e.tool, input: e, agentId: e.agentId }, () =>
      next(e),
    ),
  ).catch(($, e, next) => next(e))

  on('tool.check', async ($, e, next) => {
    const verdict = await next(e)

    await heardCheck(hostOf($), e, verdict.decision)

    return verdict
  }).catch(($, e, next) => next(e))

  // Claude Code about to show Lee a permission dialog, unless the settings
  // hooks beneath answer it: in auto mode, only for a call the classifier
  // hands to Lee.
  on('classic.PermissionRequest', async ($, e, next) => {
    const answer = await next(e)

    await heardRequest(hostOf($), e, answer)

    return answer
  }).catch(($, e, next) => next(e))

  // The turn's end, as the classic Stop says it, with what it leaves pending
  // to wake the window; unless the settings hooks beneath block it, which
  // goes on with the turn. It and turn.complete come in either order.
  on('classic.Stop', async ($, e, next) => {
    const answer = await next(e)

    await heardStop(hostOf($), e, answer)

    return answer
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: TOOL_NAMES }, ($, e) => answerCall(hostOf($), e)).catch(($, e, next) =>
    next.called
      ? next(e)
      : { deny: `The sitrep board could not take that: ${next.error.message ?? next.error.kind}.` },
  )

  on('prompt.submit', async ($, e, next) => {
    // The board's own message carries no board context: its replies are the
    // change, written once it is taken; the rest rides in with the next prompt.
    if (isBoardMessage(e.origin)) {
      return next(e)
    }

    const host = hostOf($)

    // Lee's input lifts Claude Code's refusal after a stop, before any hook
    // hears it, whether or not it goes on to start a turn. Where none
    // follows, the next look carries on what waited on it: a submit made
    // inside this hook hangs on the prompt it hears (in the test kit).
    await heardInput(host)

    // A prompt the answering mode takes goes no further, so it takes no board context either.
    const taken = await captured(host, e)

    if (taken !== undefined) {
      return { drop: taken }
    }

    const change = await serially(() => boardChange(host))

    if (change === undefined) {
      return next(e)
    }

    const entered = await next({ ...e, context: [...(e.context ?? []), change.context] })

    if (entered.drop === undefined) {
      await markSeen(host, change.session)
    }

    return entered
  }).catch(($, e, next) => next(e))

  on('session.end', async ($, e, next) => {
    const host = hostOf($)

    await serially(() => letGo(host)).catch(logFailure(host, 'letting go of the attached session'))
    await heardConversationEnd(host)
    await conversationEnded(host, e.reason === 'clear')

    return next(e)
  }).catch(($, e, next) => next(e))

  // An in-process /resume ends one conversation (session.end lets go of its
  // session) and resumes another, for which no session.start fires. Here
  // `$.session.id()` still names the conversation that ended (live): the
  // resumed one is the event's.
  on('classic.SessionStart', async ($, e, next) => {
    if (e.source === 'resume') {
      const host = hostOf($)

      await serially(() => rejoin(host, e.session_id)).catch(
        logFailure(host, "rejoining the resumed conversation's session"),
      )
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  // A slash command Lee types lifts Claude Code's refusal after a stop, as a
  // prompt does, though no turn follows it: the next look carries on what
  // waited on his input, a submit from this hook being refused.
  on('command.run', async ($, e, next) => {
    if (!isBoardMessage(e.origin)) {
      await heardInput(hostOf($))
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'sitrep' }, async $ => {
    await openBoard(hostOf($))

    return {}
  }).catch(() => ({ text: 'The sitrep board could not open.' }))

  // Inside Lee's press, where Claude Code takes the submit after a stop.
  on('ui.press', { plugin: 'sitrep', element: [SEND_NOW] }, async ($, e) => {
    await sendNow(hostOf($))

    return { element: e.element }
  }).catch(($, e, next) => next(e))

  on('ui.press', { plugin: 'sitrep', element: BAND_KEYS }, async ($, e) => {
    await pressBand(hostOf($), e.element)

    return { element: e.element }
  }).catch(($, e, next) => next(e))

  on('ui.close', { id: PANE }, async ($, e, next) => {
    const closed = await next(e)

    await boardClosed(hostOf($))

    return closed
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    heardSurvey(e.surface, e.props.hasSurvey)

    const scene = e.props.hasSurvey ? undefined : await sceneOf(hostOf($))

    if (scene === undefined) {
      return next(e)
    }

    const beneath = await next({
      ...e,
      props: { ...e.props, maxRows: e.props.maxRows - BAND_ROWS },
    })

    return drawBand($.ui.resolve(e), e.surface, e.props.bodyColumns, scene, beneath)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const host = hostOf($)
    const scene = await sceneOf(host)

    return drawPane(
      $.ui.resolve(e),
      e.surface,
      actionsOf(host),
      e.props,
      scene,
      clipOf(scene?.scroll ?? null),
    )
  })

  // Docked, the board moves its own list, clipped above Ready to send, and
  // holds the engine's window at the top, where there is nothing to scroll.
  on('ui.scroll', { requestId: PANE }, async ($, e, next) =>
    (await scrollList(hostOf($), e)) ? next({ ...e, offset: 0 }) : next(e),
  ).catch(($, e, next) => next(e))

  on('ui.focus', { requestId: PANE }, async ($, e, next) => {
    await revealFocus(hostOf($), e)

    return next(e)
  }).catch(($, e, next) => next(e))

  // The board's Clients post: each block of a docked board's list the rows it takes, and the
  // header where Claude Code seated the board.
  on('ui.message', { requestId: PANE }, async ($, e, next) => {
    const host = hostOf($)

    heardRows(host, e.data)
    await heardPlacement(host, e.surface, e.data)

    return next(e)
  }).catch(($, e, next) => next(e))

  // A refused or interrupted call keeps the engine's own row, so what went wrong shows.
  on('ui.render', { component: 'ToolUse', props: { tool: TOOL_NAMES } }, async ($, e, next) => {
    const host = hostOf($)
    const line =
      e.props.isErrored || e.props.isInterrupted
        ? undefined
        : await toolLine(e.props.tool, e.props.input, {
            kept: () => nameKept(host, e.props.tool_use_id),
            held: () => heldSession(host),
          })

    return line === undefined ? next(e) : drawToolRow($.ui.resolve(e), line)
  })

  on('ui.render', { component: 'ToolResult', props: { tool: TOOL_NAMES } }, ($, e, next) =>
    e.props.isErrored ? next(e) : drawToolResult($.ui.resolve(e)),
  )
}
