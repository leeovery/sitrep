/**
 * `sitrep watch`: the board as every surface shows it, a line of JSON each
 * time it changes, for the SitRep app, which runs one as its child and
 * starts it again should it end (see "One engine, two front ends" in
 * DESIGN.md). Each line carries the boards, as `board --json` gives them,
 * of the sessions the app follows that are new to its set or changed since
 * last printed (follow.ts).
 *
 * - It looks at the state folder every second, reading again only a file
 *   that changed (held.ts) and folding again only a session whose files
 *   did. A session off the board, finished or idle past the views, is read
 *   again every 10 seconds, unless it is followed: it changes rarely, and
 *   only a join or a post brings it back.
 * - It looks again the moment a line on its standard input says what the
 *   app follows.
 * - It looks again the moment core says the board changes by time alone,
 *   as when a heartbeat goes stale, which changes no file. Time the Mac
 *   slept, told by its two clocks, ages no heartbeat (core's pauses.ts):
 *   folded again at the instant it was to go stale, a window the Mac slept
 *   through is live still.
 * - A line is printed at the start, and then only when the board it shows
 *   differs from the last's, its own time aside, or it carries a board.
 * - It ends once the program that started it has gone, a line finds its
 *   standard output closed, or SIGTERM comes (ending.ts), and as the
 *   plugin's manifest comes to say another version, for the app to start
 *   the new one.
 */
import {
  clockAt,
  every,
  feedOf,
  foldSession,
  isOffBoard,
  isSameFiles,
  manifestVersion,
  newRows,
  nextExpiry,
  OFF_BOARD_MS,
  ownTime,
  rootOf,
  sessionPaths,
  type Clock,
  type Pause,
  type ProjectRead,
  type SessionFiles,
  type Shown,
} from '../core'
import { readBoard, readFolder, type SessionRead, type SessionReader } from './files'
import { following } from './follow'
import { heldReads } from './held'
import type { Io } from './io'
import { feedText, heldBoard, watchLine, type BoardFields, type HeldBoard } from './output'

/** How often it looks at the folder: as the mod's readers do. */
export const POLL_MS = 1_000

/** How often it reads again the sessions off the board, as every reader does. */
export { OFF_BOARD_MS }

/** A session as last read: its files, what they fold to, its board, and whether it is off the board, with no window to hear. */
type LastRead = SessionRead & { board: HeldBoard | undefined; isOff: boolean }

/** What a look is to read: a session off the board only on a look `isWhole` says, or one `followed`; and what it is to fold again: a session whose files changed, or every one once, `isDue`, the time core said the board would change came. */
type Look = {
  now: number
  clock: Clock
  isWhole: boolean
  isDue: boolean
  followed: ReadonlySet<string>
}

/** What a look found: every project and its sessions, and whether each session stood as at the last look, none folded anew. */
type Looked = { read: ProjectRead[]; isSame: boolean }

/** What a look gives to print: what it found, when, and the version the watch ran. */
type Seen = Looked & { now: number; version: string | undefined }

/** What the last line showed: the board as text, the version it ran, and the rows needing Lee shown so far. */
type Printed = { text: string; version: string | undefined; shown: Shown }

const folded = (
  key: string,
  files: SessionFiles,
  now: number,
  pauses: readonly Pause[],
): LastRead => {
  const session = foldSession(files, now, pauses)

  return {
    files,
    session,
    board: session === undefined ? undefined : heldBoard(key, session),
    isOff: isOffBoard(session, now),
  }
}

/** A board made the first time it is asked for, and kept. */
const lazily = (make: () => HeldBoard) => {
  let made: HeldBoard | undefined

  return () => (made ??= make())
}

/**
 * The board, read at each look again only where it changed, as the look
 * says; a project renamed changes it too, though no session of its folder
 * did, its name being a moved session's. No heartbeat ages through
 * `clock`'s pauses. A session's board is found by its id alone, in the
 * first project filing one by it that folds: as it was folded, in its
 * folder's project, or, for one moved to another project, made under that
 * project once asked for at the look.
 */
