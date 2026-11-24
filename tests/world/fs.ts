/** The engine's file system beneath the mod, answered from one in memory, with the plugin's manifest in its own folder. */
import type { On } from 'claude-code'
import type { MockClock } from 'claude-code/testing'
import { PLUGIN_VERSION } from '../data'
import { MANIFEST } from '../../hooks/version'
import { removeArgv, touchArgv } from '../../hooks/media'
import { isThere, listingIn, missing, textIn, type File } from '../fs'
import { exited } from './conversation'

/** The plugin's manifest, giving `version`. */
export const manifestOf = (version: unknown) =>
  `${JSON.stringify({ name: 'sitrep', version, description: 'A small window onto a session' })}\n`

/** The kinds of look the mod takes at a path. */
type Look = 'read' | 'exists' | 'list'

/** What happens once, at a moment a test picks. */
type Act = { act: () => void | Promise<void> }

/** Runs the first act `isIt` picks, once, and lets it go. */
const actOnce = async <T extends Act>(acts: T[], isIt: (each: T) => boolean) => {
  const at = acts.findIndex(isIt)

  if (at !== -1) {
    await acts.splice(at, 1)[0]?.act()
  }
}

const MISSING = (path: string) => ({ deny: missing(path) })

/** The removal of saved attachments, before the paths it removes. */
const REMOVE = removeArgv([])

/** The marking of sent attachments, before the paths it marks. */
const TOUCH = touchArgv([])

/** The paths a process given `argv` acts on after `command`; undefined where it runs another command. */
const pathsAfter = (argv: readonly string[], command: readonly string[]) =>
  command.every((each, i) => argv[i] === each) ? argv.slice(command.length) : undefined

/** Where a path lands, `.` and `..` folded: the world's files have no links. */
const folded = (path: string) =>
  `/${path
    .split('/')
    .reduce<string[]>(
      (parts, part) =>
        part === '..' ? parts.slice(0, -1) : part === '' || part === '.' ? parts : [...parts, part],
      [],
    )
    .join('/')}`

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
  const afterwards: (Act & { look: Look; path: string })[] = []
  /** What happens once, right before the mod's next write to a path lands. */
  const beforehand: (Act & { path: string })[] = []

  /** Answers the mod's look at `path`, once whatever was to happen right after it has. */
  const answered = async <T>(look: Look, path: string, answer: T) => {
    await actOnce(afterwards, each => each.look === look && each.path === path)

    return answer
  }

  /** What a read finds: the plugin's manifest in the plugin's own folder, wherever the test loads it from; else the file held there. */
  const textAt = (path: string) =>
    path.endsWith(`/${MANIFEST}`) ? manifest : files.get(path)?.text

  on('fs.read', ($, e) => {
    const text = textAt(e.path)

    return answered('read', e.path, text === undefined ? MISSING(e.path) : { value: text })
  })

  on('fs.write', async ($, e) => {
    await actOnce(beforehand, each => each.path === e.path)

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

  /** Marks each file of `paths` changed now, making none. */
  const touch = (paths: readonly string[]) => {
    for (const path of paths) {
      const file = files.get(path)

      if (file !== undefined) {
        files.set(path, { ...file, mtimeMs: clock.now() })
      }
    }
  }

  /** Removes each file of `paths`. */
  const remove = (paths: readonly string[]) => {
    for (const path of paths) {
      files.delete(path)
    }
  }

  /**
   * Answers the processes that remove saved attachments and mark them over
   * the files, as each command would, failing on a path writes are refused
   * at; undefined for any other. The save is no part of it: the kit reads no
   * attachment, so no test reaches one.
   */
  const ran = (argv: readonly string[]) => {
    const removed = pathsAfter(argv, REMOVE)
    const touched = pathsAfter(argv, TOUCH)
    const paths = removed ?? touched

    if (paths === undefined) {
      return undefined
    }

    const refused = paths.find(path => isRefused?.(path) === true)

    if (refused !== undefined) {
      return exited(1, '', `${argv[0]}: ${refused}: Operation not permitted`)
    }

    ;(removed === undefined ? touch : remove)(paths)

    return exited(0)
  }

  on('fs.stat', ($, e) => {
    const path = folded(e.path)
    const file = files.get(path)

    return isThere(files, path)
      ? {
          value: {
            kind: file === undefined ? ('dir' as const) : ('file' as const),
            size: file?.text.length ?? 0,
            mtimeMs: file?.mtimeMs ?? 0,
            isLink: false,
            ...(e.resolve ? { realPath: path } : {}),
          },
        }
      : MISSING(e.path)
  })

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
    after: (look: Look, path: string, act: Act['act']) => afterwards.push({ look, path, act }),
    /** Runs `act` once, right before the mod's next write to `path` lands: as a disk slow to take it. */
    beforeWrite: (path: string, act: Act['act']) => beforehand.push({ path, act }),
  }
}
