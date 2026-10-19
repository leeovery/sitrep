/**
 * A new ask, whoever posted it: the ◆ pulses, a toast names it, a soft
 * chime plays, and the board opens it. What counts as new is the window's
 * to say (window.ts): an ask there when it attached, or when the mod
 * reloaded, is not.
 */
import type { Timer } from 'claude-code'
import type { Ask } from '../core'
import { logFailure, type Host } from './host'
import { GLYPH } from './look'
import { itemKey } from './places'

/** The chime: macOS's Glass. */
const CHIME = 'sounds/ask.aiff'

const PULSE_FRAME_MS = 150
const PULSE_FRAMES = 24

let pulsing: Timer | undefined

const toastOf = (asks: readonly Ask[], newest: Ask) =>
  asks.length === 1
    ? `${GLYPH.ask} New ask: ${newest.title}`
    : `${GLYPH.ask} ${asks.length} new asks, the latest: ${newest.title}`

/** Pulses the asks, frame by frame, until the pulse runs out; a new pulse starts over. */
const pulse = async (host: Host, asks: readonly Ask[]) => {
  const ids = asks.map(ask => ask.id)
  let frames = PULSE_FRAMES

  pulsing?.cancel()
  await host.state.pulse.write({ asks: ids, frames })

  const timer = host.clock.every(PULSE_FRAME_MS, () => {
    frames -= 1

    if (frames === 0) {
      timer.cancel()
    }

    void host.state.pulse
      .write({ asks: frames === 0 ? [] : ids, frames })
      .catch(logFailure(host, 'the pulse'))
  })

  pulsing = timer
}

/** Tells Lee of asks that just landed in a session, oldest first. */
export const announce = async (host: Host, session: string, asks: readonly Ask[]) => {
  const newest = asks.at(-1)

  if (newest === undefined) {
    return
  }

  host.ui.toast(toastOf(asks, newest))
  void host.ui.play(CHIME).catch(logFailure(host, 'the chime'))
  await host.state.pane.update(pane => ({ ...pane, selected: itemKey(session, newest.id) }))
  await pulse(host, asks)
}
