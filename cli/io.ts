/**
 * What the CLI asks of the world: its file system, the environment and the
 * folder it runs in, the clock and waiting on it, random bytes, somewhere to
 * print, and, for the jump, programs to run and terminal devices to write
 * to. cli/shell binds it to Bun; a test binds it to memory, with a fake
 * tmux and Ghostty.
 *
 * The file system appends and never rewrites: the CLI's file may be written
 * by another run of it at the same moment, and an append keeps both runs'
 * lines whole. It moves and removes files only to bring the old layout into
 * today's, and never over another file, so a writer's file landing at the
 * same moment is never lost.
 */
import type { Random } from '../core'

/** A folder's entry, as its listing gives it. */
export type Listed = { name: string; kind: 'file' | 'dir' }

export type Env = { XDG_STATE_HOME?: string; HOME?: string; SITREP_SESSION?: string }

/** How a program ran: its exit code, whatever it was, and what it printed. */
export type Ran = { exitCode: number; stdout: string; stderr: string }

export type Io = {
  fs: {
    /** A file's text; rejects when it is not there. */
    read: (path: string) => Promise<string>
    /** A folder's files and folders; none while it is not there. */
    list: (dir: string) => Promise<Listed[]>
    /** Adds the text to the end of the file, making the file and its folder if need be. */
    append: (path: string, text: string) => Promise<void>
    /**
     * Moves a file to `to`, making its folder, where no file is there, never
     * over one: false, moving nothing, when one is. True, too, for a file
     * already gone, as another run moving it at once leaves it.
     */
    moveIn: (from: string, to: string) => Promise<boolean>
    /** Removes a file; one already gone is fine. */
    remove: (path: string) => Promise<void>
    /** Removes a folder once it is empty; one that is not, or is gone, is left. */
    removeFolder: (dir: string) => Promise<void>
  }
  env: Env
  /** The folder the CLI runs in: which projects `list` gives first. */
  cwd: string
  now: () => number
  /** Resolves once `ms` milliseconds have passed: the pause between the jump's looks at which app is in front. */
  wait: (ms: number) => Promise<void>
  random: Random
  /** Writes to standard output, as given. */
  out: (text: string) => void
  /** Writes to standard error, as given. */
  err: (text: string) => void
  /**
   * Runs a program by its words, no shell between. Rejects when it cannot
   * start, or, given `limitMs`, when it has not ended by then: it is killed.
   */
  run: (command: readonly string[], limitMs?: number) => Promise<Ran>
  /** Writes the text to a terminal device, as a program running on it would print it; rejects when the device is gone, and never makes a file. */
  writeTo: (device: string, text: string) => Promise<void>
}
