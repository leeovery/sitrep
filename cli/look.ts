/**
 * Asking a program that answers at once or not at all (tmux, `ps`,
 * lsappinfo) within a time limit, so nothing the CLI looks at hangs it.
 */
import type { Io } from './io'

/** How long tmux, `ps` and lsappinfo may take to answer, so a listing or a jump never hangs on them. */
export const LOOK_MS = 2_000

/** How a program ran; undefined when it could not start, or did not end in time. */
export const look = (io: Io, command: readonly string[]) =>
  io.run(command, LOOK_MS).catch(() => undefined)
