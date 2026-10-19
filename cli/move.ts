/**
 * The old layout moved into today's, as a run of the CLI starts: every
 * session folder under a project's `works/` into `sessions/`, its work.json
 * becoming session.json, once no window runs a version that still writes
 * the old layout. Only the CLI moves it: a mod's `$.fs` can neither delete
 * nor rename.
 *
 * Readers read both layouts as one (core's layouts.ts), so every state
 * partway through reads the same board, and two runs moving at once are
 * harmless: a file another run moved first is left so. With nothing to
 * move, a run lists each project's folder and no more.
 */
import {
  heldAt,
  isOnOldVersion,
  isSessionId,
  movedTo,
  moving,
  oldSessionsDir,
  projectPaths,
  sessionPaths,
  type SessionPaths,
} from '../core'
import { foldersIn, heartbeatsIn, projectKeys, sessionIdsIn, textAt } from './files'
import type { Io } from './io'

/** Whether a project still files sessions under the old layout: its folder of them is there. */
const filesOld = async (io: Io, root: string, key: string) => {
  const { dir } = projectPaths(root, key)
  const old = oldSessionsDir(root, key)

  return (await io.fs.list(dir)).some(
    entry => entry.kind === 'dir' && `${dir}/${entry.name}` === old,
  )
}

/** Whether a window on the board, under either layout, runs a version that still writes the old one. */
const isOldVersionRunning = async (io: Io, root: string, keys: readonly string[], now: number) => {
  const beats = await Promise.all(
    keys.map(async key =>
      Promise.all(
        (await sessionIdsIn(io, root, key)).map(async id => {
          const paths = sessionPaths(root, key, id)

          return [...(await heartbeatsIn(io, paths)), ...(await heartbeatsIn(io, paths.old))]
        }),
      ),
    ),
  )

  return beats.flat(2).some(beat => isOnOldVersion(beat, now))
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
  const [old, now] = await Promise.all([textAt(io, from), textAt(io, to)])

  if (old === undefined) {
    return
  }

  const step = moving(heldAt(paths.old, from), old, now)
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

/** Moves every session filed under the old layout into today's, unless a window still runs a version writing it. */
export const moveOldLayout = async (io: Io, root: string, now: number) => {
  const keys = await projectKeys(io, root)
  const filing = (
    await Promise.all(keys.map(async key => ((await filesOld(io, root, key)) ? [key] : [])))
  ).flat()

  if (filing.length === 0 || (await isOldVersionRunning(io, root, keys, now))) {
    return
  }

  for (const key of filing) {
    for (const id of (await foldersIn(io, oldSessionsDir(root, key))).filter(isSessionId)) {
      await moveSession(io, sessionPaths(root, key, id))
    }

    await io.fs.removeFolder(oldSessionsDir(root, key))
  }
}
