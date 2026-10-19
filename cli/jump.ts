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
import { placesShowing, readScreen, type Place } from './screen'
import { select, type Select } from './tmux'

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

/** The ids of the sessions a jump can reach, from the windows each is in; nothing is selected or knocked on. */
export const sessionsOnScreen = async (io: Io, windows: ReadonlyMap<string, readonly Where[]>) => {
  const screen = await readScreen(io, [...windows.values()].flat())

  return new Set(
    [...windows].flatMap(([id, each]) => (placesShowing(each, screen).length > 0 ? [id] : [])),
  )
}

/** Each app's bringing forward, started at its first place and kept for the jump. */
const bringing = (io: Io, front: FrontAtStart) => {
  const started = new Map<App, Bring>()

  return (app: App) => {
    const bring = started.get(app) ?? app.start(io, front)

    started.set(app, bring)

    return bring
  }
}

/** Makes the select a place needs, if any: undefined once made, else why it was not. */
const selectFor = async (io: Io, wanted: Select | undefined): Promise<Jumped | undefined> => {
  if (wanted === undefined) {
    return undefined
  }

  const selected = await select(io, wanted)

  return selected.isDone ? undefined : { is: 'unselected', said: selected.said }
}

/**
 * Brings forward the window at the first of the places that answers, tmux
 * selecting its pane's window first where it must. A select that fails ends
 * the jump; an app with no window open shows nothing at any of its places.
 */
const bringFirst = async (
  io: Io,
  places: readonly Place[],
  front: FrontAtStart,
): Promise<Jumped> => {
  const bringOf = bringing(io, front)

  for (const place of places) {
    const unselected = await selectFor(io, place.select)

    if (unselected !== undefined) {
      return unselected
    }

    const brought = await bringOf(place.app)(place.device)

    if (brought !== undefined) {
      return brought === 'forward' ? FOCUSED : OFF_SCREEN
    }
  }

  return {
    is: 'unanswered',
    devices: places.map(place => place.device),
    apps: [...new Set(places.map(place => place.app.name))],
  }
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
  const places = placesShowing(windows, screen)

  if (places.length === 0) {
    return screen.unanswered.length > 0
      ? { is: 'unknown', unanswered: screen.unanswered }
      : OFF_SCREEN
  }

  return bringFirst(io, places, { look, before })
}
