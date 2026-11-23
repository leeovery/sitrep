/**
 * An answer with an image waits in Ready to send (DESIGN.md, "An answer
 * with an image"; Lee, 23 November 2026): each attachment saved as a file,
 * named in the reply's words. The test kit cannot answer `$.prompt.media`,
 * so what the mode makes of a prompt carrying one is run on a window with
 * no engine beneath (render.ts), and the engine tests take the rest: the
 * ride where the kit's read fails, the send's words, the files a reply
 * leaving Ready to send takes with it, and the sweep.
 */
import type { PromptMedia, PromptMediaArgs, PromptSubmitAttachment } from 'claude-code'
import { drained, expect, test, tier, type Engine } from './kit'
import { MEDIA_HINT, sessionPaths } from '../core'
import { actionsOf } from '../hooks/actions'
import { captured, ELSEWHERE, NOT_TAKEN, TAKEN } from '../hooks/answering'
import type { Host } from '../hooks/host'
import { removeArgv, SAVED_READ, touchArgv } from '../hooks/media'
import type { SitrepAnswering } from '../types'
import { answering, entered, LIST, onLedgersAsks, OUTPUT } from './answers'
import {
  CLOSES,
  DAY,
  FRAMES,
  GO,
  HELD,
  LEAVES_OPEN,
  LEDGER,
  MIN,
  PROJECT,
  ROOT,
  T0,
  W1,
} from './data'
import type { File } from './fs'
import { wordsAsk, yesAsk } from './lines'
import { windowFrom, type Desk } from './render'
import { asked, CONVERSATION, world, type World } from './world'

tier('user')

const MEDIA = `${ROOT}/media`

/** A file saved for an earlier reply, as a world test names it in words typed. */
const SHOT = `${MEDIA}/aaaa.png`
const CROP = `${MEDIA}/bbbb.png`

/** An image Lee pasted, with the handle the engine reads its bytes by. */
const PASTED: PromptSubmitAttachment = { type: 'image', mediaType: 'image/png', id: 'a1' }

/** A PNG's first bytes, as the engine answers them. */
const PNG: PromptMedia = { type: 'image', mediaType: 'image/png', base64: 'iVBORw0KGgo=', size: 8 }

/** The saved files under the media folder, by path. */
const savedIn = (files: ReadonlyMap<string, File>) =>
  [...files.keys()].filter(path => path.startsWith(`${MEDIA}/`))

/** The mode, begun on the terminal, for an item. */
const modeOn = (
  session: string,
  item: string,
  as: SitrepAnswering['as'],
  title: string,
): SitrepAnswering => ({ project: PROJECT.key, session, item, as, title, surface: 'terminal' })

/**
 * Lee's Enter carrying `attachments`, on a window over `desk` in the mode,
 * its engine answering each read with `media`: what the mode made of it,
 * the window's host, its files, and its toasts.
 */
const enteredOn = async (
  desk: Desk,
  text: string,
  attachments: readonly PromptSubmitAttachment[],
  media: (args: PromptMediaArgs) => PromptMedia = () => PNG,
  signal?: AbortSignal,
) => {
  const { host, files } = await windowFrom(desk)
  const toasts: string[] = []
  const window = {
    ...host,
    clock: { ...host.clock, after: () => ({ cancel: () => {} }) },
    ui: { toast: (text: string) => toasts.push(text) },
    prompt: {
      read: async () => text,
      fill: async () => {},
      clear: async () => {},
      media: async (args: PromptMediaArgs) => media(args),
    },
  } as unknown as Host
  const made = await captured(window, { text, attachments, origin: { kind: 'composer' } }, signal)

  return { made, host: window, files, toasts }
}

/** Where a reply to the held session's yes ask goes. */
const AT_K1 = { project: PROJECT.key, session: HELD.id, item: 'k1' }

