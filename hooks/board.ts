/**
 * A folded work as `$.state` holds it, for drawing. `$.state` holds JSON
 * data, which keeps no Map or Set, so the board carries the work's map of
 * items and set of ids as lists, and drawing rebuilds them.
 */
import type { Work } from '../core'
import type { SitrepBoard } from '../types'

/** A folded work as the board `$.state` holds. */
export const boardOf = (work: Work): SitrepBoard => ({
  ...work,
  items: [...work.items.values()],
  ids: [...work.ids],
})

/** The work a board holds, its map of items and set of ids rebuilt: what drawing reads. */
export const workOf = (held: SitrepBoard): Work => ({
  ...held,
  items: new Map(held.items.map(item => [item.id, item])),
  ids: new Set(held.ids),
})
