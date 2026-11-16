/**
 * The engine's test kit, its `test` given a longer time limit, and failing
 * a test whose own hooks overran the engine's budget.
 *
 * The kit's own 5 seconds is near what the drawn and delivering tests take
 * on a quiet machine (2 to 6 seconds each), so a busy one failed them by the
 * clock alone, the release's pre-tag run among them (15 November 2026). 20
 * seconds is the most the kit gives a test (asked for 30, it stopped one at
 * 20), and still fails one that hangs.
 */
import type { HookFailure, On } from 'claude-code'
import { test as kitTest, type TestBody, type TestRest } from 'claude-code/testing'

export * from 'claude-code/testing'

const TEST_MS = 20_000

/** `on` as the guard calls it, untyped beyond what it reads: every overload's arguments passed on, and a `.catch` reading why a hook failed. */
type Registering = (...args: readonly unknown[]) => {
  catch: (
    handler: ($: unknown, e: unknown, next: { event: string; error: HookFailure }) => undefined,
  ) => void
}

/**
 * `on`, each hook it registers watched for overrunning the engine's budget,
 * and named in `overran` when it does; the hook is still skipped, as one with
 * no `.catch` is, and a test's own `.catch` throws, as a second one does.
 * Proven by a test that waited 11 seconds of real time holding the mock
 * clock's waits: its hook on `clock.every` overran, the engine refused the
 * mod's next `$.clock.every`, and the heartbeat never moved again however
 * far the clock went (16 November 2026).
 */
const watched = (on: On, overran: string[]): On =>
  ((...args: readonly unknown[]) => {
    const registration = (on as unknown as Registering)(...args)

    registration.catch(($, e, next) => {
      if (next.error.kind === 'timeout') {
        overran.push(next.event)
      }

      return undefined
    })

    return registration
  }) as unknown as On

/** Runs `body`, failing it once it returns should one of its hooks have overrun: the mock clock's timers ended there, so what it checked after was luck. */
const guarded =
  (body: TestBody): TestBody =>
  async ($, on) => {
    const overran: string[] = []

    await body($, watched(on, overran))

    if (overran.length > 0) {
      throw new Error(
        `the test's hook on ${[...new Set(overran)].join(', ')} overran the engine's 10 s budget: the mock clock's timers ended there, so whatever the test checked after moved by luck`,
      )
    }
  }

export const test = (name: string, ...rest: TestRest): void =>
  rest.length === 1
    ? kitTest(name, { timeoutMs: TEST_MS }, guarded(rest[0]))
    : kitTest(name, { timeoutMs: TEST_MS, ...rest[0] }, guarded(rest[1]))
