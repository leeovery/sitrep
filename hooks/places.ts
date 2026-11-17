/**
 * The board as a tree, with this session as home: a session sits in its
 * project, and every project under All projects. Home and All projects are
 * the tabs; anywhere else is also a step back up. Also what each place
 * shows: its sessions, its old sessions, its asks, what is parked in its
 * project, and what was taken off its project's Parked.
 */
import {
  allProjects,
  brief,
  compareText,
  NOTHING_PARKED,
  parkedBy,
  pickedUpTo,
  projectParked,
  projectTakenOff,
  reaches,
  snoozedUntilIn,
  summariseProject,
  takenOffBy,
  waitsOnLee,
  type Ask,
  type Carried,
  type Parked,
  type Parking,
  type ProjectParked,
  type Session,
  type SessionBrief,
} from '../core'
import type { SitrepPlace, SitrepSessionRef } from '../types'
import { shownAsks, type Filed, type Scene } from './scene'

export const EVERY_PROJECT: SitrepPlace = { level: 'all' }

/**
 * An ask a view lists: the session it is on, that session's name and
 * whether it is finished, where nothing waits on Lee, and when the ask
 * wakes while Lee has it snoozed.
 */
export type AskedAt = {
  at: SitrepSessionRef
  name: string
  isFinished: boolean
  ask: Ask
  snoozedUntil?: number
}

type SnoozedAt = AskedAt & { snoozedUntil: number }

const isAsleep = (asked: AskedAt): asked is SnoozedAt => asked.snoozedUntil !== undefined

/** Asks as a view lists them: those not snoozed in the order given, then those snoozed, the soonest to wake first, then the newest, then by session. */
const snoozedLast = (asked: readonly AskedAt[]): AskedAt[] => [
  ...asked.filter(each => !isAsleep(each)),
  ...asked
    .filter(isAsleep)
    .sort(
      (a, b) =>
        a.snoozedUntil - b.snoozedUntil ||
        b.ask.at - a.ask.at ||
        compareText(a.at.session, b.at.session),
    ),
]

/** Something a view lists as parked, the session that parked it, and that session's name. */
export type ParkedAt = { at: SitrepSessionRef; name: string; parked: Parked }

/** Something a view lists as taken off Parked, as it lists what is parked, and the name of the session a pick-up of it went to, where that is known. */
export type TakenAt = ParkedAt & { pickedUpBy?: string }

/**
 * An item's address on the board, wherever it shows: its session's id, then
 * its own, since a project's view and Ready to send list several sessions'
 * items, and two sessions' items may share an id. What opens it, and its
 * buttons' keys (`pick:<session>:<item>`), are made from it.
 */
export const itemKey = (session: string, item: string) => `${session}:${item}`

/** An item's address read back into its session's id and its own; undefined for an item named by its own id alone. */
export const addressed = (key: string) => {
  const at = key.indexOf(':')

  return at === -1 ? undefined : { session: key.slice(0, at), item: key.slice(at + 1) }
}

/** This session: the held session, the board's home. */
export const homeOf = ({ here, session }: Pick<Scene, 'here' | 'session'>): SitrepPlace => ({
  level: 'session',
  project: here,
  session: session.id,
})

export const projectPlace = (project: string): SitrepPlace => ({ level: 'project', project })

const keyOf = (place: SitrepPlace) => {
  switch (place.level) {
    case 'session':
      return place.session
    case 'project':
      return place.project
    case 'all':
      return ''
  }
}

export const samePlace = (a: SitrepPlace, b: SitrepPlace) =>
  a.level === b.level && keyOf(a) === keyOf(b)

/** The key of the project a session is filed under, as the board read it: the held session's, or another's it read in full or in brief; undefined for one it has not read. */
const projectOf = (scene: Scene, session: string) =>
  filedAt(scene, session)?.project ??
  scene.projects.find(project => project.sessions.some(each => each.id === session))?.key

/** One step up the tree: a session's project, the one it is filed under, then every project. */
export const up = (scene: Scene, place: SitrepPlace): SitrepPlace =>
  place.level === 'session'
    ? projectPlace(projectOf(scene, place.session) ?? place.project)
    : EVERY_PROJECT

/** Whether the board is home, on this session. */
export const isHome = (scene: Scene) => samePlace(scene.place, homeOf(scene))

/** A session the board can draw in full: the held one, or another it read. */
export const filedAt = (scene: Scene, session: string): Filed | undefined =>
  session === scene.session.id
    ? { project: scene.here, session: scene.session }
    : scene.others.get(session)

