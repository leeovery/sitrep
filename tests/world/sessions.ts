/** Sessions, projects and windows other than the world's own, their files written as theirs would be. */
import type { MockClock } from 'claude-code/testing'
import {
  sessionPaths,
  type Body,
  type Presence,
  type SessionMeta,
  type SessionPaths,
} from '../../core'
import { PROJECT, ROOT, W2 } from '../data'
import { filing, type DeskFiles, type Neighbour, type Put } from '../filing'
import type { Line } from '../lines'

/** The sessions put on the board by writing their files with `put`, each line at the clock's time. */
export function sessions(put: Put, clock: MockClock) {
  const filed = filing(put)

  /** Another window's file in a session's folder: each call writes lines to it as that window does, at the time. */
  const writer = (paths: SessionPaths, name = W2) => {
    const lines: Line[] = []

    return (...bodies: Body[]) => {
      lines.push(...bodies.map((body): Line => [clock.now(), body]))
      filed.log(paths, name, lines)
    }
  }

  return {
    /** A session started by another window, filed under `project`: its paths. */
    seed: filed.seed,
    writer,

    /** A project's file, as a start or the project tool writes it. */
    project: filed.project,

    /** Another window's heartbeat on a session. */
    beat: (id: string, presence: Presence, project = PROJECT.key) =>
      filed.beat(sessionPaths(ROOT, project, id), presence),

    /**
     * Another session, started by the window `by` names and filed under
     * `project`: its paths, that window's lines as it writes them, and its
     * heartbeat as of now, attached at `attachedAt`.
     */
    elsewhere: (meta: SessionMeta, project = PROJECT.key, by = meta.by) => {
      const paths = filed.seed(meta, project)

      return {
        paths,
        write: writer(paths, by),
        beat: (attachedAt = clock.now()) =>
          filed.beat(paths, { writer: by, attachedAt, seenAt: clock.now() }),
      }
    },

    /** Sessions beside the world's own, each one's files written whole, as a pure test's desk writes them (render.ts). */
    surround: (around: readonly Neighbour[] = []) => around.forEach(filed.neighbour),

    /** A desk's files as a pure test's scene reads them (render.ts), at the clock's time: the sessions beside the held one, then the held one, for the window to join. */
    lay: (desk: DeskFiles) => filed.desk(desk, clock.now()),
  }
}
