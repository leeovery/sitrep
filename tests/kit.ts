/**
 * The engine's test kit, its `test` given a longer time limit, and failing
 * a test that moved the mock clock once one of its hooks had overrun the
 * engine's budget.
 *
 * The kit's own 5 seconds is near what the drawn and delivering tests take
 * on a quiet machine (2 to 6 seconds each), so a busy one failed them by the
 * clock alone, the release's pre-tag run among them (15 November 2026). 20
 * seconds is the most the kit gives a test (asked for 30, it stopped one at
 * 20), so one that hangs still fails. Past 10 seconds of real time, though,
 * the engine stops a hook of the test's still running, the mock clock's
 * held waits among them, and the mod's timers end with them: a test moving
 * the clock after that fails on the guard below, whatever it checks.
 *
 * And `drained`, the settling of a test that drives the mod's code through
 * plain promises and fakes, with no engine and no mock clock beneath it.
 */
import type { HookFailure, On } from 'claude-code'
import {
  mock as kitMock,
  test as kitTest,
  type Mock,
  type TestBody,
  type TestRest,
} from 'claude-code/testing'

export * from 'claude-code/testing'

const TEST_MS = 20_000

/** What a test's hooks did to it: the events whose hooks overran, and whether the mock clock moved once one had. */
type Guard = { overran: string[]; isClockMovedAfter: boolean }

/** Each test's guard, by the `on` its body was handed. */
const guards = new WeakMap<On, Guard>()

/** `on` as the guard calls it, untyped beyond what it reads: every overload's arguments passed on, and a `.catch` reading why a hook failed. */
type Registering = (...args: readonly unknown[]) => {
  catch: (
    handler: ($: unknown, e: unknown, next: { event: string; error: HookFailure }) => undefined,
  ) => void
}

/**
 * `on`, each hook it registers watched for overrunning the engine's budget,
 * and named in the guard when it does; the hook is still skipped, as one
 * with no `.catch` is. A test's own `.catch` on a registration runs too, its
 * answer standing. Proven by a test that waited 11 seconds of real time
 * holding the mock clock's waits: its hook on `clock.every` overran, the
 * engine refused the mod's next `$.clock.every`, and the heartbeat never
 * moved again however far the clock went (16 November 2026).
 */
const watched = (on: On, guard: Guard): On =>
  ((...args: readonly unknown[]) => {
    const registration = (on as unknown as Registering)(...args)

    registration.catch(($, e, next) => {
      if (next.error.kind === 'timeout') {
        guard.overran.push(next.event)
      }

      return undefined
    })

    return registration
  }) as unknown as On

/** The kit's mocks, the clock telling the guard of the test whose `on` it hooks each time it moves. */
export const mock: Mock = {
  ...kitMock,
  clock: (on, options) => {
    const clock = kitMock.clock(on, options)
    const moved = async (move: Promise<void>) => {
      try {
        await move
      } finally {
        const guard = guards.get(on)

        if (guard !== undefined && guard.overran.length > 0) {
          guard.isClockMovedAfter = true
        }
      }
    }

    return {
      now: () => clock.now(),
      advance: ms => moved(clock.advance(ms)),
      set: ms => moved(clock.set(ms)),
      settle: () => clock.settle(),
      sleep: ms => clock.sleep(ms),
    }
  },
}

/** Why a test whose hooks overran is luck from there on, naming them. */
const overrunText = (overran: readonly string[]) =>
  `the test's hook on ${[...new Set(overran)].join(', ')} overran the engine's 10 s budget: the test spent over 10 s of real time, so the engine stopped the hook, and with it the mock clock's held waits and the mod's timers on them; whatever the test checked after moved by luck. Make the test shorter.`

/** The body's failure, saying the hooks that overran where any did: the likelier cause. */
const withOverrun = (error: unknown, overran: readonly string[]) => {
  if (overran.length === 0) {
    return error
  }

  if (error instanceof Error) {
    error.message = `${error.message}\n\n${overrunText(overran)}`

    return error
  }

  return new Error(`${String(error)}\n\n${overrunText(overran)}`)
}

/** Runs `body`, failing it should it move the mock clock once one of its hooks overran: the timers had ended, so what it checked after was luck. */
const guarded =
  (body: TestBody): TestBody =>
  async ($, on) => {
    const guard: Guard = { overran: [], isClockMovedAfter: false }
    const watching = watched(on, guard)

    guards.set(watching, guard)

    try {
      await body($, watching)
    } catch (error) {
      throw withOverrun(error, guard.overran)
    }

    if (guard.isClockMovedAfter) {
      throw new Error(overrunText(guard.overran))
    }
  }

export const test = (name: string, ...rest: TestRest): void =>
  rest.length === 1
    ? kitTest(name, { timeoutMs: TEST_MS }, guarded(rest[0]))
    : kitTest(name, { timeoutMs: TEST_MS, ...rest[0] }, guarded(rest[1]))

/** The real timer the test's process runs, which the mod's types leave out: its code waits on `$.clock` alone. */
const { setTimeout: realTimeout } = globalThis as unknown as {
  setTimeout: (run: () => void, ms: number) => unknown
}

/**
 * Resolves once every promise callback queued, and every one those queue in
 * turn, has run: a real timer's turn comes only after them, however many
 * steps each chain takes, so no count of turns stands in for it. It settles
 * only code driven through plain promises and fakes in the test's own realm.
 * It waits on nothing that crosses the engine, whose `$` work the mod runs
 * in a realm of its own: a world test settles with its mock clock instead.
 */
export const drained = () =>
  new Promise<void>(resolve => {
    realTimeout(resolve, 0)
  })
