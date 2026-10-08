/**
 * sitrep — a small window onto where a piece of work stands and what it
 * needs from Lee (DESIGN.md beside this folder).
 *
 * Claude starts or joins a piece of work through the tools, and posts to its
 * board as it goes. The window then holds that work: it writes its own file
 * in the work's folder, keeps a heartbeat there, and watches the folder, so
 * the work's fold stays current in `$.state` for the board to draw.
 *
 * What changed on the board without Claude (another window, Lee, the CLI)
 * rides into Claude's next turn as context Lee does not see. A session that
 * ends lets go of its work.
 *
 * Every call on `$` is spelled here, in `hostOf`: the engine reads them off
 * this file's source, and refuses a module that hands `$` to an import.
 */
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { logFailure, type Host } from './host'
import { boardChange, markSeen } from './seen'
import { answerCall, SPECS, TOOL_NAMES } from './tools'
import { letGo, resume, serially } from './window'

const attachment = atom({ plugin: 'sitrep', key: 'attachment' } as const, null)
const board = atom({ plugin: 'sitrep', key: 'board' } as const, null)
const seen = atom({ plugin: 'sitrep', key: 'seen' } as const, null)

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
  state: {
    attachment: {
      read: () => read($, attachment),
      write: value => update($, attachment, () => value),
    },
    board: {
      read: () => read($, board),
      write: value => update($, board, () => value),
    },
    seen: {
      read: () => read($, seen),
      write: value => update($, seen, () => value),
    },
  },
})

export const register: Register = on => {
  // Also the first hook a reload of this code runs, `$.state` still naming
  // the work the window held.
  on('session.start', async ($, e, next) => {
    const host = hostOf($)

    for (const spec of SPECS) {
      await $.tool.register(spec)
    }

    await serially(() => resume(host)).catch(logFailure(host, 'taking the attached work up again'))

    return next(e)
  })

  on('tool.call', { tool: TOOL_NAMES }, ($, e) => answerCall(hostOf($), e)).catch(($, e, next) =>
    next.called
      ? next(e)
      : { deny: `The sitrep board could not take that: ${next.error.message ?? next.error.kind}.` },
  )

  on('prompt.submit', async ($, e, next) => {
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
}
