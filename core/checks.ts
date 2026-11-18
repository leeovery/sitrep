/**
 * What Claude posts, checked and put right before it is written: each text
 * trimmed to one line, nothing empty where something is needed, and an ask
 * holding what its shape takes: a yes its button's words, a choice its
 * options and the one recommended, words what they are. A refusal says
 * what to fix, in words Claude can act on. Lee's answer to an ask from
 * outside Claude Code, as the CLI gives it, is checked here too, and Lee's
 * snooze and waking of a session, and his drop of a parked item.
 */
import { isTime } from './entries'
import { isSessionId, newItemId, type Random } from './ids'
import { directoryOf, isNameable, type Project } from './project'
import { offeredAs, readOptions, unmarked } from './recommended'
import { needsReload } from './release'
import { waitingOnLee, waitsOnLee, yesOf } from './replies'
import { turnEndOf } from './rows'
import { WANTS } from './shapes'
import type { StatusFields } from './status'
import { inWords, oneLine } from './text'
import {
  EDITABLE,
  type Ask,
  type AskBody,
  type Changes,
  type DropBody,
  type EditBody,
  type FinishBody,
  type Finisher,
  type MoveBody,
  type Item,
  type ParkBody,
  type Parked,
  type ReopenBody,
  type ReplyBody,
  type ResolveBody,
  type SnoozeSessionBody,
  type StatusBody,
  type WakeSessionBody,
  type Wants,
  type Session,
} from './types'
import { USER } from './user'

export type Checked<T> = { ok: true; value: T } | { ok: false; error: string }

type Fields = { [key: string]: unknown }

/** The fewest options a choice offers. */
const LEAST_OPTIONS = 2

/** The most characters a yes button's words take: a word or two, the verb Lee gives. */
const YES_MOST = 20

const STATUS_FIELDS = ['name', 'summary', 'now', 'next'] as const

const NOUNS: Record<Item['type'], string> = { ask: 'an ask', park: 'a parked item' }

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

/** A choice's options as given, as lines, each stripped of the markers typed in it, those that carried one, and those two became; undefined when not text. */
const optionsRead = (value: unknown) => {
  const given = lines(value)

  return given === undefined ? undefined : readOptions(given)
}

/** Each quoted, in plain words, the one recommended marked so: `“a” (recommended) or “b”`. */
const quotedOr = (answers: readonly string[], recommended?: string) =>
  inWords(
    answers.map(each => (each === recommended ? `“${each}” (recommended)` : `“${each}”`)),
    'or',
  )

const TWO_MARKED =
  'Recommend one option: more than one is marked recommended. Give the one you lean toward as recommended, and leave the word out of the options.'

/**
 * The option recommended, from the options a marker marked and the field
 * given: the field, else the one marked. Refused where they say different
 * things: two options marked, or one marked and the field naming another,
 * or clearing it.
 */
const recommendationOf = (
  marked: readonly string[],
  given: string | undefined,
): Checked<string | undefined> => {
  const [one, ...more] = marked

  if (more.length > 0) {
    return refuse(TWO_MARKED)
  }

  return one !== undefined && given !== undefined && given !== one
    ? refuse(
        `Recommend one option: “${one}” is marked recommended in the options, and recommended says otherwise.`,
      )
    : ok(given ?? one)
}

/** A recommended option as given, one line, the markers typed in it stripped; empty where it comes to nothing; undefined when not text. */
const recommendedIn = (value: unknown) => {
  const given = clearable(value)

  return given === undefined ? undefined : unmarked(given).text
}

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
type Shape = {
  wants: Wants
  yes?: string
  options: readonly string[]
  recommended?: string
  needs?: string
  /** The options two given ones became, once stripped of their markers. */
  collapsed?: readonly string[]
}

/** The fields of an ask's shape its rules read: what it wants back, and what goes with that. */
type ShapeField = 'wants' | 'yes' | 'options' | 'recommended' | 'needs'

/** Whether an edit changes a field of its ask's shape. */
const isChangedIn = (changes: Changes) => (field: ShapeField) => changes[field] !== undefined

