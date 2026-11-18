/**
 * What this window is doing, heard from its own events (core's state.ts)
 * and said in its heartbeat as it changes, not on the beat, so a reader
 * polling every second or two hears it. What it has heard outlives a
 * reload, held session or not (activity.ts): a window that attaches
 * mid-turn says the state as it stands. A new conversation starts afresh.
 *
 * A burst of quick calls is not written call by call: a change is written
 * at once, unless the heartbeat was rewritten for one within STATE_MS, and
 * then once that is up, as the state stands by then. A change that comes
 * back to what the heartbeat already says writes nothing, and holds
 * nothing back.
 *
 * Every hook here only observes. It hands the event on as it came, and a
 * failure to record what it heard is logged, never thrown into the turn, the
 * tool or the permission prompt. A change lands in memory at once and
 * nothing waits on its writes. A tool call waits on the host only for the
 * one read of `$.state` that loads what an earlier load heard, before the
 * first change of a load, and for the clock at a question's start, to stamp
 * its stop; a turn's start and end and a dialog wait on the clock for theirs.
 *
 * Each stop begun or ended is written to the debug log, with its tool and
 * how it was matched, so a live try can tell the dialog from the verdict.
 *
 * The turn's Stop says what it left pending: unless a hook beneath blocked
 * it, which goes on with the turn, its lists replace what was pending, in
 * whichever order it and the turn's end come.
 */
import type { TurnStartInput } from 'claude-code'
import {
  agentTurnEnded,
  isObject,
  permissionShown,
  QUESTION_TOOL,
  QUIET,
  toolAsked,
  toolEnded,
  toolStarted,
  turnEnded,
  turnStarted,
  turnStopped,
  USER,
  type Activity,
  type PendingCron,
  type PendingTask,
  type Stop,
  type ToolCall,
} from '../core'
import { changeActivity } from './activity'
import { logFailure, type Host } from './host'
import { restate } from './window'

/** The least time between two rewrites of the heartbeat for a change of state: well inside a reader's poll. */
export const STATE_MS = 1_000

/** A permission check as the engine raises it. */
type CheckInput = { tool: string; input: unknown; tool_use_id?: string; agentId?: string }

/** A permission dialog about to show, as the classic event says it: the tool, its input, and the subagent, where it says. */
type RequestInput = { tool_name: string; tool_input: unknown; agent_id?: string }

/** What the settings hooks beneath answered a permission request: a decision, or a block, shows no dialog. */
type RequestAnswer = { decision?: unknown; block?: string }

/** A turn's Stop as the classic event says it: the subagent it is of, where it says, and what the session has pending. */
type StopInput = {
  agent_id?: string
  background_tasks?: readonly PendingTask[]
  session_crons?: readonly PendingCron[]
}

/** What the settings hooks beneath answered a Stop: a block goes on with the turn, unless the session is to stop after it. */
type StopAnswer = { block?: string; preventContinuation?: true }

const UNWRITTEN = "writing the window's state"

/** The time the clock last gave: what a change is stamped with should the clock fail. */
let lastAt = -Infinity

/** When the heartbeat was last rewritten for a change of state. */
let rewrittenAt = -Infinity

/** The rewrite waiting for STATE_MS to pass, and when it is due, if any. */
let waiting: { due: number } | undefined

const timeNow = (host: Host) =>
  host.clock.now().then(
    at => (lastAt = at),
    (error: unknown) => {
      logFailure(host, 'reading the clock')(error)

      return lastAt
    },
  )

/** Rewrites the heartbeat as the state stands, claiming the second from `at`; one that found nothing to write gives the second back. */
const rewrite = (host: Host, at: number) => {
  rewrittenAt = at
  void restate(host).then(
    isWritten => {
      if (!isWritten && rewrittenAt === at) {
        rewrittenAt = -Infinity
      }
    },
    logFailure(host, UNWRITTEN),
  )
}

/**
 * When the heartbeat is next rewritten for a change heard `at`, given when
 * it was last rewritten for one and when a rewrite waiting is due: at once
 * (`at`), once STATE_MS has passed since the last, or undefined while a
 * rewrite waits for its time. One still waiting a second past its time
 * never fired (its timer refused, or dropped with the dispatch that set
 * it), and is waited on no more.
 */
export const rewriteAt = (at: number, rewrittenAt: number, waitingDue?: number) =>
  waitingDue !== undefined && at <= waitingDue + STATE_MS
    ? undefined
    : Math.max(at, rewrittenAt + STATE_MS)

/** Has the heartbeat say the state, `at` the time, at once or when `rewriteAt` says. Never waits on the write. */
const tell = (host: Host, at: number) => {
  const due = rewriteAt(at, rewrittenAt, waiting?.due)

  if (due === undefined) {
    return
  }

  waiting = undefined

  if (due === at) {
    rewrite(host, at)

    return
  }

  const mine = { due }

  host.clock.after(due - at, () => {
    if (waiting === mine) {
      waiting = undefined
    }

    rewrite(host, due)
  })
  waiting = mine
}

/** The stops of `stops` that `others` lacks. */
const missingFrom = (stops: readonly Stop[], others: readonly Stop[]) =>
  stops.filter(stop => !others.some(other => other.call === stop.call))

const described = (stop: Stop) =>
  stop.is === 'permission'
    ? `a permission prompt for ${stop.tool.name}${stop.tool.subject === undefined ? '' : `: ${stop.tool.subject}`}`
    : `a question${stop.question === undefined ? '' : `: ${stop.question.text}`}`

