/**
 * The old layout moved into today's, as a run of the CLI starts: every
 * session folder under a project's `works/` into `sessions/`, its work.json
 * becoming session.json, once no window that may still write the old layout
 * keeps it waiting (core's `isMoveHeld`). Only the CLI moves it: a mod's
 * `$.fs` can neither delete nor rename.
 *
 * Readers read both layouts as one (core's layouts.ts), so every state
 * partway through reads the same board, and two runs moving at once are
 * harmless: a file another run moved first is left so. With nothing to
 * move, a run lists `projects/` and each project's folder and no more.
 */
import {
  contentsAt,
  isMoveHeld,
  isSessionId,
  movedTo,
  moving,
  oldSessionsDir,
  projectPaths,
  readOldFirst,
  sessionPaths,
  type SessionPaths,
} from '../core'
import { foldersIn, heartbeatsIn, projectKeys, sessionsFiled, textAt } from './files'
import type { Io } from './io'

/** Whether a project still files sessions under the old layout: its folder of them is there. */
const filesOld = async (io: Io, root: string, key: string) => {
  const { dir } = projectPaths(root, key)
  const old = oldSessionsDir(root, key)

  return (await io.fs.list(dir)).some(
    entry => entry.kind === 'dir' && `${dir}/${entry.name}` === old,
  )
}

/** A session's heartbeats under both layouts, as core's `isMoveHeld` weighs them. */
const sessionBeats = async (io: Io, paths: SessionPaths) => {
  const { now, old } = await readOldFirst(paths, paths.old, folder => heartbeatsIn(io, folder))

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
  const { old, now } = await readOldFirst(to, from, path => textAt(io, path))

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
      await io.fs.remove(to)

      return renameIn()
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
const moveSession = async (io: Io, paths: SessionPaths) => {
  const { dir, inbox, presence } = paths.old

  for (const folder of [dir, inbox, presence]) {
    for (const entry of await io.fs.list(folder)) {
      if (entry.kind === 'file') {
        await moveFile(io, paths, `${folder}/${entry.name}`)
      }
    }
  }

  for (const folder of [inbox, presence, dir]) {
    await io.fs.removeFolder(folder)
  }
}

/** Moves every session filed under the old layout into today's, unless the board's heartbeats keep it waiting. */
export const moveOldLayout = async (io: Io, root: string, now: number) => {
  const keys = await projectKeys(io, root)
  const filing = (
    await Promise.all(keys.map(async key => ((await filesOld(io, root, key)) ? [key] : [])))
  ).flat()

  if (filing.length === 0 || (await isHeld(io, root, keys, now))) {
    return
  }

  for (const key of filing) {
    for (const id of (await foldersIn(io, oldSessionsDir(root, key))).filter(isSessionId)) {
      await moveSession(io, sessionPaths(root, key, id))
    }

    await io.fs.removeFolder(oldSessionsDir(root, key))
  }
}
