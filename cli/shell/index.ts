/**
 * The CLI bound to Bun: the file system, the environment and the folder it
 * runs in, the clock, random bytes, standard output and error, programs and
 * terminal devices, and the exit code. bin/sitrep runs it.
 */
import { constants } from 'node:fs'
import { appendFile, open, readdir } from 'node:fs/promises'
import type { Io, Listed, Ran } from '../io'
import { main } from '../main'

/** Errors a listing means "not there" by: the folder is missing, or is a file. */
const ABSENT = ['ENOENT', 'ENOTDIR']

const isAbsent = (error: unknown) =>
  typeof error === 'object' && error !== null && ABSENT.includes(String(Reflect.get(error, 'code')))

const list = async (dir: string): Promise<Listed[]> => {
  try {
    return (await readdir(dir, { withFileTypes: true })).flatMap((entry): Listed[] => {
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

const run = async (command: readonly string[], limitMs?: number): Promise<Ran> => {
  const child = Bun.spawn(command, { stdin: 'ignore', stdout: 'pipe', stderr: 'pipe' })
  let isKilled = false
  const timer =
    limitMs === undefined
      ? undefined
      : setTimeout(() => {
          if (child.exitCode === null) {
            isKilled = true
            child.kill()
          }
        }, limitMs)

  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
      child.exited,
    ])

    if (isKilled) {
      throw new Error(`${command[0]} did not end within ${limitMs}ms`)
    }

    return { exitCode, stdout, stderr }
  } finally {
    clearTimeout(timer)
  }
}

/** Opened without O_CREAT, so a device that is gone fails rather than becoming a file; O_NOCTTY, so it never becomes this process's terminal. */
const writeTo = async (device: string, text: string) => {
  const handle = await open(device, constants.O_WRONLY | constants.O_NOCTTY)

  try {
    await handle.writeFile(text)
  } finally {
    await handle.close()
  }
}

const io: Io = {
  fs: {
    read: path => Bun.file(path).text(),
    list,
    append: (path, text) => appendFile(path, text),
  },
  env: Bun.env,
  cwd: process.cwd(),
  now: () => Date.now(),
  random: count => crypto.getRandomValues(new Uint8Array(count)),
  out: text => void process.stdout.write(text),
  err: text => void process.stderr.write(text),
  run,
  writeTo,
}

/** Runs the CLI on the words it was given, and exits as it ends. */
export const shell = async () => {
  process.exitCode = await main(Bun.argv.slice(2), io)
}
