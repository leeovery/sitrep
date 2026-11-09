/**
 * A multiplexer adapter, one for each multiplexer a window may run in (tmux,
 * zmx): from where a window is, the clients showing its session, and for
 * tmux the select that makes a client show its pane. Each client then goes
 * through the one step every multiplexer's does (`seatOf`): the terminal app
 * its ancestry finds, and the device of that app's own child. The terminal
 * drivers are the other axis (`driver.ts`): each brings forward the window
 * on a device. Another multiplexer is one more adapter, and nothing else.
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
  /** The places showing a window in it, or that a select would make show it, its clients seated by the snapshot; none for a window not in it. */
  places: (where: Where, processes: Processes) => Place[]
  /** What it asked that gave no answer, for the window. */
  unanswered: (where: Where) => readonly string[]
  /** Whether the window's clients are told only by `ps`: whether `ps` giving no answer leaves where the window shows unknown. */
  needsProcesses: (where: Where) => boolean
}

/** A multiplexer: whether a window runs in it, and what it reads of the screen for those that do. */
export type Multiplexer = {
  /** Whether a window runs in it, as its heartbeat says. */
  isIn: (where: Where) => boolean
  /** Reads what it needs, each program within the time limit, for windows that run in it; nothing that fails here fails the read. */
  read: (io: Io, windows: readonly Where[]) => Promise<Reading>
}
