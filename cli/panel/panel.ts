/**
 * The panel: bare `sitrep` on a terminal, the board drawn on the alternate
 * screen and kept current until it is left.
 *
 * - Opening, it asks the terminal's colours, enters the screen, and looks
 *   at the board every second as `watch` does (looks.ts), in its own
 *   process.
 * - Its first draw waits for the first look, up to 300 ms, so `Looking for
 *   sessions…` never flashes up before a board read at once.
 * - It steps its state (state.ts) on every look, key and resize, and at a
 *   new ask's wash's end, then draws, writing only the rows that changed. A
 *   look that finds the board as it stood moves the clock alone, so the
 *   times turn over with the minute.
 * - It never ends on a look: one that fails keeps the last board, stale,
 *   or says why the board can't be read before any.
 * - Ctrl-Z gives the terminal back and stops it; SIGCONT takes the
 *   terminal again and draws afresh.
 * - However it ends, it gives the terminal back first: `q` and Ctrl-C as
 *   done, SIGTERM as terminated, SIGHUP as hung up, its writes tried though
 *   the terminal may be gone; and a thrown error, thrown on once the
 *   terminal is given back. SIGTERM and SIGHUP are heard from the first,
 *   the colour query's wait among it, when raw mode is already on.
 */
import { newRows, ownTime, type Shown } from '../../core'
import type { Io, Terminal, Waiting } from '../io'
import { looking, untilEnded, type Look } from '../looks'
import type { Size } from './cells'
import { COLOUR_QUERY, paintOf } from './colours'
import { ansi, draw } from './draw'
import { keysOf, type Key } from './keys'
import { levelOf, type Paint } from './paint'
import { ENTER, LEAVE, repaint } from './screen'
import { opening, step, type PanelEvent } from './state'
import { NEW_MS, viewOf } from './view'

/** How the panel ended: left by its keys, told to end, or its terminal gone. */
export type Closed = 'done' | 'terminated' | 'hungUp'

/** How long the first draw waits for the first look. */
export const HOLD_MS = 300

/** How long a lone ESC waits for the rest of a sequence. */
export const ESC_MS = 50

/** The size laid out at while the terminal says none. */
const UNSIZED: Size = { width: 80, height: 24 }

/** The sessions on the board no terminal on this Mac shows: none known, until SitRep says. */
const NOT_HERE: ReadonlySet<string> = new Set()

/** Why a look failed, as a sentence, as the app words it. */
const reasonOf = (error: unknown) => {
  const message = error instanceof Error ? error.message : String(error)

  return /[.!?]$/.test(message) ? message : `${message}.`
}

const sizeOf = (terminal: Terminal) => terminal.size() ?? UNSIZED

/** A wait that acts once its time has passed, unless cancelled first. */
const after = (io: Io, ms: number, act: () => void): Waiting => {
  const waiting = io.wait(ms)

  void waiting.then(act)

  return waiting
}

/** The run's end, as the panel's looks hear it: only the panel ends them, as it closes, never a signal of their own. */
const byThePanel = () => ({ ended: new Promise<void>(() => {}), stop: () => {} })

/**
 * The keys in bytes as they come: a sequence cut short held for the next
 * bytes, and read as all there is once ESC_MS pass with nothing more, so a
 * lone ESC is `esc`.
 */
const keyReader = (io: Io, pressed: (key: Key) => void, guard: (act: () => void) => void) => {
  let rest = ''
  let quiet: Waiting | undefined

  const read = (bytes: string, isQuiet: boolean) => {
    quiet?.cancel()

    const found = keysOf(rest + bytes, isQuiet)

    rest = found.rest
    quiet = rest === '' ? undefined : after(io, ESC_MS, () => guard(() => read('', true)))
    found.keys.forEach(pressed)
  }

  return {
    heard: (bytes: string) => read(bytes, false),
    stop: () => {
      quiet?.cancel()
      rest = ''
    },
  }
}

/** A promise settled once, from outside. */
const closer = () => {
  let close: (closed: Closed) => void = () => {}
  let fail: (error: unknown) => void = () => {}
  const closed = new Promise<Closed>((resolve, reject) => {
    close = resolve
    fail = reject
  })

  return { closed, close, fail }
}

