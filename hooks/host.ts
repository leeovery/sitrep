/**
 * What sitrep asks of the host: its file system, clock, session and
 * environment, its display and prompt, and the mod's values in `$.state`.
 * Each is a call on a hook's `$`, bound in register.tsx: the engine reads a
 * hooks module's calls off its source and never follows `$` across an
 * import, so the other modules are handed this in its place.
 *
 * Also what follows from the host: where sitrep's folder is, which project
 * the session works in, which writer this window is, and random bytes.
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
import { projectOf, rootOf, type Project, type Random } from '../core'
import type {
  SitrepAttachment,
  SitrepBoard,
  SitrepDelivering,
  SitrepOther,
  SitrepPane,
  SitrepProject,
  SitrepPulse,
  SitrepQueued,
  SitrepSent,
} from '../types'

/** One of the mod's values in `$.state`. */
export type Slot<T> = {
  read: () => Promise<T>
  write: (value: T) => Promise<unknown>
  /** Writes what `change` makes of the value as it stands, again should another write land first. */
  update: (change: (value: T) => T) => Promise<unknown>
}

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
  /** Runs a command by its argument vector, in `cwd`. */
  run: (argv: readonly string[], cwd: string) => Promise<ProcessRunResult>
  /** Writes a line to the debug log. */
  log: (text: string) => void
  ui: {
    toast: (text: string, options?: ToastOptions) => void
    open: (pane: PaneOpenArgs) => Promise<UiOpenResult>
    close: (id: string) => Promise<void>
    /** The mod's own open panes, as the engine records them. */
    panes: () => Promise<readonly UiPane[]>
    /** Plays a sound file of the mod's, by its path in the mod's folder. */
    play: (asset: string) => Promise<void>
  }
  prompt: {
    /** Submits text as Lee's own message: the prompt that entered, or why it did not. */
    submit: (text: string) => Promise<PromptSubmitResult>
  }
  state: {
    attachment: Slot<SitrepAttachment | null>
    board: Slot<SitrepBoard | null>
    seen: Slot<string | null>
    projects: Slot<SitrepProject[]>
    others: Slot<SitrepOther[]>
    queue: Slot<SitrepQueued[]>
    sending: Slot<SitrepQueued[]>
    sent: Slot<SitrepSent[]>
    delivering: Slot<SitrepDelivering | null>
    pane: Slot<SitrepPane>
    draft: Slot<string>
    pulse: Slot<SitrepPulse>
    flash: Slot<number>
    tick: Slot<number>
  }
}

/** Where a window stands as it starts or joins a piece of work. */
export type Place = {
  root: string
  project: Project
  /** The session's working directory, where a work it starts is started. */
  cwd: string
  /** The session's id: the window's own file and heartbeat in a work. */
  writer: string
}

/** The repository's common dir, which every worktree of it shares. */
const COMMON_DIR = ['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'] as const

export const random: Random = count => crypto.getRandomValues(new Uint8Array(count))

export const rootFor = async (host: Host) => rootOf(await host.env())

/** What a project is known by: its repository's common dir, or outside git the folder itself. */
const identityOf = async (host: Host, cwd: string) => {
  const git = await host.run(COMMON_DIR, cwd).catch(() => undefined)
  const commonDir = git?.exitCode === 0 ? git.stdout.trim() : ''

  return commonDir || cwd
}

export const placeOf = async (host: Host): Promise<Place> => {
  const cwd = await host.session.cwd()

  return {
    root: await rootFor(host),
    project: projectOf(await identityOf(host, cwd)),
    cwd,
    writer: await host.session.id(),
  }
}

/** Writes to the debug log what failed where nothing waits on it, as a timer's work. */
export const logFailure = (host: Host, what: string) => (error: unknown) =>
  host.log(`sitrep: ${what} failed: ${error instanceof Error ? error.message : String(error)}`)
