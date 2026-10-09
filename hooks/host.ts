/**
 * What sitrep asks of the host: its file system, clock, session and
 * environment, its display and prompt, and the mod's values in `$.state`.
 * Each is a call on a hook's `$`, bound in register.tsx: the engine reads a
 * hooks module's calls off its source and never follows `$` across an
 * import, so the other modules are handed this in its place.
 *
 * Also what follows from the host: where sitrep's folder is, the folder the
 * session started in, which writer this window is, and random bytes.
 */
import type {
  FsEntry,
  PaneOpenArgs,
  PromptSubmitResult,
  Timer,
  ToastOptions,
  UiOpenResult,
  UiPane,
} from 'claude-code'
import { rootOf, type Random } from '../core'
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepBoard,
  SitrepInFlight,
  SitrepOther,
  SitrepPane,
  SitrepProject,
  SitrepPulse,
  SitrepQueued,
  SitrepScroll,
  SitrepSent,
} from '../types'

/** One of the mod's values in `$.state`. */
export type Slot<T> = {
  read: () => Promise<T>
  write: (value: T) => Promise<unknown>
  /** Writes what `change` makes of the value as it stands, again should another write land first. */
  update: (change: (value: T) => T) => Promise<unknown>
}

/** How long a toast stays unless it says otherwise: long enough to read it through. */
export const TOAST_MS = 10_000

export type Host = {
  fs: {
    read: (path: string) => Promise<string>
    /** Writes the whole file, making its folders as needed. */
    write: (path: string, text: string) => Promise<void>
    list: (dir: string) => Promise<FsEntry[]>
    exists: (path: string) => Promise<boolean>
  }
  clock: {
    now: () => Promise<number>
    after: (ms: number, task: () => void) => Timer
    every: (ms: number, task: () => void) => Timer
  }
  session: {
    id: () => Promise<string>
    cwd: () => Promise<string>
  }
  env: () => Promise<{ XDG_STATE_HOME?: string; HOME?: string }>
  /** Writes a line to the debug log. */
  log: (text: string) => void
  ui: {
    toast: (text: string, options?: ToastOptions) => void
    open: (pane: PaneOpenArgs) => Promise<UiOpenResult>
    close: (id: string) => Promise<void>
    /** The mod's own open panes, as the engine records them. */
    panes: () => Promise<readonly UiPane[]>
    /** Draws the mod's panes and band again, from what has changed outside `$.state`. */
    redraw: () => void
    /** Plays a sound file of the mod's, by its path in the mod's folder. */
    play: (asset: string) => Promise<void>
  }
  prompt: {
    /** Submits text as Lee's own message: the prompt that entered, or why it did not. */
    submit: (text: string) => Promise<PromptSubmitResult>
    /** What Lee's prompt box holds: the draft, a paste in it whole. */
    read: () => Promise<string>
    /** Puts text in Lee's prompt box, over what it held. */
    fill: (text: string) => Promise<unknown>
    /** Empties Lee's prompt box. */
    clear: () => Promise<unknown>
  }
  state: {
    attachment: Slot<SitrepAttachment | null>
    board: Slot<SitrepBoard | null>
    seen: Slot<string | null>
    projects: Slot<SitrepProject[]>
    others: Slot<SitrepOther[]>
    queue: Slot<SitrepQueued[]>
    sent: Slot<SitrepSent[]>
    inFlight: Slot<SitrepInFlight | null>
    pane: Slot<SitrepPane>
    scroll: Slot<SitrepScroll | null>
    answering: Slot<SitrepAnswering | null>
    pulse: Slot<SitrepPulse>
    flash: Slot<number>
    tick: Slot<number>
  }
}

/** Where a window stands as it starts or joins a piece of work. */
export type Bearings = {
  root: string
  /** The session's working directory: where a work it starts was started, and which projects it lists first. */
  cwd: string
  /** The session's id: the window's own file and heartbeat in a work. */
  writer: string
}

export const random: Random = count => crypto.getRandomValues(new Uint8Array(count))

export const rootFor = async (host: Host) => rootOf(await host.env())

export const bearingsOf = async (host: Host): Promise<Bearings> => ({
  root: await rootFor(host),
  cwd: await host.session.cwd(),
  writer: await host.session.id(),
})

/** Writes to the debug log what failed where nothing waits on it, as a timer's work. */
export const logFailure = (host: Host, what: string) => (error: unknown) =>
  host.log(`sitrep: ${what} failed: ${error instanceof Error ? error.message : String(error)}`)
