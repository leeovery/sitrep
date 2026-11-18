import { expect, test } from './kit'
import { readSession } from '../cli/files'
import { EXIT, WRITER } from '../cli/main'
import {
  foldSession,
  parseEntries,
  serialise,
  toDeliver,
  VERSION,
  type SessionPaths,
} from '../core'
import { META, MIN, PLUGIN_VERSION, T0, W1, W2 } from './data'
import {
  choiceAsk,
  delivered,
  file,
  finish,
  kindAsk,
  park,
  reply,
  resolve,
  wordsAsk,
  yesAsk,
  type Line,
} from './lines'
import { FIRST_ID, NEXT_ID, NOW, terminal } from './terminal'

type Terminal = ReturnType<typeof terminal>

const SESSION = ['--session', META.id]

/** The session's window posted an ask of every shape and a parked item. */
const POSTED: Line[] = [
  [T0, yesAsk('k1', 'Give the ok for phase 3', 'Go')],
  [T0, choiceAsk('k2', 'Keep the sidebar, or drop it?', ['Keep it', 'Drop it'])],
  [T0, wordsAsk('k3', 'Run the export', "the command's output")],
  [T0, park('p1', 'A priority badge')],
]

/** The CLI's letters in the session's inbox, as lines. */
const letters = (t: Terminal, paths: SessionPaths) => parseEntries(t.text(paths.letters(WRITER)))

/** The session as the CLI reads it, its inbox among its files. */
const folded = async (t: Terminal, paths: SessionPaths) => {
  const session = foldSession(await readSession(t.io, paths), NOW)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

type ReplyStanding = { is: string; isAnswer: boolean; words: string; since: number } | null

type Board = {
  session: { waiting: number }
  asks: { id: string; state: string; reply: ReplyStanding }[]
  resolved: { id: string; reply: ReplyStanding; closedAt: number | null; reason: string | null }[]
}

const boardOf = async (t: Terminal) =>
  JSON.parse((await t.run('board', '--json', ...SESSION)).out) as Board

test("an answer goes into the session's inbox as the CLI's letters, a reply as the board writes one, and prints nothing", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })
  const before = t.text(paths.log(W1))

  expect(await t.run('answer', 'k1', 'Go', ...SESSION)).toEqual({
    exit: EXIT.done,
    out: '',
    err: '',
  })
  expect((await t.run('answer', 'k2', 'Drop', 'it', ...SESSION)).exit).toBe(EXIT.done)
  expect(letters(t, paths)).toEqual([
    { v: VERSION, at: NOW, seq: 1, type: 'reply', id: FIRST_ID, item: 'k1', verdict: 'yes' },
    {
      v: VERSION,
      at: NOW,
      seq: 2,
      type: 'reply',
      id: NEXT_ID,
      item: 'k2',
      verdict: 'choose',
      option: 'Drop it',
    },
  ])
  expect(t.files.has(paths.log(WRITER)), "nothing goes in the CLI's own file").toBe(false)
  expect(t.text(paths.log(W1))).toBe(before)
})

test('the board never closes an ask on the answer alone: it stays open, its answer on its way, though it no longer waits on Lee', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })

  await t.run('answer', 'k1', 'Go', ...SESSION)

  const session = await folded(t, paths)

  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.asks[0]?.answer).toBeUndefined()
  expect(session.replies).toMatchObject([{ id: FIRST_ID, by: WRITER, delivery: 'closed' }])
  expect(session.waiting).toBe(2)
  expect(JSON.parse((await t.run('list', '--json')).out).projects[0].sessions[0].waiting).toBe(2)
  expect((await boardOf(t)).session.waiting).toBe(2)
  expect((await boardOf(t)).asks[0]).toMatchObject({
    id: 'k1',
    state: 'waiting',
    reply: { is: 'onItsWay', isAnswer: true, words: '→ Go', since: NOW },
  })
})

