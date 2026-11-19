/**
 * What a pick opens: SitRep's resume command, filled from the window the
 * session is carried on from, or why nothing runs, in words naming the
 * session. A pick always runs the command, never a jump, a session a window
 * on this Mac shows among them.
 *
 * - From the feed alone (`reachOf`): a live window in tmux or zmx, the first
 *   of them in core's jump order, resumes; with no live window, the last
 *   window does. A session whose live windows are in no multiplexer is
 *   refused, since its Claude ends with its terminal and a command could
 *   only start a second beside it; so is one whose windows say nothing of
 *   where they are, and one with no window left.
 * - Then from what `ps` saw on that window's device, and the command
 *   (`carriedOn`), as the app's click carries a session on (Jump.carryOn):
 *   a Claude suspended there, or `ps` giving no answer, refuses whatever the
 *   command. The default refuses while the session's Claude may still be
 *   alive: running on a device still its conversation's, or held by a live
 *   window with no Claude seen there, as a tab just closed. A command the
 *   user wrote runs past that guard: what it does is theirs. `{tty}` is the
 *   device only while its Claude runs there, the device its own.
 */
import type { Checked, Feed, FeedWindow, LastWindow } from '../../core'
import { isDefault, lineOf } from './command'

/** The window a pick carries a session on from: its writer, folder and device, whether a live window holds the session, and whether that device is still its conversation's. */
export type Resume = {
  name: string
  claude: string
  dir?: string
  device?: string
  isHeld: boolean
  ownsDevice: boolean
}

export type Reach = { resume: Resume } | { answer: string }

/** What runs on the device a session's Claude ran on, as `ps` read it: a Claude Code stopped there, one running, none; or unknown, `ps` giving no answer. */
export type ClaudeThere = 'stopped' | 'running' | 'none' | 'unknown'

/** Why a pick of a session gone from the board opens nothing, as the app's jump says it. */
const NO_SUCH_SESSION = 'There is no such session on the board, in any project.'

/** The session's name, as its row, its Snoozed row, a window of it or its project says it. */
const nameOf = (session: string, feed: Feed) =>
  feed.rows.find(row => row.session === session)?.name ??
  feed.snoozed.find(row => row.session === session)?.name ??
  feed.windows.find(window => window.session === session)?.name ??
  feed.projects.flatMap(project => project.sessions).find(each => each.id === session)?.name

const isMultiplexed = ({ where }: FeedWindow) => where?.tmux !== undefined || where?.zmx !== undefined

const resumeOf = (name: string, window: Pick<FeedWindow, 'writer' | 'where' | 'directory'>, isHeld: boolean, ownsDevice: boolean): Reach => ({
  resume: {
    name,
    claude: window.writer,
    ...(window.directory === undefined ? {} : { dir: window.directory }),
    ...(window.where?.device === undefined ? {} : { device: window.where.device }),
    isHeld,
    ownsDevice,
  },
})

/** A held session: resumed from the first of its live windows in the jump order that is in tmux or zmx, its device its own; else refused, saying why. */
const fromLive = (name: string, windows: readonly FeedWindow[]): Reach => {
  const placed = windows
    .filter(window => window.jumpOrder !== undefined)
    .sort((a, b) => (a.jumpOrder ?? 0) - (b.jumpOrder ?? 0))
  const window = placed.find(isMultiplexed)

  if (window !== undefined) {
    return resumeOf(name, window, true, true)
  }

  return {
    answer: placed.length > 0
      ? `${name} can't be opened here: its terminal has no tmux or zmx.`
      : `${name} can't be opened here: its window didn't say where it is.`,
  }
}

/** A session no live window holds: resumed from the window it was last in; refused where none is left. */
const fromLast = (name: string, last: LastWindow | undefined): Reach =>
  last === undefined
    ? { answer: `${name} can't be carried on from here: no window of it is left.` }
    : resumeOf(name, last, false, last.ownsDevice)

/** What a pick of the session opens, decided from the feed alone. */
export const reachOf = (session: string, feed: Feed): Reach => {
  const name = nameOf(session, feed)
  const live = feed.windows.filter(window => window.session === session)

  if (name === undefined) {
    return { answer: NO_SUCH_SESSION }
  }

  return live.length > 0
    ? fromLive(name, live)
    : fromLast(name, feed.projects.flatMap(project => project.sessions).find(each => each.id === session)?.lastWindow)
}

/** Why the default would resume beside the session's Claude, in words naming it. */
const ALIVE = {
  seen: (name: string) => `${name}'s Claude is still running: set a resume command that can reach it, in SitRep's Settings.`,
  held: (name: string) => `${name}'s window has just stopped answering: try again in a moment.`,
}

/** The line a pick runs, the command filled for the window it resumes from, or why none runs, given what runs on that window's device. */
export const carriedOn = (resume: Resume, there: ClaudeThere, command: string): Checked<string> => {
  const { name, claude, dir, device, isHeld, ownsDevice } = resume
  const isSeen = there === 'running' && ownsDevice
  const alive = isSeen ? 'seen' : isHeld ? 'held' : undefined

  if (there === 'unknown') {
    return { ok: false, error: `Could not tell whether ${name}'s Claude is still running: the process table gave no answer.` }
  }

  if (there === 'stopped') {
    return { ok: false, error: `${name} is suspended in its window: type fg there to bring it back.` }
  }

  if (alive !== undefined && isDefault(command)) {
    return { ok: false, error: ALIVE[alive](name) }
  }

  return lineOf(command, { claude, ...(dir === undefined ? {} : { dir }), tty: isSeen ? (device ?? '') : '', isHeld }, name)
}
