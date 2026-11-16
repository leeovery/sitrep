import { expect, test } from './kit'
import { QUIET } from '../core'
import { activityNow } from '../hooks/activity'
import { throughCall } from '../hooks/doing'
import type { Host } from '../hooks/host'
import { loadedNow } from '../hooks/load'
import { T0 } from './data'

/** What never settles. */
const never = () => new Promise<never>(() => {})

/**
 * A host whose clock and whose writes to `$.state` never settle, its one
 * read of the window's state answering: just what hearing a call needs, the
 * window holding no session. Its own file, so the mod's modules start
 * afresh for it.
 */
const stalled = () => {
  let writes = 0
  const host = {
    clock: { now: never, after: () => ({ cancel: () => {} }), every: () => ({ cancel: () => {} }) },
    state: {
      activity: {
        get: async () => ({ value: undefined, version: 0 }),
        set: () => {
          writes += 1

          return never()
        },
      },
    },
    log: () => {},
  } as unknown as Host

  return { host, writes: () => writes }
}

test('a call runs and returns though the clock and every write of the state never settle: it waits only on the one read of the state', async () => {
  const { host, writes } = stalled()

  await loadedNow({ clock: { now: async () => T0 } } as unknown as Host)

  const result = await throughCall(
    host,
    { id: 'toolu_1', tool: 'Bash', input: { command: 'bun test' } },
    async () => 'ran',
  )
  const again = await throughCall(
    host,
    { id: 'toolu_2', tool: 'Read', input: { file_path: '/repo/a.ts' } },
    async () => 'read',
  )

  expect([result, again]).toEqual(['ran', 'read'])
  expect(await activityNow(host)).toEqual(QUIET)
  expect(writes(), 'the first write tried, and never settling').toBe(1)
})
