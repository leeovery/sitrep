/**
 * What the CLI does on screen, through Io: asks tmux which of its clients
 * show which sessions, and `ps` which processes those clients descend from,
 * and brings a piece of work's Ghostty window to the front, found by a
 * knock. Nothing in tmux changes, and no terminal is left reporting the
 * knock's marker.
 */
import type { Where } from '../core'
import {
  ANSWER_SECONDS,
  directoryAfter,
  FIND_AND_FOCUS,
  isTimedOut,
  LIST,
  markerOf,
  parseListing,
  reportText,
  type Terminal,
} from './ghostty'
import type { Io } from './io'
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
 * showing the work; none found, as programs asked gave no answer; or
 * devices showing it, where no Ghostty terminal answered the knock.
 */
export type Jumped =
  | { is: 'focused' }
  | { is: 'off screen' }
  | { is: 'unknown'; unanswered: readonly string[] }
  | { is: 'unanswered'; devices: readonly string[] }

const FOCUSED: Jumped = { is: 'focused' }
const OFF_SCREEN: Jumped = { is: 'off screen' }

/** How long tmux and `ps` may take to answer, so a listing never hangs on them. */
export const LOOK_MS = 2_000

/** How many times Ghostty's terminals are listed while they keep changing as they are read. */
const LIST_TRIES = 3

const NO_ANSWER = `Ghostty did not answer within ${ANSWER_SECONDS} seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty.`

const UNSETTLED = "Ghostty's windows kept opening or closing as they were listed. Try again."

/** How a program ran; undefined when it could not start, or did not end in time. */
const look = (io: Io, command: readonly string[]) => io.run(command, LOOK_MS).catch(() => undefined)

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

/** The ids of the works a Ghostty window shows, from the windows each is in; nothing is knocked on. */
export const worksOnScreen = async (io: Io, windows: ReadonlyMap<string, readonly Where[]>) => {
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
const bestEffort = (work: Promise<unknown>) =>
  work.then(
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
 * Knocks on the device and focuses the Ghostty terminal that answers;
 * whether one did. A device that will not take the knock, a closed one
 * (EIO, ENXIO), answers nothing and has nothing to put back. A terminal
 * taking the marker is put back whatever comes of the find: one that took
 * it after the find gave up, and one that took it before the find failed,
 * as far as listing again can tell.
 */
const knock = async (io: Io, device: string, before: readonly Terminal[]) => {
  const marker = markerOf(io.random)
  const isWritten = await io.writeTo(device, reportText(marker)).then(
    () => true,
    () => false,
  )

  if (!isWritten) {
    return false
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

  return focused !== ''
}

/**
 * Brings the first of the windows a Ghostty window shows to the front, on
 * whatever Space it is: each device showing them knocked on in turn, until
 * a terminal answers.
 */
export const jump = async (io: Io, windows: readonly Where[]): Promise<Jumped> => {
  const screen = await readScreen(io, windows)
  const devices = devicesShowing(windows, screen)

  if (devices.length === 0) {
    return screen.unanswered.length > 0
      ? { is: 'unknown', unanswered: screen.unanswered }
      : OFF_SCREEN
  }

  const before = await terminals(io)

  if (before.length === 0) {
    return OFF_SCREEN
  }

  for (const device of devices) {
    if (await knock(io, device, before)) {
      return FOCUSED
    }
  }

  return { is: 'unanswered', devices }
}