/** The held session with Claude's yes ask, the window commenting on it. */
const COMMENTING: Desk = {
  lines: [[T0, yesAsk('k1', GO.title, 'Go')]],
  answering: modeOn(HELD.id, 'k1', 'comment', GO.title),
}

test('a comment with an image waits in Ready to send: the image saved as a file, its path in the words where it sat, nothing to Claude', async () => {
  const { made, host, files } = await enteredOn(COMMENTING, 'Like this [Image #1]', [PASTED])
  const [path = ''] = savedIn(files)

  expect(made).toEqual({ drop: TAKEN.comment })
  expect(path).toMatch(new RegExp(`^${MEDIA}/[0-9a-z]{16}\\.png$`))
  expect(await host.state.queue.read()).toEqual([
    {
      project: PROJECT.key,
      session: HELD.id,
      item: 'k1',
      verdict: 'comment',
      note: `Like this [image: ${path}]`,
    },
  ])
  expect(await host.state.answering.read()).toBeNull()
})

test('a submission given up while its image was saved queues nothing, and leaves nothing saved: the mode stands', async () => {
  const { made, host, files } = await enteredOn(
    COMMENTING,
    'Like this [Image #1]',
    [PASTED],
    () => PNG,
    AbortSignal.abort(),
  )

  expect(made).toEqual({ drop: NOT_TAKEN })
  expect(savedIn(files)).toEqual([])
  expect(await host.state.queue.read()).toEqual([])
  expect(await host.state.answering.read()).toMatchObject({ item: 'k1', as: 'comment' })
})

/** The ledger's words ask, the window answering it. */
const ANSWERING_LEDGER: Desk = {
  around: [{ meta: LEDGER, lines: [[T0, wordsAsk('k3', 'Which fields does the ledger keep?')]] }],
  answering: modeOn(LEDGER.id, 'k3', 'answer', 'Which fields does the ledger keep?'),
}

test("a reply with an image to another session's ask waits in Ready to send for it, no longer refused", async () => {
  const { made, host, files, toasts } = await enteredOn(ANSWERING_LEDGER, 'These [Image #1]', [
    PASTED,
  ])
  const [path = ''] = savedIn(files)

  expect(made).toEqual({ drop: TAKEN.answer })
  expect(toasts).toEqual([])
  expect(await host.state.queue.read()).toEqual([
    {
      project: PROJECT.key,
      session: LEDGER.id,
      item: 'k3',
      verdict: 'answer',
      note: `These [image: ${path}]`,
    },
  ])
})

/** The reason each read the engine can answer leaves the image unsaved. */
const UNSAVED: readonly [string, PromptMedia][] = [
  ['unreadable', { unreadable: 'too large to process' }],
  ['refused', { deny: 'not this submission' }],
]

for (const [why, answer] of UNSAVED) {
  test(`an image the engine answers ${why} for is not saved: the prompt takes the ride as before, which another session's ask refuses`, async () => {
    const { made, host, files, toasts } = await enteredOn(
      ANSWERING_LEDGER,
      'These [Image #1]',
      [PASTED],
      () => answer,
    )

    expect(made).toEqual({ drop: NOT_TAKEN })
    expect(toasts).toEqual([ELSEWHERE])
    expect(savedIn(files)).toEqual([])
    expect(await host.state.queue.read()).toEqual([])
  })
}

test("an image the test kit can't read rides in with Lee's prompt, as before, and nothing is saved", async ($, on) => {
  const w = world($, on)

  await answering(w)
  expect(
    (await entered(w, $, 'It prints this [Image #1]', { attachments: [PASTED] })).drop,
  ).toBeUndefined()
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- ${LIST.title} → ${OUTPUT}: “It prints this [Image #1]”${CLOSES}`,
  ])
  expect(savedIn(w.files)).toEqual([])
  expect(w.state.queue ?? []).toEqual([])
})

