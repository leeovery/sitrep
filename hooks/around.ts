/**
 * The sessions around the held one, read at a slower pace than its watch.
 * Every project is read, the board open or not, so the band can count what
 * waits on Lee in every other session, and the board's views draw from what
 * was last read. In full, each other session the board draws: the session
 * it looks at, and those Lee's replies wait for or went to.
 *
 * Whatever the board shows, the session of the item Lee is answering in the
 * prompt is read in full too, so the answering mode ends once that item can
 * no longer take the reply.
 *
 * Each session is read through a reader of its own, so only a file that
 * changed is read again, and folded again only once its files changed or
 * its own fold changes by time alone (core's `nextFoldChange`). `watch`
 * folds every session again as the board changes by time alone instead,
 * which stands for what it prints; a window shares whole folds, `others`
 * and the first message's listing among them, where a snooze the board
 * leaves out still shows. A session off the board is read only on a whole
 * look, every OFF_BOARD_MS as `watch` reads its own (core's reading.ts),
 * and folded from the files it last read otherwise; one read in full is
 * read at every look. Each project's folder is listed once a look, its
 * listing handed to each of its sessions' reads. What drawing needs goes
 * in `$.state` as plain data, put only when it changed; the held session
 * itself stays the watch's.
 */
import type { FsEntry, Timer } from 'claude-code'
import {
  brief,
  every,
  isCurrent,
  isOffBoard,
  OFF_BOARD_MS,
  parkedBy,
  projectParked,
  refold,
  sessionPaths,
  type KeptFold,
  type Session,
  type SessionFiles,
} from '../core'
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepOther,
  SitrepPane,
  SitrepProject,
  SitrepQueued,
  SitrepSent,
  SitrepSessionRef,
} from '../types'
import { settleAnswering } from './answering'
import { boardOf } from './board'
import { logFailure, rootFor, type Host, type Slot } from './host'
import { projectKeys } from './projects'
import { destinations, isShowing, type Folded } from './queue'
import { createReader, filedIn, type Reader } from './reader'
import type { Filed } from './scene'

/**
 * How often the sessions around the held one are read. They change only as
 * Claude posts in other windows or Lee replies, and the views they feed are
 * glanced at rather than watched; a few seconds' lag costs nothing there,
 * and a third of the watch's pace keeps reading every project cheap.
 */
export const AROUND_MS = 5_000

/** A session as last read: its reader, its fold as kept, and whether it is off the board. */
type Kept = KeptFold & { read: Reader; isOff: boolean }

/** Each session as last read, by its folder. */
const kept = new Map<string, Kept>()

/** What the last look put in `$.state`, as JSON, so a look that changed nothing puts nothing. */
const shown: { projects?: string; others?: string } = {}

/**
 * Whether a look at `now` is whole, reading the sessions off the board too:
 * the window's first, and one every OFF_BOARD_MS. A look reads the clock a
 * little after its timer fires, later still behind a look on demand, so the
 * pace allows half a look's slack: without it, a whole look read a few ms
 * late leaves the one two looks on just short, and whole looks come every
 * three.
 */
const isWholeLook = every(OFF_BOARD_MS - AROUND_MS / 2, -Infinity)

let looking: Promise<unknown> = Promise.resolve()

let timer: Timer | undefined

/** A session folded from `files` at `now`: as last folded, where that was from the same files and its fold has not changed since by time alone. */
const keep = (dir: string, read: Reader, files: SessionFiles, now: number) => {
  const last = kept.get(dir)
  const fold = refold(last, files, now)
  const standing = fold === last ? last : { ...fold, read, isOff: isOffBoard(fold.session, now) }

  kept.set(dir, standing)

  return standing.session
}

/** A session as its files stand at `now`, read through its reader, `listing` its project folder's where the caller has it. */
const readAt = async (
  host: Host,
  root: string,
  at: SitrepSessionRef,
  now: number,
  listing?: readonly FsEntry[],
) => {
  const paths = sessionPaths(root, at.project, at.session)
  const read = kept.get(paths.dir)?.read ?? createReader()

  return keep(paths.dir, read, await read(host, paths, listing), now)
}

