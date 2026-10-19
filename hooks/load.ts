/**
 * This load of the mod among the loads a window's reloads make: when it
 * began, stamped on what it writes for the next load (its heartbeat, what it
 * heard in `$.state`), and whether a later load has since written over it.
 *
 * A call in flight across `/reload-plugins` may settle in the load it began
 * in, whose memory is then stale. The engine's types say only that a reload
 * cancels the old load's pending waits (its timers), not that its other
 * continuations never resume, so a load that finds a later load's stamp
 * writes neither again.
 */
import { logFailure, type Host } from './host'

/** When this load began, read once, as session.start asks first; undefined where the clock failed, and then nothing is fenced by it. */
let stamp: Promise<number | undefined> | undefined

let isOutrun = false

export const loadedNow = (host: Host) => {
  stamp ??= host.clock.now().catch((error: unknown) => {
    logFailure(host, 'stamping this load')(error)

    return undefined
  })

  return stamp
}

/** Whether a later load has written over this one's heartbeat or state. */
export const isSuperseded = () => isOutrun

/** Whether `theirs`, the stamp on something written, is a later load's than `mine`. */
export const isLater = (theirs: number | undefined, mine: number | undefined) =>
  theirs !== undefined && mine !== undefined && theirs > mine

/** A later load wrote `what`: this one writes no more of the window's heartbeat or state, and says so once. */
export const supersede = (host: Host, what: string) => {
  if (!isOutrun) {
    isOutrun = true
    host.log(
      `sitrep: a later load of the mod wrote ${what}: this one writes the window's heartbeat and state no more`,
    )
  }
}
