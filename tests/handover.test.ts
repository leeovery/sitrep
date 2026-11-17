/**
 * The hand-over of a send from a window's heartbeat to its session's lines,
 * as every reader reads it: the window writes the reply and its mark, then
 * its heartbeat stops saying the send. A reader that took the lines before
 * the write and the heartbeat after it would find the reply nowhere, and the
 * ask would flash back into Needs you, so the heartbeats are read first.
 */
import { expect, test } from './kit'
import { readFolder } from '../cli/files'
import type { Io } from '../cli/io'
import {
  folderKey,
  foldSession,
  metaText,
  presenceText,
  sessionPaths,
  type Presence,
  type Sending,
  type SessionFiles,
} from '../core'
import type { Host } from '../hooks/host'
import { createReader } from '../hooks/reader'
import { META, T0, W1 } from './data'
import { delivered, file, reply, yesAsk, type Line } from './lines'
import { fsOn } from './host'
import { terminal } from './terminal'

const ROOT = '/Users/me/.local/state/sitrep'

const PATHS = sessionPaths(ROOT, folderKey(META.project), META.id)

const NOW = T0 + 10 * 60_000

const ASK: Line = [T0, yesAsk('k1', 'Review round 1')]

const SENT: Sending = { at: NOW - 60_000, replies: [{ id: 'r1', item: 'k1', verdict: 'yes' }] }

type Files = Map<string, { text: string; mtimeMs: number }>

const heartbeat = (sending?: Sending): Presence => ({
  writer: W1,
  attachedAt: T0,
  seenAt: NOW,
  version: '0.2.0',
  sending: sending && [sending],
})

/** The session as the window leaves it mid-send: its ask, and its heartbeat saying the yes. */
const midSend = (): Files =>
  new Map([
    [PATHS.meta, { text: metaText(META), mtimeMs: T0 }],
    [PATHS.log(W1), { text: file(ASK), mtimeMs: T0 }],
    [PATHS.heartbeat(W1), { text: presenceText(heartbeat(SENT)), mtimeMs: NOW - 60_000 }],
  ])

/** The window's hand-over: the reply and its mark written down, then the heartbeat saying no send. */
const handOver = (files: Files) => {
  files.set(PATHS.log(W1), {
    text: file(ASK, [NOW - 1_000, reply('r1', 'k1', 'yes')], [NOW - 1_000, delivered('r1')]),
    mtimeMs: NOW - 1_000,
  })
  files.set(PATHS.heartbeat(W1), { text: presenceText(heartbeat()), mtimeMs: NOW - 1_000 })
}

/** Reads `files`, the window handing the send over the moment the first of its lines has been read. */
const handingOver = (files: Files, read: (path: string) => Promise<string>) => {
  let isHanded = false

  return async (path: string) => {
    const text = await read(path)

    if (!isHanded && path.endsWith('.jsonl')) {
      isHanded = true
      handOver(files)
    }

    return text
  }
}

/** Where the ask stands once the folder is read so: on its way, or closed by the reply delivered, never waiting on Lee. */
const standing = (read: Omit<SessionFiles, 'project'>) => {
  const session = foldSession(read, NOW)

  return { waiting: session?.waiting, state: session?.asks[0]?.state }
}

/** A host whose files are `files`, listed as the engine lists them. */
const hostOn = (files: Files): Host => {
  const fs = fsOn(files, NOW)

  return { fs: { ...fs, read: handingOver(files, fs.read) } } as unknown as Host
}

test("the mod's reader reads the heartbeats before the lines: a send handed over as it reads is on its way or delivered, never waiting on Lee", async () => {
  const files = midSend()
  const read = await createReader()(hostOn(files), PATHS)

  expect(standing(read).waiting).toBe(0)
})

test("the CLI's reader reads the heartbeats before the lines: a send handed over as it reads is on its way or delivered, never waiting on Lee", async () => {
  const files = midSend()
  const { io } = terminal({ files })
  const handed: Io = { ...io, fs: { ...io.fs, read: handingOver(files, io.fs.read) } }

  expect(standing(await readFolder(handed, PATHS)).waiting).toBe(0)
})

test('read again, either reader finds the reply delivered and the ask closed', async () => {
  const files = midSend()

  handOver(files)

  const { io } = terminal({ files })

  expect(standing(await createReader()(hostOn(files), PATHS))).toEqual({
    waiting: 0,
    state: 'closed',
  })
  expect(standing(await readFolder(io, PATHS))).toEqual({ waiting: 0, state: 'closed' })
})
