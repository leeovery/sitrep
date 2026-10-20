/**
 * Folding a session: every writer's lines, and the replies other sessions
 * left in its inbox, merged into one order (time, then writer, then the
 * writer's own count) and read into the board.
 */
import { parseEntries } from './entries'
import { parseMeta } from './meta'
import { unpaused, type Pause } from './pauses'
import { deliverer, isLive, parsePresence } from './presence'
import { parseProject, projectName } from './project'
import {
  askAfter,
  barredBy,
  fits,
  isAnswerable,
  isOpen,
  isPending,
  parkedAfter,
  pickUpLog,
  waitsOnLee,
} from './replies'
import { kindShape } from './shapes'
import { statusChange } from './status'
import { compareText } from './text'
import {
  EDITABLE,
  type Ask,
  type AskBody,
  type Body,
  type EditBody,
  type Entry,
  type Finished,
  type Item,
  type KindAskBody,
  type LogLine,
  type Note,
  type Parked,
  type Reply,
  type Status,
  type Session,
  type Voided,
} from './types'

/** A session's files as read: its session.json's text, and every other file's text by the writer its name gives. */
export type SessionFiles = {
  meta: string
  /** The project's project.json, which names the project; a folder from before projects were named has none. */
  project?: string
  /** `<writer>.jsonl`, by writer. */
  logs: Readonly<Record<string, string>>
  /** `inbox/<sender>.jsonl`, by sender. */
  inbox?: Readonly<Record<string, string>>
  /** `presence/<writer>.json`, by window. */
  presence?: Readonly<Record<string, string>>
}

/** An entry, and the writer whose file it came from. */
type Written = Entry & { by: string }

type Fold = {
  isOpen: boolean
  status: Status
  items: Map<string, Item>
  replies: Map<string, Reply>
  /** Delivered marks read before the reply they name, by reply. */
  early: Map<string, number>
  ids: Set<string>
  finished?: Finished
  /** Status and pick-up lines as derived, and notes, resolved to lines once the fold ends so edits show. */
  log: Array<LogLine | Note>
}

type Handler<T extends Body['type']> = (fold: Fold, entry: Extract<Written, { type: T }>) => void

const byName = <T>(files: Readonly<Record<string, T>>) =>
  Object.entries(files).sort(([a], [b]) => compareText(a, b))

const written = (files: Readonly<Record<string, string>>) =>
  byName(files).flatMap(([by, text]) =>
    parseEntries(text).map((entry): Written => ({ ...entry, by })),
  )

const inOrder = (a: Written, b: Written) => a.at - b.at || compareText(a.by, b.by) || a.seq - b.seq

/** Posts an item unless its id is taken: the first line to use an id keeps it. */
const post = (fold: Fold, item: Item) => {
  if (fold.items.has(item.id) || fold.replies.has(item.id)) {
    return false
  }

  fold.items.set(item.id, item)

  return true
}

const settleAsk = (ask: Ask, reply: Reply, at: number) => {
  if (isOpen(ask)) {
    ask.state = askAfter(ask, reply.verdict)
    ask.answer = reply
    ask.closedAt = isOpen(ask) ? undefined : at
  }
}

/** A pick-up marks its item picked up, and the board logs it: a line derived here, never written. */
const settleParked = (fold: Fold, parked: Parked, reply: Reply, at: number) => {
  if (parked.state !== 'parked') {
    return
  }

  parked.state = parkedAfter(parked, reply.verdict)
  parked.answer = reply

  if (parked.state === 'picked') {
    fold.log.push({ kind: 'pickup', at, by: reply.by, ...pickUpLog(parked, reply) })
  }
}

const settle = (fold: Fold, reply: Reply, at: number) => {
  const item = fold.items.get(reply.item)

  if (item?.type === 'ask') {
    settleAsk(item, reply, at)
  } else if (item?.type === 'park') {
    settleParked(fold, item, reply, at)
  }
}

/** Voids the replies on their way to an item that `isVoided` picks, saying why: none goes in from here. */
const voidOnItsWay = (
  item: Item,
  at: number,
  voided: Voided,
  isVoided: (reply: Reply) => boolean = () => true,
) => {
  if (item.type === 'note') {
    return
  }

  for (const reply of item.replies) {
    if (isPending(reply) && isVoided(reply)) {
      reply.delivery = 'void'
      reply.voided = voided
      reply.voidedAt = at
    }
  }
}

/**
 * Whether a delivered mark takes a reply in: one on its way; or one void
 * because its item took another answer first or Claude closed it, since a
 * window marks only what Claude has, and the message that carried it
 * crossed the other answer or the closing. One void since an edit stays
 * void: it fits its item no more, and the item can be answered again.
 */
