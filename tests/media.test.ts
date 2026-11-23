/**
 * Lee's attachments saved for a reply in Ready to send (DESIGN.md, "An
 * answer with an image"): core's words for them, and the mod's saving,
 * releasing and sweeping run on a host with no engine beneath, since the
 * test kit cannot answer `$.prompt.media` (no implementation, and no event
 * a test can answer it on).
 */
import type {
  ProcessRunInit,
  PromptMedia,
  PromptMediaArgs,
  PromptSubmitAttachment,
} from 'claude-code'
import { expect, test } from './kit'
import {
  mediaExtension,
  mediaFile,
  mediaNamed,
  messageText,
  MEDIA_HINT,
  namesSavedMedia,
  placeMedia,
  type SavedMedia,
} from '../core'
import type { Host } from '../hooks/host'
import {
  changeQueue,
  freshenMedia,
  processFiles,
  removeArgv,
  saveArgv,
  savedWith,
  sweepMedia,
  touchArgv,
} from '../hooks/media'
import type { SitrepQueued } from '../types'
import { DAY, HOME, MIN, PROJECT, ROOT, STATE_HOME, T0 } from './data'
import { bytesOf, type File } from './fs'
import { fsOn, slot } from './host'

const MEDIA = `${ROOT}/media`

const SHOT: SavedMedia = { kind: 'image', path: `${MEDIA}/aaaa.png` }
const CROP: SavedMedia = { kind: 'image', path: `${MEDIA}/bbbb.png` }
const SPEC: SavedMedia = { kind: 'document', path: `${MEDIA}/cccc.pdf` }

/** A PNG's first bytes, base64, in two slices as the engine answers 4 MiB at a time. */
const HEAD = 'iVBORw0K'
const TAIL = 'Ggo='

/** What the engine answers for each attachment's id: its slices in order, or one refusal. */
type Answers = Readonly<Record<string, readonly PromptMedia[]>>

const PNG: readonly PromptMedia[] = [
  { type: 'image', mediaType: 'image/png', base64: HEAD, size: 8, next: 6 },
  { type: 'image', mediaType: 'image/png', base64: TAIL, size: 8 },
]

const PDF: readonly PromptMedia[] = [
  { type: 'document', mediaType: 'application/pdf', base64: 'JVBERg==', size: 4 },
]

const image = (id?: string): PromptSubmitAttachment => ({
  type: 'image',
  mediaType: 'image/png',
  id,
})

/**
 * A host whose files are `files`, its engine answering `answers` for the
 * prompt's attachments, and the reads it was asked for. The save numbered
 * `failing`, counting from 0, fails once its file is begun, as the shell's
 * redirect makes the file before the write fails.
 */
const hostOn = (
  files: Map<string, File>,
  answers: Answers = {},
  queue: SitrepQueued[] = [],
  failing?: number,
) => {
  const fs = fsOn(files, T0)
  const reads: PromptMediaArgs[] = []
  const logged: string[] = []
  let saves = 0
  const host = {
    fs: {
      ...fs,
      save: async (path: string, base64: string) => {
        await fs.save(path, base64)

        if (saves++ === failing) {
          throw new Error('EIO')
        }
      },
    },
    env: async () => ({ XDG_STATE_HOME: STATE_HOME, HOME }),
    clock: { now: async () => T0 },
    log: (text: string) => logged.push(text),
    prompt: {
      media: async (args: PromptMediaArgs) => {
        reads.push(args)

        const slices = answers[args.id] ?? [{ deny: 'not this submission' }]
        const at =
          args.offset === undefined
            ? 0
            : slices.findIndex((_, i) => slices[i - 1]?.next === args.offset)

        return slices[at] ?? { deny: 'past the end' }
      },
    },
    state: { queue: slot(queue) },
  } as unknown as Host

  return { host, reads, logged }
}

/** The saved files under the media folder, by path. */
const savedIn = (files: ReadonlyMap<string, File>) =>
  [...files.keys()].filter(path => path.startsWith(`${MEDIA}/`))

