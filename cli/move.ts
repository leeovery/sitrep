/**
 * The old layout moved into today's, as a run of the CLI starts: every
 * session folder under a project's `works/` into `sessions/`, its work.json
 * becoming session.json, once no window that may still write the old layout
 * keeps it waiting (core's `isMoveHeld`). Only the CLI moves it: a mod's
 * `$.fs` can neither delete nor rename.
 *
 * Readers read both layouts as one (core's layouts.ts), so every state
 * partway through reads the same board, and two runs moving at once are
 * harmless: a file another run moved first is left so. There is something
 * to move while an old session folder holds a file the move acts on: a
 * meta, lines or a heartbeat. With none, a run lists `projects/`, each
 * project's `works/` and what is left in it, and no more.
 */
import {
  contentsAt,
  isMoveHeld,
  isSessionId,
  movedTo,
  moving,
  oldSessionsDir,
  readOldFirst,
  sessionPaths,
  type SessionPaths,
} from '../core'
import { foldersIn, heartbeatsIn, projectKeys, sessionsFiled, textAt } from './files'
import type { Io, Listed } from './io'

/** A session folder under the old layout, filed under the project `key`, and every file in it, its inbox's and presence's among them. */
type OldSession = { key: string; paths: SessionPaths; files: string[] }

const filesOf = (dir: string, entries: readonly Listed[]) =>
  entries.filter(entry => entry.kind === 'file').map(entry => `${dir}/${entry.name}`)

/** Every file of a session's old folder, its inbox and presence listed where it shows them. */
const oldFilesOf = async (io: Io, paths: SessionPaths) => {
  const { dir, inbox, presence } = paths.old
  const top = await io.fs.list(dir)
  const isShown = (folder: string) =>
    top.some(entry => entry.kind === 'dir' && `${dir}/${entry.name}` === folder)
  const below = await Promise.all(
    [inbox, presence]
      .filter(isShown)
      .map(async folder => filesOf(folder, await io.fs.list(folder))),
  )

  return [...filesOf(dir, top), ...below.flat()]
}

/**
 * The sessions a project files under the old layout that hold a file the
 * move acts on (a meta, lines, a heartbeat): anything else left there, as a
 * Finder file, or a folder that is no session, is nothing to move.
 */
const toMove = async (io: Io, root: string, key: string): Promise<OldSession[]> => {
  const sessions = await Promise.all(
    (await foldersIn(io, oldSessionsDir(root, key))).filter(isSessionId).map(async id => {
      const paths = sessionPaths(root, key, id)

      return { key, paths, files: await oldFilesOf(io, paths) }
    }),
  )

  return sessions.filter(({ paths, files }) =>
    files.some(path => contentsAt(paths.old, path) !== 'other'),
  )
}

/** A session's heartbeats under both layouts, as core's `isMoveHeld` weighs them. */
const sessionBeats = async (io: Io, paths: SessionPaths) => {
  const { now, old } = await readOldFirst(paths.old, paths, folder => heartbeatsIn(io, folder))

  return { beats: [...old.beats, ...now.beats], unread: [...old.unread, ...now.unread] }
}

/** Whether the heartbeats on the board, under either layout, keep the move waiting (core's `isMoveHeld`). */
const isHeld = async (io: Io, root: string, keys: readonly string[], now: number) => {
  const read = (
    await Promise.all(
      keys.map(async key =>
        Promise.all(
          (await sessionsFiled(io, root, key)).map(id =>
            sessionBeats(io, sessionPaths(root, key, id)),
          ),
        ),
      ),
    )
  ).flat()

  return isMoveHeld(
    read.flatMap(each => each.beats),
    read.flatMap(each => each.unread),
    now,
  )
}

/**
 * Moves a file of a session's old folder into today's, as core's `moving`
 * says; once more, should a file land in its place first. A file gone, as
 * another run moved it, is left so.
 */
const moveFile = async (
  io: Io,
  paths: SessionPaths,
  from: string,
  isAgain = false,
): Promise<void> => {
  const to = movedTo(paths, from)
  const { old, now } = await readOldFirst(from, to, path => textAt(io, path))

  if (old === undefined) {
    return
  }

  const step = moving(contentsAt(paths.old, from), old, now)
  const renameIn = async () => {
    if (!(await io.fs.moveIn(from, to)) && !isAgain) {
      await moveFile(io, paths, from, true)
    }
  }

  switch (step.to) {
    case 'replace':
      return io.fs.replace(from, to)
    case 'rename':
      return renameIn()
    case 'append':
      if (step.text !== '') {
        await io.fs.append(to, step.text)
      }

      return io.fs.remove(from)
    case 'drop':
      return io.fs.remove(from)
    case 'leave':
      return undefined
  }
}

/** Moves a session's old folder into today's, file by file, then removes the old folders it emptied. */
const moveSession = async (io: Io, { paths, files }: OldSession) => {
  for (const file of files) {
    await moveFile(io, paths, file)
  }

  for (const folder of [paths.old.inbox, paths.old.presence, paths.old.dir]) {
    await io.fs.removeFolder(folder)
  }
}

/** Moves every session filed under the old layout into today's, unless the board's heartbeats keep it waiting. */
export const moveOldLayout = async (io: Io, root: string, now: number) => {
  const keys = await projectKeys(io, root)
  const sessions = (await Promise.all(keys.map(key => toMove(io, root, key)))).flat()

  if (sessions.length === 0 || (await isHeld(io, root, keys, now))) {
    return
  }

  for (const session of sessions) {
    await moveSession(io, session)
  }

  for (const key of new Set(sessions.map(session => session.key))) {
    await io.fs.removeFolder(oldSessionsDir(root, key))
  }
}
