/** Sessions, projects and windows other than the world's own, their files written as theirs would be. */
import type { MockClock } from 'claude-code/testing'
import {
  metaText,
  presenceText,
  projectPaths,
  projectText,
  sessionPaths,
  type Body,
  type Presence,
  type ProjectFile,
  type SessionMeta,
  type SessionPaths,
} from '../../core'
import { PROJECT, ROOT, W2 } from '../data'
import { aroundFiles, file, type Around, type Line } from '../lines'

/** The sessions put on the board by writing their files with `put`, each line at the clock's time. */
export function sessions(put: (path: string, text: string) => void, clock: MockClock) {
  /** A session started by another window, filed under `project`: its paths. */
  const seed = (meta: SessionMeta, project = PROJECT.key) => {
    const paths = sessionPaths(ROOT, project, meta.id)

    put(paths.meta, metaText(meta))

    return paths
  }

  /** Another window's file in a session's folder: each call writes lines to it as that window does, at the time. */
  const writer = (paths: SessionPaths, name = W2) => {
    const lines: Line[] = []

    return (...bodies: Body[]) => {
      lines.push(...bodies.map((body): Line => [clock.now(), body]))
      put(paths.log(name), file(...lines))
    }
  }

  return {
    seed,
    writer,

    /** A project's file, as a start or the project tool writes it. */
    project: (key: string, held: ProjectFile) =>
      put(projectPaths(ROOT, key).file, projectText(held)),

    /** Another window's heartbeat on a session. */
    beat: (id: string, presence: Presence, project = PROJECT.key) =>
      put(sessionPaths(ROOT, project, id).heartbeat(presence.writer), presenceText(presence)),

    /**
     * Another session, started by the window `by` names and filed under
     * `project`: its paths, that window's lines as it writes them, and its
     * heartbeat as of now, attached at `attachedAt`.
     */
    elsewhere: (meta: SessionMeta, project = PROJECT.key, by = meta.by) => {
      const paths = seed(meta, project)

      return {
        paths,
        write: writer(paths, by),
        beat: (attachedAt = clock.now()) =>
          put(paths.heartbeat(by), presenceText({ writer: by, attachedAt, seenAt: clock.now() })),
      }
    },

    /** Sessions beside the world's own, each one's files written whole, as a pure test's scene folds them (render.ts). */
    surround: (around: readonly Around[] = []) => {
      for (const each of around) {
        const project = each.project ?? PROJECT.key
        const paths = sessionPaths(ROOT, project, each.meta.id)
        const files = aroundFiles(each)

        put(paths.meta, files.meta)
        Object.entries(files.logs).forEach(([by, text]) => put(paths.log(by), text))
        Object.entries(files.presence ?? {}).forEach(([by, text]) => put(paths.heartbeat(by), text))

        if (files.project !== undefined) {
          put(projectPaths(ROOT, project).file, files.project)
        }
      }
    },
  }
}
