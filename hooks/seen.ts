/**
 * What Claude has been told of the board. The board's text as Claude last
 * saw it is kept, so a turn is told of the board only once it moved on: a
 * change Claude did not make (another window's, Lee's, the CLI's) is never
 * taken as known.
 */
import { boardText, type Body, type Session, type Stamp } from '../core'
import type { Host } from './host'
import { post, refresh } from './window'

/** What heads the board's text where it rides into a turn. */
const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

/** Marks the session's board as Claude now knows it: Claude read it, or made it so. */
export const markSeen = (host: Host, session: Session) => host.state.seen.write(boardText(session))

/** Whether Claude knows the board as it stands. */
const isSeen = async (host: Host, session: Session) =>
  boardText(session) === (await host.state.seen.read())

/**
 * Posts lines Claude knows of (its own, or replies it has just been sent),
 * as of `at` as `post` takes it: the board counts as seen after them, unless
 * it had already moved on from what Claude last saw.
 */
export const postKnown = async (
  host: Host,
  session: Session,
  bodies: readonly Body[],
  at?: Stamp,
) => {
  const wasSeen = await isSeen(host, session)
  const after = await post(host, bodies, at)

  if (wasSeen && after !== undefined) {
    await markSeen(host, after)
  }

  return after
}

/**
 * The held session as it stands, and the context a turn takes for it, when
 * its board moved on since Claude last saw it; undefined when it did not.
 */
export const boardChange = async (host: Host) => {
  const session = await refresh(host)

  if (session === undefined || (await isSeen(host, session))) {
    return undefined
  }

  return { session, context: `${CHANGED}\n${boardText(session)}` }
}