/** Another session as its project's views read it, in brief: its open asks among what it holds. */
export const briefOf = (scene: Scene, session: string): SessionBrief | undefined =>
  scene.projects.flatMap(project => project.sessions).find(brief => brief.id === session)

/** Whether the board read a session as finished, in full or in brief; one it has not read, as not. */
const isFinishedAt = (scene: Scene, session: string) => {
  const filed = filedAt(scene, session)

  return filed === undefined
    ? briefOf(scene, session)?.isFinished === true
    : filed.session.finished !== undefined
}

/** Whether a reply can reach an item of `session` from this window, the session as the board reads it: core's rule (`reaches`), bound to the scene. */
export const canReach = (scene: Scene, session: string, item: Ask | Parked) =>
  reaches(scene.session.id, { id: session, isFinished: isFinishedAt(scene, session) }, item)

/**
 * How many of a session's asks wait on Lee in this window's views: as the
 * session counts them; finished, those a reply still reaches, which are the
 * held session's open asks, each waiting on Lee as its buttons say, no
 * snooze holding in a finished session.
 */
export const waitingAt = (scene: Scene, session: Session) =>
  session.finished === undefined
    ? session.waiting
    : session.asks.filter(ask => waitsOnLee(ask) && canReach(scene, session.id, ask)).length

/** How many of this session's asks wait on Lee, as every count of this window's says (`waitingAt`): its band, its tabs and its views. */
export const waitingHere = (scene: Scene) => waitingAt(scene, scene.session)

/** Sessions in the order given, but the held one first. */
export const hereFirst = <T extends { id: string }>(scene: Scene, sessions: readonly T[]) => [
  ...sessions.filter(session => session.id === scene.session.id),
  ...sessions.filter(session => session.id !== scene.session.id),
]

/** The projects read: the held session's first. */
const keysRead = (scene: Scene) => [
  ...new Set([scene.here, ...scene.projects.map(project => project.key)]),
]

/** A project as the look around last read it. */
const projectRead = (scene: Scene, key: string) =>
  scene.projects.find(project => project.key === key)

/** A project's current sessions in brief, the held one among them where it is filed, its asks waiting as this window's views count them. */
const briefsIn = (scene: Scene, key: string): SessionBrief[] => [
  ...(key === scene.here
    ? [{ ...brief(scene.session), waiting: waitingAt(scene, scene.session) }]
    : []),
  ...(projectRead(scene, key)?.sessions ?? []),
]

/** Everything parked in a project, oldest first, from every session filed under it, finished and idle ones included, each naming its session by name. */
export const parkedIn = (scene: Scene, key: string): ParkedAt[] => {
  const held = key === scene.here ? parkedBy(scene.session) : []
  const around = (projectRead(scene, key)?.parked ?? []).filter(
    each => each.session !== scene.session.id,
  )

  return projectParked([...held, ...around]).map(({ session, name, ...parked }) => ({
    at: { project: key, session },
    name,
    parked,
  }))
}

/** The name of a session filed under a project, by its id: the held session's as it stands, another's as the look read it; none where the look carried no names for the project. */
const nameIn = (scene: Scene, key: string, id: string) =>
  id === scene.session.id ? scene.session.status.name : projectRead(scene, key)?.names?.[id]

/** Items taken off a project's Parked as a view lists them, each pick-up naming the session it went to, where its line says which. */
const takenOffAt = (scene: Scene, key: string, taken: readonly ProjectParked[]): TakenAt[] =>
  taken.map(({ session, name, ...parked }) => {
    const to = pickedUpTo(parked)

    return {
      at: { project: key, session },
      name,
      parked,
      pickedUpBy: to === undefined ? undefined : nameIn(scene, key, to),
    }
  })

/**
 * What the look carried of a project's past for its views; none where it read
 * the held session as one around, its names holding it: a look from before
 * the window took that session up, whose lists, carried only in part, would
 * count it twice, or list it among the old.
 */
const pastRead = (scene: Scene, key: string) => {
  const read = projectRead(scene, key)

  return read?.names?.[scene.session.id] === undefined ? read : undefined
}

/**
 * A project's list of the board's past as its views draw it: the held
 * session's whole, where it is the project's, among what the look carried of
 * the others', `order`ed, and counting both; none until the look carries it.
 */
const withHeld = <T>(
  held: readonly T[],
  around: Carried<T> | undefined,
  order: (all: readonly T[]) => T[],
): Carried<T> | undefined =>
  around === undefined
    ? undefined
    : { entries: order([...held, ...around.entries]), count: held.length + around.count }

