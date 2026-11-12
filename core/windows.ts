/**
 * The order a jump tries a session's windows in, and the window an away
 * session was last in: board rules, so SitRep reads them through the feed,
 * and ranks no windows itself (see "The structure" in DESIGN.md).
 */
import { isLive, lastSeenAt } from './presence'
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

/**
 * The window an away session was last in, as a click carries it on from: its
 * writer, the Claude Code session it ran, where it was, its folder, and the
 * device its Claude ran on while that is still its conversation's, for a
 * resume to look for that Claude running on it still.
 */
export type LastWindow = Pick<Presence, 'writer' | 'where' | 'directory'> & { device?: string }

/**
 * The window a session no window holds at `now` was last in, among every
 * session on the `board`: its latest heartbeat, by when it was last seen
 * (`lastSeenAt`, as `rejoinable` ranks), which a `/clear` moves on to the
 * conversation after it. None while a live window holds it, nor for one no
 * window ever held; nor where that conversation, resumed, would take up
 * another session (`rejoinable`), as one that let go of it for another does,
 * live or not, so a click carries on only the session its conversation
 * comes back to. Where it was is said only where a click can still reach the
 * conversation there (`isThere`), and its device only where no later
 * conversation was seen on it (`isLatestOn`).
 */
export const lastWindowOf = (
  session: Session,
  board: readonly Session[],
  now: number,
): LastWindow | undefined => {
  if (session.presence.some(each => isLive(each, now))) {
    return undefined
  }

  const last = [...session.presence].sort((a, b) => lastSeenAt(b) - lastSeenAt(a)).at(0)

  if (last === undefined || rejoinable(board, last.writer) !== session.id) {
    return undefined
  }

  return {
    writer: last.writer,
    where: isThere(last, board) ? last.where : undefined,
    device: isLatestOn(last, board, each => each.where?.device) ? last.where?.device : undefined,
    directory: last.directory,
  }
}

/**
 * Whether a click could still find a last window's conversation where the
 * window was: not in tmux, whose pane ids start again from `%0` with each
 * server, so the pane it was in is any pane now, or a shell its Claude ended
 * in; nor in a zmx session a later conversation was seen in, which holds that
 * one's Claude, or its resume panel, now.
 */
const isThere = (last: Presence, board: readonly Session[]) =>
  last.where?.tmux === undefined && isLatestOn(last, board, each => each.where?.zmx?.session)

/**
 * Whether the last window's conversation is the latest seen at its place, as
 * `placeOf` gives it (a zmx session, a device): its window did not let go as
 * its Claude went on into another conversation (`livesOn`), and no heartbeat
 * on the board, of any session, live or let go, was seen there later
 * (`lastSeenAt`). One at no place has none to lose.
 */
const isLatestOn = (
  last: Presence,
  board: readonly Session[],
  placeOf: (presence: Presence) => string | undefined,
) => {
  const place = placeOf(last)

  return (
    last.livesOn === undefined &&
    (place === undefined ||
      !board.some(session =>
        session.presence.some(
          each => placeOf(each) === place && lastSeenAt(each) > lastSeenAt(last),
        ),
      ))
  )
}