/** Writes each stop begun and ended to the debug log, with why; the stops begun. */
const logStops = (host: Host, before: Activity, after: Activity, why: string) => {
  const begun = missingFrom(after.stops, before.stops)

  for (const [what, stops] of [
    ['begun', begun],
    ['ended', missingFrom(before.stops, after.stops)],
  ] as const) {
    for (const stop of stops) {
      host.log(`sitrep: stop ${what}, call ${stop.call}: ${described(stop)}; ${why}`)
    }
  }

  return begun
}

/**
 * Records what the window heard, `why` it changed, and has the heartbeat
 * say it, waiting on neither write: the stops it began. A change of nothing
 * does none of it.
 */
const heard = async (
  host: Host,
  change: (activity: Activity) => Activity,
  why: string,
): Promise<Stop[]> => {
  try {
    const { before, after } = await changeActivity(host, change)

    if (after === before) {
      return []
    }

    void timeNow(host)
      .then(at => tell(host, at))
      .catch(logFailure(host, UNWRITTEN))

    return logStops(host, before, after, why)
  } catch (error) {
    logFailure(host, "recording the window's state")(error)

    return []
  }
}

/**
 * A turn's start as Claude Code 2.1.318 raises it: for a subagent's run as
 * well as the window's, the subagent's carrying its `agentId`, which the
 * engine's types (written by 2.1.295) leave out.
 */
type TurnStart = TurnStartInput & { agentId?: string }

/** Whether a turn's start is the window's own: its loop is the main one, which carries no `agentId`. */
export const isWindowTurn = (start: TurnStart) => start.agentId === undefined

/** The window's turn starting. */
export const heardTurnStart = async (host: Host) => {
  const at = await timeNow(host)

  return heard(host, activity => turnStarted(activity, at), 'the turn started')
}

/** The window's turn ending, answered, stopped by Lee or failed. */
export const heardTurnEnd = async (host: Host) => {
  const at = await timeNow(host)

  return heard(host, activity => turnEnded(activity, at), 'the turn ended')
}

/** A subagent's turn ending: what it left waiting is done with. */
export const heardAgentTurnEnd = (host: Host, agentId: string) =>
  heard(host, activity => agentTurnEnded(activity, agentId), "its subagent's turn ended")

/** The conversation ending, as at a /clear: the next starts with nothing heard, your turn since it attaches. */
export const heardConversationEnd = (host: Host) =>
  heard(host, () => QUIET, 'the conversation ended')

/**
 * Runs a tool call, heard as it starts and as it ends however it ends, with
 * its tool's result where it gave one; what it settles to is the call's own.
 * Only a question's start, a stop, waits on the clock.
 */
export const throughCall = async <R>(host: Host, call: ToolCall, run: () => Promise<R>) => {
  const at = call.tool === QUESTION_TOOL ? await timeNow(host) : lastAt
  let ended: { tool: string; result: unknown } | undefined

  await heard(host, activity => toolStarted(activity, call, at), 'its call started')

  try {
    const answer = await run()

    ended = { tool: call.tool, result: isObject(answer) ? answer.result : undefined }

    return answer
  } finally {
    await heard(host, activity => toolEnded(activity, call.id, ended), 'its call settled')
  }
}

/**
 * A call's permission check settled: one put to the mode's decider is a
 * candidate for a permission dialog, and stops nothing yet. A query of the
 * check, which is no call, has no id.
 */
export const heardCheck = (
  host: Host,
  { tool, input, tool_use_id: id, agentId }: CheckInput,
  decision: string,
) =>
  decision === 'ask' && id !== undefined
    ? heard(host, activity => toolAsked(activity, { id, tool, input, agentId }), 'its check asked')
    : Promise.resolve()

/**
 * A permission dialog about to show, unless a settings hook beneath answered
 * it: the oldest call put to Lee it is for stops the window on Lee. One for
 * no candidate is logged and stops nothing. A question's dialog is its own:
 * its call stopped the window as it started.
 */
export const heardRequest = async (
  host: Host,
  { tool_name: tool, tool_input: input, agent_id: agentId }: RequestInput,
  answer: RequestAnswer,
) => {
  if (tool === QUESTION_TOOL) {
    return
  }

  if (answer.decision !== undefined || answer.block !== undefined) {
    host.log(
      `sitrep: a settings hook answered the permission request for ${tool}: no dialog, no stop`,
    )

    return
  }

  const at = await timeNow(host)
  const begun = await heard(
    host,
    activity => permissionShown(activity, { tool, input, agentId }, at),
    `its dialog shown, matched by tool, loop and input to the oldest call put to ${USER.name}`,
  )

  if (begun.length === 0) {
    host.log(`sitrep: a permission dialog for ${tool} matched no call put to ${USER.name}: no stop`)
  }
}

/** Whether a settings hook beneath blocked a Stop, which goes on with the turn. */
const isBlocked = (answer: StopAnswer) =>
  answer.block !== undefined && answer.preventContinuation !== true

/** Whether a Stop ends the window's turn: not a subagent's, nor one blocked. */
export const isTurnStop = (input: StopInput, answer: StopAnswer) =>
  input.agent_id === undefined && !isBlocked(answer)

/**
 * The window's turn stopping, unless a settings hook beneath blocked its
 * Stop, which goes on with the turn: what it lists pending replaces what
 * was. A subagent's stop is its own event, never this one; one saying a
 * subagent all the same is not the window's, and changes nothing.
 */
export const heardStop = async (
  host: Host,
  { agent_id: agentId, background_tasks: tasks, session_crons: crons }: StopInput,
  answer: StopAnswer,
) => {
  if (agentId !== undefined) {
    return
  }

  if (isBlocked(answer)) {
    host.log('sitrep: a settings hook blocked the Stop, so the turn goes on: nothing pending heard')

    return
  }

  const at = await timeNow(host)

  await heard(host, activity => turnStopped(activity, { tasks, crons }, at), 'its turn stopped')
}