const comment = (note: string): SitrepQueued => ({
  project: PROJECT.key,
  session: 'sr-he1d00',
  item: 'k1',
  verdict: 'comment',
  note,
})

test('an image takes its placeholder’s place in the words, as a file Claude can open', () => {
  expect(placeMedia('Frame 2 looks like this [Image #1]', [SHOT])).toBe(
    `Frame 2 looks like this [image: ${SHOT.path}]`,
  )
})

test('images take their placeholders lowest number first, in the order attached, wherever each sits', () => {
  expect(placeMedia('After [Image #3], before [Image #2], [Image #3] again', [SHOT, CROP])).toBe(
    `After [image: ${CROP.path}], before [image: ${SHOT.path}], [image: ${CROP.path}] again`,
  )
})

test('an attachment no placeholder places goes at the end: after a space, or on a line of its own after several lines', () => {
  expect(placeMedia('See the spec', [SPEC])).toBe(`See the spec [document: ${SPEC.path}]`)
  expect(placeMedia('Line one\nline two [Image #1]', [SHOT, CROP, SPEC])).toBe(
    `Line one\nline two [image: ${SHOT.path}]\n[image: ${CROP.path}] [document: ${SPEC.path}]`,
  )
  expect(placeMedia('[Image #1] and [Image #2]', [SHOT]), 'a placeholder with no image left').toBe(
    `[image: ${SHOT.path}] and [Image #2]`,
  )
})

test('a type that names a property every object has takes the fallback, never the property', () => {
  expect(['__proto__', 'constructor', 'toString'].map(mediaExtension)).toEqual([
    'bin',
    'bin',
    'bin',
  ])
})

test('a saved file is named for its type: the common ones by their usual extension, any other by its subtype, else bin', () => {
  expect(['image/png', 'image/jpeg', 'image/webp', 'application/pdf'].map(mediaExtension)).toEqual(
    ['png', 'jpg', 'webp', 'pdf'],
  )
  expect(mediaExtension('image/heic')).toBe('heic')
  expect(mediaExtension('image/svg+xml')).toBe('bin')
  expect(mediaFile(ROOT, 'k3x9', 'image/jpeg')).toBe(`${MEDIA}/k3x9.jpg`)
})

test('words own only the saved files they name directly in the media folder: nothing else can be named for removing', () => {
  const words = [
    `[image: ${SHOT.path}]`,
    `[document: ${SPEC.path}]`,
    `[image: ${MEDIA}/../projects/northwind/project.json]`,
    `[image: ${ROOT}/snooze.json]`,
    `[image: ${MEDIA}/deeper/aaaa.png]`,
    `[Image #1]`,
  ].join(' ')

  expect(mediaNamed(words, ROOT)).toEqual([SHOT.path, SPEC.path])
  expect(mediaNamed(undefined, ROOT)).toEqual([])
})

test('a message whose replies name a saved file tells Claude, once at its end, to open each with its Read tool; one naming none says nothing of it', () => {
  const note = `Like this [image: ${SHOT.path}]`
  const lines = [`- Give the ok → Go, with a comment: “${note}”`, '- Ship it → Redraw']

  expect(messageText(lines, [note, undefined])).toBe(
    `From the board:\n${lines.join('\n')}\n${MEDIA_HINT}`,
  )
  expect(MEDIA_HINT).toBe(
    'Each [image: …] or [document: …] above is a file the user attached: ' +
      'open it with your Read tool.',
  )
  expect(messageText(['- Run it → answer: “[Image #1]”'], ['[Image #1]'])).not.toContain(
    MEDIA_HINT,
  )
})

test('only a path a save gives, in sitrep’s media folder wherever that is, has a message tell Claude to open it: never other words in the same brackets', () => {
  expect(namesSavedMedia(`[image: ${SHOT.path}]`)).toBe(true)
  expect(namesSavedMedia('[document: /Users/me/.local/state/sitrep/media/k3x9.pdf]')).toBe(true)
  expect(
    [
      '[image: /tmp/shot.png]',
      `[image: ${ROOT}/snooze.json]`,
      `[image: ${MEDIA}/deeper/aaaa.png]`,
      `[image: ${MEDIA}/Shot 1.png]`,
      '[image: sitrep/media/aaaa.png]',
      '[image: /Users/me/notsitrep/media/aaaa.png]',
    ].map(namesSavedMedia),
  ).toEqual([false, false, false, false, false, false])
})

