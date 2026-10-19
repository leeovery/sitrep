/**
 * What the shell calls of Bun's runtime, and of Node's that Bun keeps, as
 * Bun 1.4 has them; the web's (crypto, TextEncoder) come from the DOM lib.
 * The plugin keeps no packages, so there is no @types/bun to read them from.
 */

type BunEntry = { name: string; isFile(): boolean; isDirectory(): boolean }

type BunChild = {
  readonly stdout: ReadableStream<Uint8Array>
  readonly stderr: ReadableStream<Uint8Array>
  readonly exited: Promise<number>
  /** Null until it has exited. */
  readonly exitCode: number | null
  kill(): void
}

type FileHandle = { writeFile(text: string): Promise<void>; close(): Promise<void> }

declare const Bun: {
  readonly argv: readonly string[]
  readonly env: Readonly<Record<string, string | undefined>>
  spawn(
    command: readonly string[],
    options: { stdin: 'ignore'; stdout: 'pipe'; stderr: 'pipe' },
  ): BunChild
}

interface ImportMeta {
  /** The folder of the module's own file. */
  readonly dir: string
}

declare const process: {
  cwd(): string
  /** The id of the process that started this one, as it stands: launchd's, once that one has gone. */
  readonly ppid: number
  exitCode: number | undefined
  on(event: 'SIGTERM', listener: () => void): void
  off(event: 'SIGTERM', listener: () => void): void
  stdout: {
    write(text: string): boolean
    on(event: 'error', listener: () => void): void
    off(event: 'error', listener: () => void): void
  }
  stderr: { write(text: string): boolean }
}

declare module 'node:fs' {
  export const constants: { readonly O_WRONLY: number; readonly O_NOCTTY: number }
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
  export function open(path: string, flags: number): Promise<FileHandle>
  export function mkdir(path: string, options: { recursive: true }): Promise<string | undefined>
  export function link(existing: string, made: string): Promise<void>
  export function unlink(path: string): Promise<void>
  export function rename(from: string, to: string): Promise<void>
  export function rmdir(path: string): Promise<void>
}
