/**
 * A folded session as `$.state` holds it, for drawing. `$.state` holds JSON
 * data, which keeps no Map or Set, so the board carries the session's map of
 * items and set of ids as lists, and drawing rebuilds them.
 */
import type { Session } from '../core'
import type { SitrepBoard } from '../types'

/**
 * A folded session as the board `$.state` holds, each window's state left
 * out: nothing the mod draws reads it, and a window working changes it up to
 * once a second, which would rewrite the board and redraw every pane that
 * watches the session.
 */
export const boardOf = (session: Session): SitrepBoard => ({
  ...session,
  presence: session.presence.map(({ state, ...presence }) => presence),
  items: [...session.items.values()],
  ids: [...session.ids],
})

/** The session a board holds, its map of items and set of ids rebuilt: what drawing reads. */
export const sessionOf = (held: SitrepBoard): Session => ({
  ...held,
  items: new Map(held.items.map(item => [item.id, item])),
  ids: new Set(held.ids),
})
