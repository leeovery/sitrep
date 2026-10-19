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
 */
import type { Timer } from 'claude-code'
import {
  toolAsked,
  toolEnded,
  toolStarted,
  turnEnded,
  turnStarted,
  type Activity,
  type ToolCall,
} from '../core'
import { changeActivity } from './activity'
import { logFailure, type Host } from './host'
import { restate } from './window'

/** The least time between two rewrites of the heartbeat for a change of state: well inside a reader's poll. */
export const STATE_MS = 1_000

/** A permission check as the engine raises it. */
type CheckInput = { tool: string; input: unknown; tool_use_id?: string; agentId?: string }

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

const heard = async (host: Host, change: (activity: Activity, at: number) => Activity) => {
  try {
    const at = await host.clock.now()

    await changeActivity(host, activity => change(activity, at)).finally(() => tell(host, at))
  } catch (error) {
    logFailure(host, "recording the window's state")(error)
  }
}

/** The window's turn starting: a subagent's run raises none. */
export const heardTurnStart = (host: Host) => heard(host, (_, at) => turnStarted(at))

/** The window's turn ending, answered, stopped by Lee or failed. */
export const heardTurnEnd = (host: Host) => heard(host, (_, at) => turnEnded(at))

/** Runs a tool call, heard as it starts and as it ends however it ends; what it settles to is the call's own. */
export const throughCall = async <R>(host: Host, call: ToolCall, run: () => Promise<R>) => {
  await heard(host, (activity, at) => toolStarted(activity, call, at))

  try {
    return await run()
  } finally {
    await heard(host, activity => toolEnded(activity, call.id))
  }
}

/**
 * A call's permission check settled: one put to Lee shows the permission
 * prompt, unless the mode's decider settles it first. A query of the check,
 * which is no call, has no id, and stops nothing.
 */
export const heardCheck = (
  host: Host,
  { tool, input, tool_use_id: id, agentId }: CheckInput,
  decision: string,
) =>
  decision === 'ask' && id !== undefined
    ? heard(host, (activity, at) => toolAsked(activity, { id, tool, input, agentId }, at))
    : Promise.resolve()
