/**
 * Snooze's choices as the app's `snooze.json` sets them, read as a look
 * lists sitrep's folder: the file is read again only once its size or time
 * moved, and no file, or one that does not read, is the defaults, never an
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

/** The file as last read: its size and time, and what it said. */
let kept: { size: number; mtimeMs: number; settings: SnoozeSettings } | undefined

/** Forgets the file as last read, so the next look reads it afresh. Only tests call it. */
export const forgetSnooze = () => {
  kept = undefined
}

/** Snooze's choices as the file in sitrep's folder `root` sets them now. */
export const snoozeSettings = async (host: Host, root: string) => {
  const listing = await host.fs.list(root).catch((): FsEntry[] => [])
  const entry = listing.find(each => each.kind === 'file' && each.name === SNOOZE_FILE)

  if (entry === undefined) {
    kept = undefined

    return SNOOZE_DEFAULTS
  }

  const { size, mtimeMs } = entry

  if (kept === undefined || kept.size !== size || kept.mtimeMs !== mtimeMs) {
    kept = { size, mtimeMs, settings: snoozeSettingsOf(await textAt(host, snoozeFile(root))) }
  }

  return kept.settings
}
