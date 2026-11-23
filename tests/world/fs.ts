/** The engine's file system beneath the mod, answered from one in memory, with the plugin's manifest in its own folder. */
import type { On } from 'claude-code'
import type { MockClock } from 'claude-code/testing'
import { PLUGIN_VERSION } from '../data'
import { MANIFEST } from '../../hooks/version'
import { removeArgv, saveArgv } from '../../hooks/media'
import { bytesOf, isThere, listingIn, missing, textIn, type File } from '../fs'
import { exited } from './conversation'

/** The plugin's manifest, giving `version`. */
export const manifestOf = (version: unknown) =>
  `${JSON.stringify({ name: 'sitrep', version, description: 'A small window onto a session' })}\n`

/** The kinds of look the mod takes at a path. */
type Look = 'read' | 'exists' | 'list'

const MISSING = (path: string) => ({ deny: missing(path) })

/** The removal of saved attachments, before the paths it removes. */
const REMOVE = removeArgv([])

/** Whether two argument vectors are one. */
const isSame = (one: readonly string[], other: readonly string[]) =>
  one.length === other.length && one.every((each, i) => each === other[i])

/** The engine's file system beneath the mod, its files written at the clock's time. */
export function disk(on: On, clock: MockClock) {
  const files = new Map<string, File>()
  /** Every folder the mod listed, in the order listed. */
  const listed: string[] = []
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

  on('fs.exists', ($, e) => answered('exists', e.path, { value: isThere(files, e.path) }))

  on('fs.list', ($, e) => {
    listed.push(e.path)

    return answered('list', e.path, listing(e.path))
  })

  /** Answers the processes that save attachments and remove them over the files, as the shell would; undefined for any other. */
  const ran = (argv: readonly string[], stdin = '') => {
    const path = argv.at(-1) ?? ''

    if (isSame(argv, saveArgv(path))) {
      if (isRefused?.(path)) {
        return exited(1, '', `sh: ${path}: Input/output error`)
      }

      files.set(path, { text: '', bytes: bytesOf(stdin), mtimeMs: clock.now() })
      written.push(path)

      return exited(0)
    }

    if (isSame(argv.slice(0, REMOVE.length), REMOVE)) {
      for (const each of argv.slice(REMOVE.length)) {
        files.delete(each)
      }

      return exited(0)
    }

    return undefined
  }

  /** A folder's listing, as the engine gives it. */
  const listing = (dir: string) => {
    const entries = listingIn(files, dir)

    return entries.length === 0 ? MISSING(dir) : { value: entries }
  }

  return {
    files,
    listed,
    written,
    ran,
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
