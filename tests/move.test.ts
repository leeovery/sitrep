import { expect, test } from 'claude-code/testing'
import { readSession } from '../cli/files'
import { EXIT, main, WRITER } from '../cli/main'
import {
  foldSession,
  metaText,
  movedTo,
  OLD_WINDOW_MS,
  parseEntries,
  sessionPaths,
  type SessionMeta,
  type SessionPaths,
} from '../core'
import {
  beat,
  file,
  META,
  MIN,
  note,
  reply,
  SENDER,
  seen,
  T0,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'
import { FIRST_ID, NOW, terminal } from './terminal'
import { ELSEWHERE, PROJECT, ROOT } from './world'

type Terminal = ReturnType<typeof terminal>

const SESSION = ['--session', META.id]

const LOBBY: SessionMeta = { ...META, id: 'sr-bbbbbb', name: 'Lobby', by: W2 }

/** The version a window on this release says in its heartbeat. */
const RUNNING = '0.2.0'

const DAY = 24 * 60 * MIN

/** When a window on an old version was last seen, long enough before the run that the move no longer waits on it. */
const LONG_GONE = NOW - OLD_WINDOW_MS - DAY

const L1: Line = [T0, yesAsk('k1', 'Review round 1')]
const L2: Line = [T0 + MIN, note('n2', 'Drew round 2')]
const L3: Line = [T0 + 2 * MIN, note('n3', 'Woke and wrote this')]

/** The session as the CLI reads it, under either layout. */
const folded = async (t: Terminal, paths: SessionPaths) => {
  const session = foldSession(await readSession(t.io, paths), NOW)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

/** Every file under a layout's folders, by its path. */
const filedUnder = (t: Terminal, layout: 'sessions' | 'works') =>
  [...t.files.keys()].filter(path => path.includes(`/${layout}/`)).sort()

/** The board's files as they stand, path and text. */
const snapshot = (t: Terminal) =>
  Object.fromEntries([...t.files].map(([path, held]) => [path, held.text]))

/** A session filed under the old layout, its window, on an old version, last seen eight days before the run. */
const seedOld = (t: Terminal, meta = META, lines: Line[] = [L1], project = PROJECT.key) =>
  t.seed(meta, { project, isOld: true, lines, seenAt: LONG_GONE })

/** Every file of a session's old folder moved into today's at once, as another run moves them. */
const moveAll = async (t: Terminal, paths: SessionPaths) => {
  for (const path of [...t.files.keys()].filter(each => each.startsWith(`${paths.old.dir}/`))) {
    await t.io.fs.moveIn(path, movedTo(paths, path))
  }
}

test('the CLI reads a session filed under works/ as one under sessions/, while a window on an old version keeps it there', async () => {
  const t = terminal()
  const paths = t.seed(META, { isOld: true, lines: [L1, L2], seenAt: NOW })
  const run = await t.run('board', ...SESSION)

  expect(run.exit).toBe(EXIT.done)
  expect(run.out).toContain('k1 wants a yes (Approve), waiting on Lee: Review round 1')
  expect(run.out).toContain('Drew round 2')
  expect(filedUnder(t, 'works')).toEqual(
    [paths.old.meta, paths.old.log(W1), paths.old.heartbeat(W1)].sort(),
  )
})

test('meanwhile the CLI appends under sessions/ alone, its count going on from its file under works/, which it leaves as it was', async () => {
  const t = terminal()
  const paths = t.seed(META, { isOld: true, lines: [L1], seenAt: NOW })
  const before = file(L2)

  t.files.set(paths.old.log(WRITER), { text: before, mtimeMs: T0 })

  expect((await t.run('note', 'Round 3 drawn', ...SESSION)).out).toBe(`${FIRST_ID}\n`)
  expect(parseEntries(t.text(paths.log(WRITER))).map(line => [line.seq, line.type])).toEqual([
    [2, 'note'],
  ])
  expect(t.text(paths.old.log(WRITER))).toBe(before)
  expect((await folded(t, paths)).log.map(line => line.text)).toEqual([
    'Round 3 drawn',
    'Drew round 2',
  ])
})

test('a torn last line of the file the CLI appends to is ended first, though its lines under both layouts end whole', async () => {
  const t = terminal()
  const paths = t.seed(META, { isOld: true, lines: [L1], seenAt: NOW })
  const torn = `${file(L3)}{"v":1,"at":${T0},"seq":2,"ty`

  t.files.set(paths.old.log(WRITER), { text: file(L1, L2), mtimeMs: T0 })
  t.files.set(paths.log(WRITER), { text: torn, mtimeMs: T0 })

  expect((await t.run('note', 'Round 3 drawn', ...SESSION)).exit).toBe(EXIT.done)
  expect(t.text(paths.log(WRITER)).startsWith(`${torn}\n`)).toBe(true)
  expect(parseEntries(t.text(paths.log(WRITER))).map(line => [line.seq, line.type])).toEqual([
    [1, 'note'],
    [3, 'note'],
  ])
})

test("a session read as another run moves it, between the reads of the two layouts, reads whole: the old layout first, then today's", async () => {
  const t = terminal()
  const paths = t.seed(META, { isOld: true, lines: [L1, L2] })
  const { list } = t.io.fs
  let isMoved = false

  t.io.fs.list = async dir => {
    const listed = await list(dir)

    if (dir === paths.old.dir && !isMoved) {
      isMoved = true
      await moveAll(t, paths)
    }

    return listed
  }

  const session = await folded(t, paths)

  expect(filedUnder(t, 'works'), 'the move landed').toEqual([])
  expect(session.asks.map(ask => ask.id)).toEqual(['k1'])
  expect(session.log.map(line => line.id)).toEqual(['n2'])
})

test('a run moves every session filed under works/ into sessions/, each file renamed in, work.json as session.json, and the emptied folders removed', async () => {
  const t = terminal()
  const paths = seedOld(t)
  const lobby = seedOld(t, LOBBY, [L2])
  const elsewhere = seedOld(t, { ...META, id: 'sr-cccccc' }, [L3], ELSEWHERE.key)

  t.files.set(paths.old.letters(SENDER), {
    text: file([T0, reply('r1', 'k1', 'yes')]),
    mtimeMs: T0,
  })
  t.seed({ ...META, id: 'sr-dddddd' }, { project: ELSEWHERE.key })

  const before = snapshot(t)

  expect((await t.run('list')).exit).toBe(EXIT.done)

  for (const each of [paths, lobby]) {
    expect(t.text(each.meta)).toBe(before[each.old.meta])
    expect(t.files.has(each.old.meta)).toBe(false)
  }

  expect(t.text(paths.log(W1))).toBe(before[paths.old.log(W1)])
  expect(t.text(paths.letters(SENDER))).toBe(before[paths.old.letters(SENDER)])
  expect(t.text(paths.heartbeat(W1))).toBe(before[paths.old.heartbeat(W1)])
  expect(t.text(elsewhere.log(W1))).toBe(before[elsewhere.old.log(W1)])
  expect(filedUnder(t, 'works')).toEqual([])
  expect([...t.folders].filter(folder => folder.includes('/works'))).toEqual([])
  expect(
    (await t.io.fs.list(paths.project.dir)).map(entry => entry.name),
    'its project now files sessions/ alone',
  ).toEqual(['sessions'])
})

test('a heartbeat saying no version seen within the week, anywhere on the board, keeps the old layout where it is, as does one written within it that does not read', async () => {
  const torn = { text: '{"attachedAt":', mtimeMs: NOW - MIN }
  const cases = {
    'live, under works/': (t: Terminal, paths: SessionPaths) => t.window(paths.old, W2, NOW),
    'live, under sessions/, in another project': (t: Terminal) =>
      t.seed(LOBBY, { project: ELSEWHERE.key, seenAt: NOW }),
    'its Mac asleep six days': (t: Terminal, paths: SessionPaths) =>
      t.window(paths.old, W2, NOW - 6 * DAY),
    'torn under works/, written a minute before': (t: Terminal, paths: SessionPaths) =>
      t.files.set(paths.old.heartbeat(W2), torn),
    'torn under sessions/, written a minute before': (t: Terminal, paths: SessionPaths) =>
      t.files.set(paths.heartbeat(W2), torn),
    'there, written a minute before, but not to be read': (t: Terminal, paths: SessionPaths) => {
      const { read } = t.io.fs

      t.window(paths, W2, NOW - MIN, undefined, RUNNING)
      t.io.fs.read = async path =>
        path === paths.heartbeat(W2)
          ? Promise.reject(new Error(`EACCES: permission denied, open '${path}'`))
          : read(path)
    },
  }

  for (const [why, add] of Object.entries(cases)) {
    const t = terminal()

    add(t, seedOld(t))

    const before = snapshot(t)

    expect((await t.run('list')).exit, why).toBe(EXIT.done)
    expect(snapshot(t), why).toEqual(before)
  }
})

test('a heartbeat saying no version seen over a week before, one that let go, one saying its version, or one torn over a week before does not keep it', async () => {
  const beats = {
    'seen over a week before': [beat(W2, { attachedAt: T0, seenAt: NOW - OLD_WINDOW_MS - 1 }), T0],
    'let go': [beat(W2, { attachedAt: T0, seenAt: NOW, leftAt: NOW }), T0],
    'saying its version': [beat(W2, { attachedAt: T0, seenAt: NOW, version: RUNNING }), T0],
    'torn over a week before': ['{"attachedAt":', NOW - OLD_WINDOW_MS - 1],
  } as const

  for (const [why, [text, mtimeMs]] of Object.entries(beats)) {
    const t = terminal()
    const paths = seedOld(t)

    t.files.set(paths.old.heartbeat(W2), { text, mtimeMs })
    await t.run('list')

    expect(filedUnder(t, 'works'), why).toEqual([])
    expect(t.text(paths.heartbeat(W2)), why).toBe(text)
  }
})

test("a window's later heartbeat saying its version, as after its reload, frees the move from its earlier one saying none", async () => {
  const t = terminal()
  const paths = seedOld(t)

  t.window(paths.old, W2, NOW - 10 * MIN)
  t.window(paths, W2, NOW, undefined, RUNNING)
  await t.run('list')

  expect(filedUnder(t, 'works')).toEqual([])
})

test("a file under both layouts is merged into today's: the old lines it lacks appended, a work.json beside session.json dropped, the later heartbeat kept", async () => {
  const t = terminal()
  const paths = seedOld(t, META, [L1, L2, L3])
  const moved = file(L1, L2)
  const now = metaText({ ...META, name: 'As moved' })
  const earlier = seen(W2, NOW - 20 * MIN)
  const running = (writer: string, at: number) =>
    beat(writer, { attachedAt: at, seenAt: at, version: RUNNING })

  t.files.set(paths.meta, { text: now, mtimeMs: T0 })
  t.files.set(paths.log(W1), { text: moved, mtimeMs: T0 })
  t.files.set(paths.heartbeat(W1), { text: running(W1, LONG_GONE - DAY), mtimeMs: T0 })
  t.files.set(paths.heartbeat(W2), { text: running(W2, NOW - 5 * MIN), mtimeMs: T0 })
  t.files.set(paths.old.heartbeat(W2), { text: earlier, mtimeMs: T0 })

  const before = snapshot(t)

  await t.run('list')

  expect(t.text(paths.log(W1))).toBe(`${moved}${before[paths.old.log(W1)]?.split('\n')[2]}\n`)
  expect(t.text(paths.meta)).toBe(now)
  expect(t.text(paths.heartbeat(W1)), 'the old, seen later').toBe(before[paths.old.heartbeat(W1)])
  expect(t.text(paths.heartbeat(W2)), "today's, seen later").toBe(before[paths.heartbeat(W2)])
  expect(filedUnder(t, 'works')).toEqual([])
  expect((await folded(t, paths)).log.map(line => line.id)).toEqual(['n3', 'n2'])
})

test("a heartbeat two runs both replace is never lost, though one run's whole move lands between the other's look and its replace", async () => {
  const t = terminal()
  const paths = seedOld(t)
  const before = snapshot(t)

  t.files.set(paths.heartbeat(W1), {
    text: beat(W1, { attachedAt: T0, seenAt: LONG_GONE - DAY, version: RUNNING }),
    mtimeMs: T0,
  })

  const { fs } = t.io
  const beats = [paths.old.heartbeat(W1), paths.heartbeat(W1)]
  let paused = () => {}
  let release = () => {}
  const isPaused = new Promise<void>(resolve => {
    paused = resolve
  })
  const isReleased = new Promise<void>(resolve => {
    release = resolve
  })
  /** A step of the second run on the heartbeat, made only once the first run's move is done. */
  const later =
    <A extends string[], R>(step: (...args: A) => Promise<R>) =>
    async (...args: A) => {
      if (args.some(arg => beats.includes(arg))) {
        paused()
        await isReleased
      }

      return step(...args)
    }
  const second = main(['list'], {
    ...t.io,
    fs: { ...fs, remove: later(fs.remove), moveIn: later(fs.moveIn), replace: later(fs.replace) },
  })

  await isPaused
  expect(await main(['list'], t.io)).toBe(EXIT.done)
  release()
  expect(await second).toBe(EXIT.done)

  expect(t.text(paths.heartbeat(W1))).toBe(before[paths.old.heartbeat(W1)])
  expect(filedUnder(t, 'works')).toEqual([])
})

test("a line another run appends under today's name as the move renames the old file in is never lost: the old one's lines are appended after it", async () => {
  const t = terminal()
  const paths = seedOld(t)
  const before = file(L1, L2)
  const appended = file([NOW, note('n9', 'Appended at once')])
  const { moveIn } = t.io.fs

  t.files.set(paths.old.log(WRITER), { text: before, mtimeMs: T0 })
  t.io.fs.moveIn = async (from, to) => {
    if (to === paths.log(WRITER)) {
      await t.io.fs.append(to, appended)
    }

    return moveIn(from, to)
  }
  await t.run('list')

  expect(t.text(paths.log(WRITER))).toBe(`${appended}${before}`)
  expect(t.files.has(paths.old.log(WRITER))).toBe(false)
})

test('a file the move does not know, under both layouts, is left in the old folder, which stays', async () => {
  const t = terminal()
  const paths = seedOld(t)
  const finder = `${paths.old.dir}/.DS_Store`

  t.files.set(finder, { text: 'Finder', mtimeMs: T0 })
  t.files.set(`${paths.dir}/.DS_Store`, { text: 'Finder', mtimeMs: T0 })
  await t.run('list')

  expect(filedUnder(t, 'works')).toEqual([finder])
  expect(t.text(paths.log(W1))).toBe(file(L1))
})

test('run again, the move changes nothing more', async () => {
  const t = terminal()

  seedOld(t)
  seedOld(t, LOBBY, [L2])
  await t.run('list')

  const once = snapshot(t)

  await t.run('list')

  expect(snapshot(t)).toEqual(once)
})

test('two runs moving at once leave the board as one run does', async () => {
  const one = terminal()
  const two = terminal()

  for (const t of [one, two]) {
    const paths = seedOld(t, META, [L1, L2])

    t.files.set(paths.log(W1), { text: file(L1), mtimeMs: T0 })
    seedOld(t, LOBBY, [L3])
  }

  await main(['list'], one.io)
  expect(await Promise.all([main(['list'], two.io), main(['list'], two.io)])).toEqual([
    EXIT.done,
    EXIT.done,
  ])

  for (const meta of [META, LOBBY]) {
    const paths = sessionPaths(ROOT, PROJECT.key, meta.id)

    expect(await folded(two, paths), meta.id).toEqual(await folded(one, paths))
    expect(parseEntries(two.text(paths.log(meta.by))), meta.id).toEqual(
      parseEntries(one.text(paths.log(meta.by))),
    )
  }

  expect(filedUnder(two, 'works')).toEqual([])
})

test('a move that fails is told, and the command runs on, its line landing as ever', async () => {
  const t = terminal()
  const paths = seedOld(t)

  t.io.fs.moveIn = async () => {
    throw new Error('EACCES: permission denied')
  }

  const run = await t.run('note', 'Round 3 drawn', ...SESSION)

  expect(run).toEqual({
    exit: EXIT.done,
    out: `${FIRST_ID}\n`,
    err: 'sitrep: moving the old layout failed: EACCES: permission denied\n',
  })
  expect(parseEntries(t.text(paths.log(WRITER))).map(line => line.type)).toEqual(['note'])
})

test('what is left under works/ that the move cannot act on, a Finder file or a folder that is no session, has a run read no heartbeat beyond what its command reads', async () => {
  const t = terminal()
  const lobby = t.seed(LOBBY, { project: ELSEWHERE.key, seenAt: NOW })
  const paths = sessionPaths(ROOT, PROJECT.key, META.id)
  const left = [
    `${paths.old.sessions}/.DS_Store`,
    `${paths.old.sessions}/sr-cccccc/.DS_Store`,
    `${paths.old.sessions}/drafts/notes.txt`,
  ]
  const read: string[] = []
  const { read: reading } = t.io.fs

  t.seed(META)
  left.forEach(path => t.files.set(path, { text: 'left', mtimeMs: T0 }))
  t.io.fs.read = async path => {
    read.push(path)

    return reading(path)
  }

  expect((await t.run('note', 'Round 3 drawn', ...SESSION)).exit).toBe(EXIT.done)
  expect(read).not.toContain(lobby.heartbeat(W2))
  expect(filedUnder(t, 'works')).toEqual(left.sort())
})

test('with nothing filed under works/, a run reads no heartbeat beyond what its command reads', async () => {
  const t = terminal()
  const lobby = t.seed(LOBBY, { project: ELSEWHERE.key, seenAt: NOW })
  const read: string[] = []
  const { read: reading } = t.io.fs

  t.seed(META)
  t.io.fs.read = async path => {
    read.push(path)

    return reading(path)
  }

  expect((await t.run('note', 'Round 3 drawn', ...SESSION)).exit).toBe(EXIT.done)
  expect(read).not.toContain(lobby.heartbeat(W2))
})

test('a file listed but gone by its read, as a run moving it at once leaves it, reads as not there, and the run goes on', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: [L1] })
  const { read: reading } = t.io.fs

  t.files.set(paths.log(W2), { text: file(L2), mtimeMs: T0 })
  t.io.fs.read = async path =>
    path === paths.log(W2) ? Promise.reject(new Error(`ENOENT: ${path}`)) : reading(path)

  const run = await t.run('board', ...SESSION)

  expect(run.exit).toBe(EXIT.done)
  expect(run.out).toContain('Review round 1')
  expect(run.out).not.toContain('Drew round 2')
})
