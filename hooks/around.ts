/**
 * The pieces of work around the held one, read at a slower pace than its
 * watch. The held work's project is always read, so the band can count what
 * waits in its other sessions. While the board is open, so is the project
 * it looks at, every project while it looks at all of them, and in full each
 * other work it draws: the session it looks at, and those Lee's replies wait
 * for or went to.
 *
 * Whatever the board shows, the work of the ask Lee is answering in the
 * prompt is read in full too, so the answering mode ends once that ask can
 * no longer take the answer.
 *
 * Each work is read through a reader of its own, so only a file that changed
 * is read again. What drawing needs goes in `$.state` as plain data, put
 * only when it changed; the held work itself stays the watch's.
 */
import type { Timer } from 'claude-code'
import { brief, foldWork, isCurrent, isWorkId, workPaths, worksDir } from '../core'
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepOther,
  SitrepPane,
  SitrepProject,
  SitrepQueued,
  SitrepSent,
  SitrepWorkRef,
} from '../types'
import { settleAnswering } from './answering'
import { boardOf } from './board'
import { logFailure, rootFor, type Host, type Slot } from './host'
import { projectKeys } from './projects'
import { destinations, isShowing } from './queue'
import { createReader, foldersIn, type Reader } from './reader'
import type { Filed } from './scene'

/**
 * How often the works around the held one are read. They change only as
 * Claude posts in other windows or Lee replies, and the views they feed are
 * glanced at rather than watched; a few seconds' lag costs nothing there,
 * and a third of the watch's pace keeps reading every project cheap.
 */
export const AROUND_MS = 5_000

/** What a look reads: the projects whose works it briefs, every one or those named, and the other works it reads in full. */
type Scope = {
  isAll: boolean
  projects: readonly string[]
  full: readonly SitrepWorkRef[]
}

/** Each work's reader, by its folder. */
const readers = new Map<string, Reader>()

/** What the last look put in `$.state`, as JSON, so a look that changed nothing puts nothing. */
const shown: { projects?: string; others?: string } = {}

let looking: Promise<unknown> = Promise.resolve()

let timer: Timer | undefined

/** A work as its files stand at `now`; undefined when its work.json is missing or torn. */
export const foldAt = async (host: Host, root: string, at: SitrepWorkRef, now: number) => {
  const paths = workPaths(root, at.project, at.work)
  const read = readers.get(paths.dir) ?? createReader()

  readers.set(paths.dir, read)

  return foldWork(await read(host, paths), now)
}

/** Every work filed under a project, as it stands at `now`, but the one `except` names. */
export const worksIn = async (
  host: Host,
  root: string,
  project: string,
  now: number,
  except?: string,
) => {
  const ids = (await foldersIn(host, worksDir(root, project))).filter(
    id => isWorkId(id) && id !== except,
  )
  const works = await Promise.all(ids.map(work => foldAt(host, root, { project, work }, now)))

  return works.filter(work => work !== undefined)
}

/** What the window has to do with other works: replies waiting for them or sent to them, and the ask Lee is answering in the prompt. */
type Around = {
  queue: readonly SitrepQueued[]
  sent: readonly SitrepSent[]
  answering: SitrepAnswering | null
}

const scopeOf = (held: SitrepAttachment, pane: SitrepPane, around: Around): Scope => {
  const { place } = pane
  const answered = around.answering === null ? [] : [around.answering]
  const others = (refs: readonly SitrepWorkRef[]) =>
    destinations(refs).filter(each => each.work !== held.work)

  if (!pane.isOpen) {
    return { isAll: false, projects: [held.project], full: others(answered) }
  }

  const looked = place?.level === 'session' ? [place] : []

  return {
    isAll: place?.level === 'all',
    projects: [
      ...new Set([
        held.project,
        ...(place === null || place.level === 'all' ? [] : [place.project]),
      ]),
    ],
    full: others([...looked, ...around.queue, ...around.sent, ...answered]),
  }
}

/** The projects a look briefs: every one filed, or those the scope names. */
const scopeKeys = async (host: Host, root: string, scope: Scope) =>
  scope.isAll ? projectKeys(host, root) : scope.projects

/** The works a look reads, by id: every one under the scope's projects but the held one, and each it reads in full. */
const readScope = async (host: Host, root: string, held: string, scope: Scope, now: number) => {
  const read = new Map<string, Filed>()
  const keys = await scopeKeys(host, root, scope)

  for (const project of keys) {
    for (const work of await worksIn(host, root, project, now, held)) {
      read.set(work.id, { project, work })
    }
  }

  for (const at of scope.full.filter(each => !read.has(each.work))) {
    const work = await foldAt(host, root, at, now)

    if (work !== undefined) {
      read.set(work.id, { project: at.project, work })
    }
  }

  return { keys, read }
}

/** The projects read, each with its current works; a project with none is dropped, but never the held work's. */
const projectsOf = (
  held: SitrepAttachment,
  keys: readonly string[],
  read: ReadonlyMap<string, Filed>,
  now: number,
): SitrepProject[] =>
  keys.flatMap(key => {
    const works = [...read.values()]
      .filter(({ project }) => project === key)
      .map(({ work }) => brief(work))
      .filter(work => isCurrent(work, now))

    return works.length > 0 || key === held.project ? [{ key, works }] : []
  })

const othersOf = (scope: Scope, read: ReadonlyMap<string, Filed>): SitrepOther[] =>
  scope.full.flatMap(at => {
    const filed = read.get(at.work)

    return filed === undefined ? [] : [{ project: filed.project, board: boardOf(filed.work) }]
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
    const filed = read.get(each.work)

    return filed === undefined || isShowing(filed.work, each, now)
  })

  if (showing.length < sent.length) {
    await host.state.sent.write(showing)
  }
}

/** Forgets the readers of works this look did not read. */
const prune = (root: string, read: ReadonlyMap<string, Filed>) => {
  const dirs = new Set(
    [...read.values()].map(({ project, work }) => workPaths(root, project, work.id).dir),
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
  const scope = scopeOf(held, pane, { queue, sent, answering })
  const { keys, read } = await readScope(host, root, held.work, scope, now)

  await put(host.state.projects, 'projects', projectsOf(held, keys, read, now))
  await put(host.state.others, 'others', othersOf(scope, read))
  await settleSent(host, read, now)
  await settleAnswering(host)
  prune(root, read)
}

/** Reads the works around the held one now, once any look under way has settled; never fails, its failure logged. */
export const lookAround = (host: Host) => {
  looking = looking.then(() => look(host)).catch(logFailure(host, 'reading the works around'))

  return looking
}

/** Reads the works around the held one every `AROUND_MS`, from the session's start. */
export const lookEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(AROUND_MS, () => void lookAround(host))
}