/** What was taken off a project's Parked, the newest taken off first, from every session filed under it, finished and idle ones included; none until the look carries it. */
export const takenOffIn = (scene: Scene, key: string): Carried<TakenAt> | undefined => {
  const held = key === scene.here ? takenOffBy(scene.session) : []
  const taken = withHeld(held, pastRead(scene, key)?.takenOff, projectTakenOff)

  return taken && { ...taken, entries: takenOffAt(scene, key, taken.entries) }
}

/** What is parked in a project as the board has it: the look carries the items, not the times of the sessions holding them. */
const parkingIn = (scene: Scene, key: string): Parking => ({
  ...NOTHING_PARKED,
  parked: parkedIn(scene, key).length,
})

/**
 * A project in brief: its current sessions, what is parked in it, and its
 * name, as its sessions read now name it; with none current, as the look
 * read it.
 */
const summaryIn = (scene: Scene, key: string) => {
  const sessions = briefsIn(scene, key)
  const summary = summariseProject(key, sessions, parkingIn(scene, key))

  return sessions.length > 0 ? summary : { ...summary, name: projectRead(scene, key)?.name ?? key }
}

/** A project as its view draws it: its sessions in brief, counting what is parked in it, and its old sessions as the look carries them for its view, none until it does. */
export const projectAt = (scene: Scene, key: string) => ({
  summary: summaryIn(scene, key),
  old: pastRead(scene, key)?.old,
})

/** The name the board gives a project, as its sessions read now name it. */
export const projectLabel = (scene: Scene, key: string) => summaryIn(scene, key).name

/** Every project read, ordered and folded as All projects shows them. */
export const everyProject = (scene: Scene) =>
  allProjects(
    keysRead(scene).map(key => summaryIn(scene, key)),
    scene.here,
  )

/** How many asks wait on Lee in every other session, in every project. */
export const waitingElsewhere = (scene: Scene) =>
  scene.projects
    .flatMap(project => project.sessions)
    .reduce((sum, session) => sum + session.waiting, 0)

const refOf = ({ project, session }: Filed): SitrepSessionRef => ({ project, session: session.id })

/** An ask as a view lists it, with when it wakes where it is snoozed in its session. */
const askedAt = (
  at: SitrepSessionRef,
  session: { name: string; isFinished: boolean },
  ask: Ask,
): AskedAt => {
  const snoozedUntil = snoozedUntilIn(session, ask)

  return {
    at,
    name: session.name,
    isFinished: session.isFinished,
    ask,
    ...(snoozedUntil === undefined ? {} : { snoozedUntil }),
  }
}

/** A session's Asks: its open asks, and those Lee's send just closed, the newest first; then those snoozed. */
export const askedOf = (scene: Scene, filed: Filed): AskedAt[] => {
  const session = {
    name: filed.session.status.name,
    isFinished: filed.session.finished !== undefined,
  }

  return snoozedLast(
    shownAsks(filed.session, scene.now).map(ask => askedAt(refOf(filed), session, ask)),
  )
}

/** A session's asks as its project's Asks lists them: as its own view does where the board has it in full, else its open asks. */
const briefAsked = (scene: Scene, key: string, session: SessionBrief): AskedAt[] => {
  const filed = filedAt(scene, session.id)

  return filed === undefined
    ? [...session.asks]
        .reverse()
        .map(ask => askedAt({ project: key, session: session.id }, session, ask))
    : askedOf(scene, filed)
}

/** Asks the newest first; of the same moment, this session's first, then the rest by session. */
const newestFirst = (scene: Scene) => {
  const isHere = (asked: AskedAt) => Number(asked.at.session === scene.session.id)

  return (a: AskedAt, b: AskedAt) =>
    b.ask.at - a.ask.at || isHere(b) - isHere(a) || compareText(a.at.session, b.at.session)
}

/** A project's Asks: every current session's asks, the newest first; then those snoozed. */
export const askedIn = (scene: Scene, key: string): AskedAt[] =>
  snoozedLast(
    briefsIn(scene, key)
      .flatMap(session => briefAsked(scene, key, session))
      .sort(newestFirst(scene)),
  )

/** A session's Parked: what it parked, oldest first, then what the project's other sessions parked, as the project's view lists it. */
export const parkedAt = (scene: Scene, filed: Filed): ParkedAt[] => [
  ...filed.session.parked.map(parked => ({
    at: refOf(filed),
    name: filed.session.status.name,
    parked,
  })),
  ...parkedIn(scene, filed.project).filter(({ at }) => at.session !== filed.session.id),
]

/** A session's name, with its project's where the board's own project is another. */
export const sessionLabel = (scene: Scene, filed: Filed) =>
  filed.project === scene.here
    ? filed.session.status.name
    : `${filed.session.status.name} · ${filed.session.project}`
