/**
 * sitrep — a small window onto where a piece of work stands and what it
 * needs from Lee (DESIGN.md beside this folder).
 *
 * Claude starts or joins a piece of work through the tools, and posts to its
 * board as it goes. The window then holds that work: it writes its own file
 * in the work's folder, keeps a heartbeat there, and watches the folder, so
 * the work's fold stays current in `$.state` for the board to draw.
 *
 * Lee sees it on the board pane and the band above the prompt, answers its
 * asks there, and sends the replies as Lee's own message, one message in
 * flight at a time, written down once Claude Code takes it. The board also
 * reads the works around the held one: its project's, and every
 * project's, each a view of its own, where Lee answers other sessions' asks
 * too; those replies go into the other work's inbox, and the window there
 * submits them. What changed on the board without Claude (another window,
 * the CLI) rides into Claude's next turn as context Lee does not see. A
 * session starts knowing its project's works; a conversation resumed, in a
 * new process or by /resume, takes its work up again; one that ends lets go
 * of its work.
 *
 * Every call on `$` is spelled here, in `hostOf`: the engine reads them off
 * this file's source, and refuses a module that hands `$` to an import.
 * The drawing lives in ./draw, pure functions of a surface's elements and
 * the scene.
 */
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { actionsOf, heardTyping, PASTED_HERE, tookPaste } from './actions'
import { lookAround, lookEvery } from './around'
import { heardTurn, isBoardMessage, takeUpDelivery, wentQuiet } from './deliver'
import { drawBand } from './draw/band'
import { drawPane, floatingRows } from './draw/board'
import { drawToolResult, drawToolRow, toolLine } from './draw/tool-row'
import { drewBoard, followFocus, movedTo } from './float'
import { logFailure, TOAST_MS, type Host } from './host'
import { BAND_KEYS, boardClosed, openBoard, PANE, pressBand, syncBoard } from './pane'
import { receiveEvery } from './receive'
import { heldWork, sceneOf, tickEvery } from './scene'
import { boardChange, markSeen } from './seen'
import { rejoin, startListing } from './start'
import { answerCall, SPECS, TOOL_NAMES } from './tools'
import { letGo, resume, serially } from './window'

/** The block of the session's first message that lists the project's works. */
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
  view: 'board',
  selected: null,
  commenting: null,
})
const draft = atom({ plugin: 'sitrep', key: 'draft' } as const, '')
const pulse = atom({ plugin: 'sitrep', key: 'pulse' } as const, { asks: [], frames: 0 })
const flash = atom({ plugin: 'sitrep', key: 'flash' } as const, 0)
const tick = atom({ plugin: 'sitrep', key: 'tick' } as const, 0)

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
  session: {
    id: () => $.session.id(),
    cwd: () => $.session.cwd(),
  },
  env: async () => ({
    XDG_STATE_HOME: await $.env.get('XDG_STATE_HOME'),
    HOME: await $.env.get('HOME'),
  }),
  log: text => $.ui.log(text, { to: 'debug' }),
  ui: {
    toast: (text, options) => $.ui.toast(text, { timeoutMs: TOAST_MS, ...options }),
    open: args => $.ui.open(args),
    close: id => $.ui.close({ id }),
    panes: () => $.ui.panes(),
    reveal: (pane, key) => $.ui.scroll({ to: { key }, in: pane, block: 'center' }),
    redraw: () => $.ui.invalidate('ui.render'),
    play: asset => $.audio.play({ asset }),
  },
  prompt: {
    submit: text => $.prompt.submit({ text, asUser: true }),
    read: async () => (await $.prompt.read()).text,
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
      read: () => read($, inFlight),
      write: value => update($, inFlight, () => value),
      update: change => update($, inFlight, change),
    },
    pane: {
      read: () => read($, pane),
      write: value => update($, pane, () => value),
      update: change => update($, pane, change),
    },
    draft: {
      read: () => read($, draft),
      write: value => update($, draft, () => value),
      update: change => update($, draft, change),
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
  },
})

