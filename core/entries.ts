/**
 * The lines of a writer's file: one JSON object per line, each stamped with
 * the format's version, the time and the writer's own count.
 *
 * A reader can catch a file mid-write, so parsing never throws: a torn last
 * line, a bad line or a line of a kind or version it does not know is
 * skipped, and the rest stands.
 */
import { ASK_KINDS, WANTS } from './shapes'
import type { AskKind, Body, Entry, Finisher, Verdict, Wants } from './types'

/** The format's version: a line of any other is skipped. */
export const VERSION = 1

/** What appending bodies to a file makes: the stamped entries, the text to append, the whole file after. */
export type Appended = {
  entries: Entry[]
  added: string
  text: string
}

const VERDICTS: readonly Verdict[] = ['yes', 'choose', 'answer', 'comment', 'ignore', 'pickup']

const FINISHERS: readonly Finisher[] = ['lee', 'claude']

type Check = (value: unknown) => boolean

const isObject = (value: unknown): value is { [key: string]: unknown } =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

const isText: Check = value => typeof value === 'string'
const isTexts: Check = value => Array.isArray(value) && value.every(isText)
const isTime: Check = value => typeof value === 'number' && Number.isFinite(value)
const isCount: Check = value => Number.isSafeInteger(value) && (value as number) > 0
const isWants: Check = value => WANTS.includes(value as Wants)
const isAskKind: Check = value => ASK_KINDS.includes(value as AskKind)
const isVerdict: Check = value => VERDICTS.includes(value as Verdict)
const isFinisher: Check = value => FINISHERS.includes(value as Finisher)
const maybe =
  (check: Check): Check =>
  value =>
    value === undefined || check(value)

/** What an edit may carry; it carries at least one of them. */
const CHANGES: Record<string, Check> = {
  wants: maybe(isWants),
  yes: maybe(isText),
  kind: maybe(isAskKind),
  title: maybe(isText),
  where: maybe(isText),
  options: maybe(isTexts),
  needs: maybe(isText),
  ref: maybe(isText),
  text: maybe(isText),
  detail: maybe(isTexts),
}

const isChanges: Check = value =>
  isObject(value) &&
  Object.keys(CHANGES).some(key => value[key] !== undefined) &&
  Object.entries(CHANGES).every(([key, check]) => check(value[key]))

/** Each kind of line's fields, as a reader checks them; the fields a line has beyond these are dropped. */
const SHAPES: { [T in Body['type']]: Record<string, Check> } = {
  status: { name: isText, summary: isText, now: isTexts, next: maybe(isText) },
  ask: {
    id: isText,
    wants: maybe(isWants),
    yes: maybe(isText),
    kind: maybe(isAskKind),
    title: isText,
    where: maybe(isText),
    options: maybe(isTexts),
    needs: maybe(isText),
    ref: maybe(isText),
  },
  note: { id: isText, text: isText, detail: maybe(isTexts), ref: maybe(isText) },
  park: { id: isText, title: isText, where: maybe(isText), ref: maybe(isText) },
  resolve: { item: isText, reason: maybe(isText) },
  reopen: { item: isText, reason: maybe(isText) },
  edit: { item: isText, changes: isChanges, reason: maybe(isText) },
  reply: {
    id: isText,
    item: isText,
    verdict: isVerdict,
    option: maybe(isText),
    note: maybe(isText),
  },
  delivered: { replies: isTexts },
  finish: { who: isFinisher, reason: maybe(isText) },
  unfinish: {},
}

/** What a kind of line needs beyond its fields one by one: an ask says what it wants back, or, written before asks did, its kind. */
const WHOLE: Partial<Record<Body['type'], (raw: { [key: string]: unknown }) => boolean>> = {
  ask: raw => raw.wants !== undefined || raw.kind !== undefined,
}

const isType = (value: unknown): value is Body['type'] =>
  typeof value === 'string' && Object.hasOwn(SHAPES, value)

/** A line's entry, or undefined for a line that is torn, bad, or of a kind or version this reader does not know. */
const decode = (line: string): Entry | undefined => {
  let raw: unknown

  try {
    raw = JSON.parse(line)
  } catch {
    return undefined
  }

  if (
    !isObject(raw) ||
    raw.v !== VERSION ||
    !isTime(raw.at) ||
    !isCount(raw.seq) ||
    !isType(raw.type)
  ) {
    return undefined
  }

  const fields = Object.entries(SHAPES[raw.type])

  if (!fields.every(([key, check]) => check(raw[key])) || WHOLE[raw.type]?.(raw) === false) {
    return undefined
  }

  const entry: { [key: string]: unknown } = { v: raw.v, at: raw.at, seq: raw.seq, type: raw.type }

  for (const [key] of fields) {
    if (raw[key] !== undefined) {
      entry[key] = raw[key]
    }
  }

  return entry as Entry
}

/** Every entry a file's text holds, in file order. */
export const parseEntries = (text: string): Entry[] =>
  text
    .split('\n')
    .map(decode)
    .filter(entry => entry !== undefined)

/** An entry as one line of its file, newline included. */
export const serialise = (entry: Entry) => `${JSON.stringify(entry)}\n`

/**
 * Stamps bodies as the writer's next entries and says what the file becomes:
 * `added` for a writer that appends, `text` for one that writes the whole file.
 * A file left torn mid-line is ended first, so the torn line stays the only
 * casualty.
 */
export const append = (text: string, bodies: readonly Body[], at: number): Appended => {
  const last = parseEntries(text).reduce((most, entry) => Math.max(most, entry.seq), 0)
  const entries = bodies.map((body, i): Entry => ({ v: VERSION, at, seq: last + i + 1, ...body }))
  const isTorn = text !== '' && !text.endsWith('\n')
  const added = `${isTorn ? '\n' : ''}${entries.map(serialise).join('')}`

  return { entries, added, text: text + added }
}
