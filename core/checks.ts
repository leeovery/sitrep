/**
 * What Claude posts, checked and put right before it is written: each text
 * trimmed to one line, nothing empty where something is needed, options for
 * a decision. A refusal says what to fix, in words Claude can act on.
 */
import { ASK_KINDS } from './entries'
import { isWorkId } from './ids'
import type { StatusFields } from './status'
import { oneLine } from './text'
import {
  EDITABLE,
  type AskBody,
  type AskKind,
  type Changes,
  type EditBody,
  type Item,
  type NoteBody,
  type ParkBody,
  type ReopenBody,
  type ResolveBody,
  type StatusBody,
  type Work,
} from './types'

export type Checked<T> = { ok: true; value: T } | { ok: false; error: string }

type Fields = { [key: string]: unknown }

/** The fewest options a decision offers. */
const LEAST_OPTIONS = 2

const STATUS_FIELDS = ['name', 'summary', 'now', 'next'] as const

const NOUNS: Record<Item['type'], string> = { ask: 'an ask', note: 'a note', park: 'a parked item' }

const ok = <T>(value: T): Checked<T> => ({ ok: true, value })
const refuse = (error: string): { ok: false; error: string } => ({ ok: false, error })

const fieldsOf = (input: unknown): Fields =>
  typeof input === 'object' && input !== null ? (input as Fields) : {}

/** A text as one line; undefined when it is not text or comes to nothing. */
const line = (value: unknown) =>
  typeof value === 'string' ? oneLine(value) || undefined : undefined

/** A list of lines (one text counts as a list of one), each one line, the empty and repeated dropped; undefined when not text. */
const lines = (value: unknown) => {
  const list = typeof value === 'string' ? [value] : value

  if (!Array.isArray(list) || !list.every(each => typeof each === 'string')) {
    return undefined
  }

  return [...new Set(list.map(oneLine).filter(Boolean))]
}

const isAskKind = (value: unknown): value is AskKind => ASK_KINDS.includes(value as AskKind)

/** Why these options will not do for an ask of this kind: a decide ask needs them, no other takes them. */
const misfitOf = (kind: AskKind, options: readonly string[]) => {
  if (kind === 'decide') {
    return options.length >= LEAST_OPTIONS
      ? undefined
      : `A decide ask needs at least ${LEAST_OPTIONS} options.`
  }

  return options.length === 0 ? undefined : 'Only a decide ask takes options.'
}

export const checkStart = (input: unknown): Checked<{ name: string; summary: string }> => {
  const fields = fieldsOf(input)
  const name = line(fields.name)
  const summary = line(fields.summary)

  if (name === undefined) {
    return refuse('A piece of work needs a name: a few words.')
  }

  return summary === undefined
    ? refuse('A piece of work needs a summary: one line on what it is for.')
    : ok({ name, summary })
}

/** The piece of work to join, by its id. */
export const checkJoin = (input: unknown): Checked<{ work: string }> => {
  const work = line(fieldsOf(input).work)

  return isWorkId(work)
    ? ok({ work })
    : refuse('Name the piece of work by the id start gave it: sr- and six characters.')
}

/** A status: what Claude gives replaces what it names, the rest stays as `current` has it; an empty `next` clears it. */
export const checkStatus = (input: unknown, current: StatusFields): Checked<StatusBody> => {
  const fields = fieldsOf(input)

  if (STATUS_FIELDS.every(key => fields[key] === undefined)) {
    return refuse('A status needs at least one of name, summary, now and next.')
  }

  const given = <T>(key: (typeof STATUS_FIELDS)[number], read: (value: unknown) => T, kept: T) =>
    fields[key] === undefined ? kept : read(fields[key])

  const name = given('name', line, current.name)
  const summary = given('summary', line, current.summary)
  const now = given('now', lines, current.now)
  const next = given('next', line, current.next)

  if (name === undefined || summary === undefined) {
    return refuse('A status keeps a name and a summary: neither can be empty.')
  }

  return now === undefined
    ? refuse('`now` is a list of lines, one for each thing under way.')
    : ok({ type: 'status', name, summary, now, next })
}

export const checkAsk = (input: unknown): Checked<Omit<AskBody, 'id'>> => {
  const fields = fieldsOf(input)
  const title = line(fields.title)

  if (!isAskKind(fields.kind)) {
    return refuse(`An ask's kind is one of ${ASK_KINDS.join(', ')}.`)
  }

  if (title === undefined) {
    return refuse('An ask needs a title: one line, starting with the verb.')
  }

  const options = lines(fields.options) ?? []
  const misfit = misfitOf(fields.kind, options)

  if (misfit !== undefined) {
    return refuse(misfit)
  }

  return ok({
    type: 'ask',
    kind: fields.kind,
    title,
    where: line(fields.where),
    options: options.length === 0 ? undefined : options,
    ref: line(fields.ref),
  })
}