export const register: Register = on => {
  // Also the first hook a reload of this code runs, `$.state` still naming
  // the work the window held, and the board as Lee left it.
  on('session.start', async ($, e, next) => {
    const host = hostOf($)

    for (const spec of SPECS) {
      await $.tool.register(spec)
    }

    await serially(() => resume(host)).catch(logFailure(host, 'taking the attached work up again'))
    await serially(async () => rejoin(host, await host.session.id())).catch(
      logFailure(host, 'rejoining the last work'),
    )
    // The last load's timers are gone: what it had pulsing or flashing comes to rest.
    await host.state.pulse.write({ asks: [], frames: 0 })
    await host.state.flash.write(0)
    await takeUpDelivery(host).catch(logFailure(host, 'writing down the replies Claude has'))
    await $.command.register({
      name: 'sitrep',
      description: 'Open the sitrep board: where this piece of work stands, and what waits on you.',
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
  // lists the project's works. A new process computes it before its
  // session.start runs (live), so a resumed conversation's rejoin comes first
  // here, for the listing to name it.
  on('prompt.context', async ($, e, next) => {
    const host = hostOf($)
    const listing = await serially(async () => {
      await rejoin(host, await host.session.id()).catch(logFailure(host, 'rejoining the last work'))

      return startListing(host)
    })

    return next({ ...e, blocks: [...e.blocks, { name: LISTING, text: listing }] })
  }).catch(($, e, next) => next(e))

  on('turn.start', async ($, e, next) => {
    await heardTurn(hostOf($), e.text)

    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      await wentQuiet(hostOf($))
    }

    return next(e)
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

    if (await tookPaste(host, e)) {
      return { drop: PASTED_HERE }
    }

    const change = await serially(() => boardChange(host))

    if (change === undefined) {
      return next(e)
    }

    const entered = await next({ ...e, context: [...(e.context ?? []), change.context] })

    if (entered.drop === undefined) {
      await markSeen(host, change.work)
    }

    return entered
  }).catch(($, e, next) => next(e))

  on('session.end', async ($, e, next) => {
    const host = hostOf($)

    await serially(() => letGo(host)).catch(logFailure(host, 'letting go of the attached work'))
    await wentQuiet(host)

    return next(e)
  }).catch(($, e, next) => next(e))

  // An in-process /resume ends one conversation (session.end lets go of its
  // work) and resumes another, for which no session.start fires. Here
  // `$.session.id()` still names the conversation that ended (live): the
  // resumed one is the event's.
  on('classic.SessionStart', async ($, e, next) => {
    if (e.source === 'resume') {
      const host = hostOf($)

      await serially(() => rejoin(host, e.session_id)).catch(
        logFailure(host, 'rejoining the resumed work'),
      )
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'sitrep' }, async $ => {
    await openBoard(hostOf($))

    return {}
  }).catch(() => ({ text: 'The sitrep board could not open.' }))

  on('ui.press', { plugin: 'sitrep', element: BAND_KEYS }, async ($, e) => {
    await pressBand(hostOf($), e.element)

    return { element: e.element }
  }).catch(($, e, next) => next(e))

  on('ui.close', { id: PANE }, async ($, e, next) => {
    const closed = await next(e)

    await boardClosed(hostOf($))

    return closed
  }).catch(($, e, next) => next(e))

  on('ui.message', async ($, e, next) => {
    await heardTyping(hostOf($), e.element, e.data)

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const scene = e.props.hasSurvey ? undefined : await sceneOf(hostOf($))

    return scene === undefined ? next(e) : drawBand($.ui.resolve(e), e.props.bodyColumns, scene)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const host = hostOf($)
    const scene = await sceneOf(host)

    drewBoard(e.props.scroll, floatingRows(e.props, scene))

    return drawPane($.ui.resolve(e), e.surface, actionsOf(host), e.props, scene)
  })

  // Docked, Ready to send floats over the foot of the board's window, which
  // the engine scrolls as though nothing covered it: a page key moves by the
  // rows above the box, and the focus is brought clear of it.
  on('ui.scroll', { requestId: PANE }, ($, e, next) => next({ ...e, offset: movedTo(e) })).catch(
    ($, e, next) => next(e),
  )

  on('ui.focus', { requestId: PANE }, async ($, e, next) => {
    const moved = await next(e)

    if (moved.deny === undefined) {
      await followFocus(hostOf($), e.element)
    }

    return moved
  }).catch(($, e, next) => next(e))

  // A refused or interrupted call keeps the engine's own row, so what went wrong shows.
  on('ui.render', { component: 'ToolUse', props: { tool: TOOL_NAMES } }, async ($, e, next) => {
    const line =
      e.props.isErrored || e.props.isInterrupted
        ? undefined
        : await toolLine(e.props.tool, e.props.input, () => heldWork(hostOf($)))

    return line === undefined ? next(e) : drawToolRow($.ui.resolve(e), line)
  })

  on('ui.render', { component: 'ToolResult', props: { tool: TOOL_NAMES } }, ($, e, next) =>
    e.props.isErrored ? next(e) : drawToolResult($.ui.resolve(e)),
  )
}
