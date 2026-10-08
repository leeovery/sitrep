/**
 * Which piece of work a window takes up again by itself when its session
 * resumes in a new process: the one its writer was last seen in. A window
 * leaves a heartbeat in every work it holds, and its own lines.
 */
import type { Work } from './types'

/**
 * When `writer` was last seen in the work: its heartbeat, else the latest
 * item or status it posted; undefined if never. Starting a work is not
 * being seen in it (a window beats as it attaches), nor is sending replies
 * into its inbox.
 */
export const lastSeen = (work: Work, writer: string): number | undefined => {
  const beat = work.presence.find(each => each.writer === writer)

  if (beat !== undefined) {
    return beat.leftAt ?? beat.seenAt
  }

  const times = [...work.items.values(), ...work.log.filter(line => line.kind === 'status')]
    .filter(each => each.by === writer)
    .map(each => each.at)

  return times.length === 0 ? undefined : Math.max(...times)
}

/**
 * The id of the work `writer` was last seen in, of those given; undefined
 * when it was seen in none, or that work is finished: only a join reopens
 * one, and the conversation had moved on from any it was seen in before.
 */
export const rejoinable = (works: readonly Work[], writer: string) => {
  const last = works
    .flatMap(work => {
      const at = lastSeen(work, writer)

      return at === undefined ? [] : [{ work, at }]
    })
    .sort((a, b) => b.at - a.at)
    .at(0)?.work

  return last?.finished === undefined ? last?.id : undefined
}
