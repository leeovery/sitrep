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

declare const process: {
  cwd(): string
  /** The program running: Bun's own, or the binary `bun build --compile` made. */
  readonly execPath: string
  /** The id of the process that started this one, as it stands: launchd's, once that one has gone. */
  readonly ppid: number
  exitCode: number | undefined
  /** Ends the run now, with this exit code. */
  exit(code: number): never
  on(event: 'SIGTERM', listener: () => void): void
  off(event: 'SIGTERM', listener: () => void): void
  stdin: {
    /** True on a terminal; undefined on a pipe or a file. */
    readonly isTTY: boolean | undefined
    setEncoding(encoding: 'utf8'): void
    on(event: 'data', listener: (text: string) => void): void
    off(event: 'data', listener: (text: string) => void): void
    pause(): void
  }
  stdout: {
    write(text: string): boolean
    on(event: 'error', listener: () => void): void
    off(event: 'error', listener: () => void): void
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
