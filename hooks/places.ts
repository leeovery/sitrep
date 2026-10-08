/**
 * The board as a tree, with this session as home: a session sits in its
 * project, and every project under All projects. Lee's own path up it (this
 * session, its project, every project) is the tabs; anywhere else is a step
 * back up. Also what each place shows: its works, its log, what it parked.
 */
import {
  allProjects,
  brief,
  projectLog,
  projectParked,
  summariseProject,
  type Parked,
  type WorkBrief,
} from '../core'
import type { SitrepPlace, SitrepWorkRef } from '../types'
import { titled } from './look'
import type { Filed, Scene } from './scene'

export const EVERY_PROJECT: SitrepPlace = { level: 'all' }

/** Something parked where the board is looking, the work that parked it, and that work's name. */
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

/** Lee's own path up the tree: this session, its project, every project. */
export const isOnPath = (scene: Scene) =>
  [homeOf(scene), projectPlace(scene.here), EVERY_PROJECT].some(home =>
    samePlace(scene.place, home),
  )

/** Whether something of a work's belongs where the board is looking. */
export const inPlace = (place: SitrepPlace, at: SitrepWorkRef) => {
  switch (place.level) {
    case 'session':
      return at.work === place.work
    case 'project':
      return at.project === place.project
    case 'all':
      return true
  }
}

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
export const projectName = (scene: Scene, key: string) => titled(projectAt(scene, key).summary.name)

/** Every project read, ordered and folded as All projects shows them. */
export const everyProject = (scene: Scene) =>
  allProjects(
    keysRead(scene).map(key => summariseProject(key, briefsIn(scene, key))),
    scene.here,
  )

/** Whether every project has been read: only while the board looks at all of them. */
export const isAllRead = (scene: Scene) => scene.pane.isOpen && scene.place.level === 'all'

/** How many asks wait in the held work's project's other sessions. */
export const waitingElsewhere = (scene: Scene) =>
  (scene.projects.find(project => project.key === scene.here)?.works ?? []).reduce(
    (sum, work) => sum + work.waiting,
    0,
  )

const parkedIn = (scene: Scene, key: string): ParkedAt[] => {
  const works = briefsIn(scene, key)
  const names = new Map(works.map(work => [work.id, work.name]))

  return projectParked(works).map(({ work, ...parked }) => ({
    at: { project: key, work },
    name: names.get(work) ?? work,
    parked,
  }))
}

/** What was parked where the board is looking, oldest first. */
export const parkedAt = (scene: Scene): ParkedAt[] =>
  keysRead(scene)
    .flatMap(key => parkedIn(scene, key))
    .filter(each => inPlace(scene.place, each.at))
    .sort((a, b) => a.parked.at - b.parked.at)

/** A work's name, with its project's where the board's own project is another. */
export const workLabel = (scene: Scene, filed: Filed) =>
  filed.project === scene.here
    ? filed.work.status.name
    : `${filed.work.status.name} · ${titled(filed.work.project)}`
