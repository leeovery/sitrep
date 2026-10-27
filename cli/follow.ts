/**
 * The sessions the SitRep window follows, as `watch` hears them on its
 * standard input, for it to carry their boards in its lines (see "One
 * engine, two front ends" in DESIGN.md).
 *
 * - Each line is `{"follow": ["sr-aaaaaa", ...]}`, the whole set followed
 *   now, in place of the set last given. A line is whole at its newline, and
 *   one that does not read is passed over.
 * - Every line that reads wakes the watch for a look, its set changed or
 *   not: so the app has it look straight after a write of its own.
 * - Standard input ending changes nothing: the set last given stands.
 */
import { isObject } from '../core'
import type { Io } from './io'
import type { BoardFields } from './output'

/** A session's board as the watch holds it, its text what tells it from another; undefined where it finds no such session. */
export type Board = { fields: BoardFields; text: string } | undefined

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
 * each line that reads given to `wake`. The board last printed of each is
 * kept, as its text, or null for none found, and a session dropped from the
 * set is let go of with it, so followed again it is new.
 */
export const following = (io: Io, wake: () => void) => {
  let printed = new Map<string, string | null>()
  let followed: ReadonlySet<string> = new Set()
  let rest = ''

  const take = (line: string) => {
    const set = followOf(line)

    if (set === undefined) {
      return
    }

    followed = set
    printed = new Map([...printed].filter(([id]) => set.has(id)))
    wake()
  }

  const stop = io.input(text => {
    const lines = (rest + text).split('\n')

    rest = lines.pop() ?? ''
    lines.forEach(take)
  })

  return {
    /** The sessions followed now. */
    followed: () => followed,
    /**
     * The boards to print of the sessions `looked` at that are followed
     * still: each new to the set, or changed since last printed, by `boardOf`.
     * Each counts as printed from now on.
     */
    unprinted: (looked: ReadonlySet<string>, boardOf: (id: string) => Board) => {
      const boards: Record<string, BoardFields | null> = {}

      for (const id of [...looked].filter(each => followed.has(each))) {
        const board = boardOf(id)
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
