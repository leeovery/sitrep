/**
 * A window's state, as its heartbeat says it (see "A session's state" in
 * DESIGN.md), and what the window works it out from: what it has heard of
 * its own doing.
 *
 * - A turn starts: working, since the turn began.
 * - While a tool of the window's own loop runs, working carries it, the
 *   latest started where several run.
 * - A call's permission check puts it to the mode's decider ("ask"): a
 *   candidate for a permission dialog, and nothing more. In auto mode a
 *   classifier settles most such calls, and Lee sees nothing.
 * - A permission dialog shows for one: stopped on Lee, since then. The
 *   engine says which tool, input and loop the dialog is for, never which
 *   call, so it is the oldest candidate it is for (`isFor`).
 * - A call asks Lee a question: stopped on Lee, since its start; it always
 *   puts its own dialog to Lee.
 * - Of several stops, the oldest shows. A subagent's count: they stop the
 *   window on Lee all the same. Its tools do not show, nor do its turns
 *   start or end the window's.
 * - The call ends, its prompt or question answered: back to what it was.
 * - The turn ends, or Lee stops it: your turn, since then; before any
 *   turn, since the window attached.
 * - Its Stop lists what the turn left pending that will wake the window
 *   (work.ts): with anything, on its own work, since the turn ended. The
 *   latest Stop's list stands whole, and the next turn's start clears it.
 *   A Stop and the turn's end come in either order, to the same state.
 *
 * Each loop's turn bounds what it left: the window's turn starting or
 * ending clears its own tools, candidates and stops, and a subagent's turn
 * ending clears that subagent's, so one whose end the window never heard (a
 * reload while it waited) cannot hold it for ever, and one loop's turn
 * never clears another's stop.
 *
 * Its model's requests say whether the turn only waits on background work
 * (`waitsOnWork`), which no state shows: a subagent's first request says
 * its loop runs, until its turn ends; a request of the window's own loop
 * answered asking for no tool leaves that loop done inside its turn, until
 * a request of its own goes or asks for a tool, or the turn ends.
 */
import { isCount, isFilled, isObject, isTime } from './entries'
import { QUESTION_TOOL, questionShown, toolShown } from './subject'
import { compareText } from './text'
import type { QuestionShown, StateKind, ToolShown, WindowState, Work } from './types'
import {
  parseWatch,
  parseWork,
  watchesLeft,
  watchOf,
  workOf,
  type Pending,
  type Watch,
} from './work'

/** A tool running in the window's own loop, the only loop whose tools show: its call, and how a row shows it. */
export type Running = { call: string; tool: ToolShown }

/** A call waiting on Lee: its permission prompt or its question, since when, and the subagent it runs in, if any. */
export type Stop = { call: string; at: number; agentId?: string } & (
  { is: 'permission'; tool: ToolShown } | { is: 'question'; question?: QuestionShown }
)

/** Each top-level argument of a call, as a short digest of its value: enough to match a dialog, and small whatever the argument holds. */
export type Digests = { [argument: string]: string }

/** A call its check put to the mode's decider, a candidate for a permission dialog: its tool, its arguments' digests, and its subagent, if any. */
export type Asked = { call: string; tool: string; input: Digests; agentId?: string }

/** What a window has heard of its own doing, as `$.state` keeps it. */
export type Activity = {
  /** When the running turn began; none between turns. */
  turnAt?: number
  /** When the last turn ended; none before the first. */
  endedAt?: number
  /** The tools the window's own loop runs, the latest started last. */
  tools: Running[]
  /** The calls put to the mode's decider and not yet shown to Lee, the oldest first. */
  asked: Asked[]
  /** The calls waiting on Lee, the oldest first. */
  stops: Stop[]
  /** What the latest Stop left pending, since the turn began; none with nothing pending. */
  work?: Work
  /** The monitors heard started, as far as a Stop lists them still running. */
  watches: Watch[]
  /** The subagents' loops heard running: each from its first request until its turn ends. */
  loops: string[]
  /** The window's own loop done inside its running turn: its latest request answered asked for no tool, and none has gone since. */
  isDone?: true
}

/** A tool call as the engine raises it: its id, the tool, its arguments, and the subagent's loop it runs in, if any. */
export type ToolCall = { id: string; tool: string; input: unknown; agentId?: string }

/** A permission dialog as the engine says it is about to show one: the tool, the input, and the subagent it is for, where it says. */
export type PermissionRequest = { tool: string; input: unknown; agentId?: string }

