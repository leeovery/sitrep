/**
 * Which terminal devices show a session, from where its windows are,
 * what tmux says of its servers, and which processes descend from which. A
 * window in tmux shows in every Ghostty window of this Mac whose tmux client
 * is on the tmux window holding its pane; one outside tmux, in its own, when
 * that is Ghostty's.
 *
 * A client's current tmux window, not its tmux session, is what it shows:
 * a tmux session of several windows shows one at a time, and those grouped or
 * sharing a linked window each show their own current one (live).
 *
 * A tmux client is a Ghostty window's when Ghostty's own program is among
 * its ancestors (`tmux < zsh < login < ghostty`, live). Its terminal's name
 * cannot tell: Lee's phone and iPad attach through mosh-server, and a
 * Ghostty on another Mac, attached over ssh, gives `xterm-ghostty` too.
 */
import { isLive, type Where, type Session } from '../core'

/** A tmux client: the device it is on, its process, and the tmux window it shows. */
export type Client = { device: string; pid: number; window: string }

/** What a tmux server holds: each pane's tmux window, by pane, and its clients. */
export type Server = { panes: ReadonlyMap<string, string>; clients: readonly Client[] }

/** tmux's servers by socket; undefined for a socket no server runs on. */
export type Servers = ReadonlyMap<string, Server | undefined>

/** A process: its parent's id, and its command as `ps` gives it, a path for most. */
export type Process = { parent: number; command: string }

/** Every process, by its id. */
export type Processes = ReadonlyMap<number, Process>

/**
 * What tells which devices show a window: tmux's servers, the processes of
 * their clients that descend from Ghostty, and the programs asked that gave
 * no answer, so that showing nothing may mean only not knowing.
 */
export type Screen = {
  servers: Servers
  ghostty: ReadonlySet<number>
  unanswered: readonly string[]
}

/** tmux's words for every pane on a server with its tmux window, and for every client with the tmux window it shows. */
export const PANES = ['list-panes', '-a', '-F', '#{pane_id}\t#{window_id}']
export const CLIENTS = ['list-clients', '-F', '#{client_tty}\t#{client_pid}\t#{window_id}']

/** Every process with its parent and command, one line each. */
export const PS = ['ps', '-A', '-o', 'pid=,ppid=,comm=']

/** The last part of the path of Ghostty's own program: `/Applications/Ghostty.app/Contents/MacOS/ghostty`. */
const GHOSTTY_PROGRAM = 'ghostty'

/** `$TERM_PROGRAM` in a Ghostty window, outside tmux. */
const GHOSTTY = 'ghostty'

/** `ps`'s line: the id and the parent's, right-aligned, then the command, spaces and all. */
const PROCESS_LINE = /^\s*(\d+)\s+(\d+)\s+(.*)$/

/** Each line's fields with at least `count` of them, the last taking any tab left. */
const rows = (output: string, count: number) =>
  output.split('\n').flatMap(line => {
    const fields = line.split('\t')

    return fields.length < count
      ? []
      : [[...fields.slice(0, count - 1), fields.slice(count - 1).join('\t')]]
  })

/** `list-panes -a` as each pane's tmux window. A window in several sessions lists its panes once for each, all the same window. */
export const parsePanes = (output: string): ReadonlyMap<string, string> =>
  new Map(rows(output, 2).map(([pane = '', window = '']) => [pane, window]))

/** `list-clients` as its clients. */
export const parseClients = (output: string): Client[] =>
  rows(output, 3).map(([device = '', pid = '', window = '']) => ({
    device,
    pid: Number.parseInt(pid, 10),
    window,
  }))

/** `ps`'s snapshot as every process, by its id. */
export const parseProcesses = (output: string): Processes =>
  new Map(
    output.split('\n').flatMap(line => {
      const [, pid = '', parent = '', command = ''] = PROCESS_LINE.exec(line) ?? []

      return command === ''
        ? []
        : [[Number.parseInt(pid, 10), { parent: Number.parseInt(parent, 10), command }] as const]
    }),
  )

const isGhostty = (process: Process | undefined) =>
  process?.command.split('/').at(-1) === GHOSTTY_PROGRAM

/**
 * Whether Ghostty's program is among a process's ancestors, as far as the
 * snapshot goes. A snapshot taken as processes come and go, their ids
 * reused, can loop, so each ancestor is looked at once.
 */
const isFromGhostty = (pid: number, processes: Processes) => {
  const seen = new Set<number>()

  for (
    let at = processes.get(pid)?.parent;
    at !== undefined && !seen.has(at);
    at = processes.get(at)?.parent
  ) {
    if (isGhostty(processes.get(at))) {
      return true
    }

    seen.add(at)
  }

  return false
}

/** The processes of the servers' clients that descend from Ghostty, each client's ancestry walked once. */
export const ghosttyClients = (servers: Servers, processes: Processes): ReadonlySet<number> =>
  new Set(
    [...servers.values()]
      .flatMap(server => server?.clients ?? [])
      .map(client => client.pid)
      .filter(pid => isFromGhostty(pid, processes)),
  )

/** The windows a session is in as it stands at `now`: where each live presence is, the deliverer's first. */
export const windowsOf = (session: Session, now: number): Where[] =>
  session.presence
    .filter(each => isLive(each, now))
    .sort((a, b) => Number(b.writer === session.deliverer) - Number(a.writer === session.deliverer))
    .flatMap(each => (each.where === undefined ? [] : [each.where]))

/** The tmux sockets the windows run under, each once. */
export const socketsOf = (windows: readonly Where[]) => [
  ...new Set(windows.flatMap(where => (where.tmux === undefined ? [] : [where.tmux.socket]))),
]

/** The devices of the Ghostty windows showing one window: in tmux, the Ghostty clients on its pane's tmux window; outside it, its own device. */
const devicesOf = (where: Where, { servers, ghostty }: Screen): string[] => {
  if (where.tmux === undefined) {
    return where.terminal === GHOSTTY && where.device !== undefined ? [where.device] : []
  }

  const server = servers.get(where.tmux.socket)
  const window = server?.panes.get(where.tmux.pane)

  return (server?.clients ?? [])
    .filter(client => client.window === window && ghostty.has(client.pid))
    .map(client => client.device)
}

/** The devices of the Ghostty windows showing any of the windows, each once, the first window's first. */
export const devicesShowing = (windows: readonly Where[], screen: Screen) => [
  ...new Set(windows.flatMap(where => devicesOf(where, screen))),
]
