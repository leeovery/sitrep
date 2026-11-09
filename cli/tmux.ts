/**
 * tmux's multiplexer adapter, under every driver: which tmux clients show a
 * pane, and selecting the pane's tmux window so that one does.
 *
 * A client's current tmux window, not its tmux session, is what it shows:
 * a tmux session of several windows shows one at a time, and those grouped or
 * sharing a linked window each show their own current one (live). So a pane
 * no client shows is shown by selecting its window in a tmux session that
 * holds it and has a client attached: `select-window -t $3:@45`, by the
 * session's id and the window's, so a window linked into several sessions,
 * or one of a group's, is made current in that session alone, whose clients
 * then show it. Ids, not names: tmux matches a name by its start or as a
 * pattern, and a session's id never changes.
 *
 * Selecting happens only in a jump, never as the screen is read.
 */
import { isDevice, type Where } from '../core'
import type { Io } from './io'
import { look } from './look'
import type { Multiplexer, Place, Reading } from './multiplexer'
import { seatOf, type Processes } from './processes'

/** A tmux client: the device it is on, empty for a control-mode client over pipes, its process, the tmux window it shows, and the tmux session it is attached to, by their ids. */
export type Client = { device: string; pid: number; window: string; session: string }

/** A pane: its tmux window, and the tmux sessions holding that window, by their ids, and the device it is on. */
export type Pane = { window: string; sessions: readonly string[]; device: string }

/** What a tmux server holds: each pane, by its id, and its clients. */
export type Server = { panes: ReadonlyMap<string, Pane>; clients: readonly Client[] }

/** tmux's servers by socket; undefined for a socket no server runs on. */
export type Servers = ReadonlyMap<string, Server | undefined>

/** A server's panes and clients, and whether tmux answered. */
export type ServerRead = { isAnswered: boolean; server?: Server }

/** A select: the tmux window to make current in a tmux session, on the server at the socket. */
export type Select = { socket: string; session: string; window: string }

/** A client that shows a pane, or will once tmux makes the select given. */
export type Showing<C extends Client> = { client: C; select?: Select }

/**
 * How a select went: done; tmux not answering in time, or not starting
 * (`said` undefined); or refusing, in its words.
 */
export type Selected = { isDone: true } | { isDone: false; said?: string }

/**
 * tmux's words for every pane on a server with its tmux window, tmux
 * session and device, a pane once for each tmux session its window is in;
 * and for every client with the tmux window it shows and the tmux session it
 * is attached to.
 */
export const PANES = [
  'list-panes',
  '-a',
  '-F',
  '#{pane_id}\t#{window_id}\t#{session_id}\t#{pane_tty}',
]
export const CLIENTS = [
  'list-clients',
  '-F',
  '#{client_tty}\t#{client_pid}\t#{window_id}\t#{session_id}',
]

/**
 * tmux on a server's socket, told its client takes UTF-8 (`-u`). Without it,
 * run with no UTF-8 locale and no `$TMUX`, as SitRep runs the CLI, a tmux 3.8
 * server writes each tab of a `-F` format as `_`, and every line reads as no
 * pane or client (proven live, 22 October 2026).
 */
export const tmuxOn = (socket: string) => ['tmux', '-u', '-S', socket]

/** tmux's words making a select. */
export const selectWords = ({ socket, session, window }: Select) => [
  ...tmuxOn(socket),
  'select-window',
  '-t',
  `${session}:${window}`,
]

/** Each line's fields with at least `count` of them, the last taking any tab left. */
const rows = (output: string, count: number) =>
  output.split('\n').flatMap(line => {
    const fields = line.split('\t')

    return fields.length < count
      ? []
      : [[...fields.slice(0, count - 1), fields.slice(count - 1).join('\t')]]
  })

/** `list-panes -a` as each pane, the tmux sessions its window is in gathered from its lines. */
export const parsePanes = (output: string): ReadonlyMap<string, Pane> => {
  const panes = new Map<string, { window: string; sessions: string[]; device: string }>()

  for (const [pane = '', window = '', session = '', device = ''] of rows(output, 4)) {
    const held = panes.get(pane) ?? { window, sessions: [], device }

    if (!held.sessions.includes(session)) {
      held.sessions.push(session)
    }

    panes.set(pane, held)
  }

  return panes
}

/** `list-clients` as its clients. */
export const parseClients = (output: string): Client[] =>
  rows(output, 4).map(([device = '', pid = '', window = '', session = '']) => ({
    device,
    pid: Number.parseInt(pid, 10),
    window,
    session,
  }))