test("once a window marks it delivered, board --json has the ask resolved, Lee's answer with Claude", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })
  const markedAt = NOW + MIN

  await t.run('answer', 'k2', 'Keep it', ...SESSION)
  t.files.set(paths.log(W1), {
    text: file(...POSTED, [markedAt, delivered(FIRST_ID)]),
    mtimeMs: markedAt,
  })

  const board = await boardOf(t)

  expect(board.asks.map(ask => ask.id)).toEqual(['k1', 'k3'])
  expect(board.resolved).toMatchObject([
    {
      id: 'k2',
      reply: { is: 'delivered', isAnswer: true, words: '→ Keep it', since: markedAt },
      closedAt: markedAt,
      reason: null,
    },
  ])
})

test("an ask Claude resolved shows in board --json's resolved with Claude's reason and no reply; the newest closed first", async () => {
  const t = terminal()

  t.seed(META, {
    lines: [
      ...POSTED,
      [T0 + MIN, resolve('k1', 'Went ahead in the chat')],
      [T0 + 2 * MIN, resolve('k2')],
    ],
  })

  expect((await boardOf(t)).resolved).toMatchObject([
    { id: 'k2', reply: null, closedAt: T0 + 2 * MIN, reason: null },
    { id: 'k1', reply: null, closedAt: T0 + MIN, reason: 'Went ahead in the chat' },
  ])
})

test("an answer still on its way when Claude closes its ask never goes in: board --json's resolved has it not delivered, since Claude closed it; a mark crossing the close has it delivered", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED, seenAt: NOW, version: PLUGIN_VERSION })
  const closedAt = NOW + MIN
  const closed: Line = [closedAt, resolve('k1', 'Went ahead in the chat')]
  const markedAt = closedAt + MIN

  await t.run('answer', 'k1', 'Go', ...SESSION)
  t.files.set(paths.log(W1), { text: file(...POSTED, closed), mtimeMs: closedAt })

  const board = await boardOf(t)

  expect(board.resolved).toMatchObject([
    {
      id: 'k1',
      reply: { is: 'notDelivered', isAnswer: true, words: '→ Go', since: closedAt },
      closedAt,
      reason: 'Went ahead in the chat',
    },
  ])
  expect((await folded(t, paths)).deliverer).toBe(W1)
  expect(toDeliver(await folded(t, paths), W1), 'its window never carries it').toEqual([])

  t.files.set(paths.log(W1), {
    text: file(...POSTED, closed, [markedAt, delivered(FIRST_ID)]),
    mtimeMs: markedAt,
  })
  expect((await boardOf(t)).resolved).toMatchObject([
    {
      id: 'k1',
      reply: { is: 'delivered', isAnswer: true, words: '→ Go', since: markedAt },
      closedAt,
      reason: 'Went ahead in the chat',
    },
  ])
})

test("an ask Lee's answer closed that Claude resolves after keeps when it closed in board --json's resolved, and carries Claude's reason", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })
  const markedAt = NOW + MIN
  const resolvedAt = markedAt + MIN

  await t.run('answer', 'k1', 'Go', ...SESSION)
  t.files.set(paths.log(W1), {
    text: file(
      ...POSTED,
      [markedAt, delivered(FIRST_ID)],
      [resolvedAt, resolve('k1', 'Shipped it')],
    ),
    mtimeMs: resolvedAt,
  })

  expect((await boardOf(t)).resolved).toMatchObject([
    {
      id: 'k1',
      reply: { is: 'delivered', isAnswer: true, words: '→ Go', since: markedAt },
      closedAt: markedAt,
      reason: 'Shipped it',
    },
  ])
})

test('an answer is dated as it is written, once its checks are done: later than every read of the session it was checked against', async () => {
  type File = { text: string; mtimeMs: number }
  let clock = NOW
  let checkedAt = -Infinity
  let appendedTo: string | undefined

  /** The files, noting the time on the clock at each read of the session's, but of the letters it appends to. */
  class Watched extends Map<string, File> {
    override get(path: string) {
      if (path.includes(`/${META.id}/`) && path !== appendedTo) {
        checkedAt = clock
      }

      return super.get(path)
    }
  }

  const t = terminal({ files: new Watched(), now: () => (clock += 1_000) })
  const paths = t.seed(META, { lines: POSTED })

  appendedTo = paths.letters(WRITER)
  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).exit).toBe(EXIT.done)
  expect(letters(t, paths)[0]?.at).toBeGreaterThan(checkedAt)
})

