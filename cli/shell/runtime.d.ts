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
  file(path: string): { text(): Promise<string> }
  spawn(
    command: readonly string[],
    options: { stdin: 'ignore'; stdout: 'pipe'; stderr: 'pipe' },
  ): BunChild
}

declare const process: {
  cwd(): string
  exitCode: number | undefined
  stdout: { write(text: string): boolean }
  stderr: { write(text: string): boolean }
}

declare module 'node:fs' {
  export const constants: { readonly O_WRONLY: number; readonly O_NOCTTY: number }
}

declare module 'node:fs/promises' {
  export function readdir(path: string, options: { withFileTypes: true }): Promise<BunEntry[]>
  export function appendFile(path: string, text: string): Promise<void>
  export function open(path: string, flags: number): Promise<FileHandle>
  export function mkdir(path: string, options: { recursive: true }): Promise<string | undefined>
  export function link(existing: string, made: string): Promise<void>
  export function unlink(path: string): Promise<void>
  export function rmdir(path: string): Promise<void>
  export function stat(path: string): Promise<{ mtimeMs: number }>
}
