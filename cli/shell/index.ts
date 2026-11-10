/**
 * The CLI bound to Bun: the file system, the environment and the folder it
 * runs in, the clocks and waiting on them, random bytes, standard input,
 * standard output and error and when the run is to end, the plugin's
 * manifest, and the exit code. bin/sitrep runs it.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { appendFile, mkdir } from 'node:fs/promises'
import { endOf, type Signals } from '../ending'
import type { Io, Listed, Waiting } from '../io'
import { main } from '../main'

/** Errors a listing means "not there" by: the folder is missing, or is a file. */
const ABSENT = ['ENOENT', 'ENOTDIR']

const folderOf = (path: string) => path.slice(0, path.lastIndexOf('/'))

/**
 * The plugin's manifest: from this file's folder, `cli/shell`, run on Bun;
 * from the binary's, `bin`, compiled by `bun build --compile` (the copy the
 * app carries), where this file's folder is one inside the binary.
 */
const MANIFEST = import.meta.dir.startsWith('/$bunfs/')
  ? `${folderOf(process.execPath)}/../.claude-plugin/plugin.json`
  : `${import.meta.dir}/../../.claude-plugin/plugin.json`

/** The program that started the run, as the CLI loads: before anything could miss it going. */
const PARENT = process.ppid

const hasCode = (error: unknown, codes: readonly string[]) =>
  typeof error === 'object' && error !== null && codes.includes(String(Reflect.get(error, 'code')))

const isAbsent = (error: unknown) => hasCode(error, ABSENT)

/** Lets an error with one of the codes pass, as one that leaves things as wanted; throws any other. */
const allowing =
  (codes: readonly string[]) =>
  (error: unknown): void => {
    if (!hasCode(error, codes)) {
      throw error
    }
  }

/*
 * A listing, a stat and a read are made at once, not through a promise's
 * round trip to a thread: `watch` looks every second, a look is mostly
 * these, and each costs about a tenth (measured on Bun 1.4: a stat 2µs of
 * CPU in place of 26, a listing 17 in place of 46).
 */

const statOf = async (path: string) => {
  try {
    const found = statSync(path, { throwIfNoEntry: false })

    return found === undefined ? undefined : { size: found.size, mtimeMs: found.mtimeMs }
  } catch (error) {
    allowing(ABSENT)(error)

    return undefined
  }
}

const append = async (path: string, text: string) => {
  await mkdir(folderOf(path), { recursive: true })
  await appendFile(path, text)
}

const list = async (dir: string): Promise<Listed[]> => {
  try {
    return readdirSync(dir, { withFileTypes: true }).flatMap((entry): Listed[] => {
      if (entry.isDirectory()) {
        return [{ name: entry.name, kind: 'dir' }]
      }

      return entry.isFile() ? [{ name: entry.name, kind: 'file' }] : []
    })
  } catch (error) {
    if (isAbsent(error)) {
      return []
    }

    throw error
  }
}

const wait = (ms: number): Waiting => {
  let timer: ReturnType<typeof setTimeout> | undefined
  const waited = new Promise<void>(resolve => {
    timer = setTimeout(resolve, ms)
  })

  return Object.assign(waited, { cancel: () => clearTimeout(timer) })
}

/** Pausing standard input once nothing listens lets the run end with the pipe still open (probed on Bun 1.4.3). */
const input = (heard: (text: string) => void) => {
  if (process.stdin.isTTY === true) {
    return () => {}
  }

  process.stdin.setEncoding('utf8')
  process.stdin.on('data', heard)

  return () => {
    process.stdin.off('data', heard)
    process.stdin.pause()
  }
}

const signals: Signals = {
  parent: () => process.ppid,
  onTerm: heard => {
    process.on('SIGTERM', heard)

    return () => process.off('SIGTERM', heard)
  },
  onOutputFailed: heard => {
    process.stdout.on('error', heard)

    return () => process.stdout.off('error', heard)
  },
  every: (ms, tick) => {
    const timer = setInterval(tick, ms)

    return () => clearInterval(timer)
  },
}

const io: Io = {
  fs: {
    read: async path => readFileSync(path, 'utf8'),
    list,
    stat: statOf,
    append,
  },
  env: Bun.env,
  cwd: process.cwd(),
  now: () => Date.now(),
  uptime: () => performance.now(),
  wait,
  random: count => crypto.getRandomValues(new Uint8Array(count)),
  input,
  out: text => void process.stdout.write(text),
  err: text => void process.stderr.write(text),
  ending: () => endOf(signals, PARENT),
  manifest: MANIFEST,
}

/** Runs the CLI on the words it was given, and exits as it ends. */
export const shell = async () => {
  process.exitCode = await main(Bun.argv.slice(2), io)
}
