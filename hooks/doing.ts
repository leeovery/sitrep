/**
 * What this window is doing, heard from its own events (core's state.ts)
 * and said in its heartbeat as it changes, not on the beat, so a reader
 * polling every second or two hears it. What it has heard outlives a
 * reload, held session or not (activity.ts): a window that attaches
 * mid-turn says the state as it stands.
 *
 * A burst of quick calls is not written call by call: a change is written
 * at once, unless the heartbeat was rewritten for one within STATE_MS, and
 * then once that is up, as the state stands by then. A change that comes
 * back to what the heartbeat already says writes nothing, and holds
 * nothing back.
 *
 * Every hook here only observes. It hands the event on as it came, and a
 * failure to record what it heard is logged, never thrown into the turn, the
 * tool or the permission prompt.
 *
 * Each stop begun or ended is written to the debug log, with its tool and
 * how it was matched, so a live try can tell the dialog from the verdict.
 */
import type { Timer } from 'claude-code'
import {
  permissionShown,
  QUESTION_TOOL,
  toolAsked,
  toolEnded,
  toolStarted,
  turnEnded,
  turnStarted,
  type Activity,
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

/** A permission dialog about to show, as the classic event says it: the tool and its input. */
type RequestInput = { tool_name: string; tool_input: unknown }

/** What the settings hooks beneath answered a permission request: a decision, or a block, shows no dialog. */
type RequestAnswer = { decision?: unknown; block?: string }

/** When the heartbeat was last rewritten for a change of state. */
let rewrittenAt = -Infinity

/** The rewrite waiting for STATE_MS to pass, if any. */
let waiting: Timer | undefined

/** Rewrites the heartbeat as the state stands, claiming the second from `at`; one that found nothing to write gives the second back. */
const rewrite = (host: Host, at: number) => {
  rewrittenAt = at
  void restate(host).then(
    isWritten => {
      if (!isWritten && rewrittenAt === at) {
        rewrittenAt = -Infinity
      }
    },
    logFailure(host, "writing the window's state"),
  )
}

/** Has the heartbeat say the state, a change heard `at`: at once, or once STATE_MS has passed since the last rewrite. Never waits on the write. */
const tell = (host: Host, at: number) => {
  if (waiting !== undefined) {
    return
  }

  const due = rewrittenAt + STATE_MS

  if (due <= at) {
    rewrite(host, at)

    return
  }

  waiting = host.clock.after(due - at, () => {
    waiting = undefined
    rewrite(host, due)
  })
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

/** Records what the window heard, `why` it changed, and has the heartbeat say it: the stops it began. */
const heard = async (
  host: Host,
  change: (activity: Activity, at: number) => Activity,
  why: string,
): Promise<Stop[]> => {
  try {
    const at = await host.clock.now()
    const { before, after, written } = await changeActivity(host, activity => change(activity, at))

    tell(host, at)

    const begun = logStops(host, before, after, why)

    await written.catch(logFailure(host, "recording the window's state"))

    return begun
  } catch (error) {
    logFailure(host, "recording the window's state")(error)

    return []
  }
}

/** The window's turn starting: a subagent's run raises none. */
export const heardTurnStart = (host: Host) =>
  heard(host, (_, at) => turnStarted(at), 'the turn started')

/** The window's turn ending, answered, stopped by Lee or failed. */
export const heardTurnEnd = (host: Host) => heard(host, (_, at) => turnEnded(at), 'the turn ended')

/** Runs a tool call, heard as it starts and as it ends however it ends; what it settles to is the call's own. */
export const throughCall = async <R>(host: Host, call: ToolCall, run: () => Promise<R>) => {
  await heard(host, (activity, at) => toolStarted(activity, call, at), 'its call started')

  try {
    return await run()
  } finally {
    await heard(host, activity => toolEnded(activity, call.id), 'its call settled')
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
 * it: the oldest call put to Lee with its tool and an equal input stops the
 * window on Lee. One matching none is logged and stops nothing. A question's
 * dialog is its own: its call stopped the window as it started.
 */
export const heardRequest = async (
  host: Host,
  { tool_name: tool, tool_input: input }: RequestInput,
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

  const begun = await heard(
    host,
    (activity, at) => permissionShown(activity, { tool, input }, at),
    'its dialog shown, matched by tool and input to the oldest call put to Lee',
  )

  if (begun.length === 0) {
    host.log(`sitrep: a permission dialog for ${tool} matched no call put to Lee: no stop`)
  }
}
