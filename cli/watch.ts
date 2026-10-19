/**
 * `sitrep watch`: the board as every surface shows it, a line of JSON each
 * time it changes, for the SitRep app, which runs one as its child and
 * starts it again should it end (see "One engine, two front ends" in
 * DESIGN.md).
 *
 * - It looks at the state folder every second, under both layouts as every
 *   reader does, reading again only a file that changed (held.ts) and
 *   folding again only a session whose files did. A session off the board,
 *   finished or idle past the views, is read again every 10 seconds: it
 *   changes rarely, and only a join or a post brings it back.
 * - It looks again the moment core says the board changes by time alone,
 *   as when a heartbeat goes stale, which changes no file. Time the Mac
 *   slept, told by its two clocks, ages no heartbeat (core's pauses.ts):
 *   folded again at the instant it was to go stale, a window the Mac slept
 *   through is live still.
 * - A line is printed at the start, and then only when what it would print
 *   differs from the last, its own time aside.
 * - Every 10 minutes it moves the old layout, as each run does at its start.
 * - It ends once the program that started it has gone, a line finds its
 *   standard output closed, or SIGTERM comes (ending.ts), and as the
 *   plugin's manifest comes to say another version, for the app to start
 *   the new one.
 */
import {
  clockAt,
  feedOf,
  foldSession,
  isCurrent,
  manifestVersion,
  newRows,
  nextExpiry,
  ownTime,
  rootOf,
  sessionPaths,
  summarise,
  type Clock,
  type Feed,
  type Pause,
  type ProjectRead,
  type SessionFiles,
  type Shown,
} from '../core'
import { readBoard, readFolders, type SessionRead, type SessionReader } from './files'
import { heldReads } from './held'
import type { Io } from './io'
import { boardJson, feedText, watchLine } from './output'

/** How often it looks at the folder: as the mod's readers do. */
export const POLL_MS = 1_000

/** How often it reads again the sessions off the board. */
export const OFF_BOARD_MS = 10_000

/** How often it moves the old layout, once no window still writes it. */
export const MOVE_MS = 10 * 60_000

/** A session as last read: its files, what they fold to, its board as `board --json` prints it, and whether it is off the board, with no window to hear. */
type Kept = SessionRead & { board?: string; isOff: boolean }

/** What a look found: every project and its sessions, and whether each session stood as at the last look, none folded anew. */
type Looked = { read: ProjectRead[]; isSame: boolean }

/** What the last line showed: the board as text, the version it ran, each session's `board --json` then, and the rows needing Lee shown so far. */
type Printed = {
  text: string
  version: string | undefined
  boards: ReadonlyMap<string, string>
  shown: Shown
}

const isSameTexts = (
  a: Readonly<Record<string, string>> = {},
  b: Readonly<Record<string, string>> = {},
) =>
  Object.keys(a).length === Object.keys(b).length &&
  Object.entries(a).every(([name, text]) => b[name] === text)

const isSameFiles = (a: SessionFiles, b: SessionFiles) =>
  a.meta === b.meta &&
  a.project === b.project &&
  isSameTexts(a.logs, b.logs) &&
  isSameTexts(a.inbox, b.inbox) &&
  isSameTexts(a.presence, b.presence)

const folded = (key: string, files: SessionFiles, now: number, pauses: readonly Pause[]): Kept => {
  const session = foldSession(files, now, pauses)

  return {
    files,
    session,
    board: session === undefined ? undefined : boardJson(key, session),
    isOff: session !== undefined && !session.isOpen && !isCurrent(summarise(session), now),
  }
}

/**
 * The board, read at each look again only where it changed: a session off
 * the board read only on a look `isWhole` says, and folded again only once
 * its files changed or, `isDue`, the time core said it would change came.
 * No heartbeat ages through `clock`'s pauses.
 */