test('the save writes a file only Lee can read, in a folder only Lee can open, every path an argument and never in the script', () => {
  const path = `${MEDIA}/aaaa.png`
  const [shell, flag, script, name, dir, file] = saveArgv(path)

  expect([shell, flag, name, dir, file]).toEqual(['/bin/sh', '-c', 'sh', MEDIA, path])
  expect(script).toBe(
    'umask 077 && mkdir -p "$1" && chmod 700 "$1" && /usr/bin/base64 --decode > "$2"',
  )
  expect(removeArgv([path])).toEqual(['/bin/rm', '-f', '--', path])
  expect(touchArgv([path])).toEqual(['/usr/bin/touch', '-c', '--', path])
})

test('the host saves, marks and removes by running each process from /, the bytes on the save’s standard input; one that exits otherwise fails, saying why', async () => {
  const path = `${MEDIA}/aaaa.png`
  const runs: { argv: readonly string[]; init?: ProcessRunInit }[] = []
  let exitCode = 0
  const files = processFiles(async (argv, init) => {
    runs.push({ argv, init })

    return {
      exitCode,
      stdout: '',
      stderr: exitCode === 0 ? '' : 'rm: aaaa.png: Operation not permitted\n',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    }
  })

  await files.save(path, HEAD + TAIL)
  await files.touch([path])
  await files.remove([path])
  expect(runs).toEqual([
    { argv: saveArgv(path), init: { cwd: '/', stdin: HEAD + TAIL } },
    { argv: touchArgv([path]), init: { cwd: '/' } },
    { argv: removeArgv([path]), init: { cwd: '/' } },
  ])

  exitCode = 1

  const failed = await files.remove([path]).then(
    () => 'removed',
    (error: Error) => error.message,
  )

  expect(failed).toBe('rm: aaaa.png: Operation not permitted')
})

test('an image is read slice by slice while the prompt is in flight, saved whole, and named in the words where it sat', async () => {
  const files = new Map<string, File>()
  const { host, reads } = hostOn(files, { a1: PNG })
  const saved = await savedWith(host, [image('a1')], 'Like this [Image #1]')
  const [path = ''] = savedIn(files)

  expect(reads).toEqual([{ id: 'a1' }, { id: 'a1', offset: 6 }])
  expect(path).toMatch(new RegExp(`^${MEDIA}/[0-9a-z]{16}\\.png$`))
  expect(files.get(path)?.bytes).toEqual(bytesOf(HEAD + TAIL))
  expect(saved).toEqual({ words: `Like this [image: ${path}]`, paths: [path] })
})

test('a document is saved too, and named at the end', async () => {
  const files = new Map<string, File>()
  const { host } = hostOn(files, { a1: PNG, d1: PDF })
  const saved = await savedWith(
    host,
    [image('a1'), { type: 'document', mediaType: 'application/pdf', id: 'd1' }],
    'Both [Image #1]',
  )
  const png = savedIn(files).find(path => path.endsWith('.png'))
  const pdf = savedIn(files).find(path => path.endsWith('.pdf'))

  expect(saved?.words).toBe(`Both [image: ${png}] [document: ${pdf}]`)
})

/** Each way an attachment can't be saved, as the engine or the disk answers it. */
const FAILURES: readonly [string, PromptSubmitAttachment, Answers, number?][] = [
  ['unreadable', image('a2'), { a2: [{ unreadable: 'too large to process' }] }],
  ['refused', image('a2'), { a2: [{ deny: 'not this submission' }] }],
  ['audio', { type: 'audio', mediaType: 'audio/wav', id: 'a2' }, {}],
  ['with no id', image(), {}],
  [
    'whose slices go on from no further than they started',
    image('a2'),
    { a2: [{ ...PNG[0], next: 0 } as PromptMedia] },
  ],
  [
    'whose bytes fall short of the size the engine gives',
    image('a2'),
    { a2: [{ type: 'image', mediaType: 'image/png', base64: HEAD, size: 8 }] },
  ],
  ['whose write fails, its file begun', image('a2'), { a2: PNG }, 1],
]

