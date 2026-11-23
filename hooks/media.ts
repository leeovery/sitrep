/**
 * Lee's attachments to a reply he writes in the prompt box, saved so the
 * reply can wait in Ready to send (DESIGN.md, "An answer with an image").
 * Each is read through `$.prompt.media` while the `prompt.submit` hook that
 * carries it is in flight, and written to its own file in sitrep's media
 * folder, which only Lee can read; the reply's words name each file. Any
 * that can't be read or written leaves none saved, and the prompt rides in
 * with them as before.
 *
 * A reply owns the files its words name. A file goes as soon as no reply
 * names it without having gone anywhere: undone, taken out of Ready to
 * send, cancelled, or replaced by words that no longer name it. A sent
 * reply's files stay for the Claude it went to, which opens them in the
 * turn the send starts, or, from an inbox, at that window's next delivery:
 * the sweep at each session start removes them once 14 days old, unless a
 * reply still waiting in this window's Ready to send names them.
 *
 * `$.fs` writes only text and removes nothing, so the bytes are written and
 * removed by a process (`saveArgv`, `removeArgv`), each path an argument.
 */
import type { ProcessRunResult, PromptSubmitAttachment } from 'claude-code'
import {
  mediaDir,
  mediaFile,
  mediaNamed,
  newMediaName,
  placeMedia,
  type SavedMedia,
} from '../core'
import type { SitrepQueued } from '../types'
import { logFailure, random, rootFor, type Host } from './host'

/** How long a saved file no reply in Ready to send names is kept: time enough for any Claude its reply went to to open it. */
export const MEDIA_KEPT_MS = 14 * 24 * 60 * 60_000

/** Writes its standard input, base64, decoded into `$2`, in the folder `$1`, both only Lee's to read. */
const SAVE = 'umask 077 && mkdir -p "$1" && /usr/bin/base64 --decode > "$2"'

/** The process that writes a file's bytes, given as base64 on its standard input. */
export const saveArgv = (path: string) => [
  '/bin/sh',
  '-c',
  SAVE,
  'sh',
  path.slice(0, path.lastIndexOf('/')),
  path,
]

/** The process that removes files, those already gone among them. */
export const removeArgv = (paths: readonly string[]) => ['/bin/rm', '-f', '--', ...paths]

/** A process's run as a promise of its success: one that exits otherwise fails, saying why. */
export const ranOk = ({ exitCode, stderr }: Pick<ProcessRunResult, 'exitCode' | 'stderr'>) => {
  if (exitCode !== 0) {
    throw new Error(stderr.trim() || `exit ${exitCode}`)
  }
}

/** An attachment as read: its kind and type, and its bytes, base64. */
type ReadMedia = Pick<SavedMedia, 'kind'> & { mediaType: string; base64: string }

/** An attachment's bytes, base64, as its slices from `offset` on join after `before`, and what they are; undefined where they can't be read. */
const readMedia = async (
  host: Host,
  id: string,
  offset?: number,
  before: readonly string[] = [],
): Promise<ReadMedia | undefined> => {
  const media = await host.prompt.media(offset === undefined ? { id } : { id, offset })

  if (media.type === undefined) {
    return undefined
  }

  const slices = [...before, media.base64]

  return media.next === undefined
    ? { kind: media.type, mediaType: media.mediaType, base64: slices.join('') }
    : readMedia(host, id, media.next, slices)
}

/** Removes saved files, logging a failure: what is left the sweep takes. */
export const removeMedia = async (host: Host, paths: readonly string[]) => {
  if (paths.length > 0) {
    await host.fs.remove(paths).catch(logFailure(host, 'removing saved attachments'))
  }
}

/** Saves one attachment as a file of its own, its path recorded in `tried` before it is written; undefined where it can't be read. */
const saveOne = async (
  host: Host,
  root: string,
  { type, id }: PromptSubmitAttachment,
  tried: string[],
): Promise<SavedMedia | undefined> => {
  const read = type === 'audio' || id === undefined ? undefined : await readMedia(host, id)

  if (read === undefined) {
    return undefined
  }

  const path = mediaFile(root, newMediaName(random), read.mediaType)

  tried.push(path)
  await host.fs.save(path, read.base64)

  return { kind: read.kind, path }
}

/**
 * Lee's words with every attachment saved and named in them (`placeMedia`);
 * undefined, nothing left saved, where any can't be: audio, one with no
 * handle, one the engine can't read or refuses, a read or a write failing.
 */
export const savedWith = async (
  host: Host,
  attachments: readonly PromptSubmitAttachment[],
  words: string,
) => {
  const root = await rootFor(host)
  const tried: string[] = []
  const saved: SavedMedia[] = []

  for (const attachment of attachments) {
    const one = await saveOne(host, root, attachment, tried).catch((error: unknown) => {
      logFailure(host, 'saving an attachment')(error)

      return undefined
    })

    if (one === undefined) {
      await removeMedia(host, tried)

      return undefined
    }

    saved.push(one)
  }

  return placeMedia(words, saved)
}

/** Every saved file the replies in Ready to send name. */
const namedIn = (root: string, queue: readonly SitrepQueued[]) =>
  new Set(queue.flatMap(reply => mediaNamed(reply.note, root)))

/**
 * Changes Ready to send as `change` makes it of what stands, and removes
 * each saved file a reply named before and none names after: a reply that
 * never went, undone, cancelled or replaced. Never for a send, whose files
 * stay for the Claude it went to.
 */
export const changeQueue = async (
  host: Host,
  change: (queue: SitrepQueued[]) => SitrepQueued[],
) => {
  let before: SitrepQueued[] = []
  let after: SitrepQueued[] = []

  await host.state.queue.update(queue => {
    before = queue
    after = change(queue)

    return after
  })

  const root = await rootFor(host)
  const kept = namedIn(root, after)

  await removeMedia(
    host,
    [...namedIn(root, before)].filter(path => !kept.has(path)),
  )
}

/** Removes the saved files older than `MEDIA_KEPT_MS` that no reply in this window's Ready to send names. */
export const sweepMedia = async (host: Host) => {
  const root = await rootFor(host)
  const dir = mediaDir(root)

  if (!(await host.fs.exists(dir))) {
    return
  }

  const [entries, queue, now] = await Promise.all([
    host.fs.list(dir),
    host.state.queue.read(),
    host.clock.now(),
  ])
  const named = namedIn(root, queue)

  await removeMedia(
    host,
    entries
      .filter(entry => entry.kind === 'file' && now - entry.mtimeMs > MEDIA_KEPT_MS)
      .map(entry => `${dir}/${entry.name}`)
      .filter(path => !named.has(path)),
  )
}
