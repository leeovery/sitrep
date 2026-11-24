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
 * Each session is read in the folder it was started in, which every ref the
 * window keeps names, and filed under the project its lines name, which may
 * be another since it moved (filing.ts).
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
  compareText,
  every,
  isCurrent,
  isOffBoard,
  listingOf,
  OFF_BOARD_MS,
  oldSessions,
  parkedBy,
  pickedUpTo,
  projectParked,
  projectTakenOff,
  refold,
  sessionPaths,
  projectOfFolder,
  takenOff,
  takenOffBy,
  type Filed,
  type FolderKey,
  type KeptFold,
  type Listing,
  type Parked,
  type ProjectKey,
  type Session,
  type SessionFiles,
} from '../core'
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepBoard,
  SitrepOther,
  SitrepPane,
  SitrepPlace,
  SitrepProject,
  SitrepQueued,
  SitrepSent,
  SitrepSessionRef,
} from '../types'
import { settleAnswering } from './answering'
import { boardOf, hereOf, sessionOf } from './board'
import { fromTheTop } from './clip'
import { fileOne, filingWith, projectNames, type FiledIn, type InFolder } from './filing'
import { folderKeys } from './folders'
import { logFailure, oneAtATime, rootFor, type Host, type Slot } from './host'
import { oldList, pickedUpList, projectScope } from './lists'
import { EVERY_PROJECT, samePlace } from './places'
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
type LastRead = KeptFold & { read: Reader; isOff: boolean }

/** Each session as last read, by its folder. */
const lastRead = new Map<string, LastRead>()

/** The project each session was filed under as the last look read it, by id: every one it read, and the held one where its board was its own. */
const filedLast = new Map<string, ProjectKey>()

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
    lastRead.clear()
    filedLast.clear()
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
  const last = lastRead.get(dir)
  const fold = refold(last, files, now)
  const standing = fold === last ? last : { ...fold, read, isOff: isOffBoard(fold.session, now) }

  lastRead.set(dir, standing)

  return standing.session
}

/**
 * A session as its files stand at `now`, in the folder `at` names, read
 * through its reader, `listing` that folder's where the caller has it;
 * undefined when its session.json is missing or torn.
 */
export const foldAt = async (
  host: Host,
  root: string,
  at: SitrepSessionRef,
  now: number,
  listing?: readonly FsEntry[],
) => {
  const paths = sessionPaths(root, at.project, at.session)
  const read = lastRead.get(paths.dir)?.read ?? createReader()

  return keep(paths.dir, read, await read(host, paths, listing), now)
}

/** A session as its files stand at `now`, in the folder `at` names, filed under its project; undefined when its session.json is missing or torn. */
export const filedNow = async (host: Host, root: string, at: SitrepSessionRef, now: number) => {
  const session = await foldAt(host, root, at, now)

  return session === undefined ? undefined : fileOne(host, root, { folder: at.project, session })
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
type ReadFiled = (at: SitrepSessionRef, listing: readonly FsEntry[]) => Promise<Session | undefined>

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
    sessions
      .filter(id => id !== except)
      .map(session => readFiled({ project: folder, session }, listing)),
  )

  return folded.flatMap(session => (session === undefined ? [] : [{ folder, session }]))
}

/** Each session read in its folder, filed, each project's name read once for them all. */
const filedFrom = (host: Host, root: string, found: readonly InFolder[]) =>
  Promise.all(found.map(filingWith(projectNames(host, root))))

