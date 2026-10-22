/**
 * What a turn left pending that will wake its window: the background tasks
 * and the scheduled wakes its Stop lists (see "A session's state" in
 * DESIGN.md), summed up for its heartbeat and never kept whole.
 *
 * - Every task counts, by its kind (agents, workflows, shells, monitors, any
 *   other), but those that never wake the window: a persistent monitor,
 *   which runs until it is stopped, and the engine's own ambient tasks.
 * - A monitor watching a command is listed as a shell. The Monitor call's
 *   result names its task and says whether it is persistent, so the mod
 *   hears each one start (`watchOf`) and tells it here by its task.
 * - Only a one-off wake counts: a recurring cron never ends. A one-off's
 *   schedule encodes a single fire time, read in local time, as the engine
 *   reads it, nearest now; one that does not read counts with no time.
 *
 * A shell that never ends, such as `tail -f`, cannot be told from one that
 * will: it counts while it runs.
 */
import { isCount, isFilled, isObject, isTime } from './entries'
import { shownText } from './subject'
import type { Tasks, Work } from './types'

/** A task a Stop lists (the engine's `BackgroundTaskSummary`), as far as the summary reads it. */
export type PendingTask = {
  id: string
  type: string
  description: string
  command?: string
  name?: string
}

/** A cron a Stop lists (the engine's `SessionCronSummary`), as far as the summary reads it. */
export type PendingCron = { schedule: string; recurring: boolean }

/** What a Stop lists of the session's background work; a list is absent where the engine could not read it. */
export type Pending = { tasks?: readonly PendingTask[]; crons?: readonly PendingCron[] }

/** A monitor a call of the Monitor tool started: its task, and whether it runs until it is stopped. */
export type Watch = { task: string; isPersistent: boolean }

/** The tool that starts a monitor. */
export const MONITOR_TOOL = 'Monitor'

type TaskKind = Exclude<keyof Work, 'wakes'>

/** The kinds of task, in the order their lines are chosen. */
export const TASK_KINDS: readonly TaskKind[] = ['agents', 'workflows', 'shells', 'monitors', 'others']

const KIND_OF_TYPE: ReadonlyMap<string, TaskKind> = new Map([
  ['subagent', 'agents'],
  ['workflow', 'workflows'],
  ['shell', 'shells'],
  ['monitor', 'monitors'],
])

/**
 * The engine's own tasks, by the type a Stop lists them under: they run
 * beside the conversation and end without waking it, so they would hold a
 * window on its own work after they ended.
 */
const AMBIENT: ReadonlySet<string> = new Set(['dream', 'auto-mode scan', 'memory import'])

/** The days a wake's schedule is looked for over, either side of today: four years, a 29 February's among them. */
const WAKE_DAYS = 4 * 366

const kindOf = (task: PendingTask, watches: readonly Watch[]): TaskKind | undefined => {
  const watch = watches.find(each => each.task === task.id)

  if (watch?.isPersistent === true || AMBIENT.has(task.type)) {
    return undefined
  }

  return watch === undefined ? (KIND_OF_TYPE.get(task.type) ?? 'others') : 'monitors'
}

/** What a task's words are where it says nothing of itself; never empty, as the summary's reader takes no empty words. */
const A_TASK = 'a task'

/** What a task's line says of it, one line and cut short: a shell's command, a workflow's name, else its description; its type, else "a task", where that says nothing. */
const wordsOf = (task: PendingTask, kind: TaskKind) => {
  const named = kind === 'shells' ? task.command : kind === 'workflows' ? task.name : undefined

  return [named, task.description, task.type].map(shownText).find(isFilled) ?? A_TASK
}

/** A cron field: `*`, any; else a whole number in its range; else undefined. */
const cronField = (text: string | undefined, low: number, high: number): number | '*' | undefined => {
  if (text === '*') {
    return '*'
  }

  const value = Number(text)

  return /^\d+$/.test(text ?? '') && value >= low && value <= high ? value : undefined
}

/** Whether a date is a day a schedule's day and weekday name: either, where it names both, as cron reads them. */
const isDayOf = (at: Date, day: number | '*', weekday: number | '*') => {
  const isDay = day === '*' || at.getDate() === day
  const isWeekday = weekday === '*' || at.getDay() === weekday % 7

  return day !== '*' && weekday !== '*' ? isDay || isWeekday : isDay && isWeekday
}

/** A one-off wake's schedule as read: its minute and hour, and its day, month and weekday each a number or any. */
type Schedule = { minute: number; hour: number; day: number | '*'; month: number | '*'; weekday: number | '*' }

const scheduleOf = (text: string): Schedule | undefined => {
  const fields = text.trim().split(/\s+/)
  const [minute, hour] = [cronField(fields[0], 0, 59), cronField(fields[1], 0, 23)]
  const [day, month, weekday] = [
    cronField(fields[2], 1, 31),
    cronField(fields[3], 1, 12),
    cronField(fields[4], 0, 7),
  ]

  return fields.length === 5 &&
    typeof minute === 'number' &&
    typeof hour === 'number' &&
    day !== undefined &&
    month !== undefined &&
    weekday !== undefined
    ? { minute, hour, day, month, weekday }
    : undefined
}

