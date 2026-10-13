/**
 * Where this window is, worked out as it first attaches: its environment,
 * and the terminal device Claude Code is on, which the host finds by a walk
 * up the processes.
 */
import { parseDevice, whereOf, type Where } from '../core'
import { logFailure, type Host } from './host'

/**
 * Prints the tty name (`ttys043`) of the nearest process with a terminal,
 * from the shell running it up, and nothing once it reaches pid 1. The walk is
 * needed: a process Claude Code starts has no terminal (`ps` gives `??`,
 * checked live), only Claude Code itself or a process above it does.
 */
export const TTY_WALK = `pid=$$
while [ "\${pid:-1}" -gt 1 ]; do
  tty=$(ps -o tty= -p "$pid" | tr -d ' ')
  case $tty in ''|'??') ;; *) echo "$tty"; exit ;; esac
  pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done`

/** How long the walk may take before it is given up. */
export const TTY_WALK_MS = 2_000

/** Claude Code's terminal device, as the walk finds it; throws why when it finds none. */
const deviceOf = async (host: Host) => {
  const { exitCode, stdout, stderr } = await host.terminal.tty()
  const device = exitCode === 0 ? parseDevice(stdout) : undefined

  if (device === undefined) {
    throw new Error(
      `the walk exited ${exitCode} and printed ${JSON.stringify(stdout.trim())}, with ${JSON.stringify(stderr.trim())} on stderr`,
    )
  }

  return device
}

/**
 * Where this window is, once its device is found: neither it nor the tmux
 * environment changes for the life of Claude Code's process, and a reload of
 * the mod loads this module afresh.
 */
let found: Where | undefined

/**
 * Where this window is; undefined when nothing is known. Without its device
 * when that is not found, which the debug log says, and the next attach
 * walks again.
 */
export const whereNow = async (host: Host): Promise<Where | undefined> => {
  if (found !== undefined) {
    return found
  }

  const [env, device] = await Promise.all([
    host.terminal.env(),
    deviceOf(host).catch((error: unknown) => {
      logFailure(host, 'finding the terminal device')(error)

      return undefined
    }),
  ])
  const where = whereOf(env, device)

  found = device === undefined ? undefined : where

  return where
}
