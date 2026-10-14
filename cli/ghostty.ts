/**
 * Ghostty, as the jump drives it. Its AppleScript gives each terminal an id
 * and a working directory, but no device, so the terminal on a device is
 * found by a knock: a working directory report (OSC 7) naming a marker,
 * written to the device, makes its terminal report the marker. A terminal
 * found once is focused by its id after.
 *
 * Fixed programs, run by osascript with their values as arguments and never
 * spliced into the text.
 */
import type { Random } from '../core'

/** A Ghostty terminal: its id, and the working directory it reports, empty when it reports none. */
export type Terminal = { id: string; directory: string }

/** Telling Ghostty anything launches it, so each program first checks it is running. */
const UNLESS_RUNNING = 'if application "Ghostty" is not running then return ""'

/**
 * How long each question to Ghostty may wait. With the screen locked,
 * Ghostty answers nothing about its terminals, and AppleScript's own limit
 * is two minutes.
 */
export const ANSWER_SECONDS = 5

/** A program's lines that ask Ghostty, within the time it may take to answer each. */
const askGhostty = (...lines: string[]) => [
  `with timeout of ${ANSWER_SECONDS} seconds`,
  'tell application "Ghostty"',
  ...lines,
  'end tell',
  'end timeout',
]

/** Whether osascript failed because Ghostty did not answer in time: AppleScript's error -1712. */
export const isTimedOut = (stderr: string) => stderr.includes('(-1712)')

/**
 * Every terminal, read in bulk: the ids, then the working directories, then
 * the ids again. It prints the second ids on a line of their own, a tab
 * between, then `id<TAB>working directory` a line each, paired from the
 * first ids, or no such line when the counts differ. A terminal opening or
 * closing between the reads pairs the rest wrongly; the ids read again let
 * the reader tell. Nothing while Ghostty is not running.
 */
export const LIST = [
  'on run argv',
  UNLESS_RUNNING,
  ...askGhostty(
    'set ids to id of terminals',
    'set places to working directory of terminals',
    'set idsAgain to id of terminals',
  ),
  'set found to {}',
  'if (count of places) = (count of ids) then',
  'repeat with i from 1 to count of ids',
  'set place to item i of places',
  'if place is missing value then set place to ""',
  'set end of found to (item i of ids) & tab & place',
  'end repeat',
  'end if',
  "set AppleScript's text item delimiters to tab",
  'set header to idsAgain as text',
  "set AppleScript's text item delimiters to linefeed",
  'return header & linefeed & (found as text)',
  'end run',
].join('\n')

/** Given a marker, waits about a second for a terminal to report it as its working directory, then focuses that terminal and prints its id; else prints nothing. */
export const FIND_AND_FOCUS = [
  'on run argv',
  'set marker to item 1 of argv',
  UNLESS_RUNNING,
  ...askGhostty(
    'repeat 20 times',
    'set found to (terminals whose working directory is marker)',
    'if found is not {} then',
    'set chosen to item 1 of found',
    'focus chosen',
    'return id of chosen',
    'end if',
    'delay 0.05',
    'end repeat',
  ),
  'return ""',
  'end run',
].join('\n')

/**
 * Given a terminal's id, focuses that terminal and prints its id; prints
 * nothing when no terminal has it. Looked up before it is focused, so a
 * terminal gone is never taken for one focused, whatever `focus` makes of
 * it; the lookup adds about 15ms to the focus (14 October 2026).
 */
export const FOCUS = [
  'on run argv',
  'set wanted to item 1 of argv',
  UNLESS_RUNNING,
  ...askGhostty(
    'set found to (terminals whose id is wanted)',
    'if found is not {} then',
    'focus item 1 of found',
    'return wanted',
    'end if',
  ),
  'return ""',
  'end run',
].join('\n')

/** Brings Ghostty to the front, its focused terminal as it is. */
export const ACTIVATE = ['on run', UNLESS_RUNNING, ...askGhostty('activate'), 'end run'].join('\n')

const MARKER_BYTES = 8

/** The folder every knock's marker is in. */
export const MARKER_FOLDER = '/sitrep-knock'

/** A fresh marker for one knock: a path no terminal is in. */
export const markerOf = (random: Random) =>
  `${MARKER_FOLDER}/${Array.from(random(MARKER_BYTES), byte => byte.toString(16).padStart(2, '0')).join('')}`

const isMarker = (directory: string) => directory.startsWith(`${MARKER_FOLDER}/`)

/**
 * The directory a terminal goes back to after a knock: the one it reported
 * before, else `home` when it reported none, or a marker, which another
 * jump running at once, or one cut short, left it on.
 */
export const directoryAfter = (before: string | undefined, home: string) =>
  before === undefined || before === '' || isMarker(before) ? home : before

/** Ghostty percent-decodes a report's path, so all but its `/`s is encoded, or a real `%` would come back as something else. */
const encoded = (path: string) => path.split('/').map(encodeURIComponent).join('/')

/** A working directory report naming `path`. Its host is `localhost`: Ghostty ignores a report with none. */
export const reportText = (path: string) => `\x1b]7;file://localhost${encoded(path)}\x07`

const isSame = (a: readonly string[], b: readonly string[]) =>
  a.length === b.length && a.every((each, i) => each === b[i])

/**
 * LIST's output as its terminals; undefined when they changed while it
 * read them, its pairs not matching the ids it read last. Not trimmed: the
 * last line may end in a tab, for a terminal reporting no directory.
 */
export const parseListing = (output: string): Terminal[] | undefined => {
  const [header = '', ...lines] = output.split('\n')
  const terminals = lines.flatMap(line => {
    const tab = line.indexOf('\t')

    return tab === -1 ? [] : [{ id: line.slice(0, tab), directory: line.slice(tab + 1) }]
  })
  const idsAgain = header === '' ? [] : header.split('\t')

  return isSame(
    idsAgain,
    terminals.map(each => each.id),
  )
    ? terminals
    : undefined
}
