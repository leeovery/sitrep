import { expect, test } from './kit'
import { looking, POLL_MS, type Look, type Run } from '../cli/looks'
import { append, type Body, type SessionPaths } from '../core'
import { META, PLUGIN_VERSION, PROJECT, REPO, T0, W1 } from './data'
import { yesAsk } from './lines'
import { WHERE } from './world'
import { manifestText, MANIFEST, NOW, terminal } from './terminal'

type Terminal = ReturnType<typeof terminal>

/** Northwind, living in REPO, and the session under test there asking k1, its window W1 seen now. */
const seeded = () => {
  const t = terminal()

  t.project(PROJECT.key, { name: PROJECT.name, directory: REPO, created: T0, by: W1 })

  const paths = t.seed(META, { lines: [[T0, yesAsk('k1', 'Review round 1')]], seenAt: NOW, where: WHERE })

  return { t, paths }
}

/** Lines the CLI appends to the session's file, as the clock stands. */
const post = (t: Terminal, paths: SessionPaths, ...bodies: Body[]) => {
  const path = paths.log('cli')
  const now = t.io.now()

  t.files.set(path, { text: append(t.files.get(path)?.text ?? '', bodies, now).text, mtimeMs: now })
}

/**
 * The looks over the terminal's files, the steps taken in turn, one at each
 * wait, the clock moved on by it; the run ending once they are all taken.
 * Every look handed, and every wait asked for.
 */
const looked = async (
  t: Terminal,
  steps: readonly (() => void)[],
  followed?: () => ReadonlySet<string>,
) => {
  const queue = [...steps]
  const looks: Look[] = []
  const waits: number[] = []
  const run: Run = {
    isEnded: () => queue.length === 0 && waits.length > steps.length,
    wake: () => {},
    wait: async ms => {
      waits.push(ms)
      await t.io.wait(ms)
      queue.shift()?.()
    },
    stop: () => {},
  }

  await looking(t.io, run, look => looks.push(look), followed)

  return { looks, waits }
}

/** The keys of a feed's lines, its rows' in order. */
const keys = (look: Look | undefined) =>
  look?.feed().rows.flatMap(row => row.lines.map(each => each.key))

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

test('each look carries the version the run started on, and the looks end once the manifest says another', async () => {
  const { t } = seeded()

  const { looks } = await looked(t, [
    () => t.files.set(MANIFEST, { text: manifestText('9.9.9'), mtimeMs: t.io.now() }),
    () => {},
  ])

  expect(looks.map(each => each.version)).toEqual([PLUGIN_VERSION])
})

test('each look carries the sessions followed as it read them, none unless given', async () => {
  const { t } = seeded()
  const sets = [new Set([META.id]), new Set<string>()]
  let at = 0

  const { looks } = await looked(t, [() => (at += 1)], () => sets[at] ?? new Set())
  const { looks: unfollowed } = await looked(seeded().t, [])

  expect(looks.map(each => [...each.followed])).toEqual([[META.id], []])
  expect(unfollowed.map(each => [...each.followed])).toEqual([[]])
})
