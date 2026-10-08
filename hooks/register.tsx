/**
 * sitrep — a small window onto where a piece of work stands and what it
 * needs from Lee (DESIGN.md beside this folder).
 *
 * Claude starts or joins a piece of work through the tools, and posts to its
 * board as it goes. The window then holds that work: it writes its own file
 * in the work's folder, keeps a heartbeat there, and watches the folder, so
 * the work's fold stays current in `$.state` for the board to draw.
 *
 * Lee sees it on the board pane, the band above the prompt and the glance,
 * answers its asks there, and sends the replies as Lee's own message. What
 * changed on the board without Claude (another window, the CLI) rides into
 * Claude's next turn as context Lee does not see. A session that ends lets
 * go of its work.
 *
 * Every call on `$` is spelled here, in `hostOf`: the engine reads them off
 * this file's source, and refuses a module that hands `$` to an import.
 * The drawing lives in ./draw, pure functions of a surface's elements and
 * the scene.
 */
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { actionsOf, heardTyping } from './actions'
import { isBoardMessage } from './deliver'
import { drawBand } from './draw/band'
import { drawPane } from './draw/board'
import { drawToolResult, drawToolRow, toolLine } from './draw/tool-row'
import { logFailure, type Host } from './host'
import { BAND_KEYS, boardClosed, openBoard, PANE, pressBand, syncBoard } from './pane'
import { heldWork, sceneOf, tickEvery } from './scene'
import { boardChange, markSeen } from './seen'
import { answerCall, SPECS, TOOL_NAMES } from './tools'
import { letGo, resume, serially } from './window'

const attachment = atom({ plugin: 'sitrep', key: 'attachment' } as const, null)
const board = atom({ plugin: 'sitrep', key: 'board' } as const, null)
const seen = atom({ plugin: 'sitrep', key: 'seen' } as const, null)
const queue = atom({ plugin: 'sitrep', key: 'queue' } as const, [])
const sending = atom({ plugin: 'sitrep', key: 'sending' } as const, [])
const pane = atom({ plugin: 'sitrep', key: 'pane' } as const, {
  isOpen: false,
  mode: 'full',
  view: 'session',
  selected: null,
  commenting: null,
})
const draft = atom({ plugin: 'sitrep', key: 'draft' } as const, '')
const pulse = atom({ plugin: 'sitrep', key: 'pulse' } as const, { asks: [], frames: 0 })
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
  run: (argv, cwd) => $.process.run(argv, { cwd }),
  log: text => $.ui.log(text, { to: 'debug' }),
  ui: {
    toast: (text, options) => $.ui.toast(text, options),
    open: args => $.ui.open(args),
    close: id => $.ui.close({ id }),
    panes: () => $.ui.panes(),
    play: asset => $.audio.play({ asset }),
  },
  prompt: {
    submit: text => $.prompt.submit({ text, asUser: true }),
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
    queue: {
      read: () => read($, queue),
      write: value => update($, queue, () => value),
      update: change => update($, queue, change),
    },
    sending: {
      read: () => read($, sending),
      write: value => update($, sending, () => value),
      update: change => update($, sending, change),
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
    // A send the last load made is heard of no more: its replies wait to be sent again.
    await host.state.sending.write([])
    await $.command.register({
      name: 'sitrep',
      description: 'Open the sitrep board: where this piece of work stands, and what waits on you.',
      immediate: true,
    })
    await syncBoard(host)
    tickEvery(host)

    return next(e)
  })

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

    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'sitrep' }, async $ => {
    await openBoard(hostOf($), 'full')

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

    return drawPane($.ui.resolve(e), e.surface, actionsOf(host), e.props, await sceneOf(host))
  })

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
