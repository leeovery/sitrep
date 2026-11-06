/**
 * Ghostty's driver. Since Ghostty 1.4 its AppleScript gives each terminal
 * the device it is on (`tty`, `/dev/ttys041`), so the terminal on a device
 * is asked for by it and focused, in one program, and Ghostty is kept in
 * front. An older Ghostty, which does not know the word, is refused in plain
 * words.
 *
 * A fixed program, run by osascript with its values as arguments and never
 * spliced into the text.
 */
import { Unanswered, type Brought, type Driver, type FrontAtStart } from './driver'
import { keepInFront } from './front'
import { TimedOut, type Io } from './io'

/** Telling Ghostty anything launches it, so the program first checks it is running. */
const UNLESS_RUNNING = 'if application "Ghostty" is not running then return ""'

/**
 * How long each question to Ghostty, each Apple Event the program sends, may
 * wait: `with timeout` holds for each event, not for the program. With the
 * screen locked, Ghostty answers nothing about its terminals, and
 * AppleScript's own limit is two minutes.
 */
export const ANSWER_SECONDS = 5

/**
 * How long the program may run in all, from osascript's start to its end:
 * long enough for one question to go unanswered, so a Ghostty that does not
 * answer is told in its own words, with time over for osascript to start,
 * find Ghostty and read its terms, which under heavy load is slow and which
 * no `with timeout` covers.
 */
export const PROGRAM_MS = 8_000

/** The first Ghostty whose terminals say their device (`tty`). */
export const LEAST_VERSION = '1.4'

/** What the program prints once it has focused the terminal on the device. */
export const FOCUSED = 'focused'

/**
 * Given a device, focuses the Ghostty terminal on it and prints FOCUSED;
 * prints nothing when no terminal is on it, or Ghostty is not running.
 */
export const FOCUS = [
  'on run argv',
  'set wanted to item 1 of argv',
  UNLESS_RUNNING,
  `with timeout of ${ANSWER_SECONDS} seconds`,
  'tell application "Ghostty"',
  'set found to (terminals whose tty is wanted)',
  'if found is {} then return ""',
  'focus item 1 of found',
  'end tell',
  'end timeout',
  `return "${FOCUSED}"`,
  'end run',
].join('\n')

/** Whether osascript failed because Ghostty did not answer in time: AppleScript's error -1712. */
export const isTimedOut = (stderr: string) => stderr.includes('(-1712)')

/**
 * Whether osascript failed because this Ghostty does not know the program's
 * terms, as one before 1.4 does not. One whose dictionary has no `tty` reads
 * the word as a variable, which compiles and fails as the lookup runs (-2753:
 * checked with this program, a name Ghostty 1.4 does not know in place of
 * `tty`); one with no dictionary at all, as before Ghostty could be
 * scripted, fails to compile at `focus` (-2741: checked by compiling this
 * program against Calculator, which has none). Both 6 November 2026.
 */
export const isTooOld = (stderr: string) => /\((-2753|-2741)\)/.test(stderr)

const NO_ANSWER = `Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.`

const TOO_SLOW = `Ghostty did not answer within ${PROGRAM_MS / 1_000} seconds: most likely the Mac is too busy.`

const TOO_OLD = `This Ghostty cannot say which of its windows is on a device, so sitrep cannot jump to one: update Ghostty to ${LEAST_VERSION} or later.`

/** What a failed run of the program says, in plain words where it can: Ghostty not answering in time, or too old; else in osascript's, as for macOS refusing control of Ghostty. */
const failure = (stderr: string) => {
  if (isTimedOut(stderr)) {
    return NO_ANSWER
  }

  return isTooOld(stderr) ? TOO_OLD : `osascript: ${stderr.trim()}`
}

/** Focuses the terminal on a device: forward once focused, undefined when none is on it. Killed at its limit is thrown as unanswered, any other failure in `failure`'s words. */
const focusOn = async (io: Io, device: string): Promise<Brought> => {
  const ran = await io
    .run(['osascript', '-e', FOCUS, device], PROGRAM_MS)
    .catch((error: unknown) => {
      throw error instanceof TimedOut ? new Unanswered(TOO_SLOW) : error
    })

  if (ran.exitCode !== 0) {
    throw new Error(failure(ran.stderr))
  }

  return ran.stdout.trim() === FOCUSED ? 'forward' : undefined
}

/** Brings forward the terminal on a device, and keeps Ghostty in front; a window whose device is not known has none to ask for. */
const start = (io: Io, front: FrontAtStart) => async (device: string | undefined) => {
  if (device === undefined) {
    return undefined
  }

  const brought = await focusOn(io, device)

  if (brought === 'forward') {
    await keepInFront(io, front.look, front.before)
  }

  return brought
}

/** Ghostty's driver: it brings a window forward, and declares nothing more yet. */
export const GHOSTTY: Driver = {
  name: 'Ghostty',
  program: 'ghostty',
  executable: 'ghostty',
  can: [],
  start,
}