/** A session as its files stand at `now`; undefined when its session.json is missing or torn. */
export const foldAt = (host: Host, root: string, at: SitrepSessionRef, now: number) =>
  readAt(host, root, at, now)

/** The sessions replies answer items of, by id, as they stand now: the held `session` as given, and each other read afresh. */
export const foldedFor = async (
  host: Host,
  session: Session,
  replies: readonly SitrepSessionRef[],
): Promise<Folded> => {
  const [root, now] = await Promise.all([rootFor(host), host.clock.now()])
  const others = destinations(replies).filter(each => each.session !== session.id)
  const read = await Promise.all(others.map(at => foldAt(host, root, at, now)))

  return new Map([session, ...read.flatMap(each => each ?? [])].map(each => [each.id, each]))
}

/** Reads a session filed under a project, given that project folder's listing: the session as it stands, undefined where it does not fold. */
type ReadFiled = (at: SitrepSessionRef, listing: readonly FsEntry[]) => Promise<Session | undefined>

/** Every session filed under a project but the one `except` names, each read by `readFiled`, the project's folder listed once for them all. */
const foldFiled = async (
  host: Host,
  root: string,
  project: string,
  readFiled: ReadFiled,
  except?: string,
) => {
  const { listing, sessions } = await filedIn(host, root, project)
  const folded = await Promise.all(
    sessions.filter(id => id !== except).map(session => readFiled({ project, session }, listing)),
  )

  return folded.filter(session => session !== undefined)
}

/** Every session filed under a project, as its files stand at `now`. */
export const sessionsIn = (host: Host, root: string, project: string, now: number) =>
  foldFiled(host, root, project, (at, listing) => readAt(host, root, at, now, listing))

/** What the window has to do with other sessions: replies waiting for them or sent to them, and the item Lee is answering in the prompt. */
type Around = {
  queue: readonly SitrepQueued[]
  sent: readonly SitrepSent[]
  answering: SitrepAnswering | null
}

/** The other sessions a look reads in full: those the board draws, while it is open, and the one Lee is answering in the prompt. */
const fullOf = (held: SitrepAttachment, pane: SitrepPane, around: Around) => {
  const answered = around.answering === null ? [] : [around.answering]
  const { place } = pane
  const drawn = pane.isOpen
    ? [...(place?.level === 'session' ? [place] : []), ...around.queue, ...around.sent]
    : []

  return destinations([...drawn, ...answered]).filter(each => each.session !== held.session)
}

/**
 * A session around as a look at `now` reads it: one off the board, on a
 * look that is not whole and not read in full, folded from the files it was
 * last read from, its folders not listed.
 */
const aroundAt =
  (host: Host, root: string, now: number, isWhole: boolean, full: ReadonlySet<string>): ReadFiled =>
  async (at, listing) => {
    const { dir } = sessionPaths(root, at.project, at.session)
    const last = kept.get(dir)

    return last?.isOff === true && !isWhole && !full.has(at.session)
      ? keep(dir, last.read, last.files, now)
      : readAt(host, root, at, now, listing)
  }

/** The sessions a look reads, by id: every one filed but the held one, and each other it reads in full; those `fresh` names read afresh too, off the board or not. */
const readAround = async (
  host: Host,
  root: string,
  held: string,
  full: readonly SitrepSessionRef[],
  now: number,
  isWhole: boolean,
  fresh: readonly string[],
) => {
  const read = new Map<string, Filed>()
  const keys = await projectKeys(host, root)
  const afresh = new Set([...full.map(each => each.session), ...fresh])
  const around = aroundAt(host, root, now, isWhole, afresh)

  for (const project of keys) {
    for (const session of await foldFiled(host, root, project, around, held)) {
      read.set(session.id, { project, session })
    }
  }

  for (const at of full.filter(each => !read.has(each.session))) {
    const session = await foldAt(host, root, at, now)

    if (session !== undefined) {
      read.set(session.id, { project: at.project, session })
    }
  }

  return { keys, read }
}

