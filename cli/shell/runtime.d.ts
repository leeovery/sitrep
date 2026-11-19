/**
 * What the shell calls of Bun's runtime, and of Node's that Bun keeps, as
 * Bun 1.4 has them; the web's (crypto, TextEncoder) come from the DOM lib.
 * The plugin keeps no packages, so there is no @types/bun to read them from.
 */

type BunEntry = { name: string; isFile(): boolean; isDirectory(): boolean }

declare const Bun: {
  readonly argv: readonly string[]
  readonly env: Readonly<Record<string, string | undefined>>
}

interface ImportMeta {
  /** The folder of the module's own file. */
  readonly dir: string
}

type ProcessSignal = 'SIGTERM' | 'SIGHUP' | 'SIGCONT'

declare const process: {
  cwd(): string
  /** The program running: Bun's own, or the binary `bun build --compile` made. */
  readonly execPath: string
  readonly pid: number
  /** The id of the process that started this one, as it stands: launchd's, once that one has gone. */
  readonly ppid: number
  exitCode: number | undefined
  /** Ends the run now, with this exit code. */
  exit(code: number): never
  /** Sends a signal to a process: to this one, SIGTSTP stops it, as Ctrl-Z does in a terminal's own mode. */
  kill(pid: number, signal: 'SIGTSTP'): boolean
  on(event: ProcessSignal, listener: () => void): void
  off(event: ProcessSignal, listener: () => void): void
  stdin: {
    /** True on a terminal; undefined on a pipe or a file. */
    readonly isTTY: boolean | undefined
    setEncoding(encoding: 'utf8'): void
    /** A terminal's raw mode: each byte as it is typed, unechoed, Ctrl-C and Ctrl-Z among them. */
    setRawMode(isRaw: boolean): void
    on(event: 'data', listener: (text: string) => void): void
    off(event: 'data', listener: (text: string) => void): void
    on(event: 'error', listener: () => void): void
    off(event: 'error', listener: () => void): void
    resume(): void
    pause(): void
  }
  stdout: {
    /** True on a terminal; undefined on a pipe or a file. */
    readonly isTTY: boolean | undefined
    /** A terminal's width and height, in cells; undefined off one. */
    readonly columns: number | undefined
    readonly rows: number | undefined
    write(text: string): boolean
    on(event: 'error' | 'resize', listener: () => void): void
    off(event: 'error' | 'resize', listener: () => void): void
  }
  stderr: { write(text: string): boolean }
}

declare module 'node:fs' {
  export function readdirSync(path: string, options: { withFileTypes: true }): BunEntry[]
  export function readFileSync(path: string, encoding: 'utf8'): string
  /** Undefined for a path not there, given `throwIfNoEntry: false`. */
  export function statSync(
    path: string,
    options: { throwIfNoEntry: false },
  ): { size: number; mtimeMs: number } | undefined
}

declare module 'node:fs/promises' {
  export function appendFile(path: string, text: string): Promise<void>
  export function mkdir(path: string, options: { recursive: true }): Promise<string | undefined>
}