const boardReader = (io: Io, root: string) => {
  let kept = new Map<string, Kept>()

  const look = async (
    now: number,
    clock: Clock,
    isWhole: boolean,
    isDue: boolean,
  ): Promise<Looked> => {
    const looked = new Map<string, Kept>()
    let isSame = true
    const read: SessionReader = async (key, id, project) => {
      const at = `${key}/${id}`
      const last = kept.get(at)
      const folders =
        last?.isOff === true && !isWhole
          ? last.files
          : await readFolders(io, sessionPaths(root, key, id))
      const files = { ...folders, project }
      const standing =
        last !== undefined && !isDue && isSameFiles(last.files, files)
          ? last
          : folded(key, files, now, clock.pauses)

      isSame &&= standing === last
      looked.set(at, standing)

      return standing
    }
    const board = await readBoard(io, root, read)

    isSame &&= looked.size === kept.size
    kept = looked

    return { read: board, isSame }
  }

  return { look, boardOf: (key: string, id: string) => kept.get(`${key}/${id}`)?.board ?? '' }
}

/** Whether something done every `ms` is due at `now`, counted from `from`; each time it is, the count starts again. */
const every = (ms: number, from: number) => {
  let last = from

  return (now: number) => {
    if (now - last < ms) {
      return false
    }

    last = now

    return true
  }
}

/**
 * Prints the board's line at `clock`'s look where it differs from the last,
 * its own time aside, or where a session's `board --json` changed since:
 * what the watch has not shown with it, and those sessions. Gives what was
 * last printed.
 */
const print = (
  io: Io,
  last: Printed | undefined,
  feed: Feed,
  boardOf: (key: string, id: string) => string,
  clock: Clock,
  version: string | undefined,
): Printed => {
  const text = feedText(feed, version)
  const boards = new Map(
    feed.projects.flatMap(project =>
      project.sessions.map(session => [session.id, boardOf(project.key, session.id)] as const),
    ),
  )
  const changed =
    last === undefined
      ? []
      : [...boards].filter(([id, board]) => last.boards.get(id) !== board).map(([id]) => id)

  if (last !== undefined && text === last.text && changed.length === 0) {
    return last
  }

  const { news, shown } = newRows(last?.shown, feed, ownTime(clock))

  io.out(`${watchLine(feed, version, clock.at, news, changed)}\n`)

  return { text, version, boards, shown }
}

/**
 * The run's end, a wait it cuts short, its timer let go so that nothing
 * holds the run open, and the listening stopped. Its end is listened to
 * once, not raced at every wait: each race would leave it a reaction, held
 * for as long as the run goes on.
 */
const untilEnded = (io: Io) => {
  const { ended, stop } = io.ending()
  let isEnded = false
  let wake = () => {}

  void ended.then(() => {
    isEnded = true
    wake()
  })

  return {
    isEnded: () => isEnded,
    wait: (ms: number) =>
      new Promise<void>(resolve => {
        const waiting = io.wait(ms)

        wake = () => {
          waiting.cancel()
          resolve()
        }
        void waiting.then(resolve)
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
 * a version other than the one it started on, `move` moving the old layout
 * as every run does. A file that does not read is passed over for the look;
 * anything else that fails ends it, for the app to start it again. However
 * it ends, it stops listening for its end, which would hold the run open.
 */
export const watch = async (io: Io, move: () => Promise<void>) => {
  const run = untilEnded(io)

  try {
    await watchUntil(io, move, run)
  } finally {
    run.stop()
  }
}

const watchUntil = async (
  io: Io,
  move: () => Promise<void>,
  run: ReturnType<typeof untilEnded>,
) => {
  const held = heldReads(io)
  const release = releaseOf(io, held)
  const reader = boardReader(held, rootOf(io.env))
  const isMoveDue = every(MOVE_MS, io.now())
  const isWholeLook = every(OFF_BOARD_MS, -Infinity)
  let last: Printed | undefined
  let clock: Clock | undefined
  let expiry: number | undefined

  while (!run.isEnded() && !(await release.isMoved())) {
    if (isMoveDue(io.now())) {
      await move()
    }

    const now = io.now()
    const version = release.version()

    clock = clockAt(clock, now, io.uptime())

    const isDue = expiry !== undefined && now >= expiry
    const { read, isSame } = await reader.look(now, clock, isWholeLook(now), isDue)

    expiry = nextExpiry(read, now)

    if (last === undefined || !isSame || version !== last.version) {
      last = print(io, last, feedOf(read, now, version), reader.boardOf, clock, version)
    }

    await run.wait(Math.min(POLL_MS, (expiry ?? Infinity) - now))
  }
}
