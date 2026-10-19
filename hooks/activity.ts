/**
 * What this window has heard of its own doing, for this load: read from
 * `$.state` once, as a reload left it there, then kept here, and written
 * back there at each change, in order, for the next load.
 *
 * Never read back from `$.state` once loaded: every `get` of one dispatch
 * reads one moment, and a call's hook, whose dispatch lasts as long as its
 * tool runs, would read what stood as the call began, missing a permission
 * prompt raised meanwhile.
 */
import { QUIET, type Activity } from '../core'
import { logFailure, type Host } from './host'

let known: Activity | undefined

let loading: Promise<void> | undefined

let writes: Promise<unknown> = Promise.resolve()

const load = (host: Host) =>
  (loading ??= host.state.activity.read().then(
    kept => {
      known ??= kept
    },
    (error: unknown) => {
      logFailure(host, "reading the window's state")(error)
      known ??= QUIET
    },
  ))

/** What the window has heard, as it stands. */
export const activityNow = async (host: Host) => {
  await load(host)

  return known ?? QUIET
}

/**
 * Changes what the window has heard, here at once, once it is loaded: what
 * it was, and what it is. The write to `$.state` follows the writes before
 * it, and is not waited on; one refused is logged.
 */
export const changeActivity = async (host: Host, change: (activity: Activity) => Activity) => {
  await load(host)

  const before = known ?? QUIET
  const after = change(before)

  known = after
  writes = writes
    .then(() => host.state.activity.write(after))
    .catch(logFailure(host, "recording the window's state"))

  return { before, after }
}