const boardReader = (io: Io, root: string) => {
  let lastRead = new Map<string, LastRead>()
  let byId = new Map<string, () => HeldBoard | undefined>()
  let projects = ''

  const look = async ({ now, clock, isWhole, isDue, followed }: Look): Promise<Looked> => {
    const looked = new Map<string, LastRead>()
    let isSame = true
    const readSession: SessionReader = async (key, id, project) => {
      const at = `${key}/${id}`
      const last = lastRead.get(at)
      const folder =
        last?.isOff === true && !isWhole && !followed.has(id)
          ? last.files
          : await readFolder(io, sessionPaths(root, key, id))
      const files = { ...folder, project }
      const standing =
        last !== undefined && !isDue && isSameFiles(last.files, files)
          ? last
          : folded(key, files, now, clock.pauses)

      isSame &&= standing === last
      looked.set(at, standing)

      return standing
    }
    const read = await readBoard(io, root, readSession)
    const named = JSON.stringify(read.map(each => each.project))

    isSame &&= looked.size === lastRead.size && named === projects
    lastRead = looked
    projects = named
    byId = new Map()

    for (const { project, sessions } of read) {
      for (const session of sessions.filter(each => !byId.has(each.id))) {
        const own = lastRead.get(`${project.key}/${session.id}`)?.board

        byId.set(
          session.id,
          own === undefined ? lazily(() => heldBoard(project.key, session)) : () => own,
        )
      }
    }

    return { read, isSame }
  }

  return { look, boardById: (id: string) => byId.get(id)?.() }
}

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
  { read, isSame, now, version }: Seen,
  boards: Readonly<Record<string, BoardFields | null>>,
  clock: Clock,
): Printed => {
  const isCarrying = Object.keys(boards).length > 0

  if (last !== undefined && !isCarrying && isSame && version === last.version) {
    return last
  }

  const feed = feedOf(read, now, version)
  const text = feedText(feed, version)

  if (last !== undefined && !isCarrying && text === last.text) {
    return last
  }

  const { news, shown } = newRows(last?.shown, feed, ownTime(clock))

  io.out(`${watchLine(feed, version, clock.at, news, boards)}\n`)

  return { text, version, shown }
}

/**
 * The run's end, and its waits: each cut short by the end or by a wake, a
 * wake with no wait under way ending the next at once. A wait cut short
 * has its timer let go, so that nothing holds the run open, and a wait's
 * end acts only while that wait is the one under way. Stopping stops the
 * listening for the end. That end is listened to once, not raced at every
 * wait: each race would leave it a reaction, held for as long as the run
 * goes on.
 */
const untilEnded = (io: Io) => {
  const { ended, stop } = io.ending()
  let isEnded = false
  let isWoken = false
  let cut: (() => void) | undefined

  const wake = () => {
    isWoken = cut === undefined
    cut?.()
  }

  void ended.then(() => {
    isEnded = true
    wake()
  })

  return {
    isEnded: () => isEnded,
    wake,
    wait: (ms: number) =>
      new Promise<void>(resolve => {
        if (isWoken) {
          isWoken = false
          resolve()

          return
        }

        const waiting = io.wait(ms)
        const done = () => {
          if (cut === own) {
            cut = undefined
            resolve()
          }
        }
        const own = () => {
          waiting.cancel()
          done()
        }

        cut = own
        void waiting.then(done)
      }),
    stop,
  }
}

/**
 * The version the watch runs, as the plugin's manifest says it: the first
 * read whole, so a manifest caught torn as it starts gives none until then.
 * Whether it has moved since, a manifest saying none moving nothing; each
 * look at it is a stat, read again only once it changed.
 */
const releaseOf = (io: Io, held: Io) => {
  let version: string | undefined

  return {
    version: () => version,
    isMoved: async () => {
      const now = manifestVersion(await held.fs.read(io.manifest).catch(() => ''))

      version ??= now

      return now !== undefined && now !== version
    },
  }
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

  try {
    await watchUntil(io, run, follows)
  } finally {
    follows.stop()
    run.stop()
  }
}

const watchUntil = async (
  io: Io,
  run: ReturnType<typeof untilEnded>,
  follows: ReturnType<typeof following>,
) => {
  const held = heldReads(io)
  const release = releaseOf(io, held)
  const reader = boardReader(held, rootOf(io.env))
  const isWholeLook = every(OFF_BOARD_MS, -Infinity)
  let last: Printed | undefined
  let clock: Clock | undefined
  let expiry: number | undefined

  while (!run.isEnded() && !(await release.isMoved())) {
    const now = io.now()
    const version = release.version()

    clock = clockAt(clock, now, io.uptime())

    const followed = follows.followed()
    const isWhole = isWholeLook(now)
    const isDue = expiry !== undefined && now >= expiry
    const { read, isSame } = await reader.look({ now, clock, isWhole, isDue, followed })
    const boards = follows.unprinted(followed, reader.boardById)

    expiry = nextExpiry(read, now)
    last = print(io, last, { read, isSame, now, version }, boards, clock)

    await run.wait(Math.min(POLL_MS, (expiry ?? Infinity) - now))
  }
}
