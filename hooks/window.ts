/**
 * This window's hold on a session: its own file, its heartbeat, and a watch
 * that keeps the session's fold current in `$.state` and tells Lee of an
 * ask that lands, or that its snooze's time wakes. A window holds at most
 * one session. Its hold names the folder the session's files are in, which
 * no move changes; the project it is filed under is its fold's to say, at
 * each fold, and the window follows it to another as its lines come to
 * name one.
 *
 * Whatever reads or changes the hold runs in turn (`serially`), so two tool
 * calls never write the window's file over each other, and a heartbeat never
 * lands after the window let go. The heartbeat says what the window is
 * doing as it attaches, and again whenever that changes (doing.ts); the
 * folder its Claude runs in, read again at each beat, as entering a
 * worktree moves it; the replies each send of Lee's in flight carries to
 * the session, from its claim to its end (deliver.ts); and which load wrote
 * it: a load finding a later one's there writes it no more (load.ts).
 */
import type { Timer } from 'claude-code'
import {
  append,
  attach,
  fileRead,
  heartbeat,
  HEARTBEAT_MS,
  isOpen,
  leave,
  parseEntries,
  parsePresence,
  presenceText,
  refold,
  sessionPaths,
  snoozedAsks,
  stateOf,
  waitingOnLee,
  type Body,
  type Entry,
  type Filed,
  type KeptFold,
  type Presence,
  type ReadName,
  type Sending,
  type Session,
  type SessionPaths,
} from '../core'
import type { SitrepAttachment, SitrepInFlight, SitrepQueued, SitrepSessionRef } from '../types'
import { activityNow } from './activity'
import { endAnswering, settleAnswering } from './answering'
import { filedNow, lookAround } from './around'
import { boardOf } from './board'
import { namesKept } from './filing'
import { logFailure, rootFor, type Host } from './host'
import { isLater, isSuperseded, loadedNow, supersede } from './load'
import { counted } from './look'
import { announce, type News } from './news'
import { addressed } from './places'
import { destinations, goesTo, isCarried, type FiledUnder } from './queue'
import { createReader, ownText, type Reader } from './reader'
import { versionNow } from './version'
import { whereNow } from './where'

/** How often the watch lists the session's folders for what changed. */
export const WATCH_MS = 1_500

type Hold = {
  /** The session held, by the folder its files are in. */
  attachment: SitrepAttachment
  /**
   * The session the last fold read, and that session filed, under the one
   * project the window holds it in (`heldProject`); unset until a fold
   * reads it. A fold that changed nothing gives what it gave, so `show`
   * puts nothing.
   */
  filedFold?: { from: Session; filed: Filed }
  /** The names the board gives projects, as filing the session reads them: one read again only once its file changed. */
  names: ReadName
  paths: SessionPaths
  /** The window's own file, as it last wrote it. */
  text: string
  presence: Presence
  read: Reader
  timers: Timer[]
  /** The session as last folded, so a look finding its files as they were, and its fold not changed by time alone, folds nothing. */
  fold?: KeptFold
  /** The fold whose board was last put in `$.state`, filed, and that board as JSON, so a fold that changed nothing puts nothing. */
  shown?: { filed: Filed; json: string }
  /** What the window saw of the session at its last fold; unset until its first. */
  heard?: Heard
}

/** Every ask the window has seen the session hold, and those it saw snoozed. */
type Heard = { asks: ReadonlySet<string>; asleep: ReadonlySet<string> }

let current: Hold | undefined

/**
 * The messages in flight as this load last set or read them in `$.state`,
 * kept here for the heartbeat: a hook's dispatch reads `$.state` as it stood
 * when the dispatch began, and a tool call's lasts as long as its tool runs.
 * Undefined until the load first needs them or sets them.
 */
let flight: SitrepInFlight[] | undefined

/** How many times this load has set the claims: a read of `$.state` begun before the latest is older than it. */
let changes = 0

/**
 * Takes the messages in flight from `$.state`, unless this load has set the
 * claims since `since`, a count of its changes, which is the later word.
 * Another load may have ended or let go of a claim, as one a reload left
 * running can. A read that fails changes nothing.
 */
