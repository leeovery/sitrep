/**
 * What the CLI asks of the world: its file system, the environment and the
 * folder it runs in, the clocks and waiting on them, random bytes, standard
 * input, somewhere to print and when that is gone, the plugin's manifest,
 * and the terminal it runs on, if it runs on one. It runs a program only
 * through the terminal, for a pick in the panel (panel/edge.ts). cli/shell
 * binds it to Bun; a test binds it to memory.
 *
 * The file system appends and never rewrites: the CLI's file may be written
 * by another run of it at the same moment, and an append keeps both runs'
 * lines whole.
 */
import type { Random } from '../core'
import type { ColourEnv } from './panel/paint'
import type { Size } from './panel/cells'

/** A folder's entry, as its listing gives it. */
export type Listed = { name: string; kind: 'file' | 'dir' }

/** A file's size and when it was last written; a folder's when an entry was last made, removed or renamed in it. */
export type Stat = { size: number; mtimeMs: number }

/** The environment the CLI reads: where the board is, the home folder SitRep's settings are in, the session a window holds, the login shell a pick runs in, and the terminal's colours. */
export type Env = { XDG_STATE_HOME?: string; HOME?: string; SITREP_SESSION?: string; SHELL?: string } & ColourEnv

/** A wait under way: it resolves once its time has passed, unless `cancel` lets it go first, its timer with it, never to resolve. */
export type Waiting = Promise<void> & { cancel: () => void }

/** A run's end as listened for: `ended` resolves once it is to end; `stop` stops the listening, as the run ends some other way, so nothing holds it open after. */
export type Ending = { ended: Promise<void>; stop: () => void }

/** How a program run apart from the terminal ended, and what it wrote to standard output and error. */
export type Ran = { exit: number; out: string; err: string }

/** The signals the panel answers: its terminal hung up, it is interrupted, told to quit or to end from outside, and it is brought back from a stop. */
export type Signal = 'SIGHUP' | 'SIGINT' | 'SIGQUIT' | 'SIGTERM' | 'SIGCONT'

/**
 * The terminal the CLI runs on, for the panel. Each listening gives what
 * stops it.
 */
export type Terminal = {
  /** The terminal's size, asked afresh, as a resize made while the run was stopped is never heard; undefined while it says none. */
  size: () => Size | undefined
  onResize: (heard: () => void) => () => void
  /** Listens to the keys typed, in raw mode while it listens, hearing their bytes in whatever pieces they come. */
  keys: (heard: (bytes: string) => void) => () => void
  /** Writes to the terminal, as given; a write the terminal has gone from is lost. */
  write: (text: string) => void
  /** Writes the query, ending on DA1's, and gives what the terminal answered before DA1's answer, or by the time it gave up waiting for it. */
  ask: (query: string) => Promise<string>
  /**
   * Gives the terminal to a program, with the CLI's standard input, output
   * and error, until it ends: its exit code, 128 and the signal's number for
   * one a signal ended. SIGINT and SIGQUIT are the program's while it runs,
   * and never end the CLI; SIGTSTP stops the CLI with it, as a job stops
   * whole. Rejects where it could not start.
   */
  hand: (argv: readonly string[]) => Promise<number>
  /** Runs a program apart from the terminal, up to `ms`: its exit code and what it wrote. Rejects where it could not start, or did not end in time, which ends it. */
  run: (argv: readonly string[], ms: number) => Promise<Ran>
  /** Listens for a signal; SIGHUP is heard too as the terminal goes without one, its input ended or failed. */
  onSignal: (signal: Signal, heard: () => void) => () => void
  /** Stops the run, as Ctrl-Z does in a terminal's own mode, returning once it goes on: at once where nothing stops it, as in a process group no shell controls. */
  suspend: () => void
}

export type Io = {
  fs: {
    /** A file's text; rejects when it is not there. */
    read: (path: string) => Promise<string>
    /** A file's bytes, as a binary one holds them; rejects when it is not there. */
    bytes: (path: string) => Promise<Uint8Array>
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
  /** Waits `ms` milliseconds: the pause between `watch`'s looks. */
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
  /** The terminal the CLI runs on: absent unless its standard input and output are both one. */
  terminal?: Terminal
}
