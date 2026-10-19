/**
 * What the CLI does on screen, through Io: asks tmux which of its clients
 * show which of its tmux sessions, and `ps` which processes those clients
 * descend from, and brings a session's Ghostty window to the front, and
 * keeps it there: the terminal remembered for its device focused by its id,
 * else found by a knock and remembered. Nothing in tmux changes, and no
 * terminal is left reporting the knock's marker.
 */
import type { Where } from '../core'
import { frontmost, keepInFront } from './front'
import {
  ANSWER_SECONDS,
  directoryAfter,
  FIND_AND_FOCUS,
  FOCUS,
  isTimedOut,
  LIST,
  markerOf,
  parseListing,
  reportText,
  type Terminal,
} from './ghostty'
import type { Io } from './io'
import { look } from './look'
import { readRemembered, remember, type Remembered } from './remembered'
import {
  CLIENTS,
  devicesShowing,
  ghosttyClients,
  PANES,
  parseClients,
  parsePanes,
  parseProcesses,
  PS,
  socketsOf,
  type Processes,
  type Screen,
} from './screen'

/**
 * What a jump came to: the window brought forward; no Ghostty window
 * showing the session; none found, as programs asked gave no answer; or
 * devices showing it, where no Ghostty terminal answered the knock.
 */
export type Jumped =
  | { is: 'focused' }
  | { is: 'off screen' }
  | { is: 'unknown'; unanswered: readonly string[] }
  | { is: 'unanswered'; devices: readonly string[] }

const FOCUSED: Jumped = { is: 'focused' }
const OFF_SCREEN: Jumped = { is: 'off screen' }

/** How many times Ghostty's terminals are listed while they keep changing as they are read. */
const LIST_TRIES = 3

const NO_ANSWER = `Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.`

const UNSETTLED = "Ghostty's windows kept opening or closing as they were listed. Try again."

/**
 * A tmux server's panes and clients, and whether tmux answered. It answers
 * with an error, exiting non-zero, when no server runs on the socket: an
 * answer, of no server.
 */
const readServer = async (io: Io, socket: string) => {
  const [panes, clients] = await Promise.all(
    [PANES, CLIENTS].map(words => look(io, ['tmux', '-S', socket, ...words])),
  )

  if (panes === undefined || clients === undefined) {
    return { isAnswered: false }
  }

  return panes.exitCode === 0 && clients.exitCode === 0
    ? {
        isAnswered: true,
        server: { panes: parsePanes(panes.stdout), clients: parseClients(clients.stdout) },
      }
    : { isAnswered: true }
}

/**
 * What tells which devices show the windows: tmux asked twice for each
 * socket they run under, and `ps` once beside it, its snapshot used only
 * when a server has clients. Nothing that fails here fails the run: what
 * gives no answer shows nothing, and is named.
 */
const readScreen = async (io: Io, windows: readonly Where[]): Promise<Screen> => {
  const sockets = socketsOf(windows)
  const [read, snapshot] = await Promise.all([
    Promise.all(sockets.map(async socket => [socket, await readServer(io, socket)] as const)),
    sockets.length === 0 ? undefined : look(io, PS),
  ])
  const servers = new Map(read.map(([socket, { server }]) => [socket, server]))
  const hasClients = [...servers.values()].some(server => (server?.clients.length ?? 0) > 0)
  const isSnapshot = snapshot?.exitCode === 0
  const processes: Processes =
    hasClients && isSnapshot ? parseProcesses(snapshot.stdout) : new Map()

  return {
    servers,
    ghostty: ghosttyClients(servers, processes),
    unanswered: [
      ...(read.every(([, each]) => each.isAnswered) ? [] : ['tmux']),
      ...(hasClients && !isSnapshot ? ['ps'] : []),
    ],
  }
}

/** The ids of the sessions a Ghostty window shows, from the windows each is in; nothing is knocked on. */
export const sessionsOnScreen = async (io: Io, windows: ReadonlyMap<string, readonly Where[]>) => {
  const screen = await readScreen(io, [...windows.values()].flat())

  return new Set(
    [...windows].flatMap(([id, each]) => (devicesShowing(each, screen).length > 0 ? [id] : [])),
  )
}

