/** Parts of the mod's host answered with no engine beneath, for a pure test that runs the mod's own code: its file system over files in memory, and its values in `$.state`. */
import type { Host, Slot } from '../hooks/host'
import { bytesOf, listingIn, isThere, missing, type File } from './fs'

/** The mod's file system over `files`, answering as the engine does, what it writes stamped at `now`. */
export const fsOn = (files: Map<string, File>, now: number): Host['fs'] => {
  const refused = (path: string) => Promise.reject(new Error(missing(path)))

  return {
    read: async path => files.get(path)?.text ?? refused(path),
    write: async (path, text) => {
      files.set(path, { text, mtimeMs: now })
    },
    list: async dir => {
      const listing = listingIn(files, dir)

      return listing.length === 0 ? refused(dir) : listing
    },
    exists: async path => isThere(files, path),
    save: async (path, base64) => {
      files.set(path, { text: '', bytes: bytesOf(base64), mtimeMs: now })
    },
    remove: async paths => {
      for (const path of paths) {
        files.delete(path)
      }
    },
    touch: async paths => {
      for (const path of paths) {
        const file = files.get(path)

        if (file !== undefined) {
          files.set(path, { ...file, mtimeMs: now })
        }
      }
    },
    real: async path => (isThere(files, path) ? path : undefined),
  }
}

/** One of the mod's values in `$.state`, held in memory. */
export const slot = <T>(value: T): Slot<T> => {
  let held = value

  return {
    read: async () => held,
    write: async next => {
      held = next
    },
    update: async change => {
      held = change(held)
    },
  }
}
