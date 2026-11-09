/**
 * zmx's multiplexer adapter. A zmx session is one terminal, shown whole by
 * every client attached to it, so there is no window or pane to select. zmx
 * 1.0.1 lists no session's clients, so they are read from `ps`: each process
 * whose command line is exactly `zmx attach <session>`, by any path to zmx,
 * on a tty. The session's own server runs as `zmx attach <session>
 * <command>`, on none (live, 9 November 2026). The name is compared whole,
 * after `attach `, so its spaces and `·` need no parsing.
 */
import type { Multiplexer, Place, Reading } from './multiplexer'
import { seatOf, type Processes } from './processes'

/** Whether a command line attaches to the session as a client: `zmx attach <session>`, by any path to zmx, and nothing after. */
const isClientOf = (args: string, session: string) => {
  const words = `zmx attach ${session}`

  return args === words || args.endsWith(`/${words}`)
}

/** Where a window in the zmx session can be brought forward: each client a jump can reach, on the device of its terminal's own pty. */
const placesIn = (session: string, processes: Processes): Place[] =>
  [...processes].flatMap(([pid, { device, args }]) => {
    const seat =
      device !== undefined && isClientOf(args, session)
        ? seatOf(processes, pid, device)
        : undefined

    return seat === undefined ? [] : [seat]
  })

/** zmx asks nothing of its own: its clients, and so which apps show its windows, are told by `ps` alone. */
const READING: Reading = {
  places: (where, processes) =>
    where.zmx === undefined ? [] : placesIn(where.zmx.session, processes),
  unanswered: () => [],
  needsProcesses: where => where.zmx !== undefined,
}

export const ZMX: Multiplexer = {
  isIn: where => where.zmx !== undefined,
  read: async () => READING,
}