/** What a shape must hold: each rule, the fields it reads, broken where it says, with what to fix. */
const SHAPE_RULES: readonly [
  reads: readonly ShapeField[],
  breaks: (shape: Shape) => boolean,
  error: string,
][] = [
  [
    ['wants', 'yes'],
    ({ wants, yes }) => wants === 'yes' && yes === undefined,
    `A yes ask needs yes: its button's words, the verb ${USER.name} gives, such as Go, Approve or It works.`,
  ],
  [
    ['wants', 'yes'],
    ({ wants, yes }) => wants !== 'yes' && yes !== undefined,
    'Only a yes ask takes yes.',
  ],
  [
    ['yes'],
    ({ yes }) => (yes?.length ?? 0) > YES_MOST,
    `A yes button's words are a word or two, ${YES_MOST} characters at most, such as Go or Ship it.`,
  ],
  [
    ['wants', 'options', 'recommended'],
    ({ wants, options }) => wants === 'choice' && options.length < LEAST_OPTIONS,
    `A choice ask needs at least ${LEAST_OPTIONS} options.`,
  ],
  [
    ['wants', 'options'],
    ({ wants, options }) => wants !== 'choice' && options.length > 0,
    'Only a choice ask takes options.',
  ],
  [
    ['wants', 'needs'],
    ({ wants, needs }) => wants !== 'words' && needs !== undefined,
    'Only a words ask takes needs: what its words are.',
  ],
]

/** Why a choice is left too few options by two of them becoming one once stripped of their markers, naming it; undefined where it is not. */
const collapsedMisfit = ({ wants, options, collapsed = [] }: Shape) =>
  wants === 'choice' && options.length < LEAST_OPTIONS && collapsed.length > 0
    ? `A choice ask needs at least ${LEAST_OPTIONS} options: ${quotedOr(collapsed)} is given twice, once marked recommended.`
    : undefined

/** Why the option a shape recommends will not do: on an ask that is no choice, or naming none of its options; undefined when it will. */
const recommendedMisfit = ({ wants, options, recommended }: Shape) => {
  if (recommended === undefined) {
    return undefined
  }

  if (wants !== 'choice') {
    return 'Only a choice ask takes recommended: one of its options.'
  }

  return offeredAs(options, recommended) !== undefined
    ? undefined
    : `recommended names one of the options, in its words: ${quotedOr(options)}.`
}

/**
 * Why a shape will not do, by the first rule it breaks that reads a field
 * `isJudged` picks, every rule unless told otherwise; undefined when it
 * will. The checks on two given options that became one, and on the
 * option recommended, judge always, as each reads only what is given.
 */
const misfitOf = (shape: Shape, isJudged: (field: ShapeField) => boolean = () => true) =>
  collapsedMisfit(shape) ??
  SHAPE_RULES.find(([reads, breaks]) => reads.some(isJudged) && breaks(shape))?.[2] ??
  recommendedMisfit(shape)

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
      `A session needs its project: its name as ${USER.name} would say it, such as SitRep or Switchboard.`,
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
    return refuse(
      `A project's name is one line, as ${USER.name} would say it, with a letter or a digit.`,
    )
  }

  if (!directory.ok) {
    return directory
  }

  return name === undefined && directory.value === undefined
    ? refuse('Give the project a new name, a directory, or both.')
    : ok({ name, directory: directory.value })
}

/** Where a session moves: its project's name, and its directory where a new project is made of it. */
export type MoveFields = { project: string; directory?: string }

/** A session moved to another project: named as Lee would say it, with its directory once known. */
export const checkMove = (input: unknown): Checked<MoveFields> => {
  const fields = fieldsOf(input)
  const project = projectNameOf(fields.project)
  const directory = directoryIn(fields.directory)

  if (project === undefined) {
    return refuse(
      `Name the project to move the session to: its name as ${USER.name} would say it, such as SitRep or Switchboard.`,
    )
  }

  return directory.ok ? ok({ project, directory: directory.value }) : directory
}

/** The line moving a session from the project `from` names, by key, to the project `to`; the project it is in already is refused. */
export const checkMoveTo = (
  session: Pick<Session, 'status'>,
  from: string,
  to: Pick<Project, 'key' | 'name'>,
): Checked<MoveBody> =>
  to.key === from
    ? refuse(`${session.status.name} is in ${to.name} already.`)
    : ok({ type: 'move', project: to.key })

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

  if (fields.recommended !== undefined && typeof fields.recommended !== 'string') {
    return refuse('recommended is text: one of the options, in its words.')
  }

  const read = optionsRead(fields.options) ?? { options: [], marked: [], collapsed: [] }
  const recommended = recommendationOf(read.marked, recommendedIn(fields.recommended) || undefined)

  if (!recommended.ok) {
    return recommended
  }

  const shape = {
    wants: fields.wants,
    yes: line(fields.yes),
    options: read.options,
    recommended: recommended.value,
    needs: line(fields.needs),
    collapsed: read.collapsed,
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
    recommended: shape.recommended,
    needs: shape.needs,
    ref: line(fields.ref),
  })
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