const isMarkable = (reply: Reply) =>
  isPending(reply) || (reply.delivery === 'void' && reply.voided !== 'changed')

/** A reply Claude has: it settles its item, and once that closes, any other on its way to it goes nowhere. */
const deliver = (fold: Fold, reply: Reply, at: number) => {
  const item = fold.items.get(reply.item)

  reply.delivery = 'delivered'
  reply.deliveredAt = at
  reply.voided = undefined
  reply.voidedAt = undefined
  settle(fold, reply, at)

  if (item !== undefined && item.type !== 'note' && !isAnswerable(item)) {
    voidOnItsWay(item, at, 'answered')
  }
}

/** What an ask's line says it wants back: as it says, or, written by its kind, as the kind maps to. */
const wantsOf = (body: AskBody | KindAskBody): Pick<Ask, 'wants' | 'yes' | 'kind'> =>
  'wants' in body
    ? { wants: body.wants, yes: body.yes }
    : { kind: body.kind, ...kindShape(body.kind, body.needs) }

/**
 * An ask holding only what its shape takes: a yes its label, a choice its
 * options, words what they are. One read from its kind takes its shape from
 * the kind and what it needs back, as they stand, and keeps its yes's words.
 */
const fitShape = (ask: Ask) => {
  if (ask.kind !== undefined) {
    Object.assign(ask, kindShape(ask.kind, ask.needs))
  }

  ask.yes = ask.wants === 'yes' || ask.kind !== undefined ? ask.yes : undefined
  ask.options = ask.wants === 'choice' ? ask.options : undefined
  // An edit's empty `needs` clears it.
  ask.needs = ask.wants === 'words' ? ask.needs || undefined : undefined
}

/** An edit to an ask: one saying what it wants back reads it so from then on; one written before asks did may change its kind. */
const reshape = (ask: Ask, { wants, kind }: EditBody['changes']) => {
  if (wants !== undefined) {
    ask.kind = undefined
  } else if (kind !== undefined) {
    ask.kind = kind
  }

  fitShape(ask)
}

/**
 * Where a reply written at `at` starts out: on its way, waiting on the
 * session's window or for one to take the session up; or void where its
 * item takes no answer by then, another of Lee's on its way to it or
 * delivered, or the item closed. An item takes one answer, the first to
 * reach it: of two sent at once, as two runs of the CLI may, the first goes
 * in and the second never does, so Claude never has two answers to one item.
 */
const startOf = (
  fold: Fold,
  item: Ask | Parked,
  at: number,
): Pick<Reply, 'delivery' | 'voided' | 'voidedAt'> => {
  const barred = barredBy(item)

  return barred === undefined
    ? { delivery: fold.isOpen ? 'waiting' : 'closed' }
    : { delivery: 'void', voided: barred, voidedAt: at }
}

const reopen = (item: Item, at: number) => {
  item.openedAt = at
  item.closedAt = undefined

  if (item.type === 'ask') {
    item.state = 'waiting'
    item.answer = undefined
  } else if (item.type === 'park') {
    item.state = 'parked'
    item.answer = undefined
  } else {
    item.state = 'open'
  }
}