/** A window that has heard nothing yet. */
export const QUIET: Activity = { tools: [], asked: [], stops: [], watches: [], loops: [] }

/** What of `activity` a subagent's loop left: its candidates and stops. The window's own loop has no `agentId`. */
const others = (activity: Activity, agentId: string | undefined) => ({
  asked: activity.asked.filter(asked => asked.agentId !== agentId),
  stops: activity.stops.filter(stop => stop.agentId !== agentId),
})

/** The window's turn starting: its own loop's tools, candidates and stops are cleared, a subagent's kept, and what was pending is done with: it woke the window, or Lee did. */
export const turnStarted = (activity: Activity, at: number): Activity => ({
  turnAt: at,
  tools: [],
  ...others(activity, undefined),
  watches: activity.watches,
  loops: activity.loops,
})

/** The window's turn ending: as its start, the subagents' kept, and what its Stop left pending kept, should the Stop have come first. */
export const turnEnded = (activity: Activity, at: number): Activity => ({
  endedAt: at,
  tools: [],
  ...others(activity, undefined),
  ...(activity.work === undefined ? {} : { work: activity.work }),
  watches: activity.watches,
  loops: activity.loops,
})

/** The window's own loop at work, not done: the activity itself where it was not. */
const atWork = (activity: Activity): Activity => {
  const { isDone, ...rest } = activity

  return isDone === undefined ? activity : rest
}

/**
 * A model request about to go, of the window's own loop, which is at work
 * again, or of a subagent's, whose loop runs until its turn ends. The
 * activity itself where nothing changes.
 */
export const stepStarted = (activity: Activity, agentId?: string): Activity => {
  if (agentId === undefined) {
    return atWork(activity)
  }

  return activity.loops.includes(agentId)
    ? activity
    : { ...activity, loops: [...activity.loops, agentId] }
}

/** A request of the window's own loop answered: asking for a tool, the loop is at work; for none, done inside its turn. The activity itself where nothing changes. */
export const stepAnswered = (activity: Activity, isAsking: boolean): Activity => {
  if (isAsking) {
    return atWork(activity)
  }

  return activity.isDone === true ? activity : { ...activity, isDone: true }
}

/**
 * Whether the main conversation's turn only waits on its background work:
 * it runs, its own loop done, while a subagent's loop runs. Claude Code
 * holds such a turn open until that work ends, and a prompt the mod
 * submits goes in only then.
 */
export const waitsOnWork = (activity: Activity) =>
  activity.turnAt !== undefined && activity.isDone === true && activity.loops.length > 0

/**
 * The window's turn stopping, its Stop not blocked, at `at`: what it lists
 * pending replaces what was, and nothing pending clears it; the monitors it
 * no longer lists are done with.
 */
export const turnStopped = (activity: Activity, pending: Pending, at: number): Activity => {
  const { work: _, ...rest } = activity
  const work = workOf(pending, activity.watches, at)

  return {
    ...rest,
    ...(work === undefined ? {} : { work }),
    watches: watchesLeft(activity.watches, pending),
  }
}

/** Whether the main conversation is between turns, as the window heard it: no turn of its own running, whatever a subagent or its work does. A turn stopped on Lee still runs. */
export const isBetweenTurns = (activity: Activity) => activity.turnAt === undefined

/** A subagent's turn ending: its candidates and stops are cleared, whether or not their calls were heard to end, and its loop runs no more. */
export const agentTurnEnded = (activity: Activity, agentId: string): Activity => ({
  ...activity,
  ...others(activity, agentId),
  loops: activity.loops.filter(loop => loop !== agentId),
})

/** A JSON value with its objects' keys in order. */
const ordered = (value: unknown): unknown =>
  Array.isArray(value)
    ? value.map(ordered)
    : isObject(value)
      ? Object.fromEntries(
          Object.keys(value)
            .sort(compareText)
            .map(key => [key, ordered(value[key])]),
        )
      : value

/**
 * A JSON value as text, its objects' keys in order: two values are equal as
 * JSON, whatever order their keys came in, when their texts are equal. A
 * key whose value is undefined is left out, as JSON leaves it.
 */
export const jsonOf = (value: unknown) => JSON.stringify(ordered(value)) ?? ''

