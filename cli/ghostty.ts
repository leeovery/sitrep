/**
 * Ghostty's driver. Its AppleScript gives each terminal an id and a working
 * directory, but no device, so the terminal on a device is found by a knock:
 * a working directory report (OSC 7) naming a marker, written to the device,
 * makes its terminal report the marker. A terminal found once is remembered
 * for its device and focused by its id after, and Ghostty is kept in front.
 * No terminal is left reporting the knock's marker.
 *
 * Fixed programs, run by osascript with their values as arguments and never
 * spliced into the text.
 */
import type { Random } from '../core'
import { Unanswered, type Brought, type Driver, type FrontAtStart } from './driver'
import { keepInFront } from './front'
import { TimedOut, type Io, type Ran } from './io'
import { readRemembered, remember, type Remembered } from './remembered'

/** A Ghostty terminal: its id, and the working directory it reports, empty when it reports none. */
export type Terminal = { id: string; directory: string }

/** Telling Ghostty anything launches it, so each program first checks it is running. */
const UNLESS_RUNNING = 'if application "Ghostty" is not running then return ""'

/**
 * How long each question to Ghostty, each Apple Event a program sends, may
 * wait: `with timeout` holds for each event, not for the program. With the
 * screen locked, Ghostty answers nothing about its terminals, and
 * AppleScript's own limit is two minutes.
 */
export const ANSWER_SECONDS = 5

/**
 * How long a Ghostty program may run in all, from osascript's start to its
 * end: long enough for one question to go unanswered, so a Ghostty that
 * does not answer is told in its own words, with time over for osascript to
 * start, find Ghostty and read its terms, which under heavy load is slow and
 * which no `with timeout` covers. Until 4 November 2026 a program had no
 * limit of its own, only each question in it, so its start, and the sum of
 * a find's twenty tries or a listing's three questions each answered just
 * in time, could hold a jump for minutes.
 */
export const PROGRAM_MS = 8_000

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

/** How many times Ghostty's terminals are listed while they keep changing as they are read. */
const LIST_TRIES = 3

const NO_ANSWER = `Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.`

const TOO_SLOW = `Ghostty did not answer within ${PROGRAM_MS / 1_000} seconds: most likely the Mac is too busy.`

const UNSETTLED = "Ghostty's windows kept opening or closing as they were listed. Try again."

/** A Ghostty program run within its limit: one killed at it is thrown in plain words, and any other failure to run as `otherwise` makes of it. */
const runGhostty = <T>(
  io: Io,
  words: readonly string[],
  otherwise: (error: unknown) => T,
): Promise<Ran | T> =>
  io.run(['osascript', '-e', ...words], PROGRAM_MS).catch((error: unknown) => {
    if (error instanceof TimedOut) {
      throw new Unanswered(TOO_SLOW)
    }

    return otherwise(error)
  })

const rethrow = (error: unknown): never => {
  throw error
}

/** What a Ghostty program prints. Ghostty not answering in time is thrown in plain words; any other failure, such as macOS refusing control of Ghostty, in osascript's. */
const ghostty = async (io: Io, program: string, ...args: string[]) => {
  const ran = await runGhostty(io, [program, ...args], rethrow)

  if (ran.exitCode !== 0) {
    throw new Error(isTimedOut(ran.stderr) ? NO_ANSWER : `osascript: ${ran.stderr.trim()}`)
  }

  return ran.stdout
}

/** Ghostty's terminals, listed again while they change as they are read, a few times at most. */
const terminals = async (io: Io) => {
  for (let tries = 0; tries < LIST_TRIES; tries++) {
    const listed = parseListing(await ghostty(io, LIST))

    if (listed !== undefined) {
      return listed
    }
  }

  throw new Error(UNSETTLED)
}

/** Writes back the directory a terminal reported before the knock. */
const putBack = (io: Io, device: string, before: readonly Terminal[], id: string) =>
  io.writeTo(
    device,
    reportText(directoryAfter(before.find(each => each.id === id)?.directory, io.env.HOME ?? '/')),
  )

/** Waits on what must not stop the jump, whatever comes of it. */
const bestEffort = (session: Promise<unknown>) =>
  session.then(
    () => undefined,
    () => undefined,
  )

/**
 * Writes back, straight to the device, the directory its terminal goes back
 * to when which terminal took the marker is not known: $HOME, as neither a
 * window's heartbeat nor the board says what directory its terminal
 * reports. Only the device's own terminal takes it, and Ghostty is asked
 * nothing, so it lands however busy Ghostty is.
 */
const putBackHome = (io: Io, device: string) =>
  io.writeTo(device, reportText(directoryAfter(undefined, io.env.HOME ?? '/')))

/** Whether a write landed. */
const landed = (write: Promise<unknown>) =>
  write.then(
    () => true,
    () => false,
  )

