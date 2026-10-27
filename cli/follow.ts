/**
 * The sessions the SitRep window follows, as `watch` hears them on its
 * standard input, for it to carry their boards in its lines (see "One
 * engine, two front ends" in DESIGN.md).
 *
 * - Each line is `{"follow": ["sr-aaaaaa", ...]}`, the whole set followed
 *   now, in place of the set last given. A line is whole at its newline, and
 *   one that does not read is passed over.
 * - Lines that read wake the watch for a look, their set changed or not: so
 *   the app has it look straight after a write of its own. Several heard at
 *   once wake it once, the last one's set standing.
 * - Standard input ending changes nothing: the set last given stands.
 */
import { isObject } from '../core'
import type { Io } from './io'
import type { BoardFields, HeldBoard } from './output'

/** The set a line gives; undefined for one that does not read. */
export const followOf = (line: string): ReadonlySet<string> | undefined => {
  let value: unknown

  try {
    value = JSON.parse(line)
  } catch {
    return undefined
  }

  const follow = isObject(value) ? value.follow : undefined

  return Array.isArray(follow) && follow.every(id => typeof id === 'string')
    ? new Set(follow)
    : undefined
}

/**
 * The sessions followed, heard from standard input from now until `stop`,
 * what is heard at once waking `wake` once where any line of it reads. The
 * board last printed of each is kept, as its text, or null for none found,
 * and a session dropped from the set is let go of with it, so followed again
 * it is new.
 */
export const following = (io: Io, wake: () => void) => {
  let printed = new Map<string, string | null>()
  let followed: ReadonlySet<string> = new Set()
  let rest = ''

  /** Takes the set a line gives, if it reads; whether it did. */
  const take = (line: string) => {
    const set = followOf(line)

    if (set === undefined) {
      return false
    }

    followed = set
    printed = new Map([...printed].filter(([id]) => set.has(id)))

    return true
  }

  const stop = io.input(text => {
    const lines = (rest + text).split('\n')

    rest = lines.pop() ?? ''

    if (lines.map(take).includes(true)) {
      wake()
    }
  })

  return {
    /** The sessions followed now. */
    followed: () => followed,
    /**
     * The boards to print of the sessions `looked` at that are followed
     * still, each new to the set or changed since last printed, as
     * `boardById` finds it. Each counts as printed from now on.
     */
    unprinted: (
      looked: ReadonlySet<string>,
      boardById: (id: string) => HeldBoard | undefined,
    ) => {
      const boards: Record<string, BoardFields | null> = {}

      for (const id of [...looked].filter(each => followed.has(each))) {
        const board = boardById(id)
        const text = board?.text ?? null

        if (printed.get(id) !== text) {
          boards[id] = board?.fields ?? null
          printed.set(id, text)
        }
      }

      return boards
    },
    stop,
  }
}
