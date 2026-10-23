/**
 * A new ask, whoever posted it, or one its snooze's time just woke: the ◆
 * pulses, a toast names it, a soft chime plays, and the board opens it.
 * What counts as new is the window's to say (window.ts): an ask there when
 * it attached, or when the mod reloaded, is not, nor one Lee woke.
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

/** What a fold brings Lee: the asks that just landed, and those their snooze's time just woke, each the oldest first. */
export type News = { landed: readonly Ask[]; woken: readonly Ask[] }

/** The toast: the asks that landed, else those that woke, named by the latest. */
const toastOf = ({ landed, woken }: News, newest: Ask) => {
  if (landed.length > 0) {
    return landed.length === 1
      ? `${GLYPH.ask} New ask: ${newest.title}`
      : `${GLYPH.ask} ${landed.length} new asks, the latest: ${newest.title}`
  }

  return woken.length === 1
    ? `${GLYPH.ask} Back from snooze: ${newest.title}`
    : `${GLYPH.ask} ${woken.length} back from snooze, the latest: ${newest.title}`
}

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

/** Tells Lee of asks that just landed in a session, or woke there, in one toast and one chime; the newest that landed opens, else the last that woke. */
export const announce = async (host: Host, session: string, news: News) => {
  const asks = [...news.woken, ...news.landed]
  const newest = asks.at(-1)

  if (newest === undefined) {
    return
  }

  host.ui.toast(toastOf(news, newest))
  void host.ui.play(CHIME).catch(logFailure(host, 'the chime'))
  await host.state.pane.update(pane => ({ ...pane, selected: itemKey(session, newest.id) }))
  await pulse(host, asks)
}
