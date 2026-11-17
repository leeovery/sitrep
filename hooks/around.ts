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
 * Each session is read in the folder it was started in, and filed under the
 * project its lines name, which may be another since it moved (filing.ts);
 * one named by what the window holds is found by its id.
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
 * itself stays the watch's. So does Snooze's choices as the app's
 * `snooze.json` sets them, read as each look lists sitrep's folder.
 */
import type { FsEntry, Timer } from 'claude-code'
import {
  brief,
  carried,
  compareText,
  every,
  isCurrent,
  isOffBoard,
  OFF_BOARD_MS,
  oldSessions,
  parkedBy,
  projectParked,
  projectTakenOff,
  refold,
  sessionPaths,
  projectOfFolder,
  takenOffBy,
  type Filed,
  type FolderKey,
  type KeptFold,
  type ProjectKey,
  type Session,
  type SessionFiles,
} from '../core'
import type {
  SessionKey,
  SitrepAnswering,
  SitrepAttachment,
  SitrepOther,
  SitrepPane,
  SitrepPlace,
  SitrepProject,
  SitrepQueued,
  SitrepSent,
  SitrepSessionRef,
} from '../types'
import { settleAnswering } from './answering'
import { boardOf, hereOf } from './board'
import { fileIn, fileOne, projectNames, type FiledIn, type InFolder } from './filing'
import { folderKeys, folderOf } from './folders'
import { logFailure, rootFor, type Host, type Slot } from './host'
import { oldList, pickedUpList, projectScope } from './lists'
import { destinations, isShowing, type Folded } from './queue'
import { createReader, filedIn, type Reader } from './reader'
import { forgetSnooze, snoozeSettings } from './snoozing'

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
const shown: { projects?: string; others?: string; snooze?: string } = {}

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

/**
 * Forgets what the looks so far read and put, once any look under way has
 * settled, so the next reads every session afresh and puts what it finds,
 * whole or not: with nothing kept, a look reads every session it lists.
 * Only tests call it, a pure test's look over a host of its own starting so;
 * the mod never does.
 */
export const forgetLooks = () => {
  looking = looking.then(() => {
    kept.clear()
    delete shown.projects
    delete shown.others
    delete shown.snooze
    forgetSnooze()
  })

  return looking
}

let timer: Timer | undefined

/** A session folded from `files` at `now`: as last folded, where that was from the same files and its fold has not changed since by time alone. */
const keep = (dir: string, read: Reader, files: SessionFiles, now: number) => {
  const last = kept.get(dir)
  const fold = refold(last, files, now)
  const standing = fold === last ? last : { ...fold, read, isOff: isOffBoard(fold.session, now) }

  kept.set(dir, standing)

  return standing.session
}

/** A session by the key of the folder its files are in, and its id. */
type FolderRef = { folder: FolderKey; session: string }

/** A session as its files stand at `now`, read through its reader, `listing` its folder's project folder's where the caller has it. */
const readAt = async (
  host: Host,
  root: string,
  at: FolderRef,
  now: number,
  listing?: readonly FsEntry[],
) => {
  const paths = sessionPaths(root, at.folder, at.session)
  const read = kept.get(paths.dir)?.read ?? createReader()

  return keep(paths.dir, read, await read(host, paths, listing), now)
}

/** A session as its files stand at `now`, its folder found by its id; undefined when its session.json is missing or torn. */
export const foldAt = async (
  host: Host,
  root: string,
  at: SitrepSessionRef<SessionKey>,
  now: number,
) => readAt(host, root, { folder: await folderOf(host, root, at), session: at.session }, now)

/** A session as its files stand at `now`, its folder found by its id, filed under its project; undefined when its session.json is missing or torn. */
export const filedNow = async (
  host: Host,
  root: string,
  at: SitrepSessionRef<SessionKey>,
  now: number,
) => {
  const folder = await folderOf(host, root, at)
  const session = await readAt(host, root, { folder, session: at.session }, now)

  return session === undefined ? undefined : fileOne(host, root, { folder, session })
}

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

