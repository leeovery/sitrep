import { expect, test } from './kit'
import type { Io } from '../cli/io'
import { looking, POLL_MS, untilEnded, type Look, type Run, type Watcher } from '../cli/looks'
import { append, projectsDir, type Body, type SessionPaths } from '../core'
import { META, PLUGIN_VERSION, PROJECT, REPO, ROOT, T0, W1 } from './data'
import { yesAsk } from './lines'
import { WHERE } from './world'
import { manifestText, MANIFEST, NOW, terminal } from './terminal'

type Terminal = ReturnType<typeof terminal>

/** Northwind, living in REPO, and the session under test there asking k1, its window W1 seen now. */
const seeded = () => {
  const t = terminal()

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, {
    lines: [[T0, yesAsk('k1', 'Review round 1')]],
    seenAt: NOW,
    where: WHERE,
  })

  return { t, paths }
}

/** Lines the CLI appends to the session's file, as the clock stands. */
const post = (t: Terminal, paths: SessionPaths, ...bodies: Body[]) => {
  const path = paths.log('cli')
  const now = t.io.now()

  t.files.set(path, { text: append(t.files.get(path)?.text ?? '', bodies, now).text, mtimeMs: now })
}

/** The manifest saying another version. */
const upgrade = (t: Terminal) =>
  t.files.set(MANIFEST, { text: manifestText('9.9.9'), mtimeMs: t.io.now() })

/**
 * The looks over `io`, the steps taken in turn, one at each wait, the clock
 * moved on by it; the run ending once they are all taken. Every look
 * handed, and every wait asked for.
 */
const looked = async (
  t: Terminal,
  steps: readonly (() => void)[],
  watcher: Omit<Watcher, 'seen'> = {},
  io: Io = t.io,
) => {
  const queue = [...steps]
  const looks: Look[] = []
  const waits: number[] = []
  const run: Run = {
    isEnded: () => queue.length === 0 && waits.length > steps.length,
    wake: () => {},
    end: () => {},
    wait: async ms => {
      waits.push(ms)
      await t.io.wait(ms)
      queue.shift()?.()
    },
    stop: () => {},
  }

  await looking(io, run, { ...watcher, seen: look => looks.push(look) })

  return { looks, waits }
}

/** The keys of a feed's lines, its rows' in order. */
const keys = (look: Look | undefined) =>
  look?.feed().rows.flatMap(row => row.lines.map(each => each.key))

/** The terminal's world, its look at the projects' folder failing while `isFailing` says. */
const failingWhile = (t: Terminal, isFailing: () => boolean): Io => ({
  ...t.io,
  fs: {
    ...t.io.fs,
    stat: async path => {
      if (path === projectsDir(ROOT) && isFailing()) {
        throw new Error(`EACCES: permission denied, stat '${path}'`)
      }

      return t.io.fs.stat(path)
    },
  },
})

test("each look hands the board's feed as it stands then, once a second, until the run ends", async () => {
  const { t, paths } = seeded()

  const { looks, waits } = await looked(t, [() => post(t, paths, yesAsk('k2', 'Ship it'))])

  expect(looks.map(keys)).toEqual([
    [`ask:${META.id}:k1`],
    [`ask:${META.id}:k2`, `ask:${META.id}:k1`],
  ])
  expect(looks.map(each => each.now)).toEqual([NOW, NOW + POLL_MS])
  expect(waits).toEqual([POLL_MS, POLL_MS])
})

test('a look where nothing was folded anew says so, and its feed is made once, however often asked for', async () => {
  const { t } = seeded()

  const { looks } = await looked(t, [() => {}])

  expect(looks.map(each => each.isSame)).toEqual([false, true])
  expect(looks[1]?.feed()).toBe(looks[1]?.feed())
})

test("each look finds a session's board as that look read it, not as a later one did", async () => {
  const { t, paths } = seeded()

  const { looks } = await looked(t, [() => post(t, paths, yesAsk('k2', 'Ship it'))])
  const isShipping = looks.map(each => each.boardById(META.id)?.text.includes('Ship it'))

  expect(isShipping).toEqual([false, true])
})

test('where the caller says so, the looks end once the manifest says another version than the run started on', async () => {
  const { t } = seeded()

  const { looks } = await looked(t, [() => upgrade(t), () => {}], { endsOnNewVersion: true })

  expect(looks.map(each => each.version)).toEqual([PLUGIN_VERSION])
})

test('otherwise the looks go on across a new version, each carrying the version the run started on', async () => {
  const { t } = seeded()

  const { looks } = await looked(t, [() => upgrade(t), () => {}])

  expect(looks.map(each => each.version)).toEqual([PLUGIN_VERSION, PLUGIN_VERSION, PLUGIN_VERSION])
})

test('each look carries the sessions followed as it read them, none unless given', async () => {
  const { t } = seeded()
  const sets = [new Set([META.id]), new Set<string>()]
  let at = 0

  const { looks } = await looked(t, [() => (at += 1)], { followed: () => sets[at] ?? new Set() })
  const { looks: unfollowed } = await looked(seeded().t, [])

  expect(looks.map(each => [...each.followed])).toEqual([[META.id], []])
  expect(unfollowed.map(each => [...each.followed])).toEqual([[]])
})

test('a look that fails ends the looks with its error, unless the caller says to go on', async () => {
  const { t } = seeded()
  let isFailing = false
  const io = failingWhile(t, () => isFailing)

  const ended = looked(t, [() => (isFailing = true), () => {}], {}, io)

  expect(await ended.then(() => 'went on', (error: Error) => error.message)).toBe(
    `EACCES: permission denied, stat '${projectsDir(ROOT)}'`,
  )
})

test('told to go on past a failure, the looks pass over the failed one, wait a second, and hand the next that reads', async () => {
  const { t } = seeded()
  let isFailing = false
  const failures: unknown[] = []
  const io = failingWhile(t, () => isFailing)

  const { looks, waits } = await looked(
    t,
    [() => (isFailing = true), () => (isFailing = false)],
    { isPastFailure: error => failures.push(error) > 0 },
    io,
  )

  expect(failures.length).toBe(1)
  expect(looks.map(each => [each.now, keys(each)])).toEqual([
    [NOW, [`ask:${META.id}:k1`]],
    [NOW + 2 * POLL_MS, [`ask:${META.id}:k1`]],
  ])
  expect(waits).toEqual([POLL_MS, POLL_MS, POLL_MS])
})

test('a run ended from within, as the panel quitting does, looks no more, its wait cut short', async () => {
  const { t } = seeded()
  const run = untilEnded(t.io)
  const looks: Look[] = []

  await looking(t.io, run, {
    seen: look => {
      looks.push(look)
      run.end()
    },
  })
  run.stop()

  expect(run.isEnded()).toBe(true)
  expect(looks.length).toBe(1)
  expect(t.waits).toEqual([])
})
