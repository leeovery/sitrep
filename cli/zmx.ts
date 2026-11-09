/**
 * zmx's multiplexer adapter. A zmx session is one terminal, shown whole by
 * every client attached to it, so there is no window or pane to select. zmx
 * 1.0.1 lists no session's clients, so they are read from `ps`: each process
 * whose command line is exactly `zmx attach <session>`, by any path to zmx,
 * on a tty. The name is compared whole, after `attach `, so its spaces and
 * `·` need no parsing. The session's own server, `zmx attach <session>
 * <command>`, or exactly a client's line where the session was made by a
 * bare attach, is on no tty, its parent launchd (live, 9 November 2026), so
 * it is no client.
 *
 * A client switched in place, `zmx attach B` typed inside an attach on A,
 * keeps A's name in its command line, and so reads as A's: a known limit,
 * as Portal's own switch starts a fresh `zmx attach B`.
 */
import type { Where } from '../core'
import type { Multiplexer, Place, Reading } from './multiplexer'
import { seatOf, type Processes } from './processes'

/** Whether a command line attaches to the session as a client: `zmx attach <session>`, by any path to zmx, and nothing after. */
const isClientOf = (args: string, session: string) => {
  const words = `zmx attach ${session}`

  return args === words || args.endsWith(`/${words}`)
}

/** Where a window in the zmx session can be brought forward: each client on a tty that a jump can reach, on the device of its terminal's own pty. */
const placesIn = (session: string, processes: Processes): Place[] =>
  [...processes].flatMap(([pid, { device, args }]) => {
    const seat =
      device !== undefined && isClientOf(args, session)
        ? seatOf(processes, pid, device)
        : undefined

    return seat === undefined ? [] : [seat]
  })

const isInZmx = (where: Where) => where.zmx !== undefined

/** zmx asks nothing of its own: its clients, and so which apps show its windows, are told by `ps` alone, and it cannot tell its session's pty. */
const READING: Reading = {
  isIn: isInZmx,
  isOnItsPty: () => undefined,
  places: (where, processes) =>
    where.zmx === undefined ? [] : placesIn(where.zmx.session, processes),
  unanswered: () => [],
  needsProcesses: isInZmx,
}

export const ZMX: Multiplexer = {
  isIn: isInZmx,
  read: async () => READING,
}
