/**
 * What the shell calls of Bun's runtime, and of Node's that Bun keeps, as
 * Bun 1.4 has them; the web's (crypto, TextEncoder) come from the DOM lib.
 * The plugin keeps no packages, so there is no @types/bun to read them from.
 */

type BunEntry = { name: string; isFile(): boolean; isDirectory(): boolean }

declare const Bun: {
  readonly argv: readonly string[]
  readonly env: Readonly<Record<string, string | undefined>>
  file(path: string): { text(): Promise<string> }
}

declare const process: {
  cwd(): string
  exitCode: number | undefined
  stdout: { write(text: string): boolean }
  stderr: { write(text: string): boolean }
}

declare module 'node:fs/promises' {
  export function readdir(path: string, options: { withFileTypes: true }): Promise<BunEntry[]>
  export function appendFile(path: string, text: string): Promise<void>
}
