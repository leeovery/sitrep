/**
 * When a run that goes on until it is to end, as `watch`, ends: once the
 * program that started it has gone, its standard output fails (a write to a
 * pipe its reader closed), or SIGTERM comes. A program that quits leaves its
 * child to launchd, pid 1, and while the board stays still no write finds
 * the pipe closed, so the parent is looked for every second. It is the one
 * the CLI found as it loaded: one gone before then leaves the run launchd's
 * already, which counts as gone.
 */

/** How often it looks whether the parent is still there. */
export const PARENT_MS = 1_000

/** The pid of launchd, which takes in the child of a program that quits. */
const LAUNCHD = 1

import type { Ending } from './io'

/** What a run's end is heard from, as the shell binds it to the process. Each listening gives what stops it. */
export type Signals = {
  /** The pid of the run's parent now. */
  parent: () => number
  onTerm: (heard: () => void) => () => void
  onOutputFailed: (heard: () => void) => () => void
  every: (ms: number, tick: () => void) => () => void
}

/** The run's end listened for, `loadedUnder` the parent's pid as the CLI loaded; what it listens by goes as it ends, or as it is stopped. */
export const endOf = (signals: Signals, loadedUnder: number): Ending => {
  const stops: (() => void)[] = []
  const stop = () => stops.splice(0).forEach(each => each())
  const ended = new Promise<void>(resolve => {
    const isGone = () => {
      const parent = signals.parent()

      return parent === LAUNCHD || parent !== loadedUnder
    }
    const end = () => {
      stop()
      resolve()
    }

    if (isGone()) {
      resolve()

      return
    }

    stops.push(
      signals.onTerm(end),
      signals.onOutputFailed(end),
      signals.every(PARENT_MS, () => {
        if (isGone()) {
          end()
        }
      }),
    )
  })

  return { ended, stop }
}
