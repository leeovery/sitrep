import { expect, test } from 'claude-code/testing'
import {
  filedIds,
  foldSession,
  contentsAt,
  laterBeat,
  linesLacking,
  mergedFiles,
  mergedText,
  metaText,
  moving,
  parseEntries,
  sessionPaths,
  type FolderFiles,
} from '../core'
import { beat, file, META, MIN, note, SENDER, seen, T0, W1, W2, yesAsk, type Line } from './support'

const ROOT = '/state/sitrep'

const NONE: FolderFiles = { meta: '', logs: {} }

/** Lines a window wrote, each its own line of its file. */
const L1: Line = [T0, note('n1', 'Drew round 1')]
const L2: Line = [T0 + MIN, note('n2', 'Drew round 2')]
const L3: Line = [T0 + 2 * MIN, yesAsk('k3', 'Review round 2')]

/** The text of one line, as `file` writes it at its place in a file. */
const lineOf = (text: string, at: number) => text.split('\n')[at] ?? ''

test("a project's sessions are both layouts' folders, today's first, each once", () => {
  expect(filedIds(['sr-aaaaaa', 'sr-bbbbbb'], ['sr-bbbbbb', 'sr-cccccc'])).toEqual([
    'sr-aaaaaa',
    'sr-bbbbbb',
    'sr-cccccc',
  ])
  expect(filedIds([], ['sr-cccccc'])).toEqual(['sr-cccccc'])
})

test("a session's meta is today's session.json where it reads, else the old work.json", () => {
  const now = metaText({ ...META, name: 'As started now' })
  const old = metaText(META)
  const metaOf = (today: string, before: string) =>
    mergedFiles({ ...NONE, meta: today }, { ...NONE, meta: before }).meta

  expect(metaOf(now, old)).toBe(now)
  expect(metaOf('', old)).toBe(old)
  expect(metaOf(now.slice(0, 20), old), 'a torn one').toBe(old)
  expect(metaOf(now, '')).toBe(now)
})

test("a writer's file under both layouts reads as every line of both, a line in both counted once", () => {
  const files = mergedFiles(
    { ...NONE, logs: { [W1]: file(L1, L2) } },
    { ...NONE, logs: { [W1]: file(L1, L2, L3) } },
  )
  const session = foldSession({ ...files, meta: metaText(META) }, T0 + 3 * MIN)

  expect(parseEntries(files.logs[W1] ?? '').map(line => line.seq)).toEqual([1, 2, 3])
  expect(session?.log.map(line => line.id)).toEqual(['n2', 'n1'])
  expect(session?.asks.map(ask => ask.id)).toEqual(['k3'])
})

test("the old file is never left unread for today's: a line only in the old still reads, as one only in today's does", () => {
  const today = file(L1, L3)
  const old = file(L1, L2)
  const merged = mergedText(today, old)

  expect(merged).toBe(`${today}${lineOf(old, 1)}\n`)
  expect(parseEntries(merged).map(line => line.seq)).toEqual([1, 2, 2])
})

test('a line is one under both layouts only byte for byte: the same note written at another time is a line of its own', () => {
  const once = file(L1)
  const again = file([T0 + 1, L1[1]])

  expect(mergedText(once, once)).toBe(once)
  expect(mergedText(once, again)).toBe(once + again)
})

test("what today's file lacks of the old is each line once, after a newline ending a torn last line; nothing when it lacks none", () => {
  const old = file(L1, L2)
  const torn = `${lineOf(old, 0)}\n{"v":1,"at":`

  expect(linesLacking(old, old)).toBe('')
  expect(linesLacking('', `${old}${old}`)).toBe(old)
  expect(linesLacking(torn, old)).toBe(`\n${lineOf(old, 1)}\n`)
  expect(linesLacking(old, '')).toBe('')
})

test("a window's heartbeat under both layouts reads as the one seen later; today's when seen at once, and the one that reads over one that does not", () => {
  const early = seen(W1, T0)
  const late = seen(W1, T0 + MIN)
  const sameTime = beat(W1, { attachedAt: T0 - MIN, seenAt: T0 })

  expect(laterBeat(early, late)).toBe(late)
  expect(laterBeat(late, early)).toBe(late)
  expect(laterBeat(early, sameTime)).toBe(early)
  expect(laterBeat(early.slice(0, 10), early)).toBe(early)
  expect(
    mergedFiles({ ...NONE, presence: { [W1]: early } }, { ...NONE, presence: { [W1]: late } })
      .presence,
  ).toEqual({ [W1]: late })
})

test('a file under one layout alone reads as it is, whichever layout', () => {
  const now: FolderFiles = {
    meta: metaText(META),
    logs: { [W1]: file(L1) },
    inbox: { [SENDER]: file(L2) },
    presence: { [W1]: seen(W1, T0) },
  }
  const old: FolderFiles = {
    meta: '',
    logs: { [W2]: file(L3) },
    inbox: {},
    presence: { [W2]: seen(W2, T0) },
  }

  expect(mergedFiles(now, old)).toEqual({
    meta: now.meta,
    logs: { [W1]: file(L1), [W2]: file(L3) },
    inbox: { [SENDER]: file(L2) },
    presence: { [W1]: seen(W1, T0), [W2]: seen(W2, T0) },
  })
})

test("a sender's letters under both layouts read as every line of both, as a writer's file does", () => {
  const files = mergedFiles(
    { ...NONE, inbox: { [SENDER]: file(L1) } },
    { ...NONE, inbox: { [SENDER]: file(L1, L2) } },
  )

  expect(files.inbox?.[SENDER]).toBe(file(L1, L2))
})

test("what a file of a session's folder holds, by where it sits and its name", () => {
  const { old } = sessionPaths(ROOT, 'switchboard', META.id)

  expect(contentsAt(old, old.meta)).toBe('meta')
  expect(contentsAt(old, old.log(W1))).toBe('lines')
  expect(contentsAt(old, old.letters(SENDER))).toBe('lines')
  expect(contentsAt(old, old.heartbeat(W1))).toBe('beat')
  expect(contentsAt(old, `${old.dir}/.DS_Store`)).toBe('other')
  expect(contentsAt(old, `${old.presence}/${W1}.jsonl`)).toBe('other')
  expect(contentsAt(old, `${old.inbox}/${SENDER}.json`)).toBe('other')
})

test("moving, a file today's folder lacks is renamed in, whatever it holds", () => {
  for (const held of ['meta', 'lines', 'beat', 'other'] as const) {
    expect(moving(held, 'old', undefined), held).toEqual({ to: 'rename' })
  }
})

test("moving, lines under both append what today's file lacks, and never rewrite it", () => {
  expect(moving('lines', file(L1, L2), file(L1))).toEqual({
    to: 'append',
    text: `${lineOf(file(L1, L2), 1)}\n`,
  })
  expect(moving('lines', file(L1), file(L1, L2))).toEqual({ to: 'append', text: '' })
})

test("moving, a work.json beside a session.json is dropped: today's stands", () => {
  expect(moving('meta', metaText(META), metaText(META))).toEqual({ to: 'drop' })
})

test("moving, a heartbeat seen later than today's replaces it; one seen as late or earlier is dropped", () => {
  const early = seen(W1, T0)
  const late = seen(W1, T0 + MIN)

  expect(moving('beat', late, early)).toEqual({ to: 'replace' })
  expect(moving('beat', early, late)).toEqual({ to: 'drop' })
  expect(moving('beat', early, early)).toEqual({ to: 'drop' })
})

test('moving, any other file under both is left where it is', () => {
  expect(moving('other', 'Finder', 'Finder')).toEqual({ to: 'leave' })
})
