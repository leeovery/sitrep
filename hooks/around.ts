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
 * changed is read again. What drawing needs goes in `$.state` as plain
 * data, put only when it changed; the held session itself stays the
 * watch's.
 */
import type { Timer } from 'claude-code'
import { brief, foldSession, isCurrent, isSessionId, sessionPaths, sessionsDir } from '../core'
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
import { destinations, isShowing } from './queue'
import { createReader, foldersIn, type Reader } from './reader'
import type { Filed } from './scene'

/**
 * How often the sessions around the held one are read. They change only as
 * Claude posts in other windows or Lee replies, and the views they feed are
 * glanced at rather than watched; a few seconds' lag costs nothing there,
 * and a third of the watch's pace keeps reading every project cheap.
 */
export const AROUND_MS = 5_000

/** Each session's reader, by its folder. */
const readers = new Map<string, Reader>()

/** What the last look put in `$.state`, as JSON, so a look that changed nothing puts nothing. */
const shown: { projects?: string; others?: string } = {}

let looking: Promise<unknown> = Promise.resolve()

let timer: Timer | undefined

/** A session as its files stand at `now`; undefined when its work.json is missing or torn. */
export const foldAt = async (host: Host, root: string, at: SitrepSessionRef, now: number) => {
  const paths = sessionPaths(root, at.project, at.session)
  const read = readers.get(paths.dir) ?? createReader()

  readers.set(paths.dir, read)

  return foldSession(await read(host, paths), now)
}

/** Every session filed under a project, as it stands at `now`, but the one `except` names. */
export const sessionsIn = async (
  host: Host,
  root: string,
  project: string,
  now: number,
  except?: string,
) => {
  const ids = (await foldersIn(host, sessionsDir(root, project))).filter(
    id => isSessionId(id) && id !== except,
  )
  const sessions = await Promise.all(
    ids.map(session => foldAt(host, root, { project, session }, now)),
  )

  return sessions.filter(session => session !== undefined)
}

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

/** The sessions a look reads, by id: every one filed but the held one, and each other it reads in full. */
const readAround = async (
  host: Host,
  root: string,
  held: string,
  full: readonly SitrepSessionRef[],
  now: number,
) => {
  const read = new Map<string, Filed>()
  const keys = await projectKeys(host, root)

  for (const project of keys) {
    for (const session of await sessionsIn(host, root, project, now, held)) {
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

/** The projects read, each with its current sessions; a project with none is dropped, but never the held session's. */
const projectsOf = (
  held: SitrepAttachment,
  keys: readonly string[],
  read: ReadonlyMap<string, Filed>,
  now: number,
): SitrepProject[] =>
  keys.flatMap(key => {
    const sessions = [...read.values()]
      .filter(({ project }) => project === key)
      .map(({ session }) => brief(session))
      .filter(session => isCurrent(session, now))

    return sessions.length > 0 || key === held.project ? [{ key, sessions }] : []
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

/** Forgets the readers of sessions this look did not read. */
const prune = (root: string, read: ReadonlyMap<string, Filed>) => {
  const dirs = new Set(
    [...read.values()].map(({ project, session }) => sessionPaths(root, project, session.id).dir),
  )

  for (const dir of readers.keys()) {
    if (!dirs.has(dir)) {
      readers.delete(dir)
    }
  }
}

const look = async (host: Host) => {
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
  const { keys, read } = await readAround(host, root, held.session, full, now)

  await put(host.state.projects, 'projects', projectsOf(held, keys, read, now))
  await put(host.state.others, 'others', othersOf(full, read))
  await settleSent(host, read, now)
  await settleAnswering(host)
  prune(root, read)
}

/** Reads the sessions around the held one now, once any look under way has settled; never fails, its failure logged. */
export const lookAround = (host: Host) => {
  looking = looking.then(() => look(host)).catch(logFailure(host, 'reading the sessions around'))

  return looking
}

/** Reads the sessions around the held one every `AROUND_MS`, from the window's start. */
export const lookEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(AROUND_MS, () => void lookAround(host))
}
