/**
 * What the CLI asks of the world: its file system, the environment and the
 * folder it runs in, git, the clock, random bytes, and somewhere to print.
 * cli/shell binds it to Bun; a test binds it to memory.
 *
 * The file system appends and never rewrites: the CLI's file may be written
 * by another run of it at the same moment, and an append keeps both runs'
 * lines whole.
 */
import type { Random } from '../core'

/** A folder's entry, as its listing gives it. */
export type Listed = { name: string; kind: 'file' | 'dir' }

export type Env = { XDG_STATE_HOME?: string; HOME?: string; SITREP_WORK?: string }

export type Io = {
  fs: {
    /** A file's text; rejects when it is not there. */
    read: (path: string) => Promise<string>
    /** A folder's files and folders; none while it is not there. */
    list: (dir: string) => Promise<Listed[]>
    /** Adds the text to the end of the file, making the file if need be. */
    append: (path: string, text: string) => Promise<void>
  }
  env: Env
  /** The folder the CLI runs in. */
  cwd: string
  /** Runs a command by its argument vector in `cwd`; rejects when it cannot run at all. */
  run: (argv: readonly string[], cwd: string) => Promise<{ exitCode: number; stdout: string }>
  now: () => number
  random: Random
  /** Writes to standard output, as given. */
  out: (text: string) => void
  /** Writes to standard error, as given. */
  err: (text: string) => void
}