/**
 * Knocks on the device and focuses the Ghostty terminal that answers; its
 * id, or undefined when none did. A device that will not take the knock, a
 * closed one (EIO, ENXIO), answers nothing and has nothing to put back.
 *
 * A terminal taking the marker is put back whatever comes of the find: the
 * one found, to the directory it reported before. A find that gave up lists
 * the terminals again: one on the marker goes back to the directory it
 * reported; with none on it, or the listing failing, $HOME goes straight to
 * the device, as under load Ghostty can take the marker after the listing,
 * and the device keeps the order of its writes. A find that fails puts
 * $HOME straight to the device, asking Ghostty nothing more.
 *
 * Told to end (SIGTERM) from the moment the marker is written, the run puts
 * $HOME straight to the device before it ends, once the marker's write has
 * landed, unless the put-back the knock chose is under way and lands.
 */
const knock = async (io: Io, device: string, before: readonly Terminal[]) => {
  const marker = markerOf(io.random)
  const writing = landed(io.writeTo(device, reportText(marker)))
  let puttingBack: Promise<boolean> | undefined
  const putting = (write: Promise<void>) => {
    puttingBack = landed(write)

    return puttingBack
  }
  const letGo = io.atTerm(async () => {
    if ((await writing) && !(await puttingBack)) {
      await bestEffort(putBackHome(io, device))
    }
  })

  try {
    if (!(await writing)) {
      return undefined
    }

    const found = await ghostty(io, FIND_AND_FOCUS, marker).catch(async (error: unknown) => {
      await putting(putBackHome(io, device))

      throw error
    })
    const focused = found.trim()

    if (focused === '') {
      await putBackAfterGivingUp(io, device, before, marker, putting)

      return undefined
    }

    await putting(putBack(io, device, before, focused))

    return focused
  } finally {
    letGo()
  }
}

/**
 * After a find that gave up, lists the terminals once more: one on the
 * marker is put back to the directory it reported, else $HOME goes straight
 * to the device. A listing killed at its limit is thrown once the put-back
 * is made, so the jump ends unanswered; any other failure of it is the
 * put-back's alone.
 */
const putBackAfterGivingUp = async (
  io: Io,
  device: string,
  before: readonly Terminal[],
  marker: string,
  putting: (write: Promise<void>) => Promise<boolean>,
) => {
  const listed = await terminals(io).then(
    listing => ({ marked: listing.find(each => each.directory === marker) }),
    (error: unknown) => ({ marked: undefined, error }),
  )

  await putting(
    listed.marked === undefined
      ? putBackHome(io, device)
      : putBack(io, device, before, listed.marked.id),
  )

  if ('error' in listed && listed.error instanceof Unanswered) {
    throw listed.error
  }
}

/**
 * Focuses the terminal remembered for a device, by its id; whether it did.
 * Ghostty not answering in time, or the program outliving its limit, is
 * thrown in plain words, as for every question to it; no terminal having
 * the id, or any other failure, is a miss, for a knock to settle.
 */
const focusRemembered = async (io: Io, id: string) => {
  const ran = await runGhostty(io, [FOCUS, id], () => undefined)

  if (ran !== undefined && ran.exitCode !== 0 && isTimedOut(ran.stderr)) {
    throw new Error(NO_ANSWER)
  }

  return ran?.exitCode === 0 && ran.stdout.trim() === id
}

/** What is asked at the first call only, and shared by every call after. */
const once = <T>(ask: () => Promise<T>) => {
  let asked: Promise<T> | undefined

  return () => {
    asked = asked ?? ask()

    return asked
  }
}

/**
 * Focuses the terminal on a device: the one remembered for it, else the one
 * a knock finds, remembered from then on; undefined when none answers. None
 * open when Ghostty has no terminal to knock on.
 */
const focusOn = async (
  io: Io,
  device: string,
  remembered: string | undefined,
  listing: () => Promise<Terminal[]>,
): Promise<Brought> => {
  if (remembered !== undefined && (await focusRemembered(io, remembered))) {
    return 'forward'
  }

  const before = await listing()

  if (before.length === 0) {
    return 'none open'
  }

  const found = await knock(io, device, before)

  if (found === undefined) {
    return undefined
  }

  await bestEffort(remember(io, device, found))

  return 'forward'
}

/**
 * Brings forward the terminal on a device, and keeps Ghostty in front; a
 * window whose device is not known has none to knock on. The remembered terminals are read, and Ghostty's terminals listed, at most once
 * a jump: the listing only once a device needs a knock, so a jump that ends
 * without one asks Ghostty nothing it need not.
 */
const start = (io: Io, front: FrontAtStart) => {
  const remembered = once<Remembered>(() => readRemembered(io))
  const listing = once(() => terminals(io))

  return async (device: string | undefined) => {
    if (device === undefined) {
      return undefined
    }

    const brought = await focusOn(io, device, (await remembered()).get(device), listing)

    if (brought === 'forward') {
      await keepInFront(io, front.look, front.before)
    }

    return brought
  }
}

/** Ghostty's driver: it brings a window forward, and declares nothing more yet. */
export const GHOSTTY: Driver = {
  name: 'Ghostty',
  program: 'ghostty',
  executable: 'ghostty',
  can: [],
  start,
}
