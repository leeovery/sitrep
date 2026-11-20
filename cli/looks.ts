/**
 * The board's looks, for every front end that watches it in the CLI's own
 * process: `sitrep watch` prints from them (watch.ts).
 *
 * - It looks at the state folder every second, reading again only a file
 *   that changed (held.ts) and folding again only a session whose files
 *   did. A session off the board, finished or idle past the views, is read
 *   again every 10 seconds, unless it is followed: it changes rarely, and
 *   only a join or a post brings it back.
 * - It looks again the moment it is woken, as the watch is by a line on
 *   its standard input saying what the app follows.
 * - It looks again the moment core says the board changes by time alone,
 *   as when a heartbeat goes stale, which changes no file. Time the Mac
 *   slept, told by its two clocks, ages no heartbeat (core's pauses.ts):
 *   folded again at the instant it was to go stale, a window the Mac slept
 *   through is live still.
 * - It ends as the run it is given ends, and, where its caller says so,
 *   as the plugin's manifest comes to say another version.
 */
import {
  clockAt,
  every,
  feedOf,
  foldSession,
  isOffBoard,
  isSameFiles,
  manifestVersion,
  nextExpiry,
  OFF_BOARD_MS,
  rootOf,
  sessionPaths,
  type Clock,
  type Feed,
  type Pause,
  type ProjectRead,
  type SessionFiles,
} from '../core'
import { readBoard, readFolder, type SessionRead, type SessionReader } from './files'
import { heldReads } from './held'
import type { Io } from './io'
import { heldBoard, type HeldBoard } from './output'

/** How often it looks at the folder: as the mod's readers do. */
export const POLL_MS = 1_000

/** A session as last read: its files, what they fold to, its board, and whether it is off the board, with no window to hear. */
type LastRead = SessionRead & { board: HeldBoard | undefined; isOff: boolean }

/** What a look is to read: a session off the board only on a look `isWhole` says, or one `followed`; and what it is to fold again: a session whose files changed, or every one once, `isDue`, the time core said the board would change came. */
type Reading = {
  now: number
  clock: Clock
  isWhole: boolean
  isDue: boolean
  followed: ReadonlySet<string>
}

/** What a look found: every project and its sessions, whether each session stood as at the last look, none folded anew, and each session's board, by its id. */
type Looked = {
  read: ProjectRead[]
  isSame: boolean
  boardById: (id: string) => HeldBoard | undefined
}

/**
 * A look, as handed to what watches: what it found, when, the Mac's sleeps
 * so far, the version the run started on, and the sessions it read as
 * followed. The feed and each session's board are made only once asked
 * for, and kept.
 */
export type Look = Looked & {
  now: number
  clock: Clock
  version: string | undefined
  followed: ReadonlySet<string>
  feed: () => Feed
}

/**
 * What watches the looks: `seen` handed each one, the next look waiting on
 * what it gives back, the sessions `followed` gives read as followed. The
 * looks end as the plugin's manifest comes to say another version only
 * where `endsOnNewVersion`. A look that fails ends them unless
 * `isPastFailure`, told why, says to go on, the next look waiting on it
 * too.
 */
export type Watcher = {
  seen: (look: Look) => void | Promise<void>
  followed?: () => ReadonlySet<string>
  endsOnNewVersion?: boolean
  isPastFailure?: (error: unknown) => boolean | Promise<boolean>
}

const NONE: ReadonlySet<string> = new Set()

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

/** A thing made the first time it is asked for, and kept. */
const lazily = <T>(make: () => T) => {
  let made: { value: T } | undefined

  return () => (made ??= { value: make() }).value
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
  let projects = ''

  const look = async ({ now, clock, isWhole, isDue, followed }: Reading): Promise<Looked> => {
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

    const byId = new Map<string, () => HeldBoard | undefined>()

    for (const { project, sessions } of read) {
      for (const session of sessions.filter(each => !byId.has(each.id))) {
        const own = lastRead.get(`${project.key}/${session.id}`)?.board

        byId.set(
          session.id,
          own === undefined ? lazily(() => heldBoard(project.key, session)) : () => own,
        )
      }
    }

    return { read, isSame, boardById: id => byId.get(id)?.() }
  }

  return { look }
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
export const untilEnded = (io: Io) => {
  const { ended, stop } = io.ending()
  let isEnded = false
  let isWoken = false
  let cut: (() => void) | undefined

  const wake = () => {
    isWoken = cut === undefined
    cut?.()
  }

  const end = () => {
    isEnded = true
    wake()
  }

  void ended.then(end)

  return {
    isEnded: () => isEnded,
    wake,
    end,
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

export type Run = ReturnType<typeof untilEnded>

/**
 * The version the run started on, as the plugin's manifest says it: the
 * first read whole, so a manifest caught torn as it starts gives none until
 * then. Whether it has moved since, a manifest saying none moving nothing;
 * each look at it is a stat, read again only once it changed.
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

/** How long to wait for the next look: a second, or less where the board changes by time alone sooner. */
const untilNext = (now: number, expiry: number | undefined) =>
  Math.min(POLL_MS, (expiry ?? Infinity) - now)

/**
 * Looks at the board until `run` is to end, handing each look to
 * `watcher`. A file that does not read is passed over for the look.
 */
export const looking = async (
  io: Io,
  run: Run,
  {
    seen,
    followed = () => NONE,
    endsOnNewVersion = false,
    isPastFailure = () => false,
  }: Watcher,
) => {
  const held = heldReads(io)
  const release = releaseOf(io, held)
  const reader = boardReader(held, rootOf(io.env))
  const isWholeLook = every(OFF_BOARD_MS, -Infinity)
  const isOver = async () => run.isEnded() || ((await release.isMoved()) && endsOnNewVersion)
  const passed = async (error: unknown) => {
    if (await isPastFailure(error)) {
      return undefined
    }

    throw error
  }
  let clock: Clock | undefined
  let expiry: number | undefined

  while (!(await isOver())) {
    const now = io.now()
    const version = release.version()

    clock = clockAt(clock, now, io.uptime())

    const followedNow = followed()
    const looked = await reader
      .look({
        now,
        clock,
        isWhole: isWholeLook(now),
        isDue: expiry !== undefined && now >= expiry,
        followed: followedNow,
      })
      .catch(passed)

    if (looked === undefined) {
      await run.wait(POLL_MS)

      continue
    }

    const { read } = looked

    expiry = nextExpiry(read, now)
    await seen({
      ...looked,
      now,
      clock,
      version,
      followed: followedNow,
      feed: lazily(() => feedOf(read, now, version)),
    })

    await run.wait(untilNext(now, expiry))
  }
}