/** The board on Claude's choice ask, a comment queued on it naming `named`, each saved: the ask's address, and the board. */
const commented = async (w: World, $: Engine, ...named: string[]) => {
  await w.begin()

  for (const path of named) {
    w.files.set(path, { text: '', mtimeMs: T0 })
  }

  const id = await asked(w, FRAMES)
  const ui = await w.pane()
  const key = w.item(id)

  await ui.press({ key: `comment:${key}` })
  await entered(w, $, `Frame 2 [image: ${named.join('] [image: ')}]`)
  await w.clock.advance(MIN)

  return { id, key, ui }
}

/** The processes the window ran of a command, each with how it ran it. */
const ranOf = (w: World, command: string) =>
  w.runs.flatMap((argv, i) => (argv[0] === command ? [{ argv, init: w.inits[i] }] : []))

/** Whether the window removed exactly `paths`, in one run from /, and they are gone. */
const removed = (w: World, ...paths: string[]) => {
  expect(ranOf(w, '/bin/rm')).toEqual([{ argv: removeArgv(paths), init: { cwd: '/' } }])
  expect(paths.filter(path => w.files.has(path))).toEqual([])
}

test('a send words the reply with the path in its place, and tells Claude once to open each file; the file stays for Claude to open', async ($, on) => {
  const w = world($, on)
  const { ui } = await commented(w, $, SHOT)

  await ui.press({ key: 'send' })
  expect(w.prompts.map(each => each.text)).toEqual([
    `From the board:\n- ${FRAMES.title} → comment: “Frame 2 [image: ${SHOT}]”` +
      `${LEAVES_OPEN}\n${MEDIA_HINT}`,
  ])
  expect(w.state.queue).toEqual([])
  expect(w.files.has(SHOT), 'kept for Claude').toBe(true)
  expect(ranOf(w, '/bin/rm')).toEqual([])
  expect(ranOf(w, '/usr/bin/touch')).toEqual([{ argv: touchArgv([SHOT]), init: { cwd: '/' } }])
  expect(w.files.get(SHOT)?.mtimeMs, 'its 14 days counted from the send').toBe(w.clock.now())
})

test("a reply with a saved file sent into another session's inbox keeps the file, marked fresh for that window's delivery", async ($, on) => {
  const w = world($, on)
  const ui = await onLedgersAsks(w)
  const there = w.item('k3', LEDGER.id)

  w.files.set(SHOT, { text: '', mtimeMs: T0 })
  await ui.press({ key: `pick:${there}` })
  await ui.press({ key: `answer:${there}` })
  await entered(w, $, `These [image: ${SHOT}]`)
  await w.clock.advance(MIN)
  await ui.press({ key: 'send' })

  expect(
    w.text(sessionPaths(ROOT, PROJECT.key, LEDGER.id).letters(W1)),
    'in the ledger’s inbox',
  ).toContain(SHOT)
  expect(ranOf(w, '/usr/bin/touch')).toEqual([{ argv: touchArgv([SHOT]), init: { cwd: '/' } }])
  expect(w.files.get(SHOT)?.mtimeMs).toBe(w.clock.now())
})

test('undo takes the reply’s file with it', async ($, on) => {
  const w = world($, on)
  const { key, ui } = await commented(w, $, SHOT)

  await ui.press({ key: `undo:${key}` })
  removed(w, SHOT)
})

test('✕ in Ready to send takes the reply’s file with it', async ($, on) => {
  const w = world($, on)
  const { key, ui } = await commented(w, $, SHOT, CROP)

  await ui.press({ key: `unready:${key}` })
  removed(w, SHOT, CROP)
})

test('a removal that fails says so in the debug log, and leaves the file for the sweep', async ($, on) => {
  const w = world($, on)
  const { key, ui } = await commented(w, $, SHOT)

  w.refuseWrites(path => path === SHOT)
  await ui.press({ key: `undo:${key}` })
  expect(w.logs).toContain(
    `sitrep: removing saved attachments failed: /bin/rm: ${SHOT}: Operation not permitted`,
  )
  expect(w.files.has(SHOT)).toBe(true)
  expect(w.state.queue).toEqual([])
})