const readFlight = async (host: Host, since: number) => {
  const read = await host.state.inFlight.read().catch((error: unknown) => {
    logFailure(host, 'reading the messages in flight')(error)

    return undefined
  })

  if (read !== undefined && changes === since) {
    flight = read
  }
}

/**
 * The messages in flight as this load knows them, in the order claimed: read
 * from `$.state` the first time, so a load's first heartbeat says the sends
 * an earlier load left in flight, and a load sends those an earlier load left
 * held. A read that fails is tried again at the next need.
 */
export const flightNow = async (host: Host): Promise<readonly SitrepInFlight[]> => {
  if (flight === undefined) {
    await readFlight(host, changes)
  }

  return flight ?? []
}

/**
 * Whether `held` is the window's hold on the session `ref` names, as the
 * writer it names: by the session's id, as a window holds one session.
 */
export const isHoldOn = (
  held: Pick<SitrepAttachment, 'session' | 'writer'> | undefined,
  ref: Pick<SitrepSessionRef, 'session'> & { writer: string },
) => held?.session === ref.session && held.writer === ref.writer

let queue: Promise<unknown> = Promise.resolve()

/** Runs `task` once every task before it has settled. */
export const serially = <T>(task: () => Promise<T>): Promise<T> => {
  const turn = queue.then(task, task)

  queue = turn.catch(() => undefined)

  return turn
}

/** The session this window holds, if any. */
export const attached = () => current?.attachment

/** Whether the heartbeat at `path` was written by a later load than `presence`'s: the file read live, as `$.state` in a long dispatch is not. */
const isOutrun = async (host: Host, path: string, presence: Presence) => {
  const there = isSuperseded()
    ? undefined
    : await host.fs.read(path).then(
        text => parsePresence(text, presence.writer),
        () => undefined,
      )

  if (isLater(there?.loadedAt, presence.loadedAt)) {
    supersede(host, "the window's heartbeat")
  }

  return isSuperseded()
}

const beat = async (host: Host, hold: Hold, presence: Presence) => {
  const path = hold.paths.heartbeat(hold.attachment.writer)

  if (await isOutrun(host, path, presence)) {
    return
  }

  await host.fs.write(path, presenceText(presence))
  hold.presence = presence
}

/**
 * What the session brings Lee since the window last saw it: the open asks
 * it had not seen, and those it saw snoozed that their time woke. One Lee
 * woke carries no time it woke at. None at the window's first fold, a
 * reload's among them.
 */
const newsOf = (heard: Heard | undefined, session: Session): News =>
  heard === undefined
    ? { landed: [], woken: [] }
    : {
        landed: session.asks.filter(ask => isOpen(ask) && !heard.asks.has(ask.id)),
        woken: waitingOnLee(session).filter(
          ask => heard.asleep.has(ask.id) && ask.wokeAt !== undefined,
        ),
      }

/** Announces what the session brings Lee since the window last saw it. */
const hear = async (host: Host, hold: Hold, session: Session) => {
  const news = newsOf(hold.heard, session)

  hold.heard = {
    asks: new Set(session.asks.map(ask => ask.id)),
    asleep: new Set(snoozedAsks(session).map(ask => ask.id)),
  }
  await announce(host, session.id, news)
}

/** Whether two filings are of the one fold, under the one project. */
const isSameFiled = (a: Filed | undefined, b: Filed) =>
  a?.session === b.session && a.project === b.project

/** Whether one fold filed twice is filed alike: under the one project, by the one name. */
const isFiledAlike = (a: Filed, b: Filed) =>
  a.project === b.project && a.session.project === b.session.project

/** Puts the session's board in `$.state` where it changed, saying the project it is filed under, and tells Lee what it brings; a fold already shown, nothing. */
const show = async (host: Host, hold: Hold, filed: Filed) => {
  if (isSameFiled(hold.shown?.filed, filed)) {
    return
  }

  const shown = { ...boardOf(filed.session), filedUnder: filed.project }
  const json = JSON.stringify(shown)

  if (json === hold.shown?.json) {
    hold.shown = { filed, json }

    return
  }

  await host.state.board.write(shown)
  hold.shown = { filed, json }
  await hear(host, hold, filed.session)
  await settleAnswering(host)
}