/** Every session on the board, as its files stand at `now`, each filed under its project, with the folder its files are in. */
export const everySession = async (host: Host, root: string, now: number): Promise<FiledIn[]> => {
  const found = await Promise.all(
    (await folderKeys(host, root)).map(folder =>
      foldFiled(host, root, folder, (at, listing) => foldAt(host, root, at, now, listing)),
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
    const { dir } = sessionPaths(root, at.project, at.session)
    const last = lastRead.get(dir)

    return last?.isOff === true && !isWhole && !full.has(at.session)
      ? keep(dir, last.read, last.files, now)
      : foldAt(host, root, at, now, listing)
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
    const session = await foldAt(host, root, at, now)

    if (session !== undefined) {
      found.set(session.id, { folder: at.project, session })
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
 * under, and what was taken off the held session's own Parked; the project
 * the open board shows a view of, its own or a session's, home's the held
 * session's, none at All projects; the project whose own view it shows; and
 * how much of each list the views show.
 */
type Showing = {
  here: ProjectKey
  heldTakenOff: readonly Parked[]
  shown?: ProjectKey
  viewed?: ProjectKey
  pane: SitrepPane
}

/** The project a place on the board is a view of, a session's as the look files that session; none at All projects. */
const viewedProject = (
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

/** Whether the views show every entry of one of a project's lists, which a look then carries whole. */
const isAllShown = ({ shown }: SitrepPane, list: string) => shown?.[list] === 'all'

/** Whether the views show everything taken off a project's Parked. */
const isAllPickedUp = (pane: SitrepPane, key: string) =>
  isAllShown(pane, pickedUpList(projectScope(key)))

/**
 * What a look keeps and carries by, as the board stands: the held session
 * as its board has it, filed under `here`, what was taken off its Parked
 * bounded as the views show it; none where the board is another session's.
 */
const showingOf = (
  held: SitrepAttachment,
  here: ProjectKey,
  board: SitrepBoard | null,
  pane: SitrepPane,
  read: ReadonlyMap<string, Filed>,
): Showing => ({
  here,
  heldTakenOff:
    board?.id === held.session
      ? listingOf(takenOff(sessionOf(board)), isAllPickedUp(pane, here)).entries
      : [],
  shown: pane.isOpen ? viewedProject(held, here, pane.place, read) : undefined,
  viewed: pane.isOpen && pane.place?.level === 'project' ? pane.place.project : undefined,
  pane,
})

/** The project each session is filed under as a look reads it, by id: every one read, and the held one, `held`, where its board is its own. */
const filingOf = (read: ReadonlyMap<string, Filed>, held?: { id: string; project: ProjectKey }) =>
  new Map([
    ...[...read].map(([id, { project }]) => [id, project] as const),
    ...(held === undefined ? [] : [[held.id, held.project] as const]),
  ])

/**
 * Whether a look saw a move empty a project: no session filed under it now,
 * and one the last look filed there read now under another. A session this
 * look did not read, its folder's listing failed or its session.json torn,
 * moved nowhere, so no failed read empties a project.
 */
const isMovedFrom = (key: ProjectKey, filing: ReadonlyMap<string, ProjectKey>) =>
  ![...filing.values()].includes(key) &&
  [...filedLast].some(([id, was]) => was === key && filing.has(id))

/**
 * The pane gone up to All projects, at its top, from the view of a project
 * a move emptied: one step up, as a finish goes up from the session it
 * leaves, so Lee never stands on a project the board no longer lists. Never
 * where the board is another session's, which files the held one nowhere
 * sure; and where Lee went elsewhere as the look read, the pane stays where
 * he went, as he left it: the pane as it now stands.
 */
const upFromEmptied = async (
  host: Host,
  pane: SitrepPane,
  filing: ReadonlyMap<string, ProjectKey>,
  isBoardHeld: boolean,
): Promise<SitrepPane> => {
  const { place } = pane

  if (!isBoardHeld || place?.level !== 'project' || !isMovedFrom(place.project, filing)) {
    return pane
  }

  const went = { isUp: false, pane }

  await host.state.pane.update(now => {
    went.isUp = now.place !== null && samePlace(now.place, place)
    went.pane = went.isUp ? { ...now, place: EVERY_PROJECT, selected: null } : now

    return went.pane
  })

  if (went.isUp && went.pane.isOpen) {
    await fromTheTop(host)
  }

  return went.pane
}

/** The names of the sessions its own sessions are, by id, for the projects whose views name the session a pick-up went to: the held session's, and the project the board shows. */
const namesFor = ({ here, shown }: Showing, key: string, filed: readonly Session[]) =>
  key === here || key === shown
    ? { names: Object.fromEntries(filed.map(session => [session.id, session.status.name])) }
    : {}

/**
 * The names of the sessions filed under other projects that the items a
 * project's views list as taken off its Parked went to, by id: those of
 * what the look carries, and of the held session's own where it is the
 * project's; none while the look carries none.
 */
const pickersFor = (
  { here, heldTakenOff }: Showing,
  key: string,
  taken: Listing<Parked> | undefined,
  read: ReadonlyMap<string, Filed>,
) => {
  if (taken === undefined) {
    return {}
  }

  const listed = [...taken.entries, ...(key === here ? heldTakenOff : [])]
  const pickers = listed.flatMap(parked => {
    const to = pickedUpTo(parked)
    const picker = to === undefined ? undefined : read.get(to)

    return picker === undefined || picker.project === key
      ? []
      : [[picker.session.id, picker.session.status.name] as const]
  })

  return pickers.length === 0 ? {} : { pickers: Object.fromEntries(pickers) }
}

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
  const taken =
    key === shown
      ? {
          takenOff: listingOf(projectTakenOff(filed.flatMap(takenOffBy)), isAllPickedUp(pane, key)),
        }
      : {}
  const old =
    key === viewed
      ? { old: listingOf(oldSessions(filed, now), isAllShown(pane, oldList(projectScope(key)))) }
      : {}

  return { ...taken, ...old }
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
 * projects the board shows, as `showing` says, what grows without end: the
 * names of its sessions and of those its pick-ups went to, wherever they
 * are filed, and, bounded as its views show them, what was taken off their
 * Parked and its old sessions; each project `isKept` keeps.
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
    const past = pastFor(showing, key, filed, now)

    return isKept(showing, key, sessions.length > 0 || parked.length > 0)
      ? [
          {
            key,
            name: nameOf(key, filed),
            sessions,
            parked,
            ...namesFor(showing, key, filed),
            ...pickersFor(showing, key, past.takenOff, read),
            ...past,
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

  for (const dir of lastRead.keys()) {
    if (!dirs.has(dir)) {
      lastRead.delete(dir)
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
  const here = hereOf(held, board)
  const isBoardHeld = board?.id === held.session
  const filing = filingOf(read, isBoardHeld ? { id: held.session, project: here } : undefined)
  const showing = showingOf(
    held,
    here,
    board,
    await upFromEmptied(host, pane, filing, isBoardHeld),
    read,
  )
  const projects = folders.map(projectOfFolder)

  filedLast.clear()
  filing.forEach((project, id) => filedLast.set(id, project))

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

/** Reads the sessions around the held one every `AROUND_MS`, from the window's start, skipping a tick while its last look is under way. */
export const lookEvery = (host: Host) => {
  timer?.cancel()
  timer = host.clock.every(
    AROUND_MS,
    oneAtATime(() => lookAround(host)),
  )
}
