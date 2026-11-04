/**
 * What the CLI does on screen, through Io: finds where a session's windows
 * show, and brings the first that answers to the front, in two layers. The
 * tmux layer says which clients show a pane, and selects the pane's tmux
 * window where none does; a driver per terminal app finds the window on a
 * device and brings it forward, and an app with no driver is brought
 * forward as an app.
 */
import type { Where } from '../core'
import type { App, Bring, FrontAtStart } from './driver'
import { frontmost } from './front'
import type { Io } from './io'
import { reachOf, readScreen, type Place } from './screen'
import { select, selectWords, type Select, type Selected } from './tmux'

/**
 * What a jump came to: the window brought forward; no terminal window
 * showing the session, nor any tmux could make show it; none found, as
 * programs asked gave no answer; devices showing it, in the apps named,
 * where no window answered; or tmux not selecting the pane's window, in its
 * words, or giving no answer.
 */
export type Jumped =
  | { is: 'focused' }
  | { is: 'off screen' }
  | { is: 'unknown'; unanswered: readonly string[] }
  | { is: 'unanswered'; devices: readonly string[]; apps: readonly string[] }
  | { is: 'unselected'; said?: string }

const FOCUSED: Jumped = { is: 'focused' }
const OFF_SCREEN: Jumped = { is: 'off screen' }

/** Each app's bringing forward, started at its first place and kept for the jump. */
const bringing = (io: Io, front: FrontAtStart) => {
  const started = new Map<App, Bring>()

  return (app: App) => {
    const bring = started.get(app) ?? app.start(io, front)

    started.set(app, bring)

    return bring
  }
}

/** Each select a jump makes, by its words: made once however many places need it, so one that hangs costs its time once. */
const selecting = (io: Io) => {
  const made = new Map<string, Promise<Selected>>()

  return (wanted: Select) => {
    const key = selectWords(wanted).join('\0')
    const selected = made.get(key) ?? select(io, wanted)

    made.set(key, selected)

    return selected
  }
}

/**
 * Why a place brought nothing forward: its window not answering; its app
 * with no window open; tmux not making its select; or its app unable to ask,
 * in the words it threw.
 */
type Missed =
  | { is: 'unanswered'; place: Place }
  | { is: 'none open' }
  | { is: 'unselected'; said?: string }
  | { is: 'failed'; error: unknown }

/** Brings forward the window at a place, tmux selecting its pane's window first where it must; undefined once forward, else why not. */
const tryPlace = async (
  place: Place,
  bringOf: ReturnType<typeof bringing>,
  selectFor: ReturnType<typeof selecting>,
): Promise<Missed | undefined> => {
  const selected = place.select === undefined ? undefined : await selectFor(place.select)

  if (selected !== undefined && !selected.isDone) {
    return { is: 'unselected', said: selected.said }
  }

  try {
    const brought = await bringOf(place.app)(place.device)

    if (brought === 'none open') {
      return { is: 'none open' }
    }

    return brought === 'forward' ? undefined : { is: 'unanswered', place }
  } catch (error) {
    return { is: 'failed', error }
  }
}

/**
 * Why the jump brought nothing forward: what stopped the first place, the
 * one most wanted, an app unable to ask thrown in its own words; where its
 * window did not answer, every place whose window did not.
 */
const refusal = (missed: readonly Missed[]): Jumped => {
  const [first] = missed
  const unanswered = missed.flatMap(each => (each.is === 'unanswered' ? [each.place] : []))

  switch (first?.is) {
    case 'failed':
      throw first.error
    case 'unselected':
      return { is: 'unselected', said: first.said }
    case 'unanswered':
      return {
        is: 'unanswered',
        devices: unanswered.flatMap(place => (place.device === undefined ? [] : [place.device])),
        apps: [...new Set(unanswered.map(place => place.app.name))],
      }
    default:
      return OFF_SCREEN
  }
}

/**
 * Brings forward the window at the first of the places that answers. A
 * place that does not answer, or whose select tmux does not make, gives way
 * to the next; an app with no window open, or unable to ask, is passed over
 * at its places after. The jump is refused once no place is left.
 */
const bringFirst = async (
  io: Io,
  places: readonly Place[],
  front: FrontAtStart,
): Promise<Jumped> => {
  const bringOf = bringing(io, front)
  const selectFor = selecting(io)
  const passed = new Set<App>()
  const missed: Missed[] = []

  for (const place of places) {
    if (passed.has(place.app)) {
      continue
    }

    const why = await tryPlace(place, bringOf, selectFor)

    if (why === undefined) {
      return FOCUSED
    }

    if (why.is === 'none open' || why.is === 'failed') {
      passed.add(place.app)
    }

    missed.push(why)
  }

  return refusal(missed)
}

/**
 * Brings the first of the windows a jump can reach to the front, on
 * whatever Space it is. Which app is in front is read beside tmux and `ps`,
 * which outlast it, and settled before any select or focus, so it is never
 * an app brought forward by the jump itself.
 */
export const jump = async (io: Io, windows: readonly Where[]): Promise<Jumped> => {
  const look = frontmost(io)
  const [screen, before] = await Promise.all([readScreen(io, windows), look()])
  const reach = reachOf(windows, screen)

  return reach.is === 'on screen' ? bringFirst(io, reach.places, { look, before }) : reach
}
