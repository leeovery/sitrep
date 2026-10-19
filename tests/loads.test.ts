import type { On } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import { HEARTBEAT_MS, parsePresence, presenceText, QUIET, type SessionPaths } from '../core'
import { STATE_MS } from '../hooks/doing'
import type { SitrepActivity } from '../types'
import { T0, W1 } from './support'
import { world } from './world'

tier('user')

type World = ReturnType<typeof world>

/**
 * The window's state in `$.state` as the host keeps it, versioned, so a test
 * can write it as another load of the mod would: every write the mod tried,
 * with the version it named.
 */
const activityStore = (on: On) => {
  let kept: { value?: SitrepActivity; version: number } = { version: 0 }
  const tried: { value: SitrepActivity; ifVersion?: number }[] = []

  on('state.get', { plugin: 'sitrep', key: 'activity' }, () => ({ value: kept }) as never)
  on('state.set', { plugin: 'sitrep', key: 'activity' }, ($, e) => {
    const { value, ifVersion } = e as { value: SitrepActivity; ifVersion?: number }

    tried.push({ value, ifVersion })

    if (ifVersion !== undefined && ifVersion !== kept.version) {
      return { value: { isSet: false, version: kept.version } } as never
    }

    kept = { value, version: kept.version + 1 }

    return { value: { isSet: true, version: kept.version } } as never
  })

  return {
    tried,
    kept: () => kept.value,
    /** Writes `value` as another load would. */
    byAnother: (value: SitrepActivity) => {
      kept = { value, version: kept.version + 1 }
    },
  }
}

/** How many times the window has written its heartbeat on a session. */
const beats = (w: World, paths: SessionPaths) =>
  w.written.filter(path => path === paths.heartbeat(W1)).length

/** The lines saying a later load wrote over this one. */
const outrun = (w: World) => w.logs.filter(line => line.includes('a later load of the mod'))

/** A turn, its end, and a beat: what would each write the heartbeat and the state. */
const goOn = async (w: World) => {
  await w.turnStarts('Carry on.')
  await w.clock.advance(STATE_MS)
  await w.turnEnds()
  await w.clock.advance(HEARTBEAT_MS)
}

test('each load stamps its heartbeat and the state it keeps with when it began', async ($, on) => {
  const store = activityStore(on)
  const w = world($, on, { now: T0 + 60_000 })
  const { paths } = await w.begin()

  await w.turnStarts('Carry on.')
  await w.clock.settle()

  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.loadedAt).toBe(T0 + 60_000)
  expect(store.kept()).toEqual({ turnAt: T0 + 60_000, ...QUIET, loadedAt: T0 + 60_000 })
})

test("a load that finds a later load's stamp on its heartbeat writes neither it nor the state again, and says so once", async ($, on) => {
  const store = activityStore(on)
  const w = world($, on)
  const { paths } = await w.begin()
  const theirs = presenceText({
    ...parsePresence(w.text(paths.heartbeat(W1)), W1)!,
    seenAt: T0 + 500,
    state: { is: 'working', since: T0 + 500 },
    loadedAt: T0 + 500,
  })

  w.put(paths.heartbeat(W1), theirs)
  await w.turnStarts('Carry on.')
  await w.clock.advance(STATE_MS)

  const tried = store.tried.length

  await goOn(w)

  expect(w.text(paths.heartbeat(W1))).toBe(theirs)
  expect(store.tried.length, 'the state unwritten').toBe(tried)
  expect(outrun(w)).toEqual([
    "sitrep: a later load of the mod wrote the window's heartbeat: this one writes the window's heartbeat and state no more",
  ])
})

test("a write of the state that misses on a later load's leaves it be, and the load writes neither it nor the heartbeat again", async ($, on) => {
  const store = activityStore(on)
  const w = world($, on)
  const { paths } = await w.begin()
  const theirs: SitrepActivity = { ...QUIET, endedAt: T0 + 500, loadedAt: T0 + 500 }

  store.byAnother(theirs)
  await w.turnStarts('Carry on.')
  await w.clock.advance(STATE_MS)

  const tried = store.tried.length
  const written = beats(w, paths)

  await goOn(w)

  expect(store.tried.at(-1)?.value.turnAt, 'the turn tried once, and missed').toBe(T0)
  expect(store.tried.length, 'the state unwritten').toBe(tried)
  expect(store.kept()).toEqual(theirs)
  expect(beats(w, paths), 'the heartbeat unwritten').toBe(written)
  expect(outrun(w)).toEqual([
    "sitrep: a later load of the mod wrote the window's state in $.state: this one writes the window's heartbeat and state no more",
  ])
})

test("a write of the state that misses on an earlier load's writes over it, on the version it stands at", async ($, on) => {
  const store = activityStore(on)
  const w = world($, on)

  await w.begin()
  store.byAnother({ ...QUIET, turnAt: T0 - 60_000, loadedAt: T0 - 60_000 })

  const version = store.tried.at(-1)?.ifVersion ?? 0

  await w.turnStarts('Carry on.')
  await w.clock.settle()

  expect(store.tried.slice(-2).map(each => each.ifVersion)).toEqual([version + 1, version + 2])
  expect(store.kept()).toEqual({ ...QUIET, turnAt: T0, loadedAt: T0 })
  expect(outrun(w)).toEqual([])
})
