/**
 * A call of Claude's tools answered within its hook's budget (DESIGN.md,
 * "A call is answered within its hook's budget"). Claude Code gives a hook
 * 10 seconds of its own time and, past it, skips the hook without asking
 * its `.catch`: the call fails, while its work runs on in the window's
 * queue to write its line. So a call is given until its budget's time left
 * less a margin, and is answered then by how far its work has come.
 *
 * The wait is real time, while the budget stands still through the hook's
 * own `$` calls: a call still waiting its turn is judged by the real time,
 * one begun by the budget it has left, read live. Lee stopping the turn
 * ends the wait as a deadline whose budget is spent.
 */
import { logFailure, type Host } from './host'

/** A tool's answer as the model reads it. */
export type Answered = { result: string } | { deny: string }

/** How long before its hook's budget runs out a call's deadline comes: room for a wait that ends late, and for the answer to get back, on a Mac too busy to keep time. */
export const MARGIN_MS = 3_000

/** The answer to a call dropped at its deadline, which wrote nothing. */
export const BUSY = 'The board was busy, so nothing was written: send it again.'

/** The hook's budget as a call reads it: its time left now, in ms, Infinity where nothing meters it; and the dispatch's signal, which Lee stopping the turn aborts. */
export type Budget = { left: () => number; signal: AbortSignal }

/**
 * How far a call's work has come: waiting its turn in the window's queue;
 * running; a post's, before its answer is decided; a post's whose answer
 * is decided, its check settled; or dropped at its deadline, which it
 * never leaves.
 */
type Stage = 'waiting' | 'running' | 'posting' | { known: Answered } | 'dropped'

/** What a call's deadline does: give an answer now; wait on the work to its end; or look again once more of the budget could have gone. */
type Verdict = { answer: Answered } | 'work' | 'again'

/**
 * A call's progress, as its work moves it on and its deadline reads it.
 * Each move is made at once, so no wait comes between reading the stage
 * and moving it.
 */
export type Progress = {
  /** Its turn come: whether its work goes on, which a call dropped never does. */
  begin: () => boolean
  /** A post's answer begun, the fold its check reads with it: until its answer is decided, the deadline may drop it. */
  posts: () => void
  /** A post's answer decided, before it writes anything: a line's, a refusal's, or one with nothing to change. Whether it goes on, which a post dropped never does. */
  knows: (answer: Answered) => boolean
  /** The deadline come, `isSpent` where the budget is within the margin of spent or the turn stopped: what to do now. */
  due: (isSpent: boolean) => Verdict
}

/** An answer as the model reads it, without the name a post's answer gives its row: the work keeps that itself. */
const asRead = (answer: Answered): Answered =>
  'deny' in answer ? { deny: answer.deny } : { result: answer.result }

export const progressOf = (): Progress => {
  let stage: Stage = 'waiting'
  /** Moves the call on to `to`, unless it was dropped: whether it moved. */
  const moveOn = (to: Stage) => {
    const isDropped = stage === 'dropped'

    if (!isDropped) {
      stage = to
    }

    return !isDropped
  }

  return {
    begin: () => moveOn('running'),
    posts: () => {
      moveOn('posting')
    },
    knows: answer => moveOn({ known: asRead(answer) }),
    due: isSpent => {
      if (stage === 'waiting' || (stage === 'posting' && isSpent)) {
        stage = 'dropped'

        return { answer: { deny: BUSY } }
      }

      if (stage === 'posting') {
        return 'again'
      }

      return typeof stage === 'object' ? { answer: stage.known } : 'work'
    },
  }
}

/** The deadline come before the call's work answered. */
const DUE = Symbol('due')

/** Lee stopped the turn before the call's work answered. */
const STOPPED = Symbol('stopped')

/** What ended a wait on a call's work: its deadline, Lee's stop, or the work's own answer. */
type Woke = typeof DUE | typeof STOPPED | Answered

/**
 * The answer of a call's work; or, should its deadline come first, or Lee
 * stop the turn, the answer its progress gives then, the work running on
 * unawaited, its failure logged. With no deadline, the budget unmetered or
 * within the margin of spent as the call begins, the work's answer however
 * long it takes.
 */
export const byDeadline = async (
  host: Host,
  name: string,
  work: Promise<Answered>,
  progress: Progress,
  budget: Budget,
): Promise<Answered> => {
  const first = budget.left() - MARGIN_MS

  if (!(Number.isFinite(first) && first > 0)) {
    return work
  }

  const stop = new AbortController()
  // Tied by a listener, which asks only that the dispatch's signal be heard:
  // AbortSignal.any refuses a signal made in another realm, as the engine's may be.
  const stopWithTurn = () => stop.abort()

  budget.signal.addEventListener('abort', stopWithTurn, { once: true })

  if (budget.signal.aborted) {
    stop.abort()
  }

  /** Ends once `ms` has passed, or Lee stopped the turn; a wait cut short by the work's end, or failing, takes on the work's own answer. */
  const wake = (ms: number) =>
    host.clock.sleep(ms, stop.signal).then<Woke, Woke>(
      () => DUE,
      () => (budget.signal.aborted ? STOPPED : work),
    )

  /** Waits `ms` on the work, then judges the call by how far it has come. */
  const waitFor = async (ms: number): Promise<Answered> => {
    const woke = await Promise.race([work, wake(ms)])

    if (woke !== DUE && woke !== STOPPED) {
      return woke
    }

    const left = budget.left()
    const verdict = progress.due(woke === STOPPED || left <= MARGIN_MS)

    if (verdict === 'again') {
      return waitFor(left - MARGIN_MS)
    }

    if (verdict === 'work') {
      return work
    }

    void work.catch(logFailure(host, `the ${name} call's work after its deadline`))

    return verdict.answer
  }

  return waitFor(first).finally(() => {
    budget.signal.removeEventListener('abort', stopWithTurn)
    stop.abort()
  })
}