test('its letters count on from what they hold, a torn last line ended first, and are never rewritten', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })
  const whole = serialise({
    v: VERSION,
    at: T0,
    seq: 1,
    type: 'reply',
    id: 'r1',
    item: 'k2',
    verdict: 'choose',
    option: 'Keep it',
  })
  const torn = `${whole}{"v":1,"at":`

  t.files.set(paths.letters(WRITER), { text: torn, mtimeMs: T0 })
  await t.run('answer', 'k1', 'Go', ...SESSION)

  expect(t.text(paths.letters(WRITER)).startsWith(`${torn}\n`)).toBe(true)
  expect(letters(t, paths).map(line => [line.seq, line.type === 'reply' && line.item])).toEqual([
    [1, 'k2'],
    [2, 'k1'],
  ])
})

test("an answer is refused while the window delivering the session runs a sitrep behind the CLI's, as watch's needsReload tells it, until that window reloads", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED, seenAt: NOW })
  const refused = {
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: A window holding this session runs an older sitrep: run /reload-plugins in it first.\n',
  }

  expect(await t.run('answer', 'k1', 'Go', ...SESSION), 'saying no version').toEqual(refused)
  expect((await t.run('answer', 'k9', 'Go', ...SESSION)).err, 'no such item, first').toBe(
    'sitrep: There is no item k9 on this board.\n',
  )

  t.window(paths, META.by, NOW, undefined, '0.1.9')
  expect(await t.run('answer', 'k1', 'Go', ...SESSION), 'a release behind').toEqual(refused)
  expect(t.files.has(paths.letters(WRITER))).toBe(false)

  t.window(paths, META.by, NOW, undefined, PLUGIN_VERSION)
  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).exit, 'reloaded').toBe(EXIT.done)
})

test("what needs Claude Code's prompt is refused in the CLI's words, and writes nothing: a words ask, a comment", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })

  expect(await t.run('answer', 'k3', 'v1.2.3', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: "sitrep: k3 wants words, which need Claude Code's prompt: answer it there.\n",
  })
  expect((await t.run('answer', 'k1', 'Go', '--comment', 'After lunch', ...SESSION)).err).toBe(
    'sitrep: There is no --comment. sitrep answer --help says more.\n',
  )
  expect(t.files.has(paths.letters(WRITER))).toBe(false)
})

test('an answer is refused for an ask not open, an answer its ask does not take, an item no ask, or none at all, and writes nothing', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [
      ...POSTED,
      [T0, yesAsk('k4', 'Run the apply', 'Done')],
      [T0, kindAsk('k5', 'decide', 'Which palette?')],
      [T0 + MIN, resolve('k1')],
      [T0 + MIN, reply('r1', 'k4', 'ignore')],
      [T0 + MIN, delivered('r1')],
    ],
  })
  const refused = async (...words: string[]) => {
    const run = await t.run('answer', ...words, ...SESSION)

    expect([run.exit, run.out]).toEqual([EXIT.refused, ''])

    return run.err
  }

  expect(await refused('k1', 'Go')).toBe('sitrep: k1 is already closed.\n')
  expect(await refused('k4', 'Done')).toBe('sitrep: k4 is already ignored.\n')
  expect(await refused('k5', 'Dark'), 'a decide written before asks had options').toBe(
    "sitrep: k5 gives no options to choose from: answer it in Claude Code's prompt.\n",
  )
  expect(await refused('k2', 'Forever')).toBe(
    'sitrep: k2 wants a choice: answer it with “Keep it” or “Drop it”.\n',
  )
  expect(await refused('k2')).toBe(
    'sitrep: k2 wants a choice: answer it with “Keep it” or “Drop it”.\n',
  )
  expect(await refused('p1', 'Pick it up')).toBe('sitrep: p1 is a parked item, not an ask.\n')
  expect(await refused('k9', 'Go')).toBe('sitrep: There is no item k9 on this board.\n')
  expect(await refused()).toBe('sitrep: Name the item by its id, as the board lists it.\n')
  expect(t.files.has(paths.letters(WRITER))).toBe(false)
})