/** What a Ghostty program prints. Ghostty not answering in time is thrown in plain words; any other failure, such as macOS refusing control of Ghostty, in osascript's. */
const ghostty = async (io: Io, program: string, ...args: string[]) => {
  const ran = await io.run(['osascript', '-e', program, ...args])

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

/** Lists the terminals once more, and puts back any now reporting the marker. */
const putBackMarked = async (
  io: Io,
  device: string,
  before: readonly Terminal[],
  marker: string,
) => {
  const marked = (await terminals(io)).find(each => each.directory === marker)

  if (marked !== undefined) {
    await putBack(io, device, before, marked.id)
  }
}

/**
 * Knocks on the device and focuses the Ghostty terminal that answers; its
 * id, or undefined when none did. A device that will not take the knock, a
 * closed one (EIO, ENXIO), answers nothing and has nothing to put back. A
 * terminal taking the marker is put back whatever comes of the find: one
 * that took it after the find gave up, and one that took it before the find
 * failed, as far as listing again can tell.
 */
const knock = async (io: Io, device: string, before: readonly Terminal[]) => {
  const marker = markerOf(io.random)
  const isWritten = await io.writeTo(device, reportText(marker)).then(
    () => true,
    () => false,
  )

  if (!isWritten) {
    return undefined
  }

  const found = await ghostty(io, FIND_AND_FOCUS, marker).catch(async (error: unknown) => {
    await bestEffort(putBackMarked(io, device, before, marker))

    throw error
  })
  const focused = found.trim()

  await bestEffort(
    focused === ''
      ? putBackMarked(io, device, before, marker)
      : putBack(io, device, before, focused),
  )

  return focused === '' ? undefined : focused
}

/**
 * Focuses the terminal remembered for a device, by its id; whether it did.
 * Ghostty not answering in time is thrown in plain words, as for every
 * question to it; no terminal having the id, or any other failure, is a
 * miss, for a knock to settle.
 */
const focusRemembered = async (io: Io, id: string) => {
  const ran = await io.run(['osascript', '-e', FOCUS, id]).catch(() => undefined)

  if (ran !== undefined && ran.exitCode !== 0 && isTimedOut(ran.stderr)) {
    throw new Error(NO_ANSWER)
  }

  return ran?.exitCode === 0 && ran.stdout.trim() === id
}

/** Ghostty's terminals, listed at the first call only: every knock of a jump goes by the one listing. */
const listingOnce = (io: Io) => {
  let listed: Promise<Terminal[]> | undefined

  return () => {
    listed = listed ?? terminals(io)

    return listed
  }
}

type Listing = ReturnType<typeof listingOnce>

/**
 * Focuses the terminal on a device: the one remembered for it, else the one
 * a knock finds, remembered from then on; undefined when none answers. Off
 * screen when Ghostty has no terminal to knock on.
 */
const focusOn = async (
  io: Io,
  device: string,
  remembered: string | undefined,
  listing: Listing,
): Promise<Jumped | undefined> => {
  if (remembered !== undefined && (await focusRemembered(io, remembered))) {
    return FOCUSED
  }

  const before = await listing()

  if (before.length === 0) {
    return OFF_SCREEN
  }

  const found = await knock(io, device, before)

  if (found === undefined) {
    return undefined
  }

  await bestEffort(remember(io, device, found))

  return FOCUSED
}

/**
 * Focuses the terminal on the first of the devices that has one. Ghostty's
 * terminals are listed only once a device needs a knock, so a jump that
 * ends without one asks Ghostty nothing it need not.
 */
const focusFirst = async (
  io: Io,
  devices: readonly string[],
  remembered: Remembered,
): Promise<Jumped> => {
  const listing = listingOnce(io)

  for (const device of devices) {
    const jumped = await focusOn(io, device, remembered.get(device), listing)

    if (jumped !== undefined) {
      return jumped
    }
  }

  return { is: 'unanswered', devices }
}

/**
 * Brings the first of the windows a Ghostty window shows to the front, on
 * whatever Space it is, and keeps it there. Which app is in front is read
 * beside tmux and `ps`, which outlast it, and settled before any focus, so
 * it is never Ghostty brought forward by the jump itself.
 */
export const jump = async (io: Io, windows: readonly Where[]): Promise<Jumped> => {
  const front = frontmost(io)
  const [screen, remembered, before] = await Promise.all([
    readScreen(io, windows),
    readRemembered(io),
    front(),
  ])
  const devices = devicesShowing(windows, screen)

  if (devices.length === 0) {
    return screen.unanswered.length > 0
      ? { is: 'unknown', unanswered: screen.unanswered }
      : OFF_SCREEN
  }

  const jumped = await focusFirst(io, devices, remembered)

  if (jumped.is === 'focused') {
    await keepInFront(io, front, before)
  }

  return jumped
}
