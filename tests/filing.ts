/**
 * Sessions' files written as their windows and starts write them, through
 * whatever `put` writes a file: the world's disk beneath the engine, or a
 * pure test's files in memory (render.ts). Both write a desk so, so the
 * board a pure test draws is read from the files an engine test's is.
 */
import {
  metaText,
  presenceText,
  projectPaths,
  projectText,
  sessionPaths,
  type Presence,
  type ProjectFile,
  type SessionMeta,
  type SessionPaths,
} from '../core'
import { HELP_DESK, PROJECT, REPO, ROOT, T0, W1 } from './data'
import { file, type Line } from './lines'

/** The held session of a desk: Help desk redesign, filed under Northwind, started by this window at T0. */
export const HELD: SessionMeta = {
  id: 'sr-he1d00',
  ...HELP_DESK,
  root: REPO,
  created: T0,
  by: W1,
}

/**
 * A session beside the held one: its meta, the lines its window wrote, its
 * project's key (Northwind's unless told) and that project's file where it
 * has one, and when its window attached and was last seen, where it beats.
 */
export type Neighbour = {
  meta: SessionMeta
  lines?: readonly Line[]
  project?: string
  projectFile?: ProjectFile
  seenAt?: number
}

/** A desk's files: the held session's lines and the window whose file holds them, this one's unless told, and the sessions beside it. */
export type DeskFiles = {
  lines?: readonly Line[]
  writer?: string
  around?: readonly Neighbour[]
}

/** Writes a file. */
export type Put = (path: string, text: string) => void

/** Sessions' files, written with `put` under the root sitrep keeps. */
export const filing = (put: Put) => {
  /** A session's meta, filed under `project`, as its start writes it: its paths. */
  const seed = (meta: SessionMeta, project = PROJECT.key) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    put(paths.meta, metaText(meta))

    return paths
  }

  /** A window's file in a session, holding `lines`. */
  const log = (paths: SessionPaths, writer: string, lines: readonly Line[]) =>
    put(paths.log(writer), file(...lines))

  /** A window's heartbeat on a session. */
  const beat = (paths: SessionPaths, presence: Presence) =>
    put(paths.heartbeat(presence.writer), presenceText(presence))

  /** A project's file, as a start or the project tool writes it. */
  const project = (key: string, held: ProjectFile) =>
    put(projectPaths(ROOT, key).file, projectText(held))

  /** A session beside the held one, its window attached when last seen. */
  const neighbour = ({
    meta,
    lines = [],
    project: key = PROJECT.key,
    projectFile,
    seenAt,
  }: Neighbour) => {
    const paths = seed(meta, key)

    if (lines.length > 0) {
      log(paths, meta.by, lines)
    }

    if (seenAt !== undefined) {
      beat(paths, { writer: meta.by, attachedAt: seenAt, seenAt })
    }

    if (projectFile !== undefined) {
      project(key, projectFile)
    }
  }

  /**
   * A desk at `now`: the sessions beside the held one, then the held one,
   * its lines in the file of the window `writer` names, and this window's
   * heartbeat, attached at T0 and seen now.
   */
  const desk = ({ lines = [], writer = W1, around = [] }: DeskFiles, now: number) => {
    around.forEach(neighbour)

    const paths = seed(HELD)

    if (lines.length > 0) {
      log(paths, writer, lines)
    }

    beat(paths, { writer: W1, attachedAt: T0, seenAt: now })
  }

  return { seed, log, beat, project, neighbour, desk }
}