/**
 * The session `hold` holds, folded as it stands, under the project it is
 * filed under: folded again only once its files changed, or its fold by
 * time alone (core's `refold`), as the sessions around it are. Undefined
 * with its session.json missing or torn.
 */
const foldHeld = async (host: Host, hold: Hold): Promise<Filed | undefined> => {
  const files = await hold.read(host, hold.paths)
  const logs = { ...files.logs, [hold.attachment.writer]: hold.text }

  hold.fold = refold(hold.fold, { ...files, logs }, await host.clock.now())

  const { session } = hold.fold

  if (session === undefined) {
    return undefined
  }

  const filed = await fileRead(hold.attachment.project, session, hold.names)
  const last = hold.filedFold

  if (last?.from === session && isFiledAlike(last.filed, filed)) {
    return last.filed
  }

  hold.filedFold = { from: session, filed }

  return filed
}

/** The held session folded as it stands, and filed (`heldProject`), nothing put in `$.state`: undefined with no session held, or with its session.json missing or torn. */
export const readHeld = async (host: Host): Promise<Session | undefined> =>
  current === undefined ? undefined : (await foldHeld(host, current))?.session

/** The key of the project the held session is filed under, as its last fold files it; undefined with none held, or none folded since the window took it up. */
export const heldProject = () => current?.filedFold?.filed.project

/**
 * Follows the held session to the project it moved to, a toast saying so:
 * a pick-up of what another session of the project it left parked leaves
 * Ready to send, and the sessions around are read again. Every ref the
 * window keeps names the session's folder, which moves nowhere, so none
 * changes.
 */
const follow = async (host: Host, { session }: Filed) => {
  host.ui.toast(`Moved to ${session.project}.`)
  await dropPickUpsElsewhere(host)
  void lookAround(host)
}

/**
 * The held session folded as it stands, put in `$.state` when it changed,
 * and followed where it is filed under another project than the board last
 * put. Undefined with no session held, or with its session.json missing or
 * torn.
 */
export const refresh = async (host: Host): Promise<Session | undefined> => {
  const hold = current

  if (hold === undefined) {
    return undefined
  }

  const from = hold.shown?.filed.project
  const filed = await foldHeld(host, hold)

  if (filed === undefined) {
    return undefined
  }

  await show(host, hold, filed)

  if (from !== undefined && filed.project !== from) {
    await follow(host, filed)
  }

  return filed.session
}

/** This window's own lines in the held session, as the hold keeps its file; none with none held. */
export const heldLines = (): Entry[] => parseEntries(current?.text ?? '')

/** What the window is doing, as its heartbeat says it: from what it has heard, before any turn your turn since `attachedAt`. */
const stateNow = async (host: Host, attachedAt: number) =>
  stateOf(await activityNow(host), attachedAt)

/**
 * What the window sends the session it holds as `held`: the replies each
 * send of Lee's in flight carries there, with its claim, in the order
 * claimed; none while it sends none. None for the inbox's, which are on
 * their way there already, nor for a send to another session, or claimed as
 * another writer. Nor a pick-up of another session's item: its id may be
 * one an item of the held session has too, which every reader would carry
 * it onto.
 */
const sendingTo = (
  held: SitrepAttachment,
  flights: readonly SitrepInFlight[],
): Sending[] | undefined => {
  const sends = flights
    .filter(each => each.source === 'send' && isHoldOn(held, each))
    .map(send => ({
      at: send.claimedAt,
      replies: send.replies
        .filter(reply => addressed(reply.item) === undefined)
        .map(({ type, ...reply }) => reply),
    }))
    .filter(send => send.replies.length > 0)

  return sends.length === 0 ? undefined : sends
}

/** What the heartbeat says of the window's doing on the session it holds as `held`: its state, and what it sends there. */
const doingNow = async (host: Host, held: SitrepAttachment) => ({
  state: await stateNow(host, held.attachedAt),
  sending: sendingTo(held, await flightNow(host)),
})

