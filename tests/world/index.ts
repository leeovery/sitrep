/**
 * The engine beneath the mod, for its tests: a file system in memory, the
 * conversation, the environment and the clock, the display, and a record of
 * what the mod puts in `$.state` and submits. Nothing touches a real
 * folder.
 */
import type { On } from 'claude-code'
import { mock, type Engine } from '../kit'
import { sessionPaths } from '../../core'
import { HELP_DESK, HOME, PROJECT, REPO, ROOT, STATE_HOME, T0 } from '../data'
import { startedId, tools } from './calls'
import { CONVERSATION, conversation, walking } from './conversation'
import { display } from './display'
import { disk } from './fs'
import { panes } from './panes'
import { sessions } from './sessions'
import { kept } from './state'

export { postedId, startedId } from './calls'
export { CONVERSATION, PROMPT, TTY, WHERE, type Walk } from './conversation'
export { manifestOf } from './fs'
export { ACROSS, BAND, DOCKED, INLINE, SURFACES, WIDE } from './panes'
export { writeDoor } from './state'
export {
  asked,
  asking,
  asksOnBand,
  kindsIn,
  openAsk,
  pressYes,
  sendingIn,
  toProject,
  turnEnded,
} from './steps'

/**
 * Knobs on the world: when it starts, the folder the window starts in, and
 * the environment beyond sitrep's own folders (a Ghostty window outside tmux
 * unless told otherwise).
 */
type Options = { now?: number; cwd?: string; env?: Readonly<Record<string, string>> }

export type World = ReturnType<typeof world>

/** The board as a surface draws it. */
export type Board = Awaited<ReturnType<World['pane']>>

export function world(engine: Engine, on: On, options: Options = {}) {
  const clock = mock.clock(on, { now: options.now ?? T0 })
  const shown = display(on)

  mock.env(on, {
    XDG_STATE_HOME: STATE_HOME,
    HOME,
    ...(options.env ?? { TERM_PROGRAM: 'ghostty' }),
  })

  const walk = walking(on)
  const talk = conversation(engine, on, options.cwd ?? REPO)
  const held = kept(on)
  const fs = disk(on, clock)
  const called = tools(engine, on)

  /** The conversation started, and a session started in it: its id and its folder's paths. */
  const begin = async () => {
    await engine.session.start(CONVERSATION)

    const id = startedId(await called.call('start', HELP_DESK))

    return { id, paths: sessionPaths(ROOT, PROJECT.key, id) }
  }

  return {
    clock,
    ...shown,
    ...walk,
    ...talk,
    ...held,
    ...fs,
    ...called,
    ...sessions(fs.put, clock),
    ...panes(engine),
    begin,
  }
}
