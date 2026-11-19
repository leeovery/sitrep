/**
 * `sitrep watch`: the board as every surface shows it, a line of JSON each
 * time it changes, for the SitRep app, which runs one as its child and
 * starts it again should it end (see "One engine, two front ends" in
 * DESIGN.md). Each line carries the boards, as `board --json` gives them,
 * of the sessions the app follows that are new to its set or changed since
 * last printed (follow.ts).
 *
 * - It looks at the board as looks.ts does, again the moment a line on its
 *   standard input says what the app follows, and reads the sessions it
 *   follows at every look.
 * - A line is printed at the start, and then only when the board it shows
 *   differs from the last's, its own time aside, or it carries a board.
 * - It ends as its looks do: once the program that started it has gone, a
 *   line finds its standard output closed, or SIGTERM comes, and as the
 *   plugin's manifest comes to say another version, for the app to start
 *   the new one.
 */
import { newRows, ownTime, type Shown } from '../core'
import { following } from './follow'
import type { Io } from './io'
import { looking, untilEnded, type Look } from './looks'
import { feedText, watchLine, type BoardFields } from './output'

export { OFF_BOARD_MS } from '../core'
export { POLL_MS } from './looks'

/** What the last line showed: the board as text, the version it ran, and the rows needing Lee shown so far. */
type Printed = { text: string; version: string | undefined; shown: Shown }

/**
 * Prints the board's line at `clock`'s look where it differs from the last,
 * its own time aside, or where it carries `boards`: with what the watch has
 * not shown. Where nothing was folded anew, on the version last printed,
 * and it carries none, the board is not even made. Gives what was last
 * printed.
 */
const print = (
  io: Io,
  last: Printed | undefined,
  { isSame, version, clock, feed: made }: Look,
  boards: Readonly<Record<string, BoardFields | null>>,
): Printed => {
  const isCarrying = Object.keys(boards).length > 0

  if (last !== undefined && !isCarrying && isSame && version === last.version) {
    return last
  }

  const feed = made()
  const text = feedText(feed, version)

  if (last !== undefined && !isCarrying && text === last.text) {
    return last
  }

  const { news, shown } = newRows(last?.shown, feed, ownTime(clock))

  io.out(`${watchLine(feed, version, clock.at, news, boards)}\n`)

  return { text, version, shown }
}

/**
 * Watches the board until the run is to end, or the plugin's manifest says
 * a version other than the one it started on. A file that does not read is
 * passed over for the look; anything else that fails ends it, for the app
 * to start it again. However it ends, it stops listening for its end and to
 * its standard input, either of which would hold the run open.
 */
export const watch = async (io: Io) => {
  const run = untilEnded(io)
  const follows = following(io, run.wake)
  let last: Printed | undefined

  try {
    await looking(io, run, {
      seen: look => {
        last = print(io, last, look, follows.unprinted(look.followed, look.boardById))
      },
      followed: follows.followed,
      endsOnNewVersion: true,
    })
  } finally {
    follows.stop()
    run.stop()
  }
}
