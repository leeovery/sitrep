/** What the mod puts in `$.state`, as the tests read it back, and a door on its writes of the messages in flight. */
import type { On, PluginState } from 'claude-code'
import { keptFlights } from '../../hooks/deliver'
import { takeBackKey } from '../../hooks/draw/ready'
import { itemKey } from '../../hooks/places'
import type { SitrepInFlight, SitrepStoredFlights } from '../../types'

type Sitrep = PluginState['sitrep']

export function kept(on: On) {
  const state: Partial<Sitrep> = {}
  const boards: (Sitrep['board'] | null)[] = []
  /** How many times each of the mod's values was put in `$.state`. */
  const writes: Partial<Record<keyof Sitrep, number>> = {}
  let isUnread = false

  on('state.set', ($, input, next) => {
    const e = isUnread && input.key === 'others' ? { ...input, value: [] } : input

    Object.assign(state, { [e.key]: e.value })
    writes[e.key as keyof Sitrep] = (writes[e.key as keyof Sitrep] ?? 0) + 1

    if (e.key === 'board') {
      boards.push(e.value as Sitrep['board'])
    }

    return next(e)
  })

  /** The window's messages in flight, in the order claimed, however `$.state` keeps them. */
  const flights = () => keptFlights(state.inFlight ?? null)

  return {
    state,
    boards,
    writes,
    flights,

    /** The other sessions the board reads in full, from here on, never land in `$.state`: as before the look reading one has, only their briefs are there. */
    leaveUnread: () => {
      isUnread = true
    },

    /** An item's address on the board, as its buttons are keyed (`pick:<address>`): in the held session, unless another is named. */
    item: (id: string, session = state.attachment?.session ?? '') => itemKey(session, id),

    /** The key of the take-back of the window's message in flight at `at`, the first unless told otherwise. */
    takeBack: (at = 0) => {
      const send = flights()[at]

      if (send === undefined) {
        throw new Error(`no message in flight at ${at}`)
      }

      return takeBackKey(send)
    },
  }
}

/**
 * A door on the writes of the messages in flight, set up before the test
 * first calls the engine: once `hold` picks one, by the claims it writes,
 * the next write it picks waits there until `open()`, an update read and
 * decided, not yet landed, so another can land first. `arrived` once one
 * waits there.
 */
export const writeDoor = (on: On) => {
  let isIt: ((flights: SitrepInFlight[]) => boolean) | undefined
  let arrive = () => {}
  let open = () => {}
  const arrived = new Promise<void>(resolve => {
    arrive = resolve
  })
  const opened = new Promise<void>(resolve => {
    open = resolve
  })

  on('state.set', { plugin: 'sitrep', key: 'inFlight' }, async ($, e, next) => {
    if (isIt?.(keptFlights(e.value as SitrepStoredFlights)) === true) {
      isIt = undefined
      arrive()
      await opened
    }

    return next(e)
  })

  return {
    hold: (pick: (flights: SitrepInFlight[]) => boolean) => {
      isIt = pick
    },
    arrived,
    open: () => open(),
  }
}