for (const [why, failing, answers, failingSave] of FAILURES) {
  test(`an attachment ${why} leaves nothing saved, and the prompt rides in as before`, async () => {
    const files = new Map<string, File>()
    const { host } = hostOn(files, { a1: PNG, ...answers }, [], failingSave)

    expect(await savedWith(host, [image('a1'), failing], '[Image #1] [Image #2]')).toBeUndefined()
    expect(savedIn(files), 'each one begun, removed again').toEqual([])
  })
}

test('a read that fails beneath leaves nothing saved, and says so in the debug log', async () => {
  const files = new Map<string, File>()
  const { host, logged } = hostOn(files, { a1: PNG })

  host.prompt.media = () => Promise.reject(new Error('no implementation for prompt.media'))
  expect(await savedWith(host, [image('a1')], '[Image #1]')).toBeUndefined()
  expect(savedIn(files)).toEqual([])
  expect(logged).toEqual([
    'sitrep: saving an attachment failed: no implementation for prompt.media',
  ])
})

/** The files at `paths`, each saved at `at`. */
const filesAt = (at: number, ...paths: string[]) =>
  new Map<string, File>(paths.map(path => [path, { text: '', mtimeMs: at }]))

test('a reply leaving Ready to send without going takes its files with it; files another reply names stay', async () => {
  const files = filesAt(T0, SHOT.path, CROP.path)
  const queue = [
    comment(`[image: ${SHOT.path}]`),
    { ...comment(`[image: ${CROP.path}]`), item: 'k2' },
  ]
  const { host } = hostOn(files, {}, queue)

  await changeQueue(host, waiting => waiting.filter(each => each.item !== 'k1'))
  expect(savedIn(files)).toEqual([CROP.path])
})

test('words written again that still name a file keep it; words that name it no more remove it', async () => {
  const files = filesAt(T0, SHOT.path)
  const { host } = hostOn(files, {}, [comment(`Like this [image: ${SHOT.path}]`)])

  await changeQueue(host, () => [comment(`Like this, cropped [image: ${SHOT.path}]`)])
  expect(savedIn(files)).toEqual([SHOT.path])
  await changeQueue(host, () => [comment('Never mind the picture')])
  expect(savedIn(files)).toEqual([])
})

test('the sweep removes the files older than 14 days that no reply in Ready to send names, and nothing else, nor any name a save never gives', async () => {
  const old = T0 - 14 * DAY - MIN
  const notSaved = `${MEDIA}/Notes.txt`
  const files = new Map([
    ...filesAt(old, SHOT.path, CROP.path, notSaved),
    ...filesAt(T0 - 13 * DAY, SPEC.path),
  ])
  const { host } = hostOn(files, {}, [comment(`[image: ${CROP.path}]`)])

  await sweepMedia(host)
  expect(savedIn(files).sort()).toEqual([notSaved, CROP.path, SPEC.path].sort())
})

test('a send marks the saved files its replies name fresh, so the sweep counts their 14 days from it; nothing else', async () => {
  const old = T0 - 20 * DAY
  const files = filesAt(old, SHOT.path, CROP.path)
  const { host } = hostOn(files)

  await freshenMedia(host, [comment(`[image: ${SHOT.path}]`), comment('No picture')])
  expect([files.get(SHOT.path)?.mtimeMs, files.get(CROP.path)?.mtimeMs]).toEqual([T0, old])
  await sweepMedia(host)
  expect(savedIn(files)).toEqual([SHOT.path])
})

test('the sweep with no media folder lists nothing, and removes nothing', async () => {
  const files = filesAt(T0 - 30 * DAY, `${ROOT}/snooze.json`)
  const { host } = hostOn(files)

  await sweepMedia(host)
  expect([...files.keys()]).toEqual([`${ROOT}/snooze.json`])
})
