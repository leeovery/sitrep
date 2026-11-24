import { drained, expect, test } from './kit'
import {
  BUSY,
  byDeadline,
  LOOK_AGAIN_MS,
  MARGIN_MS,
  progressOf,
  type Answered,
} from '../hooks/deadline'
import type { Host } from '../hooks/host'

/** A hook's whole budget, as it begins. */
const BUDGET_MS = 10_000

/** A status's answer. */
const SET: Answered = { result: 'Status set.' }

/** One of the clock's waits: how long it was for, its end, and whether it was cut short. */
type Wait = { ms: number; end: () => void; isCut: boolean }

/**
 * A call's deadline, every part of it driven by hand: the clock's waits
 * ended, the budget's time left set, the turn stopped, and the work
 * settled. The test moves the call's progress on as its work would. Each
 * step lets what it set going settle.
 */
const deadline = ({ left = BUDGET_MS, name = 'status' } = {}) => {
  const waits: Wait[] = []
  const logs: string[] = []
  const host = {
    clock: {
      sleep: (ms: number, signal?: AbortSignal) =>
        new Promise<void>((resolve, reject) => {
          const wait: Wait = { ms, end: resolve, isCut: false }
          const cut = () => {
            wait.isCut = true
            reject(new Error('the wait was cut short'))
          }

          waits.push(wait)

          if (signal?.aborted === true) {
            cut()
          }

          signal?.addEventListener('abort', cut, { once: true })
        }),
    },
    log: (line: string) => logs.push(line),
  } as unknown as Host
  const budget = { left }
  const turn = new AbortController()
  const call: { answer?: Answered; error?: unknown } = {}
  let settle: (answer: Answered) => void = () => {}
  let fail: (error: Error) => void = () => {}
  const work = new Promise<Answered>((resolve, reject) => {
    settle = resolve
    fail = reject
  })
  const progress = progressOf()

  byDeadline(host, name, work, progress, { left: () => budget.left, signal: turn.signal }).then(
    answer => {
      call.answer = answer
    },
    (error: unknown) => {
      call.error = error
    },
  )

  return {
    progress,
    budget,
    waits,
    logs,
    answer: () => call.answer,
    error: () => call.error,
    /** The latest wait ends, as the clock reaches it. */
    wake: async () => {
      waits.at(-1)?.end()
      await drained()
    },
    stopTurn: async () => {
      turn.abort()
      await drained()
    },
    settle: async (answer: Answered) => {
      settle(answer)
      await drained()
    },
    fail: async (error: Error) => {
      fail(error)
      await drained()
    },
  }
}

/** A call whose post has begun, its answer not yet decided. */
const postBegun = (options?: Parameters<typeof deadline>[0]) => {
  const call = deadline(options)

  call.progress.begin()
  call.progress.posts()

  return call
}

test('a call still waiting its turn at its deadline, its budget less the margin gone in real time, is refused as the board busy; its turn, when it comes, does nothing', async () => {
  const call = deadline()

  expect(call.waits.map(wait => wait.ms)).toEqual([BUDGET_MS - MARGIN_MS])

  await call.wake()
  expect(call.answer()).toEqual({ deny: BUSY })
  expect(call.progress.begin(), 'its turn').toBe(false)
})

test('a post before its check, its budget within the margin of spent at the deadline, is refused as the board busy, and writes nothing once decided', async () => {
  const call = postBegun()

  call.budget.left = MARGIN_MS
  await call.wake()
  expect(call.answer()).toEqual({ deny: BUSY })
  expect(call.progress.knows(SET), 'its answer decided').toBe(false)
})

test('a post before its check with budget left at the deadline, its own reads having stood the budget still, waits on, looking again once that much more could have gone: then its decided answer is given', async () => {
  const call = postBegun()

  call.budget.left = 8_000
  await call.wake()
  expect(call.answer(), 'waits on').toBeUndefined()
  expect(call.waits.map(wait => wait.ms)).toEqual([BUDGET_MS - MARGIN_MS, 8_000 - MARGIN_MS])

  expect(call.progress.knows(SET)).toBe(true)
  await call.wake()
  expect(call.answer()).toEqual(SET)
})

