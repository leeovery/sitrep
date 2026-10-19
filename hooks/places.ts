/**
 * The board as a tree, with this session as home: a session sits in its
 * project, and every project under All projects. Home and All projects are
 * the tabs; anywhere else is also a step back up. Also what each place
 * shows: its sessions, its asks, its notes, what it parked.
 */
import {
  allProjects,
  brief,
  projectLog,
  projectParked,
  summariseProject,
  type Ask,
  type Parked,
  type SessionBrief,
} from '../core'
import type { SitrepPlace, SitrepSessionRef } from '../types'
import { forYou, type Filed, type Scene } from './scene'

export const EVERY_PROJECT: SitrepPlace = { level: 'all' }

/** An ask a view lists, the session it is on, and that session's name. */
export type AskedAt = { at: SitrepSessionRef; name: string; ask: Ask }

/** Something a view lists as parked, the session that parked it, and that session's name. */
export type ParkedAt = { at: SitrepSessionRef; name: string; parked: Parked }

/**
 * An item's address on the board, wherever it shows: its session's id, then
 * its own, since a project's view and Ready to send list several sessions'
 * items, and two sessions' items may share an id. What opens it, and its
 * buttons' keys (`pick:<session>:<item>`), are made from it.
 */
export const itemKey = (session: string, item: string) => `${session}:${item}`

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

/** One step up the tree: a session's project, then every project. */
export const up = (place: SitrepPlace): SitrepPlace =>
  place.level === 'session' ? projectPlace(place.project) : EVERY_PROJECT

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

/** Sessions in the order given, but the held one first. */
export const hereFirst = <T extends { id: string }>(scene: Scene, sessions: readonly T[]) => [
  ...sessions.filter(session => session.id === scene.session.id),
  ...sessions.filter(session => session.id !== scene.session.id),
]

/** The projects read: the held session's first. */
const keysRead = (scene: Scene) => [
  ...new Set([scene.here, ...scene.projects.map(project => project.key)]),
]

/** A project's current sessions in brief, the held one among them where it is filed. */
const briefsIn = (scene: Scene, key: string): SessionBrief[] => [
  ...(key === scene.here ? [brief(scene.session)] : []),
  ...(scene.projects.find(project => project.key === key)?.sessions ?? []),
]

/** A project as its view draws it: its sessions in brief, its notes, what it parked. */
export const projectAt = (scene: Scene, key: string) => {
  const sessions = briefsIn(scene, key)

  return { summary: summariseProject(key, sessions), log: projectLog(sessions), sessions }
}

/** The name the board gives a project, as its sessions read now name it. */
export const projectLabel = (scene: Scene, key: string) => projectAt(scene, key).summary.name

/** Every project read, ordered and folded as All projects shows them. */
export const everyProject = (scene: Scene) =>
  allProjects(
    keysRead(scene).map(key => summariseProject(key, briefsIn(scene, key))),
    scene.here,
  )

/** How many asks wait on Lee in every other session, in every project. */
export const waitingElsewhere = (scene: Scene) =>
  scene.projects
    .flatMap(project => project.sessions)
    .reduce((sum, session) => sum + session.waiting, 0)

const refOf = ({ project, session }: Filed): SitrepSessionRef => ({ project, session: session.id })

/** A session's Asks: its open asks, and those Lee's send just closed, the newest first. */
export const askedOf = (scene: Scene, filed: Filed): AskedAt[] =>
  forYou(filed.session, scene.now).map(ask => ({
    at: refOf(filed),
    name: filed.session.status.name,
    ask,
  }))

/** A session's asks as its project's Asks lists them: as its own view does where the board has it in full, else its open asks. */
const briefAsked = (scene: Scene, key: string, session: SessionBrief): AskedAt[] => {
  const filed = filedAt(scene, session.id)

  return filed === undefined
    ? [...session.asks]
        .reverse()
        .map(ask => ({ at: { project: key, session: session.id }, name: session.name, ask }))
    : askedOf(scene, filed)
}

/** A project's Asks: every current session's asks, the newest first. */
export const askedIn = (scene: Scene, key: string): AskedAt[] =>
  briefsIn(scene, key)
    .flatMap(session => briefAsked(scene, key, session))
    .sort((a, b) => b.ask.at - a.ask.at)

/** What a session has parked, oldest first. */
export const parkedOf = (filed: Filed): ParkedAt[] =>
  filed.session.parked.map(parked => ({
    at: refOf(filed),
    name: filed.session.status.name,
    parked,
  }))

/** What a project's sessions have parked, oldest first. */
export const parkedIn = (scene: Scene, key: string): ParkedAt[] => {
  const sessions = briefsIn(scene, key)
  const names = new Map(sessions.map(session => [session.id, session.name]))

  return projectParked(sessions).map(({ session, ...parked }) => ({
    at: { project: key, session },
    name: names.get(session) ?? session,
    parked,
  }))
}

/** A session's name, with its project's where the board's own project is another. */
export const sessionLabel = (scene: Scene, filed: Filed) =>
  filed.project === scene.here
    ? filed.session.status.name
    : `${filed.session.status.name} · ${filed.session.project}`