test('a reply pressed in place of one naming a saved file takes the file with it', async () => {
  const { host, files } = await windowFrom({
    ...COMMENTING,
    answering: null,
    queue: [{ ...AT_K1, verdict: 'comment', note: `Like this [image: ${SHOT}]` }],
  })

  files.set(SHOT, { text: '', mtimeMs: T0 })
  actionsOf(host).reply({ ...AT_K1, verdict: 'yes' })
  await drained()
  expect(await host.state.queue.read()).toEqual([{ ...AT_K1, verdict: 'yes' }])
  expect(savedIn(files)).toEqual([])
})

test('cancel all takes every reply’s file with it', async ($, on) => {
  const w = world($, on)
  const { ui } = await commented(w, $, SHOT)

  await ui.press({ key: 'cancel-all' })
  removed(w, SHOT)
})

test('✎ edit with words that no longer name a file removes it; words that still name one keep it', async ($, on) => {
  const w = world($, on)
  const { key, ui } = await commented(w, $, SHOT, CROP)

  await ui.press({ key: `rewrite:${key}` })
  await entered(w, $, `Frame 2, cropped [image: ${CROP}]`)
  removed(w, SHOT)
  expect(w.files.has(CROP)).toBe(true)
})

test('the session start sweeps the saved files over 14 days old that nothing in Ready to send names, and leaves the rest', async ($, on) => {
  const w = world($, on)

  await commented(w, $, SHOT)

  const old = T0 - 14 * DAY - MIN
  const stale = `${MEDIA}/cccc.png`
  const fresh = `${MEDIA}/dddd.png`

  w.files.set(SHOT, { text: '', mtimeMs: old })
  w.files.set(stale, { text: '', mtimeMs: old })
  w.files.set(fresh, { text: '', mtimeMs: T0 - 13 * DAY })
  await $.session.start(CONVERSATION)
  removed(w, stale)
  expect([SHOT, fresh].filter(path => w.files.has(path))).toEqual([SHOT, fresh])
})

/** Claude's Read of `path`, checked, the engine's own check asking, as it does outside every working directory. */
const readChecked = (w: World, $: Engine, path: string) => {
  w.checkGives('Read', 'ask')

  return $.tool.check({ tool: 'Read', input: { file_path: path } })
}

test("Claude's Read of a saved file runs with no prompt, though it lies outside every working directory", async ($, on) => {
  const w = world($, on)

  await w.begin()
  w.files.set(SHOT, { text: '', mtimeMs: T0 })
  expect(await readChecked(w, $, SHOT)).toEqual({ decision: 'allow', reason: SAVED_READ })
  expect(
    (await readChecked(w, $, `${MEDIA}/deeper/../aaaa.png`)).decision,
    'where it lands, `..` folded',
  ).toBe('allow')
})

test("any other Read is checked as it came: beside the media folder, below it, out of it by `..`, in another folder, or named as no save names a file", async ($, on) => {
  const w = world($, on)
  const others = [
    `${ROOT}/aaaa.png`,
    `${MEDIA}/deeper/aaaa.png`,
    `${MEDIA}/../snooze.json`,
    '/Users/me/Desktop/aaaa.png',
    `${MEDIA}/Notes.txt`,
  ]

  await w.begin()

  for (const path of [...others, `${ROOT}/snooze.json`]) {
    w.files.set(path, { text: '', mtimeMs: T0 })
  }

  for (const path of others) {
    expect((await readChecked(w, $, path)).decision, path).toBe('ask')
  }
})

test("a deny of Claude's Read of a saved file stands", async ($, on) => {
  const w = world($, on)

  await w.begin()
  w.files.set(SHOT, { text: '', mtimeMs: T0 })
  w.checkGives('Read', 'deny')
  expect((await $.tool.check({ tool: 'Read', input: { file_path: SHOT } })).decision).toBe('deny')
})
