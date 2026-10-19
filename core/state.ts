/**
 * A window's state, as its heartbeat says it (see "A session's state" in
 * DESIGN.md), and what the window works it out from: what it has heard of
 * its own doing.
 *
 * - A turn starts: working, since the turn began.
 * - While a tool of the window's own loop runs, working carries it, the
 *   latest started where several run.
 * - A call's permission check puts it to Lee, or a call asks Lee a
 *   question: stopped on Lee, since then, the oldest stop first. A
 *   subagent's count: it stops the window on Lee all the same. Its tools
 *   do not show, nor do its turns start or end the window's.
 * - The call ends, its prompt or question answered: back to what it was.
 * - The turn ends, or Lee stops it: your turn, since then; before any
 *   turn, since the window attached.
 *
 * A turn's start or end clears every tool and stop, so one whose end the
 * window never heard (a reload while it waited) cannot hold it for ever.
 */
import { isCount, isFilled, isObject, isTime } from './entries'
import { QUESTION_TOOL, questionShown, toolShown } from './subject'
import type { QuestionShown, StateKind, ToolShown, WindowState } from './types'

/** A tool running in the window's own loop: its call, and how a row shows it. */
export type Running = { call: string; tool: ToolShown }

/** A call waiting on Lee: its permission prompt or its question, and since when. */
export type Stop = { call: string; at: number } & (
  { is: 'permission'; tool: ToolShown } | { is: 'question'; question?: QuestionShown }
)

/** What a window has heard of its own doing, as `$.state` keeps it. */
export type Activity = {
  /** When the running turn began; none between turns. */
  turnAt?: number
  /** When the last turn ended; none before the first. */
  endedAt?: number
  /** The tools the window's own loop runs, the latest started last. */
  tools: Running[]
  /** The calls waiting on Lee, the oldest first. */
  stops: Stop[]
}

/** A tool call as the engine raises it: its id, the tool, its arguments, and the subagent's loop it runs in, if any. */
export type ToolCall = { id: string; tool: string; input: unknown; agentId?: string }

/** A window that has heard nothing yet. */
export const QUIET: Activity = { tools: [], stops: [] }

export const turnStarted = (at: number): Activity => ({ turnAt: at, tools: [], stops: [] })

export const turnEnded = (at: number): Activity => ({ endedAt: at, tools: [], stops: [] })

/** A call starting: a question stops the window on Lee; any other tool of its own loop shows while it runs. */
export const toolStarted = (activity: Activity, call: ToolCall, at: number): Activity => {
  if (call.tool === QUESTION_TOOL) {
    return {
      ...activity,
      stops: [
        ...activity.stops,
        { call: call.id, at, is: 'question', question: questionShown(call.input) },
      ],
    }
  }

  return call.agentId === undefined
    ? {
        ...activity,
        tools: [...activity.tools, { call: call.id, tool: toolShown(call.tool, call.input) }],
      }
    : activity
}

/** A call whose check put it to Lee: the permission prompt shows, unless the call is already waiting on Lee, as a question does. */
export const toolAsked = (activity: Activity, call: ToolCall, at: number): Activity =>
  activity.stops.some(stop => stop.call === call.id)
    ? activity
    : {
        ...activity,
        stops: [
          ...activity.stops,
          { call: call.id, at, is: 'permission', tool: toolShown(call.tool, call.input) },
        ],
      }

/** A call ending, however it ended: it no longer runs, nor waits on Lee. */
export const toolEnded = (activity: Activity, call: string): Activity => ({
  ...activity,
  tools: activity.tools.filter(running => running.call !== call),
  stops: activity.stops.filter(stop => stop.call !== call),
})

const stopped = ({ at, ...stop }: Stop): WindowState =>
  stop.is === 'permission'
    ? { is: 'permission', since: at, tool: stop.tool }
    : {
        is: 'question',
        since: at,
        ...(stop.question === undefined ? {} : { question: stop.question }),
      }

/** The state a window's activity puts it in; `attachedAt` is when it attached, its your turn's start before any turn. */
export const stateOf = (activity: Activity, attachedAt: number): WindowState => {
  const [stop] = activity.stops

  if (stop !== undefined) {
    return stopped(stop)
  }

  if (activity.turnAt !== undefined) {
    const running = activity.tools.at(-1)

    return {
      is: 'working',
      since: activity.turnAt,
      ...(running === undefined ? {} : { tool: running.tool }),
    }
  }

  return { is: 'yourTurn', since: activity.endedAt ?? attachedAt }
}

const KINDS: readonly StateKind[] = ['working', 'permission', 'question', 'yourTurn']

const isKind = (value: unknown): value is StateKind => KINDS.includes(value as StateKind)

const parseTool = (raw: unknown): ToolShown | undefined =>
  isObject(raw) && isFilled(raw.name)
    ? { name: raw.name, ...(isFilled(raw.subject) ? { subject: raw.subject } : {}) }
    : undefined

const parseQuestion = (raw: unknown): QuestionShown | undefined =>
  isObject(raw) && isFilled(raw.text) && isCount(raw.count)
    ? { text: raw.text, count: raw.count }
    : undefined

/**
 * A heartbeat's state, read field by field: undefined without a state it
 * knows (a later version's kind among them) or a time, else its tool and
 * its question where each is well formed, a bad one dropped.
 */
export const parseState = (raw: unknown): WindowState | undefined => {
  if (!isObject(raw) || !isKind(raw.is) || !isTime(raw.since)) {
    return undefined
  }

  const tool = parseTool(raw.tool)
  const question = parseQuestion(raw.question)

  return {
    is: raw.is,
    since: raw.since,
    ...(tool === undefined ? {} : { tool }),
    ...(question === undefined ? {} : { question }),
  }
}
