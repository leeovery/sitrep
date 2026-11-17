/**
 * Snooze's choices as the app's `snooze.json` sets them, read as a look
 * lists sitrep's folder: the file is read again only once its size or time
 * moved, or where the last read failed or came too soon after its time to
 * trust; and no file, or one that does not read, is the defaults, never an
 * error the board shows (DESIGN.md, "Storage").
 */
import type { FsEntry } from 'claude-code'
import {
  SNOOZE_DEFAULTS,
  SNOOZE_FILE,
  snoozeFile,
  snoozeSettingsOf,
  type SnoozeSettings,
} from '../core'
import type { Host } from './host'
import { textAt } from './reader'

/**
 * How long after a file's time a read of it is not trusted: a rewrite of
 * the same size within the time's resolution, a second on HFS+ and two on
 * exFAT, leaves the time as it was, so it is read again at the next look,
 * as git takes a file changed as its index was written.
 */
const RACY_MS = 2000

/** The file as last read whole, and long enough after its time to trust: its size and time, and what it said. */
let kept: { size: number; mtimeMs: number; settings: SnoozeSettings } | undefined

/** Forgets the file as last read, so the next look reads it afresh. Only tests call it. */
export const forgetSnooze = () => {
  kept = undefined
}

/** Snooze's choices as the file in sitrep's folder `root` sets them at `now`. */
export const snoozeSettings = async (host: Host, root: string, now: number) => {
  const listing = await host.fs.list(root).catch((): FsEntry[] => [])
  const entry = listing.find(each => each.kind === 'file' && each.name === SNOOZE_FILE)

  if (entry === undefined) {
    kept = undefined

    return SNOOZE_DEFAULTS
  }

  const { size, mtimeMs } = entry

  if (kept?.size === size && kept.mtimeMs === mtimeMs) {
    return kept.settings
  }

  const text = await textAt(host, snoozeFile(root))
  const settings = snoozeSettingsOf(text)

  kept = text !== undefined && now - mtimeMs >= RACY_MS ? { size, mtimeMs, settings } : undefined

  return settings
}
