/**
 * What sitrep asks of the host: its file system, clock, conversation and
 * environment, the terminal it runs in, its display and prompt, and the
 * mod's values in `$.state`.
 * Each is a call on a hook's `$`, bound in register.tsx: the engine reads a
 * hooks module's calls off its source and never follows `$` across an
 * import, so the other modules are handed this in its place.
 *
 * Also what follows from the host: where sitrep's folder is, the folder the
 * window started in, which writer this window is, and random bytes.
 */
import type {
  FsEntry,
  PaneOpenArgs,
  ProcessRunResult,
  PromptSubmitResult,
  Timer,
  ToastOptions,
  UiOpenResult,
  UiPane,
} from 'claude-code'
import { rootOf, type Random, type WhereEnv } from '../core'
import type {
  SitrepActivity,
  SitrepAnswering,
  SitrepAttachment,
  SitrepBoard,
  SitrepInFlight,
  SitrepNamed,
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

/** One of the mod's values in `$.state`, read with the version it stands at, and written only while it stands at the version given. */
export type Versioned<T> = {
  /** The value, undefined never written, and its version, 0 then. */
  get: () => Promise<{ value: T | undefined; version: number }>
  /** Writes `value` while the value stands at `version`: whether it did, and the version it stands at. */
  set: (value: T, version: number) => Promise<{ isSet: boolean; version: number }>
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
  conversation: {
    id: () => Promise<string>
    cwd: () => Promise<string>
  }
  env: () => Promise<{ XDG_STATE_HOME?: string; HOME?: string }>
  /** What tells where this window is: read only as it attaches. */
  terminal: {
    env: () => Promise<WhereEnv>
    /** Walks up from a shell Claude Code starts to the first process with a terminal: the tty name it printed (`ttys043`), if any, and how it exited. */
    tty: () => Promise<Pick<ProcessRunResult, 'exitCode' | 'stdout' | 'stderr'>>
  }
  /** The plugin as the engine loaded it. */
  plugin: {
    /** Its manifest's text, as it stands on disk. */
    manifest: () => Promise<string>
  }
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
    /** Puts the engine's window over the board at the board's top. */
    toTop: () => Promise<unknown>
  }
  prompt: {
    /** Submits text as Lee's own message: the prompt that entered, or why it did not. */
    submit: (text: string) => Promise<PromptSubmitResult>
    /** What Lee's prompt box holds, as typed: a long paste in it is its placeholder (`[Pasted text #1 +4 lines]`, live), its text only in the prompt submitted (hooks/paste.ts). */
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
    named: Slot<SitrepNamed[]>
    activity: Versioned<SitrepActivity>
  }
}

/** Where a window stands as it starts or joins a session. */
export type Bearings = {
  root: string
  /** The window's working directory: where a session it starts was started, and which projects it lists first. */
  cwd: string
  /** Claude Code's session id: the window's own file and heartbeat in a session. */
  writer: string
}

export const random: Random = count => crypto.getRandomValues(new Uint8Array(count))

export const rootFor = async (host: Host) => rootOf(await host.env())

export const bearingsOf = async (host: Host): Promise<Bearings> => ({
  root: await rootFor(host),
  cwd: await host.conversation.cwd(),
  writer: await host.conversation.id(),
})

/** Writes to the debug log what failed where nothing waits on it, as a timer's work. */
export const logFailure = (host: Host, what: string) => (error: unknown) =>
  host.log(`sitrep: ${what} failed: ${error instanceof Error ? error.message : String(error)}`)
