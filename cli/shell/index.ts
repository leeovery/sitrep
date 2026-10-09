/**
 * The CLI bound to Bun: the file system, the environment and the folder it
 * runs in, the clock, random bytes, standard output and error, and the exit
 * code. bin/sitrep runs it.
 */
import { appendFile, readdir } from 'node:fs/promises'
import type { Io, Listed } from '../io'
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
}

/** Runs the CLI on the words it was given, and exits as it ends. */
export const shell = async () => {
  process.exitCode = await main(Bun.argv.slice(2), io)
}