/**
 * A checked park given a fresh item id, unlike any its session uses, nor any
 * of what its project's other sessions parked (`around`): ids are unique
 * only within a session, and Claude's Parked lists the project's.
 */
export const withParkId = <T>(
  checked: Checked<T>,
  session: Pick<Session, 'ids'>,
  around: readonly Pick<Parked, 'id'>[],
  random: Random,
) => withId(checked, { ids: new Set([...session.ids, ...around.map(parked => parked.id)]) }, random)

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

/** Whether an item is open as it was posted: an ask waiting on Lee, an item still parked. */
const isFresh = (item: Item) => item.state === 'waiting' || item.state === 'parked'

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

/**
 * The item a line Claude writes into another session of its project names:
 * only a parked item, which is the project's, any session of it acting on
 * it; that session's asks are its own.
 */
export const checkParkedIn = (session: Session, input: unknown): Checked<Item> => {
  const item = target(session, fieldsOf(input))

  if (!item.ok || item.value.type === 'park') {
    return item
  }

  return refuse(
    `${item.value.id} is ${NOUNS[item.value.type]} of ${session.status.name}: of another session, only what it parked is yours to resolve, edit or reopen.`,
  )
}

export const checkResolve = (session: Session, input: unknown): Checked<ResolveBody> =>
  closeOrOpen('resolve', session, input)

/**
 * The item a resolve names where Lee closed it already: an ask by his yes,
 * choice, words or ignore, a parked item by his pick-up or his drop.
 * Resolving it changes nothing, and passes quietly rather than refused,
 * since the message carrying his reply may have read to Claude as leaving
 * it open, and a resolve written would put Claude's reason over Lee's
 * reply.
 * Undefined for any other resolve, which `checkResolve` decides.
 */
export const closedByLee = (session: Session, input: unknown): Ask | Parked | undefined => {
  const item = target(session, fieldsOf(input))

  return item.ok && item.value.closedBy !== undefined && item.value.closedBy !== 'claude'
    ? item.value
    : undefined
}

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
  options: value => optionsRead(value)?.options,
  recommended: recommendedIn,
  needs: clearable,
  ref: line,
}

/** The other name an edit gives an item's one line by, its title, whatever the item. */
const TEXT = 'text'

/** The names an edit gives fields by: each field's own, and its one line's other. */
const NAMES = [...Object.keys(READERS), TEXT]

/** The field an edit's name changes: its one line, by either name. */
const fieldOf = (name: string) => (name === TEXT ? 'title' : name) as keyof Changes

/** The fields an edit to an item changes, as a refusal lists them, its one line as title or text. */
const editableOf = (item: Item) =>
  EDITABLE[item.type].map(key => (key === 'title' ? 'title or text' : key)).join(', ')

/** Whether an edit gives its item's one line twice, as text and as title, each a line, in different words; an empty one is refused by its own name. */
const isTwoLines = (fields: Fields) => {
  const [text, title] = [line(fields.text), line(fields.title)]

  return text !== undefined && title !== undefined && text !== title
}

/** An edit's changes as read, or a refusal naming the first field that will not do, by the name Claude gave it. */
const changesFor = (item: Item, fields: Fields): Checked<Changes> => {
  const named = NAMES.filter(key => fields[key] !== undefined)
  const changes: Changes = {}

  if (named.length === 0) {
    return refuse(`An edit names a field to change: for ${NOUNS[item.type]}, ${editableOf(item)}.`)
  }

  if (isTwoLines(fields)) {
    return refuse(
      "An edit gives an item's one line as text or as title, not both with different words.",
    )
  }

  for (const key of named) {
    const field = fieldOf(key)

    if (!EDITABLE[item.type].includes(field)) {
      return refuse(`An edit to ${NOUNS[item.type]} changes ${editableOf(item)}; not ${key}.`)
    }

    const value = READERS[field](fields[key])

    if (value === undefined) {
      return refuse(`An edit cannot leave ${key} empty or of the wrong kind.`)
    }

    Object.assign(changes, { [field]: value })
  }

  return ok(changes)
}

/** What an edit leaves of a field: what it gives, an empty one clearing it, else what the ask had, where its shape keeps it. */
const kept = <T>(given: T | undefined, had: T | undefined, isKept: boolean) =>
  given === undefined ? (isKept ? had : undefined) : given || undefined

/** What an ask wants back once edited, and the options it then offers. */
const editedChoice = (ask: Ask, changes: Changes) => {
  const wants = changes.wants ?? ask.wants

  return { wants, options: kept(changes.options, ask.options, wants === 'choice') ?? [] }
}