test('a yes is answered in its words alone; an ask with an answer on its way takes no second', async () => {
  const t = terminal()

  t.seed(META, { lines: POSTED })

  expect((await t.run('answer', 'k1', 'Yes', ...SESSION)).err).toBe(
    'sitrep: k1 wants a yes: answer it with “Go”.\n',
  )
  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).exit).toBe(EXIT.done)
  expect(await t.run('answer', 'k1', 'Go', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: An answer to k1 is on its way already.\n',
  })
})

test("board --json says whether the reply on its way is Lee's answer, which bars another, or a comment, which bars none: an ask with only a comment on its way still takes an answer", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })
  const commentedAt = NOW - MIN

  t.files.set(paths.letters(W2), {
    text: file([commentedAt, reply('r9', 'k1', 'comment', { note: 'Tighten the copy first' })]),
    mtimeMs: commentedAt,
  })

  expect((await boardOf(t)).asks[0]?.reply).toEqual({
    is: 'onItsWay',
    isAnswer: false,
    words: 'comment: “Tighten the copy first”',
    since: commentedAt,
  })
  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).exit).toBe(EXIT.done)
  expect((await boardOf(t)).asks[0]?.reply).toEqual({
    is: 'onItsWay',
    isAnswer: true,
    words: '→ Go',
    since: NOW,
  })
})

test("board --json's isAnswer is the bar's own fact: an old decide's comment on its way is its answer, and only a comment once an edit makes it want a yes", async () => {
  const t = terminal()
  const decide: Line = [T0, kindAsk('k7', 'decide', 'Keep the ledger 400 days, or forever?')]
  const paths = t.seed(META, { lines: [decide] })
  const commentedAt = NOW - MIN

  t.files.set(paths.letters(W2), {
    text: file([commentedAt, reply('r9', 'k7', 'comment', { note: 'Forever' })]),
    mtimeMs: commentedAt,
  })

  expect((await boardOf(t)).asks[0]?.reply).toMatchObject({
    is: 'onItsWay',
    isAnswer: true,
    words: 'answer: “Forever”',
  })

  t.files.set(paths.log(W1), {
    text: file(decide, [NOW, { type: 'edit', item: 'k7', changes: { wants: 'yes' } }]),
    mtimeMs: NOW,
  })

  expect((await boardOf(t)).asks[0]?.reply).toMatchObject({
    is: 'onItsWay',
    isAnswer: false,
    words: 'comment: “Forever”',
  })
})

test("--ignore ignores any ask, as the board's ignore does: on its way, then, once marked, gone from the asks and Resolved alike", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })

  expect(await t.run('answer', 'k3', '--ignore', ...SESSION)).toEqual({
    exit: EXIT.done,
    out: '',
    err: '',
  })
  expect(letters(t, paths)).toMatchObject([{ type: 'reply', item: 'k3', verdict: 'ignore' }])
  expect((await boardOf(t)).asks[2]).toMatchObject({
    id: 'k3',
    reply: { is: 'onItsWay', isAnswer: true, words: 'ignored', since: NOW },
  })
  expect((await t.run('answer', 'k1', 'Go', '--ignore', ...SESSION)).err).toBe(
    'sitrep: Give an answer or --ignore, not both.\n',
  )

  t.files.set(paths.log(W1), { text: file(...POSTED, [NOW, delivered(FIRST_ID)]), mtimeMs: NOW })

  const board = await boardOf(t)

  expect(board.asks.map(ask => ask.id)).toEqual(['k1', 'k2'])
  expect(board.resolved).toEqual([])
})

test('a finished session takes no answer; an unknown one is no such session', async () => {
  const t = terminal()

  t.seed(META, { lines: [...POSTED, [T0 + MIN, finish('lee')]] })

  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).err).toBe(
    'sitrep: This session is finished: its asks wait on you no more.\n',
  )
  expect((await t.run('answer', 'k1', 'Go', '--session', 'sr-zzzzzz')).exit).toBe(EXIT.noSession)
})