/** The folder this window's Claude runs in; undefined where it does not read, which the debug log says. */
const directoryNow = (host: Host) =>
  host.conversation.root().catch((error: unknown) => {
    logFailure(host, "reading the window's folder")(error)

    return undefined
  })

/** The folder the heartbeat at `path` last said, as a reload's attach keeps it should its own read fail; none with none there. */
const saidDirectory = (host: Host, path: string, writer: string) =>
  host.fs.read(path).then(
    text => parsePresence(text, writer)?.directory,
    () => undefined,
  )

/** Whether a heartbeat already says this of the window's doing. */
const isSaid = (presence: Presence, doing: Pick<Presence, 'state' | 'sending'>) =>
  JSON.stringify([presence.state, presence.sending]) ===
  JSON.stringify([doing.state, doing.sending])

/** The beat, saying the window's doing as it stands, the messages in flight read afresh from `$.state`, and the watch, each run in turn and only while `hold` is still the window's. */
const timersFor = (host: Host, hold: Hold) => {
  const whileHeld = (what: string, task: () => Promise<unknown>) => () =>
    void serially(() => (current === hold ? task() : Promise.resolve())).catch(
      logFailure(host, what),
    )

  return [
    host.clock.every(HEARTBEAT_MS, () => {
      // Counted as the beat's dispatch begins, which is the moment its read
      // of `$.state` gives, before it waits its turn on the window's queue.
      const since = changes

      whileHeld('the heartbeat', async () => {
        await readFlight(host, since)

        const directory = (await directoryNow(host)) ?? hold.presence.directory

        await beat(
          host,
          hold,
          heartbeat(
            { ...hold.presence, directory, ...(await doingNow(host, hold.attachment)) },
            await host.clock.now(),
          ),
        )
      })()
    }),
    host.clock.every(
      WATCH_MS,
      whileHeld('the watch', () => refresh(host)),
    ),
  ]
}

/** Puts nothing in `$.state` for drawing: no session is held, and nothing of one is being answered. */
const forget = async (host: Host) => {
  await host.state.attachment.write(null)
  await host.state.board.write(null)
  await endAnswering(host)
}

/**
 * Rewrites the heartbeat of the held session with what the window is doing
 * and sending there, should that differ from what it last said: whether it
 * did. With no session held, nothing: the window's doing waits for its next
 * attach.
 */
export const restate = (host: Host) =>
  serially(async () => {
    const hold = current

    if (hold === undefined) {
      return false
    }

    const doing = await doingNow(host, hold.attachment)

    if (isSaid(hold.presence, doing)) {
      return false
    }

    await beat(host, hold, heartbeat({ ...hold.presence, ...doing }, await host.clock.now()))

    return true
  })

/**
 * Keeps the messages in flight as they now stand in `$.state`, and has the
 * heartbeat say what they send the held session: each send's replies from
 * its claim to its end. Whether the heartbeat was rewritten.
 */
export const sayInFlight = (host: Host, flights: SitrepInFlight[]) => {
  flight = flights
  changes += 1

  return restate(host)
}

/**
 * Lets go of the held session: the heartbeat says so, and whether the
 * window's Claude `livesOn` into another conversation, and the beat and the
 * watch stop.
 */
export const letGo = async (host: Host, livesOn = false) => {
  const hold = current

  if (hold === undefined) {
    return
  }

  current = undefined

  for (const timer of hold.timers) {
    timer.cancel()
  }

  try {
    await beat(host, hold, leave(hold.presence, await host.clock.now(), livesOn))
  } finally {
    await forget(host)
  }
}

/** Why pick-ups left Ready to send: the window took up a session of another project than theirs. */
const pickUpsLeft = (count: number) =>
  `${counted(count, 'pick-up', 'pick-ups')} of another project left Ready to send: pick up from a window of that project.`

/**
 * Where the held session and the sessions of these pick-ups are filed now:
 * the held one as its last fold files it, each other read afresh; one not
 * read, under none. What tells where a pick-up goes (queue.ts's `goesTo`).
 */