/**
 * Why an ask, once edited, would not hold what its shape takes, judged by
 * what the edit changes: by each rule reading a field of the shape the edit
 * changes, so an edit to what the ask wants answers for the whole shape. A
 * rule the ask broke already, on fields the edit leaves alone, refuses
 * none of it: a decide written before asks had options takes a new title.
 * The checks on two given options that became one, and on the option
 * recommended, judge every edit, as each reads only what the edit gives.
 * Undefined when it would.
 */
const editedMisfit = (item: Item, changes: Changes, collapsed: readonly string[]) => {
  if (item.type !== 'ask') {
    return undefined
  }

  const { wants, options } = editedChoice(item, changes)

  return misfitOf(
    {
      wants,
      yes: kept(changes.yes, item.yes, wants === 'yes'),
      options,
      recommended: changes.recommended || undefined,
      needs: kept(changes.needs, item.needs, wants === 'words'),
      collapsed,
    },
    isChangedIn(changes),
  )
}

/**
 * An edit's changes with the option it recommends in the words the ask
 * offers it in: an option posted before markers were read may still carry
 * one, and is named without it.
 */
const offeredIn = (item: Item, changes: Changes): Changes => {
  if (item.type !== 'ask' || !changes.recommended) {
    return changes
  }

  const offered = offeredAs(editedChoice(item, changes).options, changes.recommended)

  return offered === undefined ? changes : { ...changes, recommended: offered }
}

/**
 * An edit's changes with the option its options mark recommended read as
 * its field: refused where two are marked, or one is and the edit's
 * recommended says otherwise.
 */
const markedIn = (changes: Changes, fields: Fields): Checked<Changes> => {
  const marked = optionsRead(fields.options)?.marked ?? []
  const recommended = recommendationOf(marked, changes.recommended)

  if (!recommended.ok) {
    return recommended
  }

  return ok(
    recommended.value === undefined ? changes : { ...changes, recommended: recommended.value },
  )
}

/**
 * The option an ask recommended that an edit leaves it without, though the
 * edit never named it: its option gone from the options, or the ask no
 * choice now. Undefined where the ask keeps it, the edit names it or
 * another, or it had none.
 */
export const droppedRecommendation = (session: Session, { item, changes }: EditBody) => {
  const ask = session.items.get(item)

  if (ask?.type !== 'ask' || ask.recommended === undefined || changes.recommended !== undefined) {
    return undefined
  }

  const wants = changes.wants ?? ask.wants
  const options = changes.options ?? ask.options ?? []

  return wants === 'choice' && offeredAs(options, ask.recommended) !== undefined
    ? undefined
    : ask.recommended
}

/** The fields whose change reshapes an ask: what it wants back, and what goes with that, not the option it recommends. */
const SHAPE_FIELDS: readonly ShapeField[] = ['wants', 'yes', 'options', 'needs']

/**
 * An edit's changes as written. One changing the shape of an ask still read
 * from its kind says what it wants back, so it reads by its shape from then
 * on; any other keeps the kind, so the replies written to it keep their
 * meaning.
 */
const written = (item: Item, changes: Changes): Changes =>
  item.type === 'ask' && item.kind !== undefined && SHAPE_FIELDS.some(isChangedIn(changes))
    ? { wants: item.wants, ...changes }
    : changes

