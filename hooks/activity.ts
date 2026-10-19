/**
 * What this window has heard of its own doing, for this load: read from
 * `$.state` once, as an earlier load left it there, then kept here, and
 * written back there at each change, in order, for the next load.
 *
 * Never read back from `$.state` once loaded: every `get` of one dispatch
 * reads one moment, and a call's hook, whose dispatch lasts as long as its
 * tool runs, would read what stood as the call began, missing a permission
 * prompt raised meanwhile.
 *
 * Each write carries this load's stamp and lands only on the version this
 * load last saw. A miss is another load's write: an earlier load's is
 * written over, and a later load's means this load is stale (load.ts), and
 * writes no more.
 */
import { isTime, parseActivity, QUIET, type Activity } from '../core'
import type { SitrepActivity } from '../types'
import { logFailure, type Host } from './host'
import { isLater, isSuperseded, loadedNow, supersede } from './load'

let known: Activity | undefined

let loading: Promise<void> | undefined

let writes: Promise<unknown> = Promise.resolve()

/** The value in `$.state` as this load last saw it: its version, and the stamp of the load that wrote it. */
let seen: { version: number; loadedAt?: number } = { version: 0 }

const see = ({ value, version }: { value?: SitrepActivity; version: number }) => {
  seen = { version, loadedAt: isTime(value?.loadedAt) ? value.loadedAt : undefined }
}

const load = (host: Host) =>
  (loading ??= host.state.activity.get().then(
    read => {
      see(read)
      known ??= parseActivity(read.value)
    },
    (error: unknown) => {
      logFailure(host, "reading the window's state")(error)
      known ??= QUIET
    },
  ))

/** Writes `activity`, stamped `loadedAt`, on the version last seen; on a miss, reads it again and writes once more, unless a later load wrote it. */
const put = async (
  host: Host,
  activity: Activity,
  loadedAt: number | undefined,
  isAgain = false,
): Promise<void> => {
  if (isSuperseded()) {
    return
  }

  if (isLater(seen.loadedAt, loadedAt)) {
    supersede(host, "the window's state in $.state")

    return
  }

  const stamped = loadedAt === undefined ? activity : { ...activity, loadedAt }
  const written = await host.state.activity.set(stamped, seen.version)

  if (written.isSet) {
    seen = { version: written.version, loadedAt }

    return
  }

  if (isAgain) {
    throw new Error('another load wrote it first, twice')
  }

  see(await host.state.activity.get())

  return put(host, activity, loadedAt, true)
}

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
    .then(async () => put(host, after, await loadedNow(host)))
    .catch(logFailure(host, "recording the window's state"))

  return { before, after }
}