/** A project's name, as the most recently updated of its sessions names it. */
const nameOf = (key: string, sessions: readonly Session[]) =>
  [...sessions].sort((a, b) => b.updatedAt - a.updatedAt).at(0)?.project ?? key

/**
 * The projects read, each with its current sessions, and what every session
 * filed under it parked, finished and idle ones included; a project with
 * neither is dropped, but never the held session's.
 */
const projectsOf = (
  held: SitrepAttachment,
  keys: readonly string[],
  read: ReadonlyMap<string, Filed>,
  now: number,
): SitrepProject[] =>
  keys.flatMap(key => {
    const filed = [...read.values()]
      .filter(({ project }) => project === key)
      .map(({ session }) => session)
    const sessions = filed.map(brief).filter(session => isCurrent(session, now))
    const parked = projectParked(filed.flatMap(parkedBy))

    return sessions.length > 0 || parked.length > 0 || key === held.project
      ? [{ key, name: nameOf(key, filed), sessions, parked }]
      : []
  })

const othersOf = (
  full: readonly SitrepSessionRef[],
  read: ReadonlyMap<string, Filed>,
): SitrepOther[] =>
  full.flatMap(at => {
    const filed = read.get(at.session)

    return filed === undefined ? [] : [{ project: filed.project, board: boardOf(filed.session) }]
  })

const put = async <T>(slot: Slot<T>, key: keyof typeof shown, value: T) => {
  const json = JSON.stringify(value)

  if (json !== shown[key]) {
    await slot.write(value)
    shown[key] = json
  }
}

/** Drops where replies went once Ready to send stops showing them. */
const settleSent = async (host: Host, read: ReadonlyMap<string, Filed>, now: number) => {
  const sent = await host.state.sent.read()
  const showing = sent.filter(each => {
    const filed = read.get(each.session)

    return filed === undefined || isShowing(filed.session, each, now)
  })

  if (showing.length < sent.length) {
    await host.state.sent.write(showing)
  }
}

/** Forgets what was kept of the sessions this look did not read. */
const prune = (root: string, read: ReadonlyMap<string, Filed>) => {
  const dirs = new Set(
    [...read.values()].map(({ project, session }) => sessionPaths(root, project, session.id).dir),
  )

  for (const dir of kept.keys()) {
    if (!dirs.has(dir)) {
      kept.delete(dir)
    }
  }
}

const look = async (host: Host, fresh: readonly string[]) => {
  const held = await host.state.attachment.read()

  if (held === null) {
    await put(host.state.projects, 'projects', [])
    await put(host.state.others, 'others', [])

    return
  }

  const [pane, queue, sent, answering, root, now] = await Promise.all([
    host.state.pane.read(),
    host.state.queue.read(),
    host.state.sent.read(),
    host.state.answering.read(),
    rootFor(host),
    host.clock.now(),
  ])
  const full = fullOf(held, pane, { queue, sent, answering })
  const isWhole = isWholeLook(now)
  const { keys, read } = await readAround(host, root, held.session, full, now, isWhole, fresh)

  await put(host.state.projects, 'projects', projectsOf(held, keys, read, now))
  await put(host.state.others, 'others', othersOf(full, read))
  await settleSent(host, read, now)
  await settleAnswering(host)
  prune(root, read)
}

/**
 * Reads the sessions around the held one now, once any look under way has
 * settled, those `fresh` names afresh, as after a write into them, where one
 * off the board would wait for a whole look; never fails, its failure logged.
 */
export const lookAround = (host: Host, fresh: readonly string[] = []) => {
  looking = looking
    .then(() => look(host, fresh))
    .catch(logFailure(host, 'reading the sessions around'))

  return looking
}

/** Reads the sessions around the held one every `AROUND_MS`, from the window's start. */
export const lookEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(AROUND_MS, () => void lookAround(host))
}
