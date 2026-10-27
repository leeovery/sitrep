/**
 * What Claude posts, checked and put right before it is written: each text
 * trimmed to one line, nothing empty where something is needed, and an ask
 * holding what its shape takes: a yes its button's words, a choice its
 * options, words what they are. A refusal says what to fix, in words Claude
 * can act on. Lee's answer to an ask from outside Claude Code, as the CLI
 * gives it, is checked here too, and Lee's snooze and waking of asks.
 */
import { isTime } from './entries'
import { isSessionId, newItemId, type Random } from './ids'
import { directoryOf, isNameable } from './project'
import { needsReload } from './release'
import { isSnoozed, replyOnItsWay, yesOf } from './replies'
import { WANTS } from './shapes'
import type { StatusFields } from './status'
import { inWords, oneLine } from './text'
import {
  EDITABLE,
  type Ask,
  type AskBody,
  type Changes,
  type EditBody,
  type FinishBody,
  type Finisher,
  type Item,
  type NoteBody,
  type ParkBody,
  type ReopenBody,
  type ReplyBody,
  type ResolveBody,
  type SnoozeBody,
  type StatusBody,
  type WakeBody,
  type Wants,
  type Session,
} from './types'

export type Checked<T> = { ok: true; value: T } | { ok: false; error: string }

type Fields = { [key: string]: unknown }

/** The fewest options a choice offers. */
const LEAST_OPTIONS = 2

/** The most characters a yes button's words take: a word or two, the verb Lee gives. */
const YES_MOST = 20

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

const isWants = (value: unknown): value is Wants => WANTS.includes(value as Wants)

/** A project's name: one line, with a letter or a digit to match it by; undefined when not. */
const projectNameOf = (value: unknown) => {
  const name = line(value)

  return name !== undefined && isNameable(name) ? name : undefined
}

/** A project's directory as given: none, or an absolute path, the slashes after it dropped. */
const directoryIn = (value: unknown): Checked<string | undefined> => {
  const path = typeof value === 'string' ? value.trim() : value

  if (path === undefined || path === '') {
    return ok(undefined)
  }

  return typeof path === 'string' && path.startsWith('/')
    ? ok(directoryOf(path))
    : refuse("A project's directory is an absolute path: where the project lives.")
}

/** An ask's shape as it would stand: what it wants back, and what goes with that. */
type Shape = { wants: Wants; yes?: string; options: readonly string[]; needs?: string }

/** What a shape must hold, each rule broken where it says, with what to fix. */
const SHAPE_RULES: readonly [breaks: (shape: Shape) => boolean, error: string][] = [
  [
    ({ wants, yes }) => wants === 'yes' && yes === undefined,
    "A yes ask needs yes: its button's words, the verb Lee gives, such as Go, Approve or It works.",
  ],
  [({ wants, yes }) => wants !== 'yes' && yes !== undefined, 'Only a yes ask takes yes.'],
  [
    ({ yes }) => (yes?.length ?? 0) > YES_MOST,
    `A yes button's words are a word or two, ${YES_MOST} characters at most, such as Go or Ship it.`,
  ],
  [
    ({ wants, options }) => wants === 'choice' && options.length < LEAST_OPTIONS,
    `A choice ask needs at least ${LEAST_OPTIONS} options.`,
  ],
  [
    ({ wants, options }) => wants !== 'choice' && options.length > 0,
    'Only a choice ask takes options.',
  ],
  [
    ({ wants, needs }) => wants !== 'words' && needs !== undefined,
    'Only a words ask takes needs: what its words are.',
  ],
]

/** Why a shape will not do; undefined when it will. */
const misfitOf = (shape: Shape) => SHAPE_RULES.find(([breaks]) => breaks(shape))?.[1]

/** A session to start: its name and summary, and its project's name and directory. */
export type StartFields = { name: string; summary: string; project: string; directory?: string }

/** What the project tool changes of a project: its name, its directory, or both. */
export type ProjectChange = { name?: string; directory?: string }

export const checkStart = (input: unknown): Checked<StartFields> => {
  const fields = fieldsOf(input)
  const name = line(fields.name)
  const summary = line(fields.summary)
  const project = projectNameOf(fields.project)
  const directory = directoryIn(fields.directory)

  if (name === undefined) {
    return refuse('A session needs a name: a few words.')
  }

  if (summary === undefined) {
    return refuse('A session needs a summary: one line on what it is for.')
  }

  if (project === undefined) {
    return refuse(
      'A session needs its project: its name as Lee would say it, such as SitRep or Switchboard.',
    )
  }

  return directory.ok ? ok({ name, summary, project, directory: directory.value }) : directory
}

