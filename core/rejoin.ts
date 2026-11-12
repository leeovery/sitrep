/**
 * Which session a window takes up again by itself when its conversation
 * resumes in a new process: the one its writer was last seen in. A window
 * leaves a heartbeat in every session it holds, and its own lines.
 */
import { lastSeenAt } from './presence'
import type { Session } from './types'

/**
 * When `writer` was last seen in the session: its heartbeat, else the latest
 * item or status it posted; undefined if never. Starting a session is not
 * being seen in it (a window beats as it attaches), nor is sending replies
 * into its inbox.
 */
export const lastSeen = (session: Session, writer: string): number | undefined => {
  const beat = session.presence.find(each => each.writer === writer)

  if (beat !== undefined) {
    return lastSeenAt(beat)
  }

  const times = [...session.items.values(), ...session.log.filter(line => line.kind === 'status')]
    .filter(each => each.by === writer)
    .map(each => each.at)

  return times.length === 0 ? undefined : Math.max(...times)
}

/**
 * The id of the session `writer` was last seen in, of those given; undefined
 * when it was seen in none, or that session is finished: only a join reopens
 * one, and the conversation had moved on from any it was seen in before.
 */
export const rejoinable = (sessions: readonly Session[], writer: string) => {
  const last = sessions
    .flatMap(session => {
      const at = lastSeen(session, writer)

      return at === undefined ? [] : [{ session, at }]
    })
    .sort((a, b) => b.at - a.at)
    .at(0)?.session

  return last?.finished === undefined ? last?.id : undefined
}
