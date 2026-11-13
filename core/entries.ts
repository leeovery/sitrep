/**
 * The lines of a writer's file: one JSON object per line, each stamped with
 * the format's version, the time and the writer's own count.
 *
 * A reader can catch a file mid-write, so parsing never throws: a torn last
 * line, a bad line or a line of a kind or version it does not know is
 * skipped, and the rest stands. A line of a past version is read in today's
 * shape (see versions.ts).
 */
import { ASK_KINDS, WANTS } from './shapes'
import type { AskKind, Body, Entry, Finisher, SentReply, Verdict, Wants } from './types'
import { upgraded, versionOf, type Raw, type Upgrade } from './versions'

/** How a line of each past version is brought to the next: none yet, the format being at its first. */
const UPGRADES: readonly Upgrade[] = []

/** The format's version: a line of a later one is skipped. */
export const VERSION = versionOf(UPGRADES)

/** What appending bodies to a file makes: the stamped entries and the whole file after. */
export type Appended = {
  entries: Entry[]
  text: string
}

const VERDICTS: readonly Verdict[] = ['yes', 'choose', 'answer', 'comment', 'ignore', 'pickup']

const FINISHERS: readonly Finisher[] = ['lee', 'claude']

type Check = (value: unknown) => boolean

/** Whether a value read from JSON is an object of keys: not null, and not a list. */
export const isObject = (value: unknown): value is { [key: string]: unknown } =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

/**
 * A JSON object's text in today's shape, through its format's upgrades;
 * undefined when it is torn, not an object, or of a version this reader
 * does not know.
 */
export const parseVersioned = (text: string, upgrades: readonly Upgrade[]): Raw | undefined => {
  let raw: unknown

  try {
    raw = JSON.parse(text)
  } catch {
    return undefined
  }

  return isObject(raw) ? upgraded(raw, upgrades) : undefined
}

/** Whether a value read from JSON is text with something in it. */
export const isFilled = (value: unknown): value is string =>
  typeof value === 'string' && value !== ''

/** The furthest a `Date` holds from the epoch, either side, in milliseconds. */
const DATE_RANGE_MS = 8.64e15

/** Whether a value read from JSON is a time: a number a `Date` holds, so it compares and words as one. */
export const isTime = (value: unknown): value is number =>
  typeof value === 'number' && Math.abs(value) <= DATE_RANGE_MS

/** Whether a value read from JSON is a count from one up. */
export const isCount = (value: unknown): value is number =>
  Number.isSafeInteger(value) && (value as number) > 0

const isText: Check = value => typeof value === 'string'
const isTexts: Check = value => Array.isArray(value) && value.every(isText)
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
  snoozeSession: { until: isTime },
  wakeSession: {},
  snooze: { item: isText, until: isTime },
  wake: { item: isText },
  snoozeTurn: { turn: isTime, until: maybe(isTime) },
  wakeTurn: { turn: isTime },
}

/** What a kind of line needs beyond its fields one by one: an ask says what it wants back, or, written before asks did, its kind. */
const WHOLE: Partial<Record<Body['type'], (raw: Raw) => boolean>> = {
  ask: raw => raw.wants !== undefined || raw.kind !== undefined,
}

const isType = (value: unknown): value is Body['type'] =>
  typeof value === 'string' && Object.hasOwn(SHAPES, value)

/** The fields `shape` checks, as `raw` holds them, those beyond them dropped; undefined where one does not read. */
const fieldsIn = (shape: Record<string, Check>, raw: Raw): Raw | undefined => {
  const fields = Object.entries(shape)

  if (!fields.every(([key, check]) => check(raw[key]))) {
    return undefined
  }

  return Object.fromEntries(
    fields.flatMap(([key]) => (raw[key] === undefined ? [] : [[key, raw[key]]])),
  )
}

/** A line's entry in today's shape, or undefined for a line that is torn, bad, or of a kind or version this reader does not know. */
const decode = (line: string): Entry | undefined => {
  const raw = parseVersioned(line, UPGRADES)

  if (raw === undefined || !isTime(raw.at) || !isCount(raw.seq) || !isType(raw.type)) {
    return undefined
  }

  const fields = fieldsIn(SHAPES[raw.type], raw)

  if (fields === undefined || WHOLE[raw.type]?.(raw) === false) {
    return undefined
  }

  return { v: raw.v, at: raw.at, seq: raw.seq, type: raw.type, ...fields } as Entry
}

/** A reply as a message in flight carries it, read as a reply line's fields are; undefined where one does not read. */
export const parseSentReply = (value: unknown): SentReply | undefined =>
  isObject(value) ? (fieldsIn(SHAPES.reply, value) as SentReply | undefined) : undefined

/** Every entry a file's text holds, in file order. */
export const parseEntries = (text: string): Entry[] =>
  text.split('\n').map(decode).filter(entry => entry !== undefined)

/** An entry as one line of its file, newline included. */
export const serialise = (entry: Entry) => `${JSON.stringify(entry)}\n`

/**
 * What goes before lines appended to a file's text: a newline ending a last
 * line left torn mid-write, so the torn line stays the only casualty;
 * nothing after a whole one.
 */
export const tornLineEnd = (text: string) => (text !== '' && !text.endsWith('\n') ? '\n' : '')

/** Stamps bodies as the writer's next entries, its count going on from the highest `text` holds. */
export const stamp = (text: string, bodies: readonly Body[], at: number): Entry[] => {
  const last = parseEntries(text).reduce((most, entry) => Math.max(most, entry.seq), 0)

  return bodies.map((body, i): Entry => ({ v: VERSION, at, seq: last + i + 1, ...body }))
}

/** What adds entries to the end of a file whose text is `file`: a newline ending a torn last line first. */
export const addition = (file: string, entries: readonly Entry[]) =>
  `${tornLineEnd(file)}${entries.map(serialise).join('')}`

/** Stamps bodies as the writer's next entries and says what the file becomes, a torn last line ended first. */
export const append = (text: string, bodies: readonly Body[], at: number): Appended => {
  const entries = stamp(text, bodies, at)

  return { entries, text: text + addition(text, entries) }
}
