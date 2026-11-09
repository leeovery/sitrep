/**
 * Every process of this Mac, as one `ps` snapshot gives it, and the one step
 * every multiplexer's client goes through: where a jump can bring it
 * forward. A client is in the terminal app it descends from, Ghostty's when
 * Ghostty's own program is the nearest app among its ancestors
 * (`tmux < zsh < login < ghostty`, live); its terminal's name cannot tell, as
 * Lee's phone and iPad attach through mosh-server, and a Ghostty on another
 * Mac, attached over ssh, gives `xterm-ghostty` too, and neither descends
 * from an app. Its window there is on the device of the app's own child,
 * the terminal's pty, which a relaying pty between them does not hide.
 */
import { isDevice } from '../core'
import { appOfCommand, isReachable } from './apps'
import type { App } from './driver'

/** A process: its parent's id, the device it is on, if any, and its command line as `ps` gives it. */
export type Process = { parent: number; device?: string; args: string }

/** Every process, by its id. */
export type Processes = ReadonlyMap<number, Process>

/**
 * Every process with its parent, its terminal and its command line, one line
 * each: one `ps` a look. The terminal is its device's numbers (`tdev`), as
 * its name (`tty`) made `ps` about five times slower (a median of 580ms
 * against 122ms at a load of 110, 9 November 2026).
 */
export const PS = ['ps', '-A', '-o', 'pid=,ppid=,tdev=,args=']

/** `ps`'s line: the id and the parent's, right-aligned, the terminal's numbers, `??` for none, then the command line, spaces and all. */
const PROCESS_LINE = /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(.*)$/s

/** A pseudo-terminal's numbers, major 16: `16/32` for `/dev/ttys032`, as `ls -l` gives it `16, 32`. */
const PTY = /^16\/(\d+)$/

/** The device a terminal's numbers name, `/dev/ttys032` for `16/32`; none for `??`, or any device but a pty. */
export const deviceOfNumbers = (tdev: string) => {
  const [, minor] = PTY.exec(tdev) ?? []

  return minor === undefined ? undefined : `/dev/ttys${minor.padStart(3, '0')}`
}

/** A line of `ps`'s as its process, by its id; none for a line that is no process. */
const processOf = (line: string): [number, Process][] => {
  const [, pid = '', parent = '', tdev = '', args = ''] = PROCESS_LINE.exec(line) ?? []
  const device = deviceOfNumbers(tdev)
  const process = {
    parent: Number.parseInt(parent, 10),
    ...(device === undefined ? {} : { device }),
    args,
  }

  return args === '' ? [] : [[Number.parseInt(pid, 10), process]]
}

/** `ps`'s snapshot as every process, by its id. */
export const parseProcesses = (output: string): Processes =>
  new Map(output.split('\n').flatMap(processOf))

/** The nearest ancestor of a process that is a terminal app, and that app's own child among them, the process itself or one above it. */
const appAbove = (pid: number, processes: Processes) => {
  const seen = new Set<number>()
  let child = processes.get(pid)

  while (child !== undefined && !seen.has(child.parent)) {
    const parent = processes.get(child.parent)
    const app = parent === undefined ? undefined : appOfCommand(parent.args)

    if (app !== undefined) {
      return { app, child }
    }

    seen.add(child.parent)
    child = parent
  }

  return undefined
}

/** Where a jump can bring a client forward: the terminal app it is in, and the device of its window there, which only an app with no driver may lack. */
export type Seat = { app: App; device?: string }

/**
 * Where a multiplexer's client can be brought forward: in the nearest
 * terminal app among its ancestors, on the device of the app's own child,
 * the terminal's pty, however many relaying ptys sit between (Portal's,
 * `script`'s); where that child is on none, on the client's own device. A
 * client on no tty of its own, as a tmux control-mode client over pipes, is
 * on no device: it is no window a driver could find. Undefined for a client
 * in no app, or in a driver's app on no device. A snapshot taken as
 * processes come and go, their ids reused, can loop, so each ancestor is
 * looked at once.
 */
export const seatOf = (processes: Processes, pid: number, own: string): Seat | undefined => {
  const above = appAbove(pid, processes)

  if (above === undefined) {
    return undefined
  }

  const device = isDevice(own) ? (above.child.device ?? own) : undefined

  return isReachable(above.app, device) ? { app: above.app, device } : undefined
}
