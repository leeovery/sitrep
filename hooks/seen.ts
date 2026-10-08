/**
 * What Claude has been told of the board. The board's text as Claude last
 * saw it is kept, so a turn is told of the board only once it moved on: a
 * change Claude did not make (another window's, Lee's, the CLI's) is never
 * taken as known.
 */
import { boardText, type Work } from '../core'
import type { Host } from './host'
import { refresh } from './window'

/** What heads the board's text where it rides into a turn. */
const CHANGED = 'The sitrep board changed since you last saw it. It now reads:'

/** Marks the work's board as Claude now knows it: Claude read it, or made it so. */
export const markSeen = (host: Host, work: Work) => host.state.seen.write(boardText(work))

/** Whether Claude knows the board as it stands. */
export const isSeen = async (host: Host, work: Work) =>
  boardText(work) === (await host.state.seen.read())

/**
 * The held work as it stands, and the context a turn takes for it, when its
 * board moved on since Claude last saw it; undefined when it did not.
 */
export const boardChange = async (host: Host) => {
  const work = await refresh(host)

  if (work === undefined || (await isSeen(host, work))) {
    return undefined
  }

  return { work, context: `${CHANGED}\n${boardText(work)}` }
}
