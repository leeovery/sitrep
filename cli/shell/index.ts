/**
 * The CLI bound to Bun: the file system, the environment and the folder it
 * runs in, the clock and waiting on it, random bytes, standard output and
 * error, programs and terminal devices, and the exit code. bin/sitrep runs
 * it.
 */
import { constants } from 'node:fs'
import { appendFile, link, mkdir, open, readdir, rmdir, unlink } from 'node:fs/promises'
import type { Io, Listed, Ran } from '../io'
import { main } from '../main'

/** Errors a listing means "not there" by: the folder is missing, or is a file. */
const ABSENT = ['ENOENT', 'ENOTDIR']

/** Errors a folder's removal leaves it by: it holds something (macOS says ENOTEMPTY, POSIX allows EEXIST). */
const NOT_EMPTY = ['ENOTEMPTY', 'EEXIST']

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

const folderOf = (path: string) => path.slice(0, path.lastIndexOf('/'))

const append = async (path: string, text: string) => {
  await mkdir(folderOf(path), { recursive: true })
  await appendFile(path, text)
}

/** A hard link, then the old name unlinked: unlike a rename, a link never lands over a file. */
const moveIn = async (from: string, to: string) => {
  await mkdir(folderOf(to), { recursive: true })

  try {
    await link(from, to)
  } catch (error) {
    if (isAbsent(error)) {
      return true
    }

    if (hasCode(error, ['EEXIST'])) {
      return false
    }

    throw error
  }

  await unlink(from).catch(allowing(ABSENT))

  return true
}

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
    append,
    moveIn,
    remove: path => unlink(path).catch(allowing(ABSENT)),
    removeFolder: dir => rmdir(dir).catch(allowing([...ABSENT, ...NOT_EMPTY])),
  },
  env: Bun.env,
  cwd: process.cwd(),
  now: () => Date.now(),
  wait: ms => new Promise(resolve => setTimeout(resolve, ms)),
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
