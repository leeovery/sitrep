/**
 * A file system in memory: its files by path, and what the folders hold as
 * the files under them imply. The engine's file events beneath the mod are
 * answered from one; the CLI's world reads and writes another.
 */
import type { On } from 'claude-code'
import type { MockClock } from 'claude-code/testing'
import { PLUGIN_VERSION } from '../data'
import { MANIFEST } from '../../hooks/version'

export type File = { text: string; mtimeMs: number }

const isUnder = (dir: string, path: string) => path.startsWith(`${dir}/`)

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

/** The plugin's manifest, giving `version`. */
export const manifestOf = (version: unknown) =>
  `${JSON.stringify({ name: 'sitrep', version, description: 'A small window onto a session' })}\n`

/** The kinds of look the mod takes at a path. */
type Look = 'read' | 'exists' | 'list'

const MISSING = (path: string) => ({ deny: `ENOENT: no such file or directory, ${path}` })

/** The engine's file system beneath the mod, its files written at the clock's time. */
export function disk(on: On, clock: MockClock) {
  const files = new Map<string, File>()
  /** Every folder the mod listed, in the order listed. */
  const listed: string[] = []
  /** Every folder the mod listed that was not there: each a line in the engine's debug log. */
  const unlisted: string[] = []
  /** Every path the mod wrote, in the order written. */
  const written: string[] = []
  let isRefused: ((path: string) => boolean) | undefined
  /** The plugin's manifest; none, as one that cannot be read. */
  let manifest: string | undefined = manifestOf(PLUGIN_VERSION)
  /** What happens once, right after the mod's next look of a kind at a path is answered. */
  const afterwards: { look: Look; path: string; act: () => void | Promise<void> }[] = []

  /** Answers the mod's look at `path`, once whatever was to happen right after it has. */
  const answered = async <T>(look: Look, path: string, answer: T) => {
    const at = afterwards.findIndex(each => each.look === look && each.path === path)

    if (at !== -1) {
      await afterwards.splice(at, 1)[0]?.act()
    }

    return answer
  }

  /** What a read finds: the plugin's manifest in the plugin's own folder, wherever the test loads it from; else the file held there. */
  const textAt = (path: string) =>
    path.endsWith(`/${MANIFEST}`) ? manifest : files.get(path)?.text

  on('fs.read', ($, e) => {
    const text = textAt(e.path)

    return answered('read', e.path, text === undefined ? MISSING(e.path) : { value: text })
  })

  on('fs.write', ($, e) => {
    if (isRefused?.(e.path)) {
      return { deny: `EIO: i/o error, write ${e.path}` }
    }

    files.set(e.path, { text: e.text, mtimeMs: clock.now() })
    written.push(e.path)

    return { value: undefined }
  })

  on('fs.exists', ($, e) =>
    answered('exists', e.path, {
      value: files.has(e.path) || [...files.keys()].some(path => isUnder(e.path, path)),
    }),
  )

  on('fs.list', ($, e) => {
    listed.push(e.path)

    return answered('list', e.path, listing(e.path))
  })

  /** A folder's listing, as the engine gives it. */
  const listing = (dir: string) => {
    const entries = entriesIn(files, dir)

    if (entries.length === 0) {
      unlisted.push(dir)

      return MISSING(dir)
    }

    return {
      value: entries.map(({ name, entry }) => ({
        name,
        ...(entry === 'dir'
          ? { kind: 'dir' as const, size: 0, mtimeMs: 0 }
          : {
              kind: 'file' as const,
              size: new TextEncoder().encode(entry.text).length,
              mtimeMs: entry.mtimeMs,
            }),
        isLink: false,
      })),
    }
  }

  return {
    files,
    listed,
    unlisted,
    written,
    /** Writes a file as another writer would: a window elsewhere, the CLI, Lee's board. */
    put: (path: string, text: string) => files.set(path, { text, mtimeMs: clock.now() }),
    /** The text of a file, failing the test when it is not there. */
    text: (path: string) => textIn(files, path),
    /** Writes from here on to a path `test` picks fail, as a full disk fails them; given none, they land again. */
    refuseWrites: (test?: (path: string) => boolean) => {
      isRefused = test
    },
    /** The plugin's manifest from here on is `text`; given none, it cannot be read. */
    manifestGives: (text?: string) => {
      manifest = text
    },
    /** Runs `act` once, right after the mod's next look of the kind at `path` is answered: as another writer writing at that moment. */
    after: (look: Look, path: string, act: () => void | Promise<void>) =>
      afterwards.push({ look, path, act }),
  }
}