/**
 * The first time a schedule fires on one side of `from`, the days from it
 * looked at in turn, later (`step` 1) or earlier (-1), over four years.
 */
const firstFire = (
  { minute, hour, day, month, weekday }: Schedule,
  from: Date,
  step: 1 | -1,
  isOnItsSide: (at: number) => boolean,
): number | undefined => {
  for (let days = 0; days <= WAKE_DAYS; days += 1) {
    const at = new Date(from.getFullYear(), from.getMonth(), from.getDate() + step * days, hour, minute)

    if (isOnItsSide(at.getTime()) && (month === '*' || at.getMonth() + 1 === month) && isDayOf(at, day, weekday)) {
      return at.getTime()
    }
  }

  return undefined
}

/**
 * When a one-off wake's schedule fires, in local time, as near `now` as it
 * does: its next time, from the start of `now`'s minute, unless the last
 * before it is nearer. A one-off still listed has not fired, so one whose
 * minute just passed is due now, not a day or a year away. Undefined where
 * the schedule does not read, or names no time four years either side.
 */
export const wakeAt = (text: string, now: number): number | undefined => {
  const schedule = scheduleOf(text)

  if (schedule === undefined) {
    return undefined
  }

  const from = new Date(now)

  from.setSeconds(0, 0)

  const next = firstFire(schedule, from, 1, at => at >= from.getTime())
  const last = firstFire(schedule, from, -1, at => at < from.getTime())

  return last !== undefined && (next === undefined || now - last < next - now) ? last : next
}

/**
 * What a Stop's lists leave pending, at `now`, the monitors heard started
 * telling theirs: each kind of task with how many and its first, and the
 * one-off wakes with the soonest's time. Undefined with nothing pending.
 */
export const workOf = (
  { tasks = [], crons = [] }: Pending,
  watches: readonly Watch[],
  now: number,
): Work | undefined => {
  const counted = tasks.flatMap(task => {
    const kind = kindOf(task, watches)

    return kind === undefined ? [] : [{ kind, words: wordsOf(task, kind) }]
  })
  const byKind: Work = Object.fromEntries(
    TASK_KINDS.flatMap(kind => {
      const words = counted.filter(each => each.kind === kind).map(each => each.words)
      const [first] = words

      return first === undefined ? [] : [[kind, { count: words.length, first }]]
    }),
  )
  const wakes = crons.filter(cron => !cron.recurring)
  const times = wakes.flatMap(cron => wakeAt(cron.schedule, now) ?? [])

  if (wakes.length === 0) {
    return Object.keys(byKind).length === 0 ? undefined : byKind
  }

  return {
    ...byKind,
    wakes: { count: wakes.length, ...(times.length === 0 ? {} : { at: Math.min(...times) }) },
  }
}

/** The monitors still running by a Stop's list: all of them where it lists no tasks. */
export const watchesLeft = (watches: readonly Watch[], { tasks }: Pending): Watch[] =>
  tasks === undefined ? [...watches] : watches.filter(watch => tasks.some(task => task.id === watch.task))

/**
 * The monitor a call started, from the tool's result: its task, and whether
 * it is persistent, which the result says either way (the engine's tool
 * types: `persistent`, or a `timeoutMs` of 0); none for any other tool, or a
 * result naming no task.
 */
export const watchOf = (tool: string, result: unknown): Watch | undefined =>
  tool === MONITOR_TOOL && isObject(result) && isFilled(result.taskId)
    ? { task: result.taskId, isPersistent: result.persistent === true || result.timeoutMs === 0 }
    : undefined

const parseTasks = (raw: unknown): Tasks | undefined =>
  isObject(raw) && isCount(raw.count) && isFilled(raw.first)
    ? { count: raw.count, first: raw.first }
    : undefined

const parseWakes = (raw: unknown): Work['wakes'] =>
  isObject(raw) && isCount(raw.count)
    ? { count: raw.count, ...(isTime(raw.at) ? { at: raw.at } : {}) }
    : undefined

/** What is pending, as a heartbeat or `$.state` keeps it, read field by field: a kind that does not read is dropped; undefined with none that does. */
export const parseWork = (raw: unknown): Work | undefined => {
  if (!isObject(raw)) {
    return undefined
  }

  const wakes = parseWakes(raw.wakes)
  const work: Work = Object.fromEntries(
    TASK_KINDS.flatMap(kind => {
      const tasks = parseTasks(raw[kind])

      return tasks === undefined ? [] : [[kind, tasks]]
    }),
  )

  return Object.keys(work).length === 0 && wakes === undefined
    ? undefined
    : { ...work, ...(wakes === undefined ? {} : { wakes }) }
}

/** A monitor heard started, as `$.state` keeps it: read whole, or undefined. */
export const parseWatch = (raw: unknown): Watch | undefined =>
  isObject(raw) && isFilled(raw.task) && typeof raw.isPersistent === 'boolean'
    ? { task: raw.task, isPersistent: raw.isPersistent }
    : undefined
