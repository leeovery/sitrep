/**
 * The sessions a window holds that no terminal on this Mac shows, as SitRep
 * last read them, from its `here.json`: SitRep writes the file at every
 * read of here, every 3 seconds (`HereWatch.every` in the app) and at each
 * board line, and removes it as it quits. A file older than HERE_STALE_MS
 * is a SitRep no longer reading, so it says nothing; and no file, or one
 * that does not read, says nothing either: every held session is then here.
 */
import { isTime, parseVersioned } from './entries'
import type { Upgrade } from './versions'

/** How the app's `here.json` of each past version is brought to the next: none yet, the format being at its first. */
const UPGRADES: readonly Upgrade[] = []

/** How old a file may be and still say what SitRep reads: three of its reads, 3 seconds apart, and a second over. */
export const HERE_STALE_MS = 10_000

const NONE: ReadonlySet<string> = new Set()

const isIds = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every(each => typeof each === 'string')

/**
 * The sessions `here.json`'s text says no terminal on this Mac shows, at
 * `now`: none where there is no file, or it is not a JSON object of a
 * version this reader knows, holding a time and a list of ids, or its time
 * is HERE_STALE_MS or more from `now`, either side, as a clock set back
 * leaves it.
 */
export const notHereOf = (text: string | undefined, now: number): ReadonlySet<string> => {
  const file = text === undefined ? undefined : parseVersioned(text, UPGRADES)

  if (file === undefined || !isTime(file.at) || !isIds(file.notHere) || Math.abs(now - file.at) >= HERE_STALE_MS) {
    return NONE
  }

  return new Set(file.notHere)
}
