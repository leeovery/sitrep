/**
 * Where a jump can bring a session's windows forward, from where they are,
 * what tmux says of its servers, and which processes descend from which. A
 * window in tmux shows in every terminal window of this Mac whose tmux
 * client is on the tmux window holding its pane, or could be made to show it
 * (the tmux layer); one outside tmux, in its own, when its terminal app is
 * known.
 *
 * A tmux client is in the terminal app it descends from: Ghostty's when
 * Ghostty's own program is the nearest app among its ancestors
 * (`tmux < zsh < login < ghostty`, live). Its terminal's name cannot tell:
 * Lee's phone and iPad attach through mosh-server, and a Ghostty on another
 * Mac, attached over ssh, gives `xterm-ghostty` too; neither descends from an
 * app.
 */
import { isLive, type Presence, type Session, type Where } from '../core'
import { appOfCommand, appOfProgram, isDriver } from './apps'
import type { App } from './driver'
import type { Io } from './io'
import { look } from './look'
import { readServer, showingPane, type Select, type Servers } from './tmux'

/** A process: its parent's id, and its command as `ps` gives it, a path for most. */
export type Process = { parent: number; command: string }

/** Every process, by its id. */
export type Processes = ReadonlyMap<number, Process>

/**
 * What tells where a window shows: tmux's servers, the terminal app of each
 * of their clients that is in one, by the client's process, and the programs
 * asked that gave no answer, so that showing nowhere may mean only not
 * knowing.
 */
export type Screen = {
  servers: Servers
  apps: ReadonlyMap<number, App>
  unanswered: readonly string[]
}

/**
 * Where a jump can bring a window forward: the terminal app, the device of
 * its window there, which only an app with no driver may lack, and the
 * select that makes that window show the pane first, where tmux must make one.
 */
export type Place = { app: App; device?: string; select?: Select }

/** Every process with its parent and command, one line each. */
export const PS = ['ps', '-A', '-o', 'pid=,ppid=,comm=']

/** `ps`'s line: the id and the parent's, right-aligned, then the command, spaces and all. */
const PROCESS_LINE = /^\s*(\d+)\s+(\d+)\s+(.*)$/

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

/**
 * The terminal app a process runs in: its nearest ancestor that is one, as
 * far as the snapshot goes. A snapshot taken as processes come and go, their
 * ids reused, can loop, so each ancestor is looked at once.
 */
const appAbove = (pid: number, processes: Processes) => {
  const seen = new Set<number>()

  for (
    let at = processes.get(pid)?.parent;
    at !== undefined && !seen.has(at);
    at = processes.get(at)?.parent
  ) {
    const process = processes.get(at)
    const app = process === undefined ? undefined : appOfCommand(process.command)

    if (app !== undefined) {
      return app
    }

    seen.add(at)
  }

  return undefined
}

/** The terminal app of each of the servers' clients that is in one, by its process, each client's ancestry walked once. */
export const clientApps = (servers: Servers, processes: Processes): ReadonlyMap<number, App> =>
  new Map(
    [...servers.values()]
      .flatMap(server => server?.clients ?? [])
      .flatMap(client => {
        const app = appAbove(client.pid, processes)

        return app === undefined ? [] : [[client.pid, app] as const]
      }),
  )

/** The tmux sockets the windows run under, each once. */
export const socketsOf = (windows: readonly Where[]) => [
  ...new Set(windows.flatMap(where => (where.tmux === undefined ? [] : [where.tmux.socket]))),
]

/**
 * What tells where the windows show: tmux asked twice for each socket they
 * run under, and `ps` once beside it, its snapshot used only when a server
 * has clients. Nothing that fails here fails the run: what gives no answer
 * shows nothing, and is named.
 */
export const readScreen = async (io: Io, windows: readonly Where[]): Promise<Screen> => {
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
    apps: clientApps(servers, processes),
    unanswered: [
      ...(read.every(([, each]) => each.isAnswered) ? [] : ['tmux']),
      ...(hasClients && !isSnapshot ? ['ps'] : []),
    ],
  }
}

/**
 * Where one window can be brought forward: in tmux, the clients in a
 * terminal app that show its pane, or could be made to; outside it, its own
 * device, in the app its `$TERM_PROGRAM` names. A driver needs the device to
 * find the window; an app with no driver is brought forward whole, so needs
 * none.
 */
const placesOf = (where: Where, { servers, apps }: Screen): Place[] => {
  if (where.tmux === undefined) {
    const app = appOfProgram(where.terminal)

    return app === undefined || (where.device === undefined && isDriver(app))
      ? []
      : [{ app, device: where.device }]
  }

  const { socket, pane } = where.tmux
  const server = servers.get(socket)

  if (server === undefined) {
    return []
  }

  const inApps = server.clients.flatMap(client => {
    const app = apps.get(client.pid)

    return app === undefined ? [] : [{ ...client, app }]
  })

  return showingPane(socket, server, pane, inApps).map(({ client, select }) => ({
    app: client.app,
    device: client.device,
    select,
  }))
}

/** What tells places apart: the device, else, for an app with no driver, the app. */
const placeKey = (place: Place) => place.device ?? place.app

/** Where any of the windows can be brought forward, each device once, the first window's first. */
export const placesShowing = (windows: readonly Where[], screen: Screen): Place[] => {
  const places = windows.flatMap(where => placesOf(where, screen))

  return places.filter(
    (place, i) => places.findIndex(each => placeKey(each) === placeKey(place)) === i,
  )
}

/** A window stopped on Lee: at a permission prompt or a question. */
const needsLee = (presence: Presence) =>
  presence.state?.is === 'permission' || presence.state?.is === 'question'

/**
 * How a window ranks for a jump: stopped on Lee first; then working, as it is
 * active now, however long ago its turn began; then on its own work, as the
 * session's row prefers it (core's `turnOf`), so the jump goes to the window
 * the row describes; then the rest, on its turn, or saying no state.
 */
const rankOf = (presence: Presence) => {
  if (needsLee(presence)) {
    return 0
  }

  switch (presence.state?.is) {
    case 'working':
      return 1
    case 'onItsWork':
      return 2
    default:
      return 3
  }
}

/** When a window's state began; else, saying none, as one before any turn does, its attach. */
const sinceOf = (presence: Presence) => presence.state?.since ?? presence.attachedAt

/**
 * The window that needs Lee first, then one working, then one on its own
 * work, then the rest; within each, the latest to begin its state (the later
 * stop, the turn Lee started last, the later end of a turn), then the one
 * attached last.
 */
const byJump = (a: Presence, b: Presence) =>
  rankOf(a) - rankOf(b) || sinceOf(b) - sinceOf(a) || b.attachedAt - a.attachedAt

/** The windows a session is in as it stands at `now`: where each live presence is, in the order a jump tries them. */
export const windowsOf = (session: Session, now: number): Where[] =>
  session.presence
    .filter(each => isLive(each, now))
    .sort(byJump)
    .flatMap(each => (each.where === undefined ? [] : [each.where]))
