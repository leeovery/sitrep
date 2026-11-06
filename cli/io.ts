/**
 * What the CLI asks of the world: its file system, the environment and the
 * folder it runs in, the clocks and waiting on them, random bytes, standard
 * input, somewhere to print and when that is gone, the plugin's manifest,
 * and, for the jump, programs to run.
 * cli/shell binds it to Bun; a test binds it to memory, with a fake tmux and
 * Ghostty.
 *
 * The file system appends and never rewrites: the CLI's file may be written
 * by another run of it at the same moment, and an append keeps both runs'
 * lines whole.
 */
import type { Random } from '../core'

/** A folder's entry, as its listing gives it. */
export type Listed = { name: string; kind: 'file' | 'dir' }

/** A file's size and when it was last written; a folder's when an entry was last made, removed or renamed in it. */
export type Stat = { size: number; mtimeMs: number }

export type Env = { XDG_STATE_HOME?: string; HOME?: string; SITREP_SESSION?: string }

/** How a program ran: its exit code, whatever it was, and what it printed. */
export type Ran = { exitCode: number; stdout: string; stderr: string }

/** What `run` rejects with for a program given a limit that had not ended by then, and was killed. */
export class TimedOut extends Error {
  constructor(program: string, limitMs: number) {
    super(`${program} did not end within ${limitMs}ms`)
  }
}

/** A wait under way: it resolves once its time has passed, unless `cancel` lets it go first, its timer with it, never to resolve. */
export type Waiting = Promise<void> & { cancel: () => void }

/** A run's end as listened for: `ended` resolves once it is to end; `stop` stops the listening, as the run ends some other way, so nothing holds it open after. */
export type Ending = { ended: Promise<void>; stop: () => void }

export type Io = {
  fs: {
    /** A file's text; rejects when it is not there. */
    read: (path: string) => Promise<string>
    /** A folder's files and folders; none while it is not there. */
    list: (dir: string) => Promise<Listed[]>
    /** A file's or a folder's size and time; undefined while it is not there. */
    stat: (path: string) => Promise<Stat | undefined>
    /** Adds the text to the end of the file, making the file and its folder if need be. */
    append: (path: string, text: string) => Promise<void>
  }
  env: Env
  /** The folder the CLI runs in: which projects `list` gives first. */
  cwd: string
  now: () => number
  /** Milliseconds by a clock that does not run while the Mac sleeps, from some start: what tells `watch` a sleep from a stall. */
  uptime: () => number
  /** Waits `ms` milliseconds: the pause between the jump's looks at which app is in front, and between `watch`'s looks. */
  wait: (ms: number) => Waiting
  random: Random
  /**
   * Listens to standard input, hearing its text as it comes, in whatever
   * pieces, and nothing of its end; nothing while it is a terminal. Asked
   * only by `watch`, which stops the listening however it ends. Gives what
   * stops it.
   */
  input: (heard: (text: string) => void) => () => void
  /** Writes to standard output, as given. */
  out: (text: string) => void
  /** Writes to standard error, as given. */
  err: (text: string) => void
  /**
   * Listens for the run's end: what reads its standard output has gone, as
   * when the program that started it quit or a write found it closed, or it
   * was told to end (SIGTERM). Asked only by `watch`, which runs until then
   * and stops the listening however it ends (ending.ts).
   */
  ending: () => Ending
  /** Where the plugin's manifest is, `.claude-plugin/plugin.json`, in the copy of the plugin the CLI runs from: it says the version the CLI runs. */
  manifest: string
  /**
   * Runs a program by its words, no shell between. Rejects when it cannot
   * start, or, given `limitMs`, when it has not ended by then: it is
   * killed, and the rejection is a `TimedOut`.
   */
  run: (command: readonly string[], limitMs?: number) => Promise<Ran>
}
