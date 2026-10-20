import { expect, test } from 'claude-code/testing'
import { readSession } from '../cli/files'
import { EXIT, WRITER } from '../cli/main'
import { foldSession, parseEntries, serialise, VERSION, type SessionPaths } from '../core'
import {
  choiceAsk,
  delivered,
  file,
  finish,
  META,
  MIN,
  note,
  park,
  reply,
  resolve,
  T0,
  W1,
  wordsAsk,
  yesAsk,
  type Line,
} from './support'
import { FIRST_ID, NEXT_ID, NOW, terminal } from './terminal'

type Terminal = ReturnType<typeof terminal>

const SESSION = ['--session', META.id]

/** The session's window posted an ask of every shape, a note and a parked item. */
const POSTED: Line[] = [
  [T0, yesAsk('k1', 'Give the go for stage 3', 'Go')],
  [T0, choiceAsk('k2', 'Keep the sidebar, or drop it?', ['Keep it', 'Drop it'])],
  [T0, wordsAsk('k3', 'Run the export', "the command's output")],
  [T0, note('n1', 'Merged')],
  [T0, park('p1', 'A tmux indicator')],
]

/** The CLI's letters in the session's inbox, as lines. */
const letters = (t: Terminal, paths: SessionPaths) =>
  parseEntries(t.text(paths.letters(WRITER)))

/** The session as the CLI reads it, under either layout, its inbox among its files. */
const folded = async (t: Terminal, paths: SessionPaths) => {
  const session = foldSession(await readSession(t.io, paths), NOW)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

type Answer = { is: string; words: string; since: number } | null

type Board = {
  asks: { id: string; state: string; answer: Answer }[]
  resolved: { id: string; answer: Answer; closedAt: number | null; reason: string | null }[]
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

test('the board never closes an ask on the answer alone: it waits, counted, its answer on its way, until a window gives it to Claude', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: POSTED })

  await t.run('answer', 'k1', 'Go', ...SESSION)

  const session = await folded(t, paths)

  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.asks[0]?.answer).toBeUndefined()
  expect(session.replies).toMatchObject([{ id: FIRST_ID, by: WRITER, delivery: 'closed' }])
  expect(session.waiting).toBe(3)
  expect(JSON.parse((await t.run('list', '--json')).out).projects[0].works[0].waiting).toBe(3)
  expect((await boardOf(t)).asks[0]).toMatchObject({
    id: 'k1',
    state: 'waiting',
    answer: { is: 'onItsWay', words: '→ Go', since: NOW },
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
      answer: { is: 'delivered', words: '→ Keep it', since: markedAt },
      closedAt: markedAt,
      reason: null,
    },
  ])
})

test("an ask Claude resolved shows in board --json's resolved with Claude's reason and no answer; the newest closed first", async () => {
  const t = terminal()

  t.seed(META, {
    lines: [
      ...POSTED,
      [T0 + MIN, resolve('k1', 'Went ahead in the chat')],
      [T0 + 2 * MIN, resolve('k2')],
    ],
  })

  expect((await boardOf(t)).resolved).toMatchObject([
    { id: 'k2', answer: null, closedAt: T0 + 2 * MIN, reason: null },
    { id: 'k1', answer: null, closedAt: T0 + MIN, reason: 'Went ahead in the chat' },
  ])
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

test('while a window on an old version keeps the old layout, the letters go under sessions/ alone, counting on from those under works/', async () => {
  const t = terminal()
  const paths = t.seed(META, { isOld: true, lines: POSTED, seenAt: NOW })
  const before = file([T0, reply('r1', 'k2', 'choose', { option: 'Keep it' })])

  t.files.set(paths.old.letters(WRITER), { text: before, mtimeMs: T0 })

  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).exit).toBe(EXIT.done)
  expect(letters(t, paths).map(line => [line.seq, line.type === 'reply' && line.item])).toEqual([
    [2, 'k1'],
  ])
  expect(t.text(paths.old.letters(WRITER))).toBe(before)
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
  const paths = t.seed(META, { lines: [...POSTED, [T0 + MIN, resolve('k1')]] })
  const refused = async (...words: string[]) => {
    const run = await t.run('answer', ...words, ...SESSION)

    expect([run.exit, run.out]).toEqual([EXIT.refused, ''])

    return run.err
  }

  expect(await refused('k1', 'Go')).toBe('sitrep: k1 is already closed.\n')
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
    err: 'sitrep: A reply to k1 is on its way already.\n',
  })
})

test('a finished session takes no answer; an unknown one is no such session', async () => {
  const t = terminal()

  t.seed(META, { lines: [...POSTED, [T0 + MIN, finish('lee')]] })

  expect((await t.run('answer', 'k1', 'Go', ...SESSION)).err).toBe(
    'sitrep: This session is finished: its asks wait on Lee no more.\n',
  )
  expect((await t.run('answer', 'k1', 'Go', '--session', 'sr-zzzzzz')).exit).toBe(EXIT.noSession)
})
