/**
 * What the checker calls of Bun's runtime, and of Node's that Bun keeps, as
 * Bun 1.4 has them. The plugin keeps no packages, so there is no @types/bun
 * to read them from.
 */

interface ImportMeta {
  /** The folder of the module's own file. */
  readonly dir: string
}

declare const process: {
  readonly argv: readonly string[]
  /** `TZ` set here sets the zone every `Date` after reads in. */
  env: Record<string, string | undefined>
  exitCode: number | undefined
  stdout: { write(text: string): boolean }
}

declare module 'node:fs' {
  export function readdirSync(path: string): string[]
  export function readFileSync(path: string, encoding: 'utf8'): string
  export function writeFileSync(path: string, text: string): void
  export function unlinkSync(path: string): void
  export function existsSync(path: string): boolean
  export function mkdirSync(path: string, options: { recursive: true }): void
}