/**
 * A tmux server's panes and clients, and whether tmux answered. It answers
 * with an error, exiting non-zero, when no server runs on the socket: an
 * answer, of no server.
 */
export const readServer = async (io: Io, socket: string): Promise<ServerRead> => {
  const [panes, clients] = await Promise.all(
    [PANES, CLIENTS].map(words => look(io, [...tmuxOn(socket), ...words])),
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
 * Of the clients given, those that show the pane: those whose current window
 * is its window; else, when none is, those attached to a tmux session holding
 * its window, each with the select that makes it show the pane. None for a
 * pane the server does not have.
 */
export const showingPane = <C extends Client>(
  socket: string,
  server: Server,
  pane: string,
  clients: readonly C[],
): Showing<C>[] => {
  const at = server.panes.get(pane)

  if (at === undefined) {
    return []
  }

  const showing = clients.filter(client => client.window === at.window)

  return showing.length > 0
    ? showing.map(client => ({ client }))
    : clients
        .filter(client => at.sessions.includes(client.session))
        .map(client => ({
          client,
          select: { socket, session: client.session, window: at.window },
        }))
}

/** The tmux sockets the windows run under, each once. */
export const socketsOf = (windows: readonly Where[]) => [
  ...new Set(windows.flatMap(where => (where.tmux === undefined ? [] : [where.tmux.socket]))),
]

/**
 * Where a window in tmux can be brought forward: the clients a jump can
 * reach that show its pane, or could be made to, each seated by the
 * snapshot, on the device of its terminal's own pty, else on its own. A
 * client a jump cannot reach, Lee's phone, neither shows the pane nor stops
 * a select making another client show it.
 */
const placesIn = (where: Where, servers: Servers, processes: Processes): Place[] => {
  const server = where.tmux === undefined ? undefined : servers.get(where.tmux.socket)

  if (where.tmux === undefined || server === undefined) {
    return []
  }

  const seated = server.clients.flatMap(client => {
    const seat = seatOf(processes, client.pid, client.device)

    return seat === undefined ? [] : [{ ...client, seat }]
  })

  return showingPane(where.tmux.socket, server, where.tmux.pane, seated).map(
    ({ client, select }) => ({ ...client.seat, select }),
  )
}

const isInTmux = (where: Where) => where.tmux !== undefined

/**
 * Whether the window's device is its tmux pane's: undefined where that
 * cannot be told, the pane gone, its server silent, or the window saying no
 * device.
 */
const isOnPane = (where: Where, servers: Servers) => {
  const { tmux } = where
  const pane = tmux === undefined ? undefined : servers.get(tmux.socket)?.panes.get(tmux.pane)

  return pane === undefined || !isDevice(pane.device) || where.device === undefined
    ? undefined
    : pane.device === where.device
}

/** What tmux said of its servers, by socket, and the sockets it gave no answer for, as a reading of the screen. */
export const tmuxReading = (servers: Servers, unansweredSockets: ReadonlySet<string>): Reading => ({
  isIn: isInTmux,
  isOnItsPty: where => isOnPane(where, servers),
  places: (where, processes) => placesIn(where, servers, processes),
  unanswered: where =>
    where.tmux !== undefined && unansweredSockets.has(where.tmux.socket) ? ['tmux'] : [],
  needsProcesses: where =>
    where.tmux !== undefined && (servers.get(where.tmux.socket)?.clients.length ?? 0) > 0,
})

/**
 * tmux, asked twice for each socket the windows run under; a server with
 * clients needs `ps` to tell which apps they are in. tmux not answering, or
 * not on PATH, makes its sockets' windows unknown, never off screen.
 */
export const TMUX: Multiplexer = {
  isIn: isInTmux,
  read: async (io, windows) => {
    const read = await Promise.all(
      socketsOf(windows).map(async socket => [socket, await readServer(io, socket)] as const),
    )

    return tmuxReading(
      new Map(read.map(([socket, { server }]) => [socket, server])),
      new Set(read.flatMap(([socket, each]) => (each.isAnswered ? [] : [socket]))),
    )
  },
}

/** Makes the select, within the time tmux's reads have. */
export const select = async (io: Io, wanted: Select): Promise<Selected> => {
  const ran = await look(io, selectWords(wanted))

  if (ran === undefined) {
    return { isDone: false }
  }

  return ran.exitCode === 0 ? { isDone: true } : { isDone: false, said: ran.stderr.trim() }
}