const HANDLERS: { [T in Body['type']]: Handler<T> } = {
  status: (fold, { name, summary, now, next, at, by }) => {
    const status = { name, summary, now, next, at, by }
    const change = statusChange(fold.status, status)

    if (change !== undefined) {
      fold.log.push({ kind: 'status', at, by, ...change })
    }

    fold.status = status
  },

  ask: (fold, entry) => {
    const { id, title, where, options, needs, ref, at, by } = entry
    const ask: Ask = {
      type: 'ask',
      id,
      ...wantsOf(entry),
      title,
      where,
      options,
      needs,
      ref,
      by,
      at,
      openedAt: at,
      state: 'waiting',
      replies: [],
    }

    fitShape(ask)
    post(fold, ask)
  },

  note: (fold, { id, text, detail, ref, at, by }) => {
    const note: Note = { type: 'note', id, text, detail, ref, by, at, openedAt: at, state: 'open' }

    if (post(fold, note)) {
      fold.log.push(note)
    }
  },

  park: (fold, { id, title, where, ref, at, by }) => {
    post(fold, {
      type: 'park',
      id,
      title,
      where,
      ref,
      by,
      at,
      openedAt: at,
      state: 'parked',
      replies: [],
    })
  },

  resolve: (fold, { item: id, reason, at }) => {
    const item = fold.items.get(id)

    if (item !== undefined) {
      item.state = 'closed'
      item.closedAt = at
      item.reason = reason
      voidOnItsWay(item, at, 'resolved')
    }
  },

  reopen: (fold, { item: id, reason, at }) => {
    const item = fold.items.get(id)

    if (item !== undefined) {
      reopen(item, at)
      item.reason = reason
    }
  },

  edit: (fold, { item: id, changes, reason, at }) => {
    const item = fold.items.get(id)

    if (item === undefined) {
      return
    }

    for (const key of EDITABLE[item.type]) {
      if (changes[key] !== undefined) {
        Object.assign(item, { [key]: changes[key] })
      }
    }

    if (item.type === 'ask') {
      reshape(item, changes)
    }

    item.editedAt = at
    item.reason = reason
    voidOnItsWay(item, at, 'changed', reply => !fits(item, reply))
  },

  reply: (fold, { id, item: target, verdict, option, note, at, by }) => {
    const item = fold.items.get(target)
    const fields = { item: target, verdict, option, note }

    if (fold.replies.has(id) || fold.items.has(id) || item === undefined || !fits(item, fields)) {
      return
    }

    const reply: Reply = { id, ...fields, by, at, ...startOf(fold, item, at) }
    const early = fold.early.get(id)

    fold.replies.set(id, reply)
    item.replies.push(reply)

    if (early !== undefined && isMarkable(reply)) {
      deliver(fold, reply, early)
    }
  },

  delivered: (fold, { replies, at }) => {
    for (const id of replies) {
      const reply = fold.replies.get(id)

      if (reply === undefined && !fold.early.has(id)) {
        fold.early.set(id, at)
      } else if (reply !== undefined && isMarkable(reply)) {
        deliver(fold, reply, at)
      }
    }
  },

  finish: (fold, { who, reason, at, by }) => {
    fold.finished = { at, by, who, reason }
  },

  unfinish: fold => {
    fold.finished = undefined
  },
}

const take = (fold: Fold, entry: Written) => {
  const handle = HANDLERS[entry.type] as Handler<Body['type']>

  if ('id' in entry) {
    fold.ids.add(entry.id)
  }

  handle(fold, entry as never)
}

const noteLine = ({ at, by, text, detail, ref, id }: Note): LogLine => ({
  kind: 'note',
  at,
  by,
  text,
  detail: detail ?? [],
  ref,
  id,
})

/** The log, newest first: status lines, and the notes not closed, as they read now. */
const logOf = (fold: Fold) =>
  fold.log
    .flatMap(line => {
      if (!('type' in line)) {
        return [line]
      }

      return line.state === 'open' ? [noteLine(line)] : []
    })
    .reverse()

const presenceOf = (files: Readonly<Record<string, string>>, pauses: readonly Pause[]) =>
  byName(files).flatMap(([writer, text]) => {
    const beat = parsePresence(text, writer)

    return beat === undefined ? [] : [unpaused(beat, pauses)]
  })

const isAsk = (item: Item): item is Ask => item.type === 'ask'
const isParked = (item: Item): item is Parked => item.type === 'park' && item.state === 'parked'

/**
 * A session as it stands at `now`; undefined when its session.json is
 * missing or bad. Only replies count from the inbox: a sender may answer
 * this session's items, never post to it. No heartbeat ages through
 * `pauses`, the time a reader that looks on and on was not running
 * (pauses.ts).
 */
export const foldSession = (
  files: SessionFiles,
  now: number,
  pauses: readonly Pause[] = [],
): Session | undefined => {
  const meta = parseMeta(files.meta)

  if (meta === undefined) {
    return undefined
  }

  const presence = presenceOf(files.presence ?? {}, pauses)
  const fold: Fold = {
    isOpen: presence.some(each => isLive(each, now)),
    status: { name: meta.name, summary: meta.summary, now: [], at: meta.created, by: meta.by },
    items: new Map(),
    replies: new Map(),
    early: new Map(),
    ids: new Set(),
    log: [],
  }
  const letters = written(files.inbox ?? {}).filter(entry => entry.type === 'reply')
  const entries = [...written(files.logs), ...letters].sort(inOrder)

  for (const entry of entries) {
    take(fold, entry)
  }

  const items = [...fold.items.values()]
  const asks = items.filter(isAsk)

  return {
    id: meta.id,
    project: projectName(parseProject(files.project ?? ''), meta.project),
    root: meta.root,
    created: meta.created,
    by: meta.by,
    status: fold.status,
    asks,
    parked: items.filter(isParked),
    items: fold.items,
    replies: [...fold.replies.values()],
    log: logOf(fold),
    presence,
    isOpen: fold.isOpen,
    deliverer: deliverer(presence, now),
    waiting: fold.finished === undefined ? asks.filter(waitsOnLee).length : 0,
    finished: fold.finished,
    ids: fold.ids,
    updatedAt: Math.max(meta.created, entries.at(-1)?.at ?? 0),
  }
}
