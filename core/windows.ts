/**
 * The order a jump tries a session's windows in, and the window an away
 * session was last in: board rules, so SitRep reads them through the feed,
 * and ranks no windows itself (see "The structure" in DESIGN.md).
 */
import { isLive } from './presence'
import { rejoinable } from './rejoin'
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

/** The window an away session was last in, as a click carries it on from: its writer, the Claude Code session it ran, where it was, and its folder. */
export type LastWindow = Pick<Presence, 'writer' | 'where' | 'directory'>

/**
 * The window a session no window holds at `now` was last in, among every
 * session on the `board`: its latest heartbeat, by when it was last seen,
 * which a `/clear` moves on to the conversation after it. None while a live
 * window holds it, nor for one no window ever held; nor where that
 * conversation, resumed, would take up another session (`rejoinable`), as
 * one that let go of it for another does, live there or not, so a click
 * carries on only the session its conversation comes back to. Where it was
 * is left out where a live window is in its multiplexer session (`taken`).
 */
export const lastWindowOf = (
  session: Session,
  board: readonly Session[],
  now: number,
): LastWindow | undefined => {
  if (session.presence.some(each => isLive(each, now))) {
    return undefined
  }

  const last = [...session.presence].sort((a, b) => b.seenAt - a.seenAt).at(0)

  if (last === undefined || rejoinable(board, last.writer) !== session.id) {
    return undefined
  }

  return {
    writer: last.writer,
    where: taken(last.where, board, now) ? undefined : last.where,
    directory: last.directory,
  }
}

/** Whether two windows are in one multiplexer session: the same zmx session, or the same tmux server's pane. */
const isSameMultiplexed = (a: Where, b: Where) =>
  (a.zmx !== undefined && a.zmx.session === b.zmx?.session) ||
  (a.tmux !== undefined && a.tmux.socket === b.tmux?.socket && a.tmux.pane === b.tmux?.pane)

/**
 * Whether a live window on the board, of any session, is in the multiplexer
 * session a window was in: another Claude holds it now, after a `/clear` or
 * one started there, so it is no longer the window's to jump to or attach to.
 */
const taken = (where: Where | undefined, board: readonly Session[], now: number) =>
  where !== undefined &&
  board.some(session =>
    session.presence.some(
      each => isLive(each, now) && each.where !== undefined && isSameMultiplexed(where, each.where),
    ),
  )