/** The panel on the terminal: opened until it closes, then the terminal given back. */
const live = (io: Io, terminal: Terminal) => {
  const closing = closer()
  const run = untilEnded({ ...io, ending: byThePanel })
  const listening: (() => void)[] = []
  let paint: Paint = { level: levelOf(io.env) }
  let state = opening(sizeOf(terminal), io.now(), NOT_HERE)
  let isClosed = false
  let isHeld = true
  let isOnScreen = false
  let onScreen: string[] | undefined
  let stopKeys = () => {}
  let shown: Shown | undefined
  let hold: Waiting | undefined
  let wash: Waiting | undefined
  let looks: Promise<unknown> = Promise.resolve()

  const close = (closed: Closed) => {
    isClosed = true
    closing.close(closed)
  }

  const guard = (act: () => void) => {
    try {
      if (!isClosed) {
        act()
      }
    } catch (error) {
      isClosed = true
      closing.fail(error)
    }
  }

  /** The clock stepped at the earliest wash's end, NEW_MS from its line's first showing. */
  const washing = () => {
    const first = Math.min(...state.arrivals.values())

    wash?.cancel()
    wash = Number.isFinite(first) ? after(io, first + NEW_MS - io.now(), () => guard(() => apply({ tick: io.now() }))) : undefined
  }

  const frame = () => {
    if (isHeld || !isOnScreen) {
      return
    }

    const view = viewOf(state.feed, state, io.now(), state.notHere)
    const lines = draw(view, state.size, paint).map(line => ansi([line], paint.level))
    const writes = repaint(onScreen, lines)

    if (writes !== '') {
      terminal.write(writes)
    }

    onScreen = lines
    washing()
  }

  const apply = (event: PanelEvent) => {
    state = step(state, event).state
    frame()
  }

  const pressed = (key: Key) => {
    if (isClosed) {
      return
    }

    if (key.kind === 'quit') {
      close('done')
    } else if (key.kind === 'suspend') {
      suspend()
    } else {
      apply({ key })
    }
  }

  const reader = keyReader(io, pressed, guard)

  /** The terminal taken: its keys listened to, raw mode set afresh where a stop from outside left it to the shell, and the screen entered. */
  const enter = () => {
    stopKeys()
    isOnScreen = true
    onScreen = undefined
    stopKeys = terminal.keys(bytes => guard(() => reader.heard(bytes)))
    terminal.write(ENTER)
  }

  const leave = () => {
    if (!isOnScreen) {
      return
    }

    isOnScreen = false

    try {
      terminal.write(LEAVE)
    } finally {
      stopKeys()
      stopKeys = () => {}
      reader.stop()
    }
  }

  const suspend = () => {
    leave()
    terminal.suspend()
  }

  const resume = () => {
    enter()
    frame()
  }

  const unhold = () => {
    isHeld = false
    hold?.cancel()
  }

  /** A look's board, stepped as a board where it changed or the board was stale; else the clock alone. */
  const onLook = (look: Look) => {
    unhold()

    if (look.isSame && state.board === 'read') {
      apply({ tick: look.now })

      return
    }

    const feed = look.feed()
    const news = newRows(shown, feed, ownTime(look.clock))

    shown = news.shown
    apply({ board: feed, news: news.news, now: look.now })
  }

  const onFailure = (error: unknown) => {
    unhold()
    apply({ failed: reasonOf(error) })

    return true
  }

  const resized = () => {
    onScreen = undefined
    apply({ size: sizeOf(terminal) })
  }

  /** The panel opened: told to end from the first, even while it asks the colours with raw mode on; then on the screen, watching the board. */
  const open = async () => {
    listening.push(
      terminal.onSignal('SIGTERM', () => close('terminated')),
      terminal.onSignal('SIGHUP', () => close('hungUp')),
    )
    paint = paintOf(paint.level, await terminal.ask(COLOUR_QUERY))

    if (!isClosed) {
      listening.push(
        terminal.onSignal('SIGCONT', () => guard(resume)),
        terminal.onResize(() => guard(resized)),
      )
      enter()
      hold = after(io, HOLD_MS, () =>
        guard(() => {
          unhold()
          frame()
        }),
      )
      looks = looking(io, run, { seen: onLook, endsOnNewVersion: false, isPastFailure: onFailure }).catch(closing.fail)
    }

    return closing.closed
  }

  const giveBack = async () => {
    isClosed = true
    run.end()
    hold?.cancel()
    wash?.cancel()
    listening.forEach(stop => stop())
    leave()
    await looks
  }

  return { open, giveBack }
}

/**
 * The panel on the terminal, until it is left, told to end or its terminal
 * hangs up: how it ended. A failure is thrown once the terminal is given
 * back.
 */
export const panel = async (io: Io, terminal: Terminal): Promise<Closed> => {
  const drawn = live(io, terminal)

  try {
    return await drawn.open()
  } finally {
    await drawn.giveBack()
  }
}
