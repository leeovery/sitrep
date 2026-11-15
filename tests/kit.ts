/**
 * The engine's test kit, its `test` given a longer time limit. The kit's own
 * 5 seconds is near what the drawn and delivering tests take on a quiet
 * machine (2 to 6 seconds each), so a busy one failed them by the clock
 * alone, the release's pre-tag run among them (15 November 2026). 20
 * seconds is the most the kit gives a test (asked for 30, it stopped one
 * at 20), and still fails one that hangs.
 */
import { test as kitTest, type TestRest } from 'claude-code/testing'

export * from 'claude-code/testing'

const TEST_MS = 20_000

export const test = (name: string, ...rest: TestRest): void =>
  rest.length === 1
    ? kitTest(name, { timeoutMs: TEST_MS }, rest[0])
    : kitTest(name, { timeoutMs: TEST_MS, ...rest[0] }, rest[1])
