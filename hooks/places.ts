/**
 * The board as a tree, with this session as home: a session sits in its
 * project, and every project under All projects. Home and All projects are
 * the tabs; anywhere else is also a step back up.
 * Also what each place shows: its works, its asks, its log, what it parked.
 */
import {
  allProjects,
  brief,
  projectLog,
  projectParked,
  summariseProject,
  type Ask,
  type Parked,
  type WorkBrief,
} from '../core'
import type { SitrepPlace, SitrepWorkRef } from '../types'
import { forYou, type Filed, type Scene } from './scene'

export const EVERY_PROJECT: SitrepPlace = { level: 'all' }

/** An ask a view lists, the work it is on, and that work's name. */
export type AskedAt = { at: SitrepWorkRef; name: string; ask: Ask }

/** Something a view lists as parked, the work that parked it, and that work's name. */
export type ParkedAt = { at: SitrepWorkRef; name: string; parked: Parked }

/** This session: the held work, the board's home. */
export const homeOf = ({ here, work }: Pick<Scene, 'here' | 'work'>): SitrepPlace => ({
  level: 'session',
  project: here,
  work: work.id,
})

export const projectPlace = (project: string): SitrepPlace => ({ level: 'project', project })

const keyOf = (place: SitrepPlace) => {
  switch (place.level) {
    case 'session':
      return place.work
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

/** A work the board can draw in full: the held one, or another it read. */
export const filedAt = (scene: Scene, work: string): Filed | undefined =>
  work === scene.work.id ? { project: scene.here, work: scene.work } : scene.others.get(work)

/** Works in the order given, but the held one first. */
export const hereFirst = <T extends { id: string }>(scene: Scene, works: readonly T[]) => [
  ...works.filter(work => work.id === scene.work.id),
  ...works.filter(work => work.id !== scene.work.id),
]

/** The projects read: the held work's first. */
const keysRead = (scene: Scene) => [
  ...new Set([scene.here, ...scene.projects.map(project => project.key)]),
]

/** A project's current works in brief, the held one among them where it is filed. */
const briefsIn = (scene: Scene, key: string): WorkBrief[] => [
  ...(key === scene.here ? [brief(scene.work)] : []),
  ...(scene.projects.find(project => project.key === key)?.works ?? []),
]

/** A project as its view draws it: its works in brief, its log, what it parked. */
export const projectAt = (scene: Scene, key: string) => {
  const works = briefsIn(scene, key)

  return { summary: summariseProject(key, works), log: projectLog(works), works }
}

/** A project's name, as its works name it. */
export const projectName = (scene: Scene, key: string) => projectAt(scene, key).summary.name

/** Every project read, ordered and folded as All projects shows them. */
export const everyProject = (scene: Scene) =>
  allProjects(
    keysRead(scene).map(key => summariseProject(key, briefsIn(scene, key))),
    scene.here,
  )

/** How many asks wait on Lee in every other work, in every project. */
export const waitingElsewhere = (scene: Scene) =>
  scene.projects.flatMap(project => project.works).reduce((sum, work) => sum + work.waiting, 0)

const refOf = ({ project, work }: Filed): SitrepWorkRef => ({ project, work: work.id })

/** A session's For you: its open asks, and those Lee's send just closed, the newest first. */
export const askedOf = (scene: Scene, filed: Filed): AskedAt[] =>
  forYou(filed.work, scene.now).map(ask => ({
    at: refOf(filed),
    name: filed.work.status.name,
    ask,
  }))

/** A work's asks as its project's For you lists them: as its own view does where the board has it in full, else its open asks. */
const briefAsked = (scene: Scene, key: string, work: WorkBrief): AskedAt[] => {
  const filed = filedAt(scene, work.id)

  return filed === undefined
    ? [...work.asks]
        .reverse()
        .map(ask => ({ at: { project: key, work: work.id }, name: work.name, ask }))
    : askedOf(scene, filed)
}

/** A project's For you: every current session's asks, the newest first. */
export const askedIn = (scene: Scene, key: string): AskedAt[] =>
  briefsIn(scene, key)
    .flatMap(work => briefAsked(scene, key, work))
    .sort((a, b) => b.ask.at - a.ask.at)

/** What a session has parked, oldest first. */
export const parkedOf = (filed: Filed): ParkedAt[] =>
  filed.work.parked.map(parked => ({ at: refOf(filed), name: filed.work.status.name, parked }))

/** What a project's sessions have parked, oldest first. */
export const parkedIn = (scene: Scene, key: string): ParkedAt[] => {
  const works = briefsIn(scene, key)
  const names = new Map(works.map(work => [work.id, work.name]))

  return projectParked(works).map(({ work, ...parked }) => ({
    at: { project: key, work },
    name: names.get(work) ?? work,
    parked,
  }))
}

/** A work's name, with its project's where the board's own project is another. */
export const workLabel = (scene: Scene, filed: Filed) =>
  filed.project === scene.here
    ? filed.work.status.name
    : `${filed.work.status.name} · ${filed.work.project}`
