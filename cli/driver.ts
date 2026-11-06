/**
 * A terminal app, as a jump brings its windows forward: one with a driver of
 * its own, which finds the window on a device and brings that window
 * forward, or one with none, brought forward as an app. A driver recognises
 * its windows: outside tmux by the `$TERM_PROGRAM` they give, in the
 * heartbeat's `where`; under tmux by its program among the tmux client's
 * ancestors. The tmux layer under every app makes the window show the pane.
 */
import type { Front } from './front'
import type { Io } from './io'

/**
 * What bringing forward the window on a device came to: brought forward, or
 * undefined, nothing on the device answering, for the next to be tried. An
 * app that cannot ask throws, in plain words.
 */
export type Brought = 'forward' | undefined

/**
 * What a driver throws when its app gave no answer in time, as when the Mac
 * is too busy to reach it: a jump refused so ends unanswered, not refused.
 */
export class Unanswered extends Error {}

/** Brings forward the window on a device, for one jump; a driver finds none on a device not known, and an app with no driver needs none. */
export type Bring = (device: string | undefined) => Promise<Brought>

/** The front as a jump began: a look at it, and which app was in front then, by its bundle id; undefined when lsappinfo could not tell. */
export type FrontAtStart = { look: Front; before: string | undefined }

/** A terminal app: its name in words, and what brings its windows forward for one jump, given the front as the jump began. */
export type App = { name: string; start: (io: Io, front: FrontAtStart) => Bring }

/**
 * What a driver may do beyond bringing a window forward, declared for what
 * comes later and built for none yet: select a tab, select a split, show a
 * session's state.
 */
export type Capability = 'tab' | 'split' | 'state'

/** A terminal app with a driver of its own. */
export type Driver = App & {
  /** `$TERM_PROGRAM` in its windows outside tmux. */
  program: string
  /** The last part of its program's path, as `ps` gives it, which a tmux client in one of its windows descends from. */
  executable: string
  can: readonly Capability[]
}
