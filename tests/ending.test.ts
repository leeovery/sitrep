import { expect, test } from 'claude-code/testing'
import { endOf, PARENT_MS, type Signals } from '../cli/ending'

/** The app's pid, the run's parent as the CLI loaded. */
const APP = 4321

/**
 * The process a run's end is heard from: its parent `parents` says, the
 * listeners held while listening, and what fires each.
 */
const processOf = (parents: () => number = () => APP) => {
  const terms = new Set<() => void>()
  const failures = new Set<() => void>()
  const ticks = new Set<() => void>()
  const periods: number[] = []
  const held = (listeners: Set<() => void>) => (heard: () => void) => {
    listeners.add(heard)

    return () => listeners.delete(heard)
  }
  const signals: Signals = {
    parent: parents,
    onTerm: held(terms),
    onOutputFailed: held(failures),
    every: (ms, tick) => {
      periods.push(ms)

      return held(ticks)(tick)
    },
  }
  const fire = (listeners: Set<() => void>) => () => [...listeners].forEach(each => each())

  return {
    signals,
    periods,
    term: fire(terms),
    fail: fire(failures),
    tick: fire(ticks),
    listening: () => terms.size + failures.size + ticks.size,
  }
}

/** Whether the run has ended, once every promise that can has settled. */
const isEnded = async (ended: Promise<void>) => {
  let isDone = false

  void ended.then(() => {
    isDone = true
  })

  for (let turn = 0; turn < 10; turn += 1) {
    await Promise.resolve()
  }

  return isDone
}

test('SIGTERM ends the run, and what it listened by goes with it', async () => {
  const world = processOf()
  const { ended } = endOf(world.signals, APP)

  expect(await isEnded(ended)).toBe(false)

  world.term()

  expect(await isEnded(ended)).toBe(true)
  expect(world.listening()).toBe(0)
})

test('standard output failing, as a write to a pipe its reader closed, ends the run', async () => {
  const world = processOf()
  const { ended } = endOf(world.signals, APP)

  world.fail()

  expect(await isEnded(ended)).toBe(true)
  expect(world.listening()).toBe(0)
})

test('the parent quitting ends the run at the next look, a second apart; while it stays, the run goes on', async () => {
  let parent = APP
  const world = processOf(() => parent)
  const { ended } = endOf(world.signals, APP)

  world.tick()
  world.tick()

  expect(world.periods).toEqual([PARENT_MS])
  expect(await isEnded(ended)).toBe(false)

  parent = 1
  world.tick()

  expect(await isEnded(ended)).toBe(true)
  expect(world.listening()).toBe(0)
})

test('a parent gone before the run asks ends it at once, launchd its parent already: gone before the CLI loaded, or since', async () => {
  const unheard = processOf(() => 1)
  const since = processOf(() => 1)

  expect(await isEnded(endOf(unheard.signals, 1).ended)).toBe(true)
  expect(await isEnded(endOf(since.signals, APP).ended)).toBe(true)
  expect(unheard.listening() + since.listening()).toBe(0)
})

test('the listening stopped, as a run ends some other way, holds nothing: no signal is listened for, and no look made', async () => {
  const world = processOf()
  const { ended, stop } = endOf(world.signals, APP)

  expect(world.listening()).toBe(3)

  stop()
  world.term()

  expect(world.listening()).toBe(0)
  expect(await isEnded(ended)).toBe(false)
})