test('a post that waits on, its budget standing still just past the margin through a slow read, looks again no sooner than its shortest wait, never spinning', async () => {
  const call = postBegun()

  call.budget.left = MARGIN_MS + 10
  await call.wake()
  await call.wake()
  expect(call.answer(), 'waits on').toBeUndefined()
  expect(call.waits.map(wait => wait.ms)).toEqual([
    BUDGET_MS - MARGIN_MS,
    LOOK_AGAIN_MS,
    LOOK_AGAIN_MS,
  ])
})

test('a budget read as no time once the call has waited on counts as spent: a post before its check is refused, never looking again at once', async () => {
  for (const left of [Number.NaN, Number.POSITIVE_INFINITY]) {
    const call = postBegun()

    call.budget.left = left
    await call.wake()
    expect(call.answer(), String(left)).toEqual({ deny: BUSY })
    expect(call.waits, String(left)).toHaveLength(1)
  }
})

test('a post that waits on at its deadline is refused once a later look finds its budget within the margin of spent', async () => {
  const call = postBegun()

  call.budget.left = 8_000
  await call.wake()
  call.budget.left = MARGIN_MS - 500
  await call.wake()
  expect(call.answer()).toEqual({ deny: BUSY })
  expect(call.progress.knows(SET), 'its answer decided').toBe(false)
})

test('a post whose answer is decided is given it at its deadline, a refusal or an answer with nothing to change as well as a line, without the name its row is given', async () => {
  const quiet = {
    result: 'k1 was closed already by the user: nothing to resolve.',
    names: 'Review',
  }

  for (const decided of [SET, { deny: 'Status needs at least one of its fields.' }, quiet]) {
    const call = postBegun()

    call.progress.knows(decided)
    await call.wake()
    expect(call.answer()).toEqual('deny' in decided ? decided : { result: decided.result })
  }
})

test('a call begun that is no post waits on at its deadline, its budget spent and the turn stopped, and answers once its work does', async () => {
  const call = deadline()
  const board: Answered = { result: 'The board as it stands.' }

  call.progress.begin()
  call.budget.left = 0
  await call.wake()
  await call.stopTurn()
  expect(call.answer(), 'waits on').toBeUndefined()

  await call.settle(board)
  expect(call.answer()).toEqual(board)
})

test('Lee stopping the turn ends the wait as a deadline whose budget is spent: a call waiting its turn, or a post before its check whatever its budget, is refused; a decided answer is given', async () => {
  const waiting = deadline()
  const undecided = postBegun()
  const decided = postBegun()

  decided.progress.knows(SET)

  for (const call of [waiting, undecided, decided]) {
    await call.stopTurn()
  }

  expect(waiting.answer()).toEqual({ deny: BUSY })
  expect(undecided.answer()).toEqual({ deny: BUSY })
  expect(decided.answer()).toEqual(SET)
})

test('with no deadline, the budget unmetered or within the margin of spent as the hook begins, a call waits on its work however long it takes', async () => {
  for (const left of [Infinity, MARGIN_MS]) {
    const call = postBegun({ left })

    expect(call.waits, `${left} left: no wait`).toEqual([])

    await call.settle(SET)
    expect(call.answer()).toEqual(SET)
  }
})

test("work that answers before its deadline gives the call's answer and cuts its wait short; work that fails before then fails the call, for the hook's .catch", async () => {
  const answered = deadline()

  answered.progress.begin()
  await answered.settle(SET)
  expect(answered.answer()).toEqual(SET)
  expect(answered.waits.map(wait => wait.isCut)).toEqual([true])

  const failed = deadline()

  failed.progress.begin()
  await failed.fail(new Error('EIO: i/o error'))
  expect((failed.error() as Error | undefined)?.message).toBe('EIO: i/o error')
  expect(failed.waits.map(wait => wait.isCut)).toEqual([true])
  expect(failed.logs).toEqual([])
})

test("the work's failure after its call was answered at the deadline is written to the debug log, never left unhandled", async () => {
  const call = deadline({ name: 'ask' })

  await call.wake()
  expect(call.answer()).toEqual({ deny: BUSY })

  await call.fail(new Error('EIO: i/o error'))
  expect(call.logs).toEqual([
    "sitrep: the ask call's work after its deadline failed: EIO: i/o error",
  ])
})