export const checkEdit = (session: Session, input: unknown): Checked<EditBody> => {
  const fields = fieldsOf(input)
  const item = target(session, fields)

  if (!item.ok) {
    return item
  }

  const read = changesFor(item.value, fields)
  const marked = read.ok ? markedIn(read.value, fields) : read

  if (!marked.ok) {
    return marked
  }

  const changes = offeredIn(item.value, marked.value)
  const misfit = editedMisfit(item.value, changes, optionsRead(fields.options)?.collapsed ?? [])

  return misfit === undefined
    ? ok({
        type: 'edit',
        item: item.value.id,
        changes: written(item.value, changes),
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

/** Why Lee's drop of a parked item is refused once the item is off Parked, by how it left. */
const OFF_PARKED: Record<Exclude<Parked['state'], 'parked'>, string> = {
  picked: 'it was picked up already.',
  closed: 'Claude closed it already.',
  dropped: 'you dropped it already.',
}

/**
 * Lee's drop of an item the session parked, from the board: refused once it
 * is off Parked, and while his pick-up of it is on its way to Claude, who
 * would be told to pick up what the board no longer holds. A finished
 * session's item drops as any other.
 */
export const checkDrop = (session: Session, id: string): Checked<DropBody> => {
  const item = session.items.get(id)

  if (item?.type !== 'park') {
    return refuse('it is no longer on the board.')
  }

  if (item.state !== 'parked') {
    return refuse(OFF_PARKED[item.state])
  }

  return item.answerOnItsWay === undefined
    ? ok({ type: 'drop', item: id })
    : refuse('your pick-up of it is on its way to Claude.')
}

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

const FINISHED = 'This session is finished: its asks wait on you no more.'

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

  const answer = given === undefined ? undefined : offeredAs(answers, given)

  if (answer === undefined) {
    return refuse(
      `${ask.id} wants ${wanted}: answer it with ${quotedOr(answers, ask.recommended)}.`,
    )
  }

  return ok(
    ask.wants === 'yes'
      ? { type: 'reply', item: ask.id, verdict: 'yes' }
      : { type: 'reply', item: ask.id, verdict: 'choose', option: answer },
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
const isRefusal = <T>(checked: Checked<T>): checked is { ok: false; error: string } => !checked.ok

/** Why a snooze is refused where an ask waits on Lee that the row did not show: it came in since, and is never snoozed unseen. */
const UNSEEN = 'An ask waits on you that the snooze did not name: look at it, then snooze again.'

/**
 * Why the asks a snooze names, those its row showed, by their ids, will not
 * do: an id that is no item, or no ask; or an ask waiting on Lee, not
 * snoozed, that they leave out. Undefined while they do.
 */
const unshown = (session: Session, fields: Fields) => {
  const named = (lines(fields.ask) ?? []).map(id => askIn(session, id))
  const refused = named.find(isRefusal)

  if (refused !== undefined) {
    return refused.error
  }

  const ids = new Set(named.flatMap(each => (each.ok ? [each.value.id] : [])))

  return waitingOnLee(session).every(ask => ids.has(ask.id)) ? undefined : UNSEEN
}

/** Whether a session needs anything of Lee that a snooze puts off at `now`: an ask waiting on him, snoozed or not, or its turn. */
const needsLeeAt = (session: Session, now: number) =>
  session.asks.some(waitsOnLee) || turnEndOf(session, now) !== undefined

/** When a snooze wakes, as given: whole milliseconds since the epoch, as a number or in digits, that a `Date` holds; undefined where it is no time. */
const timeIn = (value: unknown) => {
  const time = typeof value === 'string' && /^\d+$/.test(value.trim()) ? Number(value) : value

  return isTime(time) && Number.isInteger(time) ? time : undefined
}

/**
 * Lee's snooze of the session until a time, as the app's row menu and the
 * pane give it: everything it needs of Lee, its asks waiting and its turn,
 * put off together. The asks named are those the row showed, so one that
 * came in since is never snoozed unseen. Refused in a finished session, and
 * in one needing nothing of Lee, a window's stops being its own; snoozed
 * already, it is snoozed again, to the new time, still to come at `now`.
 * With no time it holds until it moves, as the session's next turn ends.
 * The line holds the asks waiting on Lee as it is checked, snoozed or not:
 * one whose answer is on its way then is not his to put off.
 */
export const checkSnooze = (
  session: Session,
  input: unknown,
  now: number,
): Checked<SnoozeSessionBody> => {
  if (session.finished !== undefined) {
    return refuse(FINISHED)
  }

  const fields = fieldsOf(input)
  const unseen = unshown(session, fields)

  if (unseen !== undefined) {
    return refuse(unseen)
  }

  if (!needsLeeAt(session, now)) {
    return refuse(`${session.status.name} needs nothing of you: there is nothing to snooze.`)
  }

  const asks = session.asks.filter(waitsOnLee).map(ask => ask.id)

  if (fields.until === undefined) {
    return ok({ type: 'snoozeSession', asks })
  }

  const until = timeIn(fields.until)

  if (until === undefined) {
    return refuse(
      'A snooze wakes at a time in milliseconds since the epoch, or with none until it moves.',
    )
  }

  return until > now
    ? ok({ type: 'snoozeSession', until, asks })
    : refuse('That time has come already: give one still to come.')
}

/**
 * Lee's waking of the session now, whatever he snoozed of it: refused in a
 * finished session, and with no snooze of his standing. One run out at its
 * time, or an old line's of an ask, or of a turn the session has moved on
 * from, still stands until woken, so a Wake now pressed as its time comes
 * is never refused.
 */
export const checkWake = (session: Session): Checked<WakeSessionBody> => {
  if (session.finished !== undefined) {
    return refuse(FINISHED)
  }

  const isAsleep =
    session.snooze !== undefined ||
    session.turnSnooze !== undefined ||
    session.asks.some(ask => ask.snoozedUntil !== undefined || ask.wokeAt !== undefined)

  return isAsleep ? ok({ type: 'wakeSession' }) : refuse(`${session.status.name} is not snoozed.`)
}
