import { drained, expect, test } from './kit'
import { QUIET, type Activity } from '../core'
import { activityNow } from '../hooks/activity'
import { throughCall } from '../hooks/doing'
import type { Host } from '../hooks/host'
import { T0 } from './data'

/**
 * A host whose clock has stopped answering: just what hearing a call needs,
 * the window holding no session. Its own file, so the mod's modules start
 * afresh for it.
 */
const stoppedClock = () => {
  const written: Activity[] = []
  const logs: string[] = []
  const host = {
    clock: {
      now: () => Promise.reject(new Error('the clock stopped')),
      after: () => ({ cancel: () => {} }),
      every: () => ({ cancel: () => {} }),
    },
    state: {
      activity: {
        get: async () => ({ value: { ...QUIET, turnAt: T0 }, version: 1 }),
        set: async (value: Activity) => {
          written.push(value)

          return { isSet: true, version: written.length + 1 }
        },
      },
    },
    log: (line: string) => logs.push(line),
  } as unknown as Host

  return { host, written, logs }
}

test('a call starts and ends though the clock fails throughout: its end needs no time, and nothing of it is left running', async () => {
  const { host, written, logs } = stoppedClock()
  let ranWith: Activity | undefined

  const result = await throughCall(
    host,
    { id: 'toolu_1', tool: 'Bash', input: { command: 'bun test' } },
    async () => {
      ranWith = await activityNow(host)

      return 'ran'
    },
  )

  await drained()

  expect(result).toBe('ran')
  expect(ranWith?.tools.map(running => running.call)).toEqual(['toolu_1'])
  expect(await activityNow(host)).toEqual({ ...QUIET, turnAt: T0 })
  expect(written.at(-1), 'and so it is kept').toEqual({ ...QUIET, turnAt: T0 })
  expect(
    logs.every(line => /^sitrep: (reading the clock|stamping this load) failed/.test(line)),
    logs.join('\n'),
  ).toBe(true)
})
