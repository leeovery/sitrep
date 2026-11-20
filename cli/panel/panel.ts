/**
 * The panel: bare `sitrep` on a terminal, the board drawn on the alternate
 * screen and kept current until it is left.
 *
 * - Opening, it hears the keys, raw mode on, then asks the terminal's
 *   colours, so a key typed before the answer comes is read, and the answer
 *   never is: the key reader passes it over. Then it enters the screen,
 *   reading the size again, since a resize while it asked goes unheard, and
 *   looks at the board every second as `watch` does (looks.ts), in its own
 *   process.
 * - Its first draw waits for the first look, up to 300 ms, so `Looking for
 *   sessions…` never flashes up before a board read at once.
 * - It steps its state (state.ts) on every look, key and resize, and at a
 *   new ask's wash's end, then draws, writing only the rows that changed. A
 *   look that finds the board as it stood moves the clock alone, so the
 *   times turn over with the minute. A resize to the size it had redraws
 *   nothing.
 * - It never ends on a look: one that fails keeps the last board, stale,
 *   or says why the board can't be read before any.
 * - Ctrl-Z gives the terminal back and stops it, then takes the terminal
 *   back as the stop returns: on `fg`, or at once in a process group no
 *   shell controls, where the stop is lost. That stop's own SIGCONT does
 *   nothing more. A SIGCONT after a stop from outside, which leaves the
 *   terminal to the shell, cooked, takes it back. Taking it back reads the
 *   size again, since a resize made while stopped goes to the shell.
 * - However it ends, it gives the terminal back first: `q` and Ctrl-C as
 *   done; SIGHUP, or the terminal gone without one, as hung up; SIGINT,
 *   SIGQUIT and SIGTERM from outside as each says. Its writes are tried
 *   though the terminal may be gone, and every wait it set is let go. A
 *   thrown error is thrown on once the terminal is given back. The signals
 *   that end it are heard from the first: one during the colour query lets
 *   the query go at once, never waiting out its answer.
 * - A pick, ⏎ or a tap on the band's row, one at a time: what the session's
 *   window can reach (reach.ts), then the resume command readied by the
 *   edge (edge.ts). Refused, it says why in the pick's answer. Else the
 *   terminal is handed over: given back as for a stop, then handed to the
 *   login shell. SIGINT and SIGQUIT are the program's meanwhile, as is a
 *   SIGCONT, Ctrl-Z stopping the panel with it; SIGTERM and SIGHUP still
 *   end the panel, taking nothing back, though the run ends only once the
 *   program does, which keeps it alive, so the terminal never goes to the
 *   shell under the program. It keeps looking at the board, drawing
 *   nothing, and takes the terminal back as the program ends, drawn whole
 *   from the latest board, the band where it was, with what the pick leaves
 *   to say. Nothing else takes it back meanwhile, a
 *   Ctrl-Z's take-back pressed while the pick was readied among them.
 * - At every look it reads SitRep's `here.json` too, the board changed,
 *   unchanged or not read at all, and draws hollow and dimmed each held
 *   session open on no device it is looked at from (core's here.ts): on
 *   the Mac, those the notch dims; over SSH, those not open on that phone.
 *   Where it is looked at from is read once, as it opens: its own tty, and
 *   its own `SSH_CONNECTION`. With no file, or a stale one, as with SitRep
 *   not running, every held session draws filled.
 * - Each ask new on a look's board posts a terminal notification
 *   (notices.ts), unless the run turned them off: a write each, after the
 *   look's frame, so never inside one. A look while a program has the
 *   terminal, or while it draws `Too small`, posts them as any does. The
 *   first board posts none, since core's `newRows` finds nothing new on it.
 *   What landed while looks failed posts at the next good one, once each.
 *   A look whose reads end after the panel closed is dropped, so nothing
 *   reaches the shell after the terminal is given back.
 */
import { hereFile, newRows, notHereOf, ownTime, rootOf, type Feed, type Lookout, type Shown } from '../../core'
import { textAt } from '../files'
import { KEYED, type Io, type Signal, type Terminal } from '../io'
import { looking, untilEnded, type Look } from '../looks'
import type { Size } from './cells'
import { COLOUR_QUERY, paintOf } from './colours'
import { ansi, draw } from './draw'
import { handed, readied } from './edge'
import { keysOf, type Key } from './keys'
import { levelOf, type Paint } from './paint'
import { noticesOf } from './notices'
import { reachOf } from './reach'
import { ENTER, LEAVE, repaint } from './screen'
import { opening, step, type PanelEvent } from './state'
import { cleaned, NEW_MS, viewOf } from './view'

