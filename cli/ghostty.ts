/**
 * Ghostty's driver. Since Ghostty 1.4 its AppleScript gives each terminal
 * the device it is on (`tty`, `/dev/ttys041`), so the terminal on a device
 * is asked for by it and focused, in one program, and Ghostty is kept in
 * front. An older Ghostty, which cannot tell, is refused in plain words.
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

/**
 * Given a device, focuses the Ghostty terminal on it and prints the device;
 * prints nothing when no terminal is on it, or Ghostty is not running; and
 * prints Ghostty's version for one too old to say a terminal's device.
 * `tty` is not in an older Ghostty's terms, so there it reads as a variable,
 * which compiles, and the version is checked before it is reached (checked
 * on this Mac with a name Ghostty 1.4 does not know, 6 November 2026).
 */
export const FOCUS = [
  'on run argv',
  'set wanted to item 1 of argv',
  UNLESS_RUNNING,
  `with timeout of ${ANSWER_SECONDS} seconds`,
  'tell application "Ghostty"',
  'considering numeric strings',
  `if version < "${LEAST_VERSION}" then return version`,
  'end considering',
  'set found to (terminals whose tty is wanted)',
  'if found is {} then return ""',
  'focus item 1 of found',
  'end tell',
  'end timeout',
  'return wanted',
  'end run',
].join('\n')

/** Whether osascript failed because Ghostty did not answer in time: AppleScript's error -1712. */
export const isTimedOut = (stderr: string) => stderr.includes('(-1712)')

const NO_ANSWER = `Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.`

const TOO_SLOW = `Ghostty did not answer within ${PROGRAM_MS / 1_000} seconds: most likely the Mac is too busy.`

const tooOld = (version: string) =>
  `Ghostty ${version} cannot say which of its windows is on a device, so sitrep cannot jump to one: update Ghostty to ${LEAST_VERSION} or later.`

/**
 * What the program prints. Killed at its limit, or Ghostty not answering in
 * time, is thrown in plain words; any other failure, such as macOS refusing
 * control of Ghostty, in osascript's.
 */
const ghostty = async (io: Io, device: string) => {
  const ran = await io
    .run(['osascript', '-e', FOCUS, device], PROGRAM_MS)
    .catch((error: unknown) => {
      throw error instanceof TimedOut ? new Unanswered(TOO_SLOW) : error
    })

  if (ran.exitCode !== 0) {
    throw new Error(isTimedOut(ran.stderr) ? NO_ANSWER : `osascript: ${ran.stderr.trim()}`)
  }

  return ran.stdout.trim()
}

/** Focuses the terminal on a device: forward once focused, undefined when none is on it. */
const focusOn = async (io: Io, device: string): Promise<Brought> => {
  const printed = await ghostty(io, device)

  switch (printed) {
    case device:
      return 'forward'
    case '':
      return undefined
    default:
      throw new Error(tooOld(printed))
  }
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