export const filingNow = async (
  host: Host,
  pickUps: readonly SitrepSessionRef[],
): Promise<FiledUnder> => {
  const held = current?.attachment.session
  const here = heldProject()
  const [root, now] = await Promise.all([rootFor(host), host.clock.now()])
  const others = destinations(pickUps).filter(at => at.session !== held)
  const read = await Promise.all(others.map(at => filedNow(host, root, at, now)))
  const filed = new Map(
    read.flatMap(each => (each === undefined ? [] : [[each.session.id, each.project] as const])),
  )

  return session => (session === held ? here : filed.get(session))
}

/**
 * Takes out of Ready to send each pick-up that goes to none (queue.ts's
 * `goesTo`), of what a session filed under another project than the held
 * session's parked, each filed as it stands, none a send in flight
 * carries, a toast saying so: a pick-up goes to the window's Claude, and
 * none of another project is given one. As the window takes up a session,
 * as its session moves, and as a claim ends unwritten, its replies back in
 * Ready to send. One pressed for a session of the held session's project
 * that moves after stays, going to none while that session is filed
 * elsewhere.
 */
export const dropPickUpsElsewhere = async (host: Host) => {
  const held = current?.attachment

  if (held === undefined || heldProject() === undefined) {
    return
  }

  const [flights, queue] = await Promise.all([flightNow(host), host.state.queue.read()])
  const isPickUp = (reply: SitrepQueued) => reply.verdict === 'pickup' && !isCarried(flights, reply)
  const filedUnder = await filingNow(host, queue.filter(isPickUp))
  const isLeft = (reply: SitrepQueued) =>
    isPickUp(reply) &&
    filedUnder(reply.session) !== undefined &&
    goesTo(held, reply, filedUnder) === undefined
  const left = queue.filter(isLeft).length

  if (left > 0) {
    await host.state.queue.update(waiting => waiting.filter(reply => !isLeft(reply)))
    host.ui.toast(pickUpsLeft(left))
  }
}

/**
 * Holds the session `attaching` names, by the folder its files are in,
 * letting go of any other first: reads the window's own file back, works
 * out where the window is, writes its heartbeat, saying its folder (the one
 * its heartbeat there said, where the folder does not read), the version it
 * runs and what it is doing as it stands, files it, starts the beat and the
 * watch, and folds the session. A pick-up of another project's item leaves
 * Ready to send.
 */
export const attachTo = async (host: Host, root: string, attaching: SitrepAttachment) => {
  const { project, session, writer, attachedAt } = attaching
  const paths = sessionPaths(root, project, session)
  const [where, directory, version, doing, loadedAt] = await Promise.all([
    whereNow(host),
    directoryNow(host).then(read => read ?? saidDirectory(host, paths.heartbeat(writer), writer)),
    versionNow(host),
    doingNow(host, attaching),
    loadedNow(host),
  ])
  const hold: Hold = {
    attachment: attaching,
    names: namesKept(host, root),
    paths,
    text: await ownText(host, paths.log(writer)),
    presence: attach(writer, attachedAt, { where, directory, version, ...doing, loadedAt }),
    read: createReader(),
    timers: [],
  }

  await letGo(host)
  await beat(host, hold, heartbeat(hold.presence, await host.clock.now()))
  current = hold
  await foldHeld(host, hold)
  await host.state.attachment.write(hold.attachment)
  await dropPickUpsElsewhere(host)
  hold.timers = timersFor(host, hold)

  return refresh(host)
}

/**
 * Takes the held session up again from `$.state`, after a reload of the
 * mod's code or a restart of its worker. A hold left by another
 * conversation (one that ended without letting go) is dropped instead: its
 * file is not this one's.
 */
export const resume = async (host: Host) => {
  const held = await host.state.attachment.read()

  if (held === null || current !== undefined) {
    return
  }

  if (held.writer !== (await host.conversation.id())) {
    await forget(host)

    return
  }

  await attachTo(host, await rootFor(host), held)
}

/** Writes lines to the end of the window's own file, the whole file at once, and folds the session again. */
export const post = async (host: Host, bodies: readonly Body[]) => {
  const hold = current

  if (hold === undefined) {
    throw new Error('no session is held to post to')
  }

  const { text } = append(hold.text, bodies, await host.clock.now())

  await host.fs.write(hold.paths.log(hold.attachment.writer), text)
  hold.text = text

  return refresh(host)
}