/** How the panel ended: left by its keys, or by a signal, its terminal gone among them. */
export type Closed = 'done' | 'hungUp' | 'interrupted' | 'quit' | 'terminated'

/** What the run's flags set: whether a new ask posts a notification, as it does unless `--no-notify` says not. */
export type PanelOptions = { isNotifying: boolean }

/** How long the first draw waits for the first look. */
export const HOLD_MS = 300

/** How long a lone ESC waits for the rest of a sequence. */
export const ESC_MS = 50

/** The signals that end the panel, and how each ends it. */
const ENDINGS: readonly (readonly [Signal, Closed])[] = [
  ['SIGHUP', 'hungUp'],
  ['SIGINT', 'interrupted'],
  ['SIGQUIT', 'quit'],
  ['SIGTERM', 'terminated'],
]

/** The size laid out at while the terminal says none. */
const UNSIZED: Size = { width: 80, height: 24 }

/** The sessions on the board open on no device the panel is looked at from: none known, until SitRep says. */
const NOT_HERE: ReadonlySet<string> = new Set()

/** The sessions SitRep's `here.json` says are open on no device the panel is looked at from at `now`; none while SitRep says nothing. */
const notHereAt = async (io: Io, now: number, lookout: Lookout) =>
  notHereOf(await textAt(io, hereFile(rootOf(io.env))), now, lookout)

const isSameSet = (a: ReadonlySet<string>, b: ReadonlySet<string>) =>
  a.size === b.size && [...a].every(each => b.has(each))

/** Why a look failed, as a sentence, as the app words it, made harmless for the terminal. */
const reasonOf = (error: unknown) => {
  const message = cleaned(error instanceof Error ? error.message : String(error))

  return /[.!?]$/.test(message) ? message : `${message}.`
}

const sizeOf = (terminal: Terminal) => terminal.size() ?? UNSIZED

const isSameSize = (a: Size, b: Size) => a.width === b.width && a.height === b.height

/** The run's end, as the panel's looks hear it: only the panel ends them, as it closes, never a signal of their own. */
const byThePanel = () => ({ ended: new Promise<void>(() => {}), stop: () => {} })

/** Something to do once `ms` have passed, unless let go first by what it gives. */
type Later = (ms: number, act: () => void) => () => void

/**
 * The keys in bytes as they come: a sequence cut short held for the next
 * bytes, and read as all there is once ESC_MS pass with nothing more, so a
 * lone ESC is `esc`.
 */