/** A short digest of a text: 53 bits (cyrb53), in base 36. Two texts with one digest are taken as one. */
export const digestOf = (text: string) => {
  let h1 = 0xdeadbeef
  let h2 = 0x41c6ce57

  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i)

    h1 = Math.imul(h1 ^ code, 2654435761)
    h2 = Math.imul(h2 ^ code, 1597334677)
  }

  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909)
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909)

  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36)
}

/** A call's arguments as digests, each top-level one's value as `jsonOf` writes it; an input that is no object, as one argument named "". */
export const digestsOf = (input: unknown): Digests =>
  Object.fromEntries(
    Object.entries(isObject(input) ? input : { '': input })
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [key, digestOf(jsonOf(value))]),
  )

/**
 * Whether a dialog is for a candidate: the same tool; the same loop, a
 * request saying no subagent being the window's own and taking only its own
 * calls; and the arguments equal on every one both carry, at least one, or
 * both carry none. Not equal as wholes: the check and the request may each
 * carry an argument the other lacks (Bash's `description`, `timeout`).
 */
const isFor = (request: PermissionRequest, input: Digests, asked: Asked) => {
  const shared = Object.keys(asked.input).filter(key => Object.hasOwn(input, key))
  const isEmpty = Object.keys(asked.input).length === 0 && Object.keys(input).length === 0

  return (
    asked.tool === request.tool &&
    asked.agentId === request.agentId &&
    (shared.length > 0 ? shared.every(key => asked.input[key] === input[key]) : isEmpty)
  )
}

