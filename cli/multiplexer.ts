/**
 * A multiplexer adapter, one for each multiplexer a window may run in (tmux,
 * zmx): from where a window is, the clients showing its session, and for
 * tmux the select that makes a client show its pane. Each client then goes
 * through the one step every multiplexer's does (`seatOf`): the terminal app
 * its ancestry finds, and the device of that app's own child. The terminal
 * drivers are the other axis (`driver.ts`): each brings forward the window
 * on a device. Another multiplexer is one more adapter here, beside what
 * every window records of where it is: a field of `Where` for its session,
 * the variable it is read from, and its line in `watch`'s windows.
 *
 * A window that records two, one run inside the other, is in the innermost:
 * the one whose own pty is the window's device, where one can tell; else
 * each that cannot tell, never one that says its pty is another.
 */
import type { Where } from '../core'
import type { Io } from './io'
import type { Processes, Seat } from './processes'
import type { Select } from './tmux'

/**
 * Where a jump can bring a window forward: the terminal app, the device of
 * its window there, which only an app with no driver may lack, and the
 * select that makes that window show the pane first, where tmux must make one.
 */
export type Place = Seat & { select?: Select }

/** What a multiplexer read of the screen, for the windows in it. */
export type Reading = {
  /** Whether a window runs in it, as its heartbeat says. */
  isIn: (where: Where) => boolean
  /** Whether the window's device is this multiplexer's own pty for it, so the innermost of those it runs in; undefined where that cannot be told. */
  isOnItsPty: (where: Where) => boolean | undefined
  /** The places showing a window in it, or that a select would make show it, its clients seated by the snapshot; none for a window not in it. */
  places: (where: Where, processes: Processes) => Place[]
  /** What it asked that gave no answer, for the window. */
  unanswered: (where: Where) => readonly string[]
  /** Whether the window's clients are told only by `ps`: whether `ps` giving no answer leaves where the window shows unknown. */
  needsProcesses: (where: Where) => boolean
}

/** A multiplexer: whether a window runs in it, and what it reads of the screen for those that do. */
export type Multiplexer = Pick<Reading, 'isIn'> & {
  /** Reads what it needs, each program within the time limit, for windows that run in it; nothing that fails here fails the read. */
  read: (io: Io, windows: readonly Where[]) => Promise<Reading>
}
