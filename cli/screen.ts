/**
 * Where a jump can bring a session's windows forward, from where they are,
 * what each multiplexer they run in says of its clients, and which
 * processes descend from which. A window in a multiplexer shows in every
 * terminal window of this Mac holding a client of its session (for tmux, on
 * the tmux window holding its pane, or which the tmux layer could make show
 * it), each seated by one step (`seatOf`); one outside any, in its own, when
 * its terminal app is known.
 */
import { windowsOf, type Session, type Where } from '../core'
import { appOfProgram, isReachable } from './apps'
import type { Io } from './io'
import { look } from './look'
import type { Multiplexer, Place, Reading } from './multiplexer'
import { parseProcesses, PS, type Processes } from './processes'
import { TMUX } from './tmux'
import { ZMX } from './zmx'

/** Every multiplexer a window may run in, by its adapter. */
export const MULTIPLEXERS: readonly Multiplexer[] = [TMUX, ZMX]

/**
 * What tells where windows show: what each multiplexer they run in read,
 * `ps`'s snapshot, none where it gave no answer or none was needed, and what
 * gave no answer, so that showing nowhere may mean only not knowing.
 */
export type Screen = {
  readings: readonly Reading[]
  processes?: Processes
  unanswered: readonly string[]
}

/** Whether a window runs in any multiplexer. */
const isMultiplexed = (where: Where) => MULTIPLEXERS.some(each => each.isIn(where))

/**
 * The readings of the multiplexer a window is innermost in: of those it
 * runs in, the one whose own pty is its device; where none says so, each
 * that cannot tell. A multiplexer run inside another passes its variables
 * on (tmux started in zmx keeps `$ZMX_SESSION`, zmx started in tmux
 * `$TMUX`), so the outer one's would name a session the window is not on.
 */
const innermostOf = (where: Where, readings: readonly Reading[]) => {
  const inIt = readings.filter(reading => reading.isIn(where))

  if (inIt.length < 2) {
    return inIt
  }

  const onIts = inIt.filter(reading => reading.isOnItsPty(where) === true)

  return onIts.length > 0 ? onIts : inIt.filter(reading => reading.isOnItsPty(where) === undefined)
}

/**
 * What gave no answer of the windows: what a multiplexer they run in asked,
 * as tmux for a socket one runs under; and `ps`, where their clients are
 * told only by it: a tmux server one runs under with clients, whose apps it
 * tells, or a zmx session, whose clients it lists. A window in no
 * multiplexer asks neither.
 */
const unansweredOf = (
  windows: readonly Where[],
  { readings, processes }: Omit<Screen, 'unanswered'>,
) => {
  const asked = windows.flatMap(where => readings.flatMap(reading => reading.unanswered(where)))
  const isPsUnanswered =
    processes === undefined &&
    windows.some(where => readings.some(reading => reading.needsProcesses(where)))

  return [...new Set([...asked, ...(isPsUnanswered ? ['ps'] : [])])]
}

/**
 * What tells where the windows show: each multiplexer they run in read for
 * them, and `ps` once beside, where any runs in one. Nothing that fails here
 * fails the run: what gives no answer shows nothing, and is named.
 */
export const readScreen = async (io: Io, windows: readonly Where[]): Promise<Screen> => {
  const [readings, snapshot] = await Promise.all([
    Promise.all(
      MULTIPLEXERS.flatMap(multiplexer => {
        const inIt = windows.filter(multiplexer.isIn)

        return inIt.length === 0 ? [] : [multiplexer.read(io, inIt)]
      }),
    ),
    windows.some(isMultiplexed) ? look(io, PS) : undefined,
  ])
  const processes = snapshot?.exitCode === 0 ? parseProcesses(snapshot.stdout) : undefined

  return { readings, processes, unanswered: unansweredOf(windows, { readings, processes }) }
}

/**
 * Where one window can be brought forward: in a multiplexer, the places the
 * innermost it runs in finds for its clients; outside any, its own device,
 * in the app its `$TERM_PROGRAM` names.
 */
const placesOf = (where: Where, { readings, processes = new Map() }: Screen): Place[] => {
  if (isMultiplexed(where)) {
    return innermostOf(where, readings).flatMap(reading => reading.places(where, processes))
  }

  const app = appOfProgram(where.terminal)

  return app === undefined || !isReachable(app, where.device) ? [] : [{ app, device: where.device }]
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

/**
 * Whether a jump can reach windows: the places it can bring them forward
 * at; none, nothing showing them; or none found, as programs asked of them
 * gave no answer, which is never taken for none.
 */
export type Reach =
  | { is: 'on screen'; places: Place[] }
  | { is: 'off screen' }
  | { is: 'unknown'; unanswered: readonly string[] }

/** Whether a jump can reach the windows, as the screen tells it. */
export const reachOf = (windows: readonly Where[], screen: Screen): Reach => {
  const places = placesShowing(windows, screen)

  if (places.length > 0) {
    return { is: 'on screen', places }
  }

  const unanswered = unansweredOf(windows, screen)

  return unanswered.length > 0 ? { is: 'unknown', unanswered } : { is: 'off screen' }
}

/**
 * A session a live window holds, whether a jump could reach it, and the
 * terminal app showing it, the first place a jump would bring forward: in
 * a multiplexer the app its client descends from, which `$TERM_PROGRAM`,
 * `tmux` in tmux, cannot tell. None where it is not on screen.
 */
export type Shown = { session: Session; is: Reach['is']; app?: string }

/** Which sessions a live window holds show on screen, and what gave no answer. */
export type OnScreen = { shown: Shown[]; unanswered: readonly string[] }

/**
 * Whether a jump could reach each session a live window holds, as it stands
 * at `now`: the screen read once for every such window, so each tmux
 * socket is asked once however many sessions run under it, and `ps` once.
 * A session no window holds is away, and left out.
 */
export const readOnScreen = async (
  io: Io,
  sessions: readonly Session[],
  now: number,
): Promise<OnScreen> => {
  const held = sessions
    .filter(session => session.isOpen)
    .map(session => ({ session, windows: windowsOf(session, now) }))
  const screen = await readScreen(io, held.flatMap(({ windows }) => windows))

  return {
    shown: held.map(({ session, windows }) => {
      const reach = reachOf(windows, screen)

      return reach.is === 'on screen'
        ? { session, is: reach.is, app: reach.places[0]?.app.name }
        : { session, is: reach.is }
    }),
    unanswered: screen.unanswered,
  }
}
