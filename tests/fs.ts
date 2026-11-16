/**
 * A file system in memory: its files by path, and what the folders hold as
 * the files under them imply it. The mod's world and the CLI's each keep one.
 */
export type File = { text: string; mtimeMs: number }

export const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

/** The files and folders directly in `dir`, as the files under it imply them: each a file, held there, or a folder. */
export const entriesIn = (files: ReadonlyMap<string, File>, dir: string) => {
  const entries = new Map<string, File | 'dir'>()

  for (const [path, file] of files) {
    if (isUnder(dir, path)) {
      const [name = '', ...deeper] = path.slice(dir.length + 1).split('/')

      entries.set(name, deeper.length > 0 ? 'dir' : file)
    }
  }

  return [...entries].map(([name, entry]) => ({ name, entry }))
}

/** The text of a file, failing the test when it is not there. */
export const textIn = (files: ReadonlyMap<string, File>, path: string) => {
  const file = files.get(path)

  if (file === undefined) {
    throw new Error(`no file at ${path}`)
  }

  return file.text
}