const keyReader = (later: Later, pressed: (key: Key) => void) => {
  let rest = ''
  let letQuietGo = () => {}

  const read = (bytes: string, isQuiet: boolean) => {
    letQuietGo()

    const found = keysOf(rest + bytes, isQuiet)

    rest = found.rest
    letQuietGo = !isQuiet && rest !== '' ? later(ESC_MS, () => read('', true)) : () => {}
    found.keys.forEach(pressed)
  }

  return {
    heard: (bytes: string) => read(bytes, false),
    stop: () => {
      letQuietGo()
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
const live = (io: Io, terminal: Terminal, { isNotifying }: PanelOptions) => {
  const closing = closer()
  const run = untilEnded({ ...io, ending: byThePanel })
  const lookout: Lookout = { tty: terminal.device(), sshConnection: io.env.SSH_CONNECTION }
  const listening: (() => void)[] = []
  const waiting = new Set<() => void>()
  let paint: Paint = { level: levelOf(io.env) }
  let state = opening(sizeOf(terminal), io.now(), NOT_HERE)
  let isClosed = false
  let isHeld = true
  let isOnScreen = false
  let onScreen: string[] | undefined
  let stopKeys = () => {}
  let shown: Shown | undefined
  /**
   * The panel's own stop's SIGCONT is yet to come, the terminal taken back
   * already as the stop returned. In a process group no shell controls the
   * stop is lost and none comes, so the next SIGCONT is taken for it: only
   * a SIGSTOP stops such a group, and nothing takes its terminal meanwhile.
   */
  let isWaking = false
  /** A pick is under way, from ⏎ until it is answered or the program it ran ends. */
  let isPicking = false
  /** A program has the terminal. */
  let isHanded = false
  let letHoldGo = () => {}
  let letWashGo = () => {}
  let looks: Promise<unknown> = Promise.resolve()

  const close = (closed: Closed) => {
    isClosed = true
    closing.close(closed)
  }

  const fail = (error: unknown) => {
    isClosed = true
    closing.fail(error)
  }

  const guard = (act: () => void) => {
    try {
      if (!isClosed) {
        act()
      }
    } catch (error) {
      fail(error)
    }
  }

  /** A signal that ends the panel, but for one a terminal's keys send while a program has the terminal. */
  const ended = (signal: Signal, closed: Closed) => {
    if (!(isHanded && KEYED.has(signal))) {
      close(closed)
    }
  }

  /** Acts, guarded, once `ms` have passed; each wait kept until it acts or is let go, so closing lets every one go. */
  const later: Later = (ms, act) => {
    const wait = io.wait(ms)
    const letGo = () => {
      waiting.delete(letGo)
      wait.cancel()
    }

    waiting.add(letGo)
    void wait.then(() => {
      waiting.delete(letGo)
      guard(act)
    })

    return letGo
  }

  /** The clock stepped at the earliest wash's end, NEW_MS from its line's first showing. */
  const washing = () => {
    const first = Math.min(...state.arrivals.values())

    letWashGo()
    letWashGo = Number.isFinite(first) ? later(first + NEW_MS - io.now(), () => apply({ tick: io.now() })) : () => {}
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

    const { state: next, open } = step(state, { key })

    state = next

    if (key.kind === 'quit') {
      close('done')
    } else if (key.kind === 'suspend') {
      suspend()
    } else {
      frame()
      pick(open)
    }
  }

  const reader = keyReader(later, pressed)

  /** The keys heard, raw mode set afresh, as a stop from outside leaves it to the shell, cooked. */
  const listen = () => {
    stopKeys()
    stopKeys = terminal.keys(bytes => guard(() => reader.heard(bytes)))
  }

  const enter = () => {
    isOnScreen = true
    onScreen = undefined
    terminal.write(ENTER)
  }

  /** The terminal given back: the screen left, where it was entered, then raw mode let go and the keys no more heard. */
  const release = () => {
    try {
      if (isOnScreen) {
        isOnScreen = false
        terminal.write(LEAVE)
      }
    } finally {
      stopKeys()
      stopKeys = () => {}
      reader.stop()
    }
  }

  /** The terminal taken back, as after a stop, unless a program has it: the keys heard, the screen entered, its size read again, and drawn whole. */
  const takeBack = () => {
    if (isHanded) {
      return
    }

    listen()
    enter()
    state = step(state, { size: sizeOf(terminal) }).state
    frame()
  }

  /**
   * Ctrl-Z, once the screen is taken: the terminal given back, the run
   * stopped, and the terminal taken back as the stop returns, a macrotask
   * on, so a SIGTERM or SIGHUP sent with the SIGCONT closes the panel first.
   */
  const suspend = () => {
    if (!isOnScreen) {
      return
    }

    release()
    isWaking = true
    terminal.suspend()
    later(0, takeBack)
  }

  /** SIGCONT, a macrotask on, as Ctrl-Z's take-back is: nothing for the panel's own stop, taken back already; a stop from outside taken back. */
  const continued = () => {
    later(0, () => {
      if (isWaking) {
        isWaking = false
      } else {
        takeBack()
      }
    })
  }

  /**
   * The terminal handed to the login shell, and taken back a macrotask after
   * it ends, unless the panel closed meanwhile, what the pick leaves to say
   * drawn with it: a SIGTERM or SIGHUP sent to the whole job as it ends, as a
   * shell's `kill %1` or a terminal closing sends it, closes the panel first.
   * The keyed signals stay the program's until then.
   */
  const handOver = async (argv: readonly string[], name: string) => {
    release()
    isHanded = true

    const said = await handed(io, terminal, argv, name)

    if (!isClosed) {
      later(0, () => {
        isHanded = false
        state = step(state, { opened: said }).state
        takeBack()
      })
    }
  }

  /** A pick refused, saying why. */
  const refused = (answer: string) => guard(() => apply({ opened: answer }))

  /** The session picked opened, as the window it is carried on from reaches: refused, saying why; or its resume command run, the terminal handed over. */
  const picked = async (feed: Feed, session: string) => {
    const reach = reachOf(session, feed)

    if ('answer' in reach) {
      return refused(reach.answer)
    }

    const argv = await readied(io, terminal, reach.resume)

    if (!argv.ok) {
      refused(argv.error)
    } else if (!isClosed) {
      await handOver(argv.value, reach.resume.name)
    }
  }

  /** The session ⏎ or a tap asks to open, if any, while no other pick is under way. */
  const pick = (session: string | undefined) => {
    const { feed } = state

    if (session === undefined || feed === undefined || isPicking) {
      return
    }

    isPicking = true
    void picked(feed, session).then(() => {
      isPicking = false
    }, fail)
  }

  const resized = () => {
    const size = sizeOf(terminal)

    if (!isSameSize(size, state.size)) {
      onScreen = undefined
      apply({ size })
    }
  }

  const unhold = () => {
    isHeld = false
    letHoldGo()
  }

  /** Each ask new on the board posted, a write each, where the run notifies. */
  const notify = (feed: Feed, news: readonly string[]) => {
    if (isNotifying) {
      noticesOf(feed, news, io.env).forEach(notice => terminal.write(notice))
    }
  }

  /** The sessions open on no device the panel is looked at from stepped in, where SitRep says other than it did; drawn with what is stepped next. */
  const fill = (notHere: ReadonlySet<string>) => {
    if (!isSameSet(notHere, state.notHere)) {
      state = step(state, { notHere }).state
    }
  }

  /**
   * What SitRep says is open on no device the panel is looked at from,
   * read as the look's reads end, the board read or not, so a look that
   * fails still moves the fill; then `act` with it, unless the panel closed
   * meanwhile.
   */
  const withHere = async (act: (notHere: ReadonlySet<string>) => void) => {
    const notHere = await notHereAt(io, io.now(), lookout)

    guard(() => act(notHere))
  }

  /**
   * A look's board, stepped as a board where it changed or the board was
   * stale, the sessions open on no device the panel is looked at from with
   * it, so the band follows its row from where it was drawn; else the clock
   * alone, the fill first, where SitRep says other than it did, so an
   * unchanged board redraws with its new fill.
   */
  const onLook = (look: Look, notHere: ReadonlySet<string>) => {
    unhold()

    if (look.isSame && state.board === 'read') {
      fill(notHere)
      apply({ tick: look.now })

      return
    }

    const feed = look.feed()
    const news = newRows(shown, feed, ownTime(look.clock))

    shown = news.shown
    apply({ board: feed, news: news.news, now: look.now, notHere })
    notify(feed, news.news)
  }

  /** A look, unless the panel closed while its reads were under way. */
  const lookedAt = (look: Look) => withHere(notHere => onLook(look, notHere))

  /** A look that failed: the board kept, stale, or why it can't be read, with the fill as SitRep says it now. */
  const onFailure = async (error: unknown) => {
    await withHere(notHere => {
      unhold()
      fill(notHere)
      apply({ failed: reasonOf(error) })
    })

    return true
  }

  /**
   * The panel opened: closed by a signal from the first, the colour query
   * let go as it closes; its keys heard before it asks the colours, so the
   * tty is never cooked between; then on the screen, at the size the
   * terminal has once the query is answered, watching the board.
   */
  const open = async () => {
    listening.push(...ENDINGS.map(([signal, closed]) => terminal.onSignal(signal, () => ended(signal, closed))))
    listen()

    const asking = terminal.ask(COLOUR_QUERY)

    void closing.closed.then(asking.cancel, asking.cancel)
    paint = paintOf(paint.level, await asking)

    if (!isClosed) {
      listening.push(
        terminal.onSignal('SIGCONT', continued),
        terminal.onResize(() => guard(resized)),
      )
      state = step(state, { size: sizeOf(terminal) }).state
      enter()
      letHoldGo = later(HOLD_MS, () => {
        unhold()
        frame()
      })
      looks = looking(io, run, { seen: lookedAt, endsOnNewVersion: false, isPastFailure: onFailure }).catch(closing.fail)
    }

    return closing.closed
  }

  const giveBack = async () => {
    isClosed = true
    run.end()
    ;[...waiting].forEach(letGo => letGo())
    listening.splice(0).forEach(stop => stop())
    release()
    await looks
  }

  return { open, giveBack }
}

/**
 * The panel on the terminal, until it is left, told to end or its terminal
 * hangs up: how it ended. A failure is thrown once the terminal is given
 * back.
 */
export const panel = async (io: Io, terminal: Terminal, options: PanelOptions): Promise<Closed> => {
  const drawn = live(io, terminal, options)

  try {
    return await drawn.open()
  } finally {
    await drawn.giveBack()
  }
}