/** A call starting: a question stops the window on Lee, since `at`; any other tool of its own loop shows while it runs. */
export const toolStarted = (activity: Activity, call: ToolCall, at: number): Activity => {
  if (call.tool === QUESTION_TOOL) {
    return {
      ...activity,
      stops: [
        ...activity.stops,
        {
          call: call.id,
          at,
          agentId: call.agentId,
          is: 'question',
          question: questionShown(call.input),
        },
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

/** A call whose check put it to the mode's decider: a candidate for a permission dialog, unless it is one already or waits on Lee, as a question does. */
export const toolAsked = (activity: Activity, call: ToolCall): Activity =>
  [...activity.asked, ...activity.stops].some(each => each.call === call.id)
    ? activity
    : {
        ...activity,
        asked: [
          ...activity.asked,
          { call: call.id, tool: call.tool, input: digestsOf(call.input), agentId: call.agentId },
        ],
      }

/** A permission dialog about to show: the oldest candidate it is for waits on Lee, since `at`. With none, nothing changes. */
export const permissionShown = (
  activity: Activity,
  request: PermissionRequest,
  at: number,
): Activity => {
  const input = digestsOf(request.input)
  const shown = activity.asked.find(asked => isFor(request, input, asked))

  return shown === undefined
    ? activity
    : {
        ...activity,
        asked: activity.asked.filter(asked => asked !== shown),
        stops: [
          ...activity.stops,
          {
            call: shown.call,
            at,
            agentId: shown.agentId,
            is: 'permission',
            tool: toolShown(request.tool, request.input),
          },
        ],
      }
}

/** A call ending, however it ended, with its tool's result, if any: it no longer runs, is no candidate, nor waits on Lee; a monitor it started is heard. */
export const toolEnded = (
  activity: Activity,
  call: string,
  ended?: { tool: string; result: unknown },
): Activity => {
  const watch = ended === undefined ? undefined : watchOf(ended.tool, ended.result)

  return {
    ...activity,
    tools: activity.tools.filter(running => running.call !== call),
    asked: activity.asked.filter(asked => asked.call !== call),
    stops: activity.stops.filter(stop => stop.call !== call),
    watches: watch === undefined ? activity.watches : [...activity.watches, watch],
  }
}

const stopped = (stop: Stop, since: number): WindowState =>
  stop.is === 'permission'
    ? { is: 'permission', since, tool: stop.tool }
    : { is: 'question', since, ...(stop.question === undefined ? {} : { question: stop.question }) }

/**
 * The state a window's activity puts it in; `attachedAt` is when it
 * attached, its your turn's start before any turn, and the time of anything
 * heard before the clock first answered, which has none of its own.
 */
export const stateOf = (activity: Activity, attachedAt: number): WindowState => {
  const sinceOf = (at: number | undefined) => (isTime(at) ? at : attachedAt)
  const [stop] = activity.stops

  if (stop !== undefined) {
    return stopped(stop, sinceOf(stop.at))
  }

  if (activity.turnAt !== undefined) {
    const running = activity.tools.at(-1)

    return {
      is: 'working',
      since: sinceOf(activity.turnAt),
      ...(running === undefined ? {} : { tool: running.tool }),
    }
  }

  return activity.work === undefined
    ? { is: 'yourTurn', since: sinceOf(activity.endedAt) }
    : { is: 'onItsWork', since: sinceOf(activity.endedAt), work: activity.work }
}

const KINDS: readonly StateKind[] = ['working', 'permission', 'question', 'onItsWork', 'yourTurn']

const isKind = (value: unknown): value is StateKind => KINDS.includes(value as StateKind)

const parseTool = (raw: unknown): ToolShown | undefined =>
  isObject(raw) && isFilled(raw.name)
    ? { name: raw.name, ...(isFilled(raw.subject) ? { subject: raw.subject } : {}) }
    : undefined

const parseQuestion = (raw: unknown): QuestionShown | undefined =>
  isObject(raw) && isFilled(raw.text) && isCount(raw.count)
    ? { text: raw.text, count: raw.count }
    : undefined

const listOf = <T>(raw: unknown, parse: (each: unknown) => T | undefined): T[] =>
  Array.isArray(raw) ? raw.flatMap(each => parse(each) ?? []) : []

const isAgent = (raw: unknown): raw is string | undefined => raw === undefined || isFilled(raw)

const parseRunning = (raw: unknown): Running | undefined => {
  if (!isObject(raw) || !isFilled(raw.call)) {
    return undefined
  }

  const tool = parseTool(raw.tool)

  return tool === undefined ? undefined : { call: raw.call, tool }
}

const parseDigests = (raw: unknown): Digests | undefined =>
  isObject(raw) && Object.values(raw).every(digest => isFilled(digest))
    ? (raw as Digests)
    : undefined

const parseAsked = (raw: unknown): Asked | undefined => {
  if (!isObject(raw) || !isFilled(raw.call) || !isFilled(raw.tool) || !isAgent(raw.agentId)) {
    return undefined
  }

  const input = parseDigests(raw.input)

  return input === undefined
    ? undefined
    : { call: raw.call, tool: raw.tool, input, agentId: raw.agentId }
}

const parseStop = (raw: unknown): Stop | undefined => {
  if (!isObject(raw) || !isFilled(raw.call) || !isTime(raw.at) || !isAgent(raw.agentId)) {
    return undefined
  }

  const { call, at, agentId } = raw
  const tool = parseTool(raw.tool)
  const question = parseQuestion(raw.question)

  if (raw.is === 'permission') {
    return tool === undefined ? undefined : { call, at, agentId, is: 'permission', tool }
  }

  return raw.is === 'question'
    ? { call, at, agentId, is: 'question', ...(question === undefined ? {} : { question }) }
    : undefined
}

/**
 * What a window heard, as an earlier load kept it in `$.state`, read field
 * by field: that load may have kept another shape. A time, a list or what
 * is pending that does not read is as QUIET has it, and an entry that does
 * not read is dropped, the rest kept.
 */
export const parseActivity = (raw: unknown): Activity => {
  if (!isObject(raw)) {
    return QUIET
  }

  const work = parseWork(raw.work)

  return {
    ...(isTime(raw.turnAt) ? { turnAt: raw.turnAt } : {}),
    ...(isTime(raw.endedAt) ? { endedAt: raw.endedAt } : {}),
    tools: listOf(raw.tools, parseRunning),
    asked: listOf(raw.asked, parseAsked),
    stops: listOf(raw.stops, parseStop),
    ...(work === undefined ? {} : { work }),
    watches: listOf(raw.watches, parseWatch),
    loops: listOf(raw.loops, loop => (isFilled(loop) ? loop : undefined)),
    ...(raw.isDone === true ? { isDone: true } : {}),
  }
}

/**
 * A heartbeat's state, read field by field: undefined without a state it
 * knows (a later version's kind among them) or a time, else its tool, its
 * question and what is pending where each is well formed, a bad one
 * dropped.
 */
export const parseState = (raw: unknown): WindowState | undefined => {
  if (!isObject(raw) || !isKind(raw.is) || !isTime(raw.since)) {
    return undefined
  }

  const tool = parseTool(raw.tool)
  const question = parseQuestion(raw.question)
  const work = parseWork(raw.work)

  return {
    is: raw.is,
    since: raw.since,
    ...(tool === undefined ? {} : { tool }),
    ...(question === undefined ? {} : { question }),
    ...(work === undefined ? {} : { work }),
  }
}
