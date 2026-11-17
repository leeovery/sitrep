/**
 * A folded session as `$.state` holds it, for drawing. `$.state` holds JSON
 * data, which keeps no Map or Set, so the board carries the session's map of
 * items and set of ids as lists, and drawing rebuilds them.
 */
import { ITEM_TYPES, type Session } from '../core'
import type { SitrepAttachment, SitrepBoard, SitrepItem } from '../types'

/**
 * A folded session as the board `$.state` holds, each window's state and
 * what it sends left out: nothing the mod draws reads them, the replies sent
 * showing on their items, and a window working changes its state up to
 * once a second, which would rewrite the board and redraw every pane that
 * watches the session.
 */
export const boardOf = (session: Session): SitrepBoard => ({
  ...session,
  log: [],
  presence: session.presence.map(({ state, sending, ...presence }) => presence),
  items: [...session.items.values()],
  ids: [...session.ids],
})

/** Whether an item is of a type today's board knows: a board an older load saved can hold notes, gone since (17 November 2026). */
const isKnown = (item: SitrepItem) => (ITEM_TYPES as readonly string[]).includes(item.type)

/** The session a board holds, its map of items and set of ids rebuilt, and its history, which a board an older load saved lacks: what drawing reads. */
export const sessionOf = ({ log, filedUnder, ...held }: SitrepBoard): Session => ({
  ...held,
  history: held.history ?? [],
  items: new Map(held.items.filter(isKnown).map(item => [item.id, item])),
  ids: new Set(held.ids),
})

/** The key of the project the held session is filed under, as its board says; with a board of another session, or one from a load before moves, the folder `held` names. */
export const hereOf = (held: SitrepAttachment, board: SitrepBoard | null) =>
  board?.id === held.session ? (board.filedUnder ?? held.project) : held.project
