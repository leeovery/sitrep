/**
 * The order a jump tries a session's windows in, and the window an away
 * session was last in: board rules, so SitRep reads them through the feed,
 * and ranks no windows itself (see "The structure" in DESIGN.md).
 */
import { isLive } from './presence'
import type { Presence, Session, Where } from './types'

/** A window stopped on Lee: at a permission prompt or a question. */
const needsLee = (presence: Presence) =>
  presence.state?.is === 'permission' || presence.state?.is === 'question'

/**
 * How a window ranks for a jump: stopped on Lee first; then working, as it is
 * active now, however long ago its turn began; then on its own work, as the
 * session's row prefers it (rows.ts's `turnOf`), so the jump goes to the
 * window the row describes; then the rest, on its turn, or saying no state.
 */
const rankOf = (presence: Presence) => {
  if (needsLee(presence)) {
    return 0
  }

  switch (presence.state?.is) {
    case 'working':
      return 1
    case 'onItsWork':
      return 2
    default:
      return 3
  }
}

/** When a window's state began; else, saying none, as one before any turn does, its attach. */
const sinceOf = (presence: Presence) => presence.state?.since ?? presence.attachedAt

/**
 * The window that needs Lee first, then one working, then one on its own
 * work, then the rest; within each, the latest to begin its state (the later
 * stop, the turn Lee started last, the later end of a turn), then the one
 * attached last.
 */
const byJump = (a: Presence, b: Presence) =>
  rankOf(a) - rankOf(b) || sinceOf(b) - sinceOf(a) || b.attachedAt - a.attachedAt

/** A presence that says where its window is. */
type Placed = Presence & { where: Where }

/** The live presences of a session at `now` that say where their windows are, in the order a jump tries them. */
export const inJumpOrder = (session: Session, now: number): Placed[] =>
  session.presence
    .filter((each): each is Placed => isLive(each, now) && each.where !== undefined)
    .sort(byJump)

/** The windows a session is in as it stands at `now`: where each live presence is, in the order a jump tries them. */
export const windowsOf = (session: Session, now: number): Where[] =>
  inJumpOrder(session, now).map(each => each.where)

/**
 * The window a session no window holds at `now` was last in: its latest
 * heartbeat, by when it was last seen, which a `/clear` moves on to the
 * conversation after it. None while a live window holds it, nor for one no
 * window ever held.
 */
export const lastWindowOf = (session: Session, now: number): Presence | undefined =>
  session.presence.some(each => isLive(each, now))
    ? undefined
    : [...session.presence].sort((a, b) => b.seenAt - a.seenAt).at(0)