/** A project renamed, given a directory, or both. */
export const checkProject = (input: unknown): Checked<ProjectChange> => {
  const fields = fieldsOf(input)
  const name = projectNameOf(fields.name)
  const directory = directoryIn(fields.directory)

  if (fields.name !== undefined && name === undefined) {
    return refuse("A project's name is one line, as Lee would say it, with a letter or a digit.")
  }

  if (!directory.ok) {
    return directory
  }

  return name === undefined && directory.value === undefined
    ? refuse('Give the project a new name, a directory, or both.')
    : ok({ name, directory: directory.value })
}

/** The session to join, by its id. */
export const checkJoin = (input: unknown): Checked<{ session: string }> => {
  const session = line(fieldsOf(input).session)

  return isSessionId(session)
    ? ok({ session })
    : refuse('Name the session by the id start gave it: sr- and six characters.')
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

  if (!isWants(fields.wants)) {
    return refuse(
      `An ask's wants is one of ${WANTS.join(', ')}: a yes, one of its options, or words.`,
    )
  }

  if (title === undefined) {
    return refuse('An ask needs a title: one line, starting with the verb.')
  }

  const shape = {
    wants: fields.wants,
    yes: line(fields.yes),
    options: lines(fields.options) ?? [],
    needs: line(fields.needs),
  }
  const misfit = misfitOf(shape)

  if (misfit !== undefined) {
    return refuse(misfit)
  }

  return ok({
    type: 'ask',
    wants: shape.wants,
    yes: shape.yes,
    title,
    where: line(fields.where),
    options: shape.options.length === 0 ? undefined : shape.options,
    needs: shape.needs,
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

/** A checked post given a fresh item id, unlike any its session uses. */
export const withId = <T>(
  checked: Checked<T>,
  session: Pick<Session, 'ids'>,
  random: Random,
): Checked<T & { id: string }> =>
  checked.ok ? ok({ ...checked.value, id: newItemId(random, session.ids) }) : checked

/** The item `fields.item` names on the board, or a refusal. */
const target = (session: Session, fields: Fields): Checked<Item> => {
  const id = line(fields.item)
  const item = id === undefined ? undefined : session.items.get(id)

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
  session: Session,
  input: unknown,
): Checked<{ type: T; item: string; reason?: string }> => {
  const fields = fieldsOf(input)
  const item = target(session, fields)
  const already = ALREADY[type]

  if (!item.ok) {
    return item
  }

  return already.is(item.value)
    ? refuse(`${item.value.id} is already ${already.where}.`)
    : ok({ type, item: item.value.id, reason: line(fields.reason) })
}

export const checkResolve = (session: Session, input: unknown): Checked<ResolveBody> =>
  closeOrOpen('resolve', session, input)

export const checkReopen = (session: Session, input: unknown): Checked<ReopenBody> =>
  closeOrOpen('reopen', session, input)

/** A text as one line, empty where it comes to nothing: what an edit clears a field with. */
const clearable = (value: unknown) => (typeof value === 'string' ? oneLine(value) : undefined)

/** How each field an edit changes is read: undefined when what was given will not do. */
const READERS: { [K in keyof Changes]-?: (value: unknown) => Changes[K] | undefined } = {
  wants: value => (isWants(value) ? value : undefined),
  yes: line,
  title: line,
  where: line,
  options: lines,
  needs: clearable,
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

/** What an edit leaves of a field: what it gives, an empty one clearing it, else what the ask had, where its shape keeps it. */
const kept = <T>(given: T | undefined, had: T | undefined, isKept: boolean) =>
  given === undefined ? (isKept ? had : undefined) : given || undefined

/** Why an ask, once edited, would not hold what its shape takes; undefined when it would. */
const editedMisfit = (item: Item, changes: Changes) => {
  if (item.type !== 'ask') {
    return undefined
  }

  const wants = changes.wants ?? item.wants

  return misfitOf({
    wants,
    yes: kept(changes.yes, item.yes, wants === 'yes'),
    options: kept(changes.options, item.options, wants === 'choice') ?? [],
    needs: kept(changes.needs, item.needs, wants === 'words'),
  })
}

/** The fields of an ask's shape: what it wants back, and what goes with that. */
const SHAPE_FIELDS: readonly (keyof Changes)[] = ['wants', 'yes', 'options', 'needs']

/**
 * An edit's changes as written. One changing the shape of an ask still read
 * from its kind says what it wants back, so it reads by its shape from then
 * on; any other keeps the kind, so the replies written to it keep their
 * meaning.
 */
const written = (item: Item, changes: Changes): Changes =>
  item.type === 'ask' &&
  item.kind !== undefined &&
  SHAPE_FIELDS.some(key => changes[key] !== undefined)
    ? { wants: item.wants, ...changes }
    : changes

export const checkEdit = (session: Session, input: unknown): Checked<EditBody> => {
  const fields = fieldsOf(input)
  const item = target(session, fields)

  if (!item.ok) {
    return item
  }

  const changes = changesFor(item.value, fields)

  if (!changes.ok) {
    return changes
  }

  const misfit = editedMisfit(item.value, changes.value)

  return misfit === undefined
    ? ok({
        type: 'edit',
        item: item.value.id,
        changes: written(item.value, changes.value),
        reason: line(fields.reason),
      })
    : refuse(misfit)
}

/** Finishes the session, by Lee or by Claude, with Claude's reason; refused once it is. */
export const checkFinish = (
  session: Session,
  who: Finisher,
  input?: unknown,
): Checked<FinishBody> =>
  session.finished === undefined
    ? ok({ type: 'finish', who, reason: line(fieldsOf(input).reason) })
    : refuse('This session is already finished.')

/** The words a yes or a choice ask is answered in outside Claude Code: its yes, or one of its options; none for words. */
const answersOf = (ask: Ask): readonly string[] => {
  switch (ask.wants) {
    case 'yes':
      return [yesOf(ask)]
    case 'choice':
      return ask.options ?? []
    case 'words':
      return []
  }
}

/** Each quoted, in plain words: `“a” or “b”`. */
const quotedOr = (answers: readonly string[]) => inWords(answers.map(each => `“${each}”`), 'or')

/** A rule an ask Lee acts on from outside Claude Code keeps, broken where it says, with why. */
type AskRule = readonly [breaks: (ask: Ask) => boolean, error: (ask: Ask) => string]

/** What an ask needs to take an answer or a snooze: open still, neither closed nor ignored. */
const OPEN_RULES: readonly AskRule[] = [[isClosed, ask => `${ask.id} is already ${ask.state}.`]]

/** What any answer from outside Claude Code needs of its ask. */
const ANSWER_RULES: readonly AskRule[] = [
  ...OPEN_RULES,
  [ask => ask.answerOnItsWay !== undefined, ask => `An answer to ${ask.id} is on its way already.`],
]

/** Why the first rule any of the asks breaks refuses them, the rules in their order, then the asks in theirs; undefined while none does. */
const brokenBy = (rules: readonly AskRule[], asks: readonly Ask[]) => {
  for (const [breaks, error] of rules) {
    const ask = asks.find(breaks)

    if (ask !== undefined) {
      return error(ask)
    }
  }

  return undefined
}

const FINISHED = 'This session is finished: its asks wait on Lee no more.'

const OLD_WINDOW =
  'A window holding this session runs an older sitrep: run /reload-plugins in it first.'

/**
 * Whether the window that delivers the session's inbox runs a sitrep behind
 * `version`, the CLI's, and needs `/reload-plugins`, as `watch` tells it
 * (`needsReload`): it delivers by its release's rules, and one from before
 * second answers were voided would give Claude two at once.
 */
const isDeliveredByOld = (session: Session, version: string | undefined) => {
  const window = session.presence.find(each => each.writer === session.deliverer)

  return window !== undefined && needsReload(window.version, version)
}

type Answer = Checked<Omit<ReplyBody, 'id'>>

/** A yes or a choice in the words given, the ask's own; or why they will not answer it. */
const worded = (ask: Ask, given: string | undefined): Answer => {
  const answers = answersOf(ask)
  const wanted = ask.wants === 'yes' ? 'a yes' : 'a choice'

  if (answers.length === 0) {
    return refuse(
      ask.wants === 'words'
        ? `${ask.id} wants words, which need Claude Code's prompt: answer it there.`
        : `${ask.id} gives no options to choose from: answer it in Claude Code's prompt.`,
    )
  }

  if (given === undefined || !answers.includes(given)) {
    return refuse(`${ask.id} wants ${wanted}: answer it with ${quotedOr(answers)}.`)
  }

  return ok(
    ask.wants === 'yes'
      ? { type: 'reply', item: ask.id, verdict: 'yes' }
      : { type: 'reply', item: ask.id, verdict: 'choose', option: given },
  )
}

/** Lee's ignore, as the board's `✕ ignore` gives it: seen, and not to be acted on, whatever the ask wants back. */
const ignored = (ask: Ask, given: string | undefined): Answer =>
  given === undefined
    ? ok({ type: 'reply', item: ask.id, verdict: 'ignore' })
    : refuse('Give an answer or --ignore, not both.')

/** The ask an id names on the board, or a refusal: no id, no item, or one that is no ask. */
const askIn = (session: Session, id: unknown): Checked<Ask> => {
  const item = target(session, { item: id })

  if (!item.ok) {
    return item
  }

  return item.value.type === 'ask'
    ? ok(item.value)
    : refuse(`${item.value.id} is ${NOUNS[item.value.type]}, not an ask.`)
}

/** The ask an answer names, in a session still waiting on Lee whose window can take an answer in; or a refusal. */
const askAnswered = (
  session: Session,
  fields: Fields,
  version: string | undefined,
): Checked<Ask> => {
  if (session.finished !== undefined) {
    return refuse(FINISHED)
  }

  const ask = askIn(session, fields.ask)

  return ask.ok && isDeliveredByOld(session, version) ? refuse(OLD_WINDOW) : ask
}

/**
 * Lee's answer to an ask of the session, as the CLI gives it from outside
 * Claude Code: a yes in its button's words, or one of a choice's options,
 * as the board shows them; or, `ignore`, Lee's ignore, which any ask takes.
 * Words, a comment and a permission prompt need Claude Code's prompt.
 * Refused in a finished session, whose asks wait on Lee no more; while the
 * window delivering the session runs a sitrep behind `version`, the CLI's;
 * and for an ask closed or ignored, or with another answer of Lee's on its
 * way already, since it takes no second answer. A comment on its way bars
 * none.
 */
export const checkAnswer = (session: Session, input: unknown, version?: string): Answer => {
  const fields = fieldsOf(input)
  const asked = askAnswered(session, fields, version)

  if (!asked.ok) {
    return asked
  }

  const ask = asked.value
  const broken = brokenBy(ANSWER_RULES, [ask])

  if (broken !== undefined) {
    return refuse(broken)
  }

  const given = line(fields.answer)

  return fields.ignore === true ? ignored(ask, given) : worded(ask, given)
}

/** What a snooze needs of each ask it names: open, and waiting on Lee as posted. */
const SNOOZE_RULES: readonly AskRule[] = [
  ...OPEN_RULES,
  [
    ask => replyOnItsWay(ask) !== undefined,
    ask => `Lee's reply to ${ask.id} is on its way: it waits on Lee no more.`,
  ],
  [
    ask => ask.state === 'replied',
    ask => `${ask.id} waits on Claude: Lee's comment is Claude's to act on.`,
  ],
]

/** What a wake needs of each ask it names: snoozed. */
const WAKE_RULES: readonly AskRule[] = [
  [ask => !isSnoozed(ask), ask => `${ask.id} is not snoozed.`],
]

const isRefusal = <T>(checked: Checked<T>): checked is { ok: false; error: string } => !checked.ok

/**
 * The asks a snooze or a wake names, by their ids, in a session not
 * finished, each an ask that keeps `rules`; or a refusal, the first that
 * applies saying why, whichever ask it is.
 */
const asksNamed = (session: Session, fields: Fields, rules: readonly AskRule[]): Checked<Ask[]> => {
  if (session.finished !== undefined) {
    return refuse(FINISHED)
  }

  const named = (lines(fields.ask) ?? []).map(id => askIn(session, id))

  if (named.length === 0) {
    return refuse('Name the asks by their ids, as the board lists them.')
  }

  const refused = named.find(isRefusal)

  if (refused !== undefined) {
    return refused
  }

  const asks = named.flatMap(each => (each.ok ? [each.value] : []))
  const broken = brokenBy(rules, asks)

  return broken === undefined ? ok(asks) : refuse(broken)
}

/** When a snooze wakes, as given: whole milliseconds since the epoch, as a number or in digits, that a `Date` holds; undefined where it is no time. */
const timeIn = (value: unknown) => {
  const time = typeof value === 'string' && /^\d+$/.test(value.trim()) ? Number(value) : value

  return isTime(time) && Number.isInteger(time) ? time : undefined
}

/**
 * Lee's snooze of asks of the session until a time, a line for each, as the
 * CLI and the pane give it: every ask named takes it, or none does. Each is
 * open and waits on Lee as posted, with no reply of Lee's on its way to it
 * nor a comment of Lee's for Claude to act on; one snoozed already is
 * snoozed again, to the new time, which is still to come at `now`.
 */
export const checkSnooze = (
  session: Session,
  input: unknown,
  now: number,
): Checked<SnoozeBody[]> => {
  const fields = fieldsOf(input)
  const asks = asksNamed(session, fields, SNOOZE_RULES)

  if (!asks.ok) {
    return asks
  }

  const until = timeIn(fields.until)

  if (until === undefined) {
    return refuse('A snooze needs its time: --until, in milliseconds since the epoch.')
  }

  return until > now
    ? ok(asks.value.map((ask): SnoozeBody => ({ type: 'snooze', item: ask.id, until })))
    : refuse('That time has come already: give one still to come.')
}

/** Lee's waking of snoozed asks of the session now, a line for each: every ask named is snoozed, or none is woken. */
export const checkWake = (session: Session, input: unknown): Checked<WakeBody[]> => {
  const asks = asksNamed(session, fieldsOf(input), WAKE_RULES)

  return asks.ok ? ok(asks.value.map((ask): WakeBody => ({ type: 'wake', item: ask.id }))) : asks
}
