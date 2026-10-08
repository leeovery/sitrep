/**
 * Folding a piece of work: every writer's lines, and the replies other works
 * left in its inbox, merged into one order (time, then writer, then the
 * writer's own count) and read into the board.
 */
import { parseEntries } from './entries'
import { parseMeta } from './meta'
import { deliverer, isLive, parsePresence } from './presence'
import { askAfter, fits, isOpen, isPending, parkedAfter, pickUpLog } from './replies'
import { statusChange } from './status'
import { compareText } from './text'
import {
  EDITABLE,
  type Ask,
  type Body,
  type Entry,
  type Finished,
  type Item,
  type LogLine,
  type Note,
  type Parked,
  type Reply,
  type Status,
  type Work,
} from './types'

/** A work's files as read: work.json's text, and every other file's text by the writer its name gives. */
export type WorkFiles = {
  meta: string
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

const deliver = (fold: Fold, reply: Reply, at: number) => {
  reply.delivery = 'delivered'
  reply.deliveredAt = at
  settle(fold, reply, at)
}

/**
 * An edit voids the replies on their way to an item that they no longer fit:
 * a mark naming one later changes nothing, and the item can be answered again.
 */
const voidUnfitting = (item: Item, at: number) => {
  if (item.type === 'note') {
    return
  }

  for (const reply of item.replies) {
    if (isPending(reply) && !fits(item, reply)) {
      reply.delivery = 'void'
      reply.voidedAt = at
    }
  }
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

  ask: (fold, { id, kind, title, where, options, ref, at, by }) => {
    post(fold, {
      type: 'ask',
      id,
      kind,
      title,
      where,
      options,
      ref,
      by,
      at,
      openedAt: at,
      state: 'waiting',
      replies: [],
    })
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

    if (item.type === 'ask' && item.kind !== 'decide') {
      item.options = undefined
    }

    item.editedAt = at
    item.reason = reason
    voidUnfitting(item, at)
  },

  reply: (fold, { id, item: target, verdict, option, note, at, by }) => {
    const item = fold.items.get(target)
    const fields = { item: target, verdict, option, note }

    if (fold.replies.has(id) || fold.items.has(id) || item === undefined || !fits(item, fields)) {
      return
    }

    const reply: Reply = { id, ...fields, by, at, delivery: fold.isOpen ? 'waiting' : 'closed' }
    const early = fold.early.get(id)

    fold.replies.set(id, reply)
    item.replies.push(reply)

    if (early !== undefined) {
      deliver(fold, reply, early)
    }
  },

  delivered: (fold, { replies, at }) => {
    for (const id of replies) {
      const reply = fold.replies.get(id)

      if (reply === undefined && !fold.early.has(id)) {
        fold.early.set(id, at)
      } else if (reply !== undefined && isPending(reply)) {
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

const presenceOf = (files: Readonly<Record<string, string>>) =>
  byName(files).flatMap(([writer, text]) => parsePresence(text, writer) ?? [])

const isAsk = (item: Item): item is Ask => item.type === 'ask'
const isParked = (item: Item): item is Parked => item.type === 'park' && item.state === 'parked'

/**
 * A piece of work as it stands at `now`; undefined when its work.json is
 * missing or bad. Only replies count from the inbox: a sender may answer
 * this work's items, never post to it.
 */
export const foldWork = (files: WorkFiles, now: number): Work | undefined => {
  const meta = parseMeta(files.meta)

  if (meta === undefined) {
    return undefined
  }

  const presence = presenceOf(files.presence ?? {})
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
    project: meta.project,
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
    waiting: fold.finished === undefined ? asks.filter(ask => ask.state === 'waiting').length : 0,
    finished: fold.finished,
    ids: fold.ids,
    updatedAt: Math.max(meta.created, entries.at(-1)?.at ?? 0),
  }
}