/** Reads a session in a project's folder, given that folder's listing: the session as it stands, undefined where it does not fold. */
type ReadFiled = (at: FolderRef, listing: readonly FsEntry[]) => Promise<Session | undefined>

/** Every session in a project's folder but the one `except` names, each read by `readFiled`, the folder listed once for them all. */
const foldFiled = async (
  host: Host,
  root: string,
  folder: FolderKey,
  readFiled: ReadFiled,
  except?: string,
): Promise<InFolder[]> => {
  const { listing, sessions } = await filedIn(host, root, folder)
  const folded = await Promise.all(
    sessions.filter(id => id !== except).map(session => readFiled({ folder, session }, listing)),
  )

  return folded.flatMap(session => (session === undefined ? [] : [{ folder, session }]))
}

/** Each session read in its folder, filed, each project's name read once for them all. */
const filedFrom = (host: Host, root: string, found: readonly InFolder[]) =>
  Promise.all(found.map(fileIn(projectNames(host, root))))

/** Every session on the board, as its files stand at `now`, each filed under its project, with the folder its files are in. */
export const everySession = async (host: Host, root: string, now: number): Promise<FiledIn[]> => {
  const found = await Promise.all(
    (await folderKeys(host, root)).map(folder =>
      foldFiled(host, root, folder, (at, listing) => readAt(host, root, at, now, listing)),
    ),
  )

  return filedFrom(host, root, found.flat())
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

/**
 * A session around as a look at `now` reads it: one off the board, on a
 * look that is not whole and not read in full, folded from the files it was
 * last read from, its folders not listed.
 */
const aroundAt =
  (host: Host, root: string, now: number, isWhole: boolean, full: ReadonlySet<string>): ReadFiled =>
  async (at, listing) => {
    const { dir } = sessionPaths(root, at.folder, at.session)
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
  const found = new Map<string, InFolder>()
  const folders = await folderKeys(host, root)
  const afresh = new Set([...full.map(each => each.session), ...fresh])
  const around = aroundAt(host, root, now, isWhole, afresh)

  for (const folder of folders) {
    for (const each of await foldFiled(host, root, folder, around, held)) {
      found.set(each.session.id, each)
    }
  }

  for (const at of full.filter(each => !found.has(each.session))) {
    const folder = await folderOf(host, root, at)
    const session = await readAt(host, root, { folder, session: at.session }, now)

    if (session !== undefined) {
      found.set(session.id, { folder, session })
    }
  }

  const filed = await filedFrom(host, root, [...found.values()])

  return { folders, read: new Map(filed.map(each => [each.session.id, each])) }
}

/** Sessions the most recently updated first, those updated at once by id. */
const latestFirst = (a: Session, b: Session) => b.updatedAt - a.updatedAt || compareText(a.id, b.id)

/** A project's name, as the most recently updated of its sessions names it. */
const nameOf = (key: string, sessions: readonly Session[]) =>
  [...sessions].sort(latestFirst).at(0)?.project ?? key

/**
 * What a look keeps and carries by: the project the held session is filed
 * under; the project the open board shows a view of, its own or a
 * session's, home's the held session's, none at All projects; the project
 * whose own view it shows; and how much of each list the views show.
 */
type Showing = { here: ProjectKey; shown?: ProjectKey; viewed?: ProjectKey; pane: SitrepPane }

/** The project a place on the board is a view of, a session's as the look files that session; none at All projects. */
const projectAt = (
  held: SitrepAttachment,
  here: ProjectKey,
  place: SitrepPlace | null,
  read: ReadonlyMap<string, Filed>,
) => {
  if (place === null || (place.level === 'session' && place.session === held.session)) {
    return here
  }

  switch (place.level) {
    case 'session':
      return read.get(place.session)?.project
    case 'project':
      return place.project
    case 'all':
      return undefined
  }
}

/** What a look keeps and carries by, the held session filed under `here`, as the board stands. */
const showingOf = (
  held: SitrepAttachment,
  here: ProjectKey,
  pane: SitrepPane,
  read: ReadonlyMap<string, Filed>,
): Showing => ({
  here,
  shown: pane.isOpen ? projectAt(held, here, pane.place, read) : undefined,
  viewed: pane.isOpen && pane.place?.level === 'project' ? pane.place.project : undefined,
  pane,
})

/** Its sessions' names, for the projects whose views name the session a pick-up went to: the held session's, and the project the board shows. */
const namesFor = ({ here, shown }: Showing, key: string, filed: readonly Session[]) =>
  key === here || key === shown
    ? { names: Object.fromEntries(filed.map(session => [session.id, session.status.name])) }
    : {}

/** Whether the views show every entry of one of a project's lists, which a look then carries whole. */
const isAllShown = ({ shown }: SitrepPane, list: string) => shown?.[list] === 'all'

/**
 * For the project the board shows, what only its views draw, of every
 * session filed under it: what was taken off their Parked, which every view
 * of the project draws, and its old sessions, which its own view draws; of
 * each, the latest the views show and how many there are, or every one
 * while they show all of it.
 */
const pastFor = (
  { shown, viewed, pane }: Showing,
  key: string,
  filed: readonly Session[],
  now: number,
) => {
  const scope = projectScope(key)
  const takenOff =
    key === shown
      ? {
          takenOff: carried(
            projectTakenOff(filed.flatMap(takenOffBy)),
            isAllShown(pane, pickedUpList(scope)),
          ),
        }
      : {}
  const old =
    key === viewed
      ? { old: carried(oldSessions(filed, now), isAllShown(pane, oldList(scope))) }
      : {}

  return { ...takenOff, ...old }
}

/**
 * Whether a look keeps a project, `isHolding` whether it holds a current
 * session or a parked item: one holding either, the held session's, and the
 * one the open board shows a view of, so a finished session's view in a
 * project with nothing else on the board still draws what was taken off its
 * Parked.
 */
const isKept = ({ here, shown }: Showing, key: string, isHolding: boolean) =>
  isHolding || key === here || key === shown

/**
 * The projects read, each with its current sessions, and what every session
 * filed under it parked, finished and idle ones included; and only for the
 * projects the board shows, as `showing` says, what grows without end: its
 * sessions' names, and, bounded as its views show them, what was taken off
 * their Parked and its old sessions; each project `isKept` keeps.
 */
const projectsOf = (
  showing: Showing,
  keys: readonly ProjectKey[],
  read: ReadonlyMap<string, Filed>,
  now: number,
): SitrepProject[] =>
  keys.flatMap(key => {
    const filed = [...read.values()]
      .filter(({ project }) => project === key)
      .map(({ session }) => session)
    const sessions = filed.map(brief).filter(session => isCurrent(session, now))
    const parked = projectParked(filed.flatMap(parkedBy))

    return isKept(showing, key, sessions.length > 0 || parked.length > 0)
      ? [
          {
            key,
            name: nameOf(key, filed),
            sessions,
            parked,
            ...namesFor(showing, key, filed),
            ...pastFor(showing, key, filed, now),
          },
        ]
      : []
  })

/** The other sessions the board draws in full, each by its project, as a look read them; one it could not read is left out. */
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
const prune = (root: string, read: ReadonlyMap<string, FiledIn>) => {
  const dirs = new Set(
    [...read.values()].map(({ folder, session }) => sessionPaths(root, folder, session.id).dir),
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

  const [board, pane, queue, sent, answering, root, now] = await Promise.all([
    host.state.board.read(),
    host.state.pane.read(),
    host.state.queue.read(),
    host.state.sent.read(),
    host.state.answering.read(),
    rootFor(host),
    host.clock.now(),
  ])
  const full = fullOf(held, pane, { queue, sent, answering })
  const isWhole = isWholeLook(now)
  const { folders, read } = await readAround(host, root, held.session, full, now, isWhole, fresh)
  const showing = showingOf(held, hereOf(held, board), pane, read)
  const projects = folders.map(projectOfFolder)

  await put(host.state.projects, 'projects', projectsOf(showing, projects, read, now))
  await put(host.state.others, 'others', othersOf(full, read))
  await put(host.state.snooze, 'snooze', await snoozeSettings(host, root, now))
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