export const checkNote = (input: unknown): Checked<Omit<NoteBody, 'id'>> => {
  const fields = fieldsOf(input)
  const text = line(fields.text)
  const detail = lines(fields.detail)

  return text === undefined
    ? refuse('A note needs its text: one line.')
    : ok({ type: 'note', text, detail: detail?.length ? detail : undefined, ref: line(fields.ref) })
}

export const checkPark = (input: unknown): Checked<Omit<ParkBody, 'id'>> => {
  const fields = fieldsOf(input)
  const title = line(fields.title)

  return title === undefined
    ? refuse('A parked item needs a title: one line.')
    : ok({ type: 'park', title, where: line(fields.where), ref: line(fields.ref) })
}

/** The item `fields.item` names on the board, or a refusal. */
const target = (work: Work, fields: Fields): Checked<Item> => {
  const id = line(fields.item)
  const item = id === undefined ? undefined : work.items.get(id)

  if (id === undefined) {
    return refuse('Name the item by its id, as the board lists it.')
  }

  return item === undefined ? refuse(`There is no item ${id} on this board.`) : ok(item)
}

const isClosed = (item: Item) => item.state === 'closed' || item.state === 'ignored'

/** Whether an item is open as it was posted: an ask waiting on Lee, a note shown, an item still parked. */
const isFresh = (item: Item) =>
  item.state === 'waiting' || item.state === 'open' || item.state === 'parked'

/** What resolve and reopen refuse: an item already where either would leave it. */
const ALREADY = {
  resolve: { is: isClosed, where: 'closed' },
  reopen: { is: isFresh, where: 'open' },
}

const closeOrOpen = <T extends keyof typeof ALREADY>(
  type: T,
  work: Work,
  input: unknown,
): Checked<{ type: T; item: string; reason?: string }> => {
  const fields = fieldsOf(input)
  const item = target(work, fields)
  const already = ALREADY[type]

  if (!item.ok) {
    return item
  }

  return already.is(item.value)
    ? refuse(`${item.value.id} is already ${already.where}.`)
    : ok({ type, item: item.value.id, reason: line(fields.reason) })
}

export const checkResolve = (work: Work, input: unknown): Checked<ResolveBody> =>
  closeOrOpen('resolve', work, input)

export const checkReopen = (work: Work, input: unknown): Checked<ReopenBody> =>
  closeOrOpen('reopen', work, input)

/** How each field an edit changes is read: undefined when what was given will not do. */
const READERS: { [K in keyof Changes]-?: (value: unknown) => Changes[K] | undefined } = {
  kind: value => (isAskKind(value) ? value : undefined),
  title: line,
  where: line,
  options: lines,
  ref: line,
  text: line,
  detail: lines,
}

/** An edit's changes as read, or a refusal naming the first field that will not do. */
const changesFor = (item: Item, fields: Fields): Checked<Changes> => {
  const allowed = EDITABLE[item.type]
  const named = (Object.keys(READERS) as (keyof Changes)[]).filter(key => fields[key] !== undefined)
  const changes: Changes = {}

  if (named.length === 0) {
    return refuse(
      `An edit names a field to change: for ${NOUNS[item.type]}, ${allowed.join(', ')}.`,
    )
  }

  for (const key of named) {
    if (!allowed.includes(key)) {
      return refuse(`An edit to ${NOUNS[item.type]} changes ${allowed.join(', ')}; not ${key}.`)
    }

    const value = READERS[key](fields[key])

    if (value === undefined) {
      return refuse(`An edit cannot leave ${key} empty or of the wrong kind.`)
    }

    Object.assign(changes, { [key]: value })
  }

  return ok(changes)
}

/** Why an ask, once edited, would not have the options its kind calls for; undefined when it would. */
const editedMisfit = (item: Item, changes: Changes) => {
  if (item.type !== 'ask') {
    return undefined
  }

  const kind = changes.kind ?? item.kind
  const kept = kind === 'decide' ? (item.options ?? []) : []

  return misfitOf(kind, changes.options ?? kept)
}

export const checkEdit = (work: Work, input: unknown): Checked<EditBody> => {
  const fields = fieldsOf(input)
  const item = target(work, fields)

  if (!item.ok) {
    return item
  }

  const changes = changesFor(item.value, fields)

  if (!changes.ok) {
    return changes
  }

  const misfit = editedMisfit(item.value, changes.value)

  return misfit === undefined
    ? ok({ type: 'edit', item: item.value.id, changes: changes.value, reason: line(fields.reason) })
    : refuse(misfit)
}
