/**
 * Folding a session: every writer's lines, the replies other sessions left
 * in its inbox, and those its live windows' messages in flight carry, not
 * written down yet, each dated at its claim, merged into one order (time,
 * then writer, then a writer's own file before its letters before its
 * messages in flight, then the count within each) and read into the board.
 */
import {
  endAskSnooze,
  newNeed,
  nothingAsleep,
  replied,
  snoozeAsk,
  snoozeSession,
  standAsleep,
  wakeAsk,
  wakeSession,
  type Asleep,
} from './asleep'
import { parseEntries } from './entries'
import { parseMeta } from './meta'
import { unpaused, type Pause } from './pauses'
import { deliverer, isLive, parsePresence } from './presence'
import { parseProject, projectName } from './project'
import { offeredAs } from './recommended'
import {
  askAfter,
  closedReason,
  fits,
  isAnswer,
  isHandedBack,
  isOpen,
  isPending,
  reaches,
  waitingOnLee,
  type ReplyFields,
} from './replies'
import { kindShape } from './shapes'
import { statusChange } from './status'
import { compareText } from './text'
import {
  EDITABLE,
  UNTIL_IT_MOVES,
  type Ask,
  type AskBody,
  type Body,
  type EditBody,
  type Entry,
  type Finished,
  type Item,
  type KindAskBody,
  type Parked,
  type Presence,
  type Reply,
  type SentReply,
  type Status,
  type Session,
  type StatusLine,
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

/** Where a writer's reads come from, in the order those of one moment are read: its own file, its letters in the inbox, then the replies its messages in flight carry. */
const FROM = { file: 0, letters: 1, sending: 2 } as const

type From = keyof typeof FROM

/** An entry, the writer whose file it came from, and whether that file is its own or its letters in the inbox. */
type Written = Entry & { by: string; from: Exclude<From, 'sending'> }

/** A reply a live window's message carries, not written down yet, read as a line of that window's dated at the claim. */
type Carried = {
  type: 'carried'
  at: number
  by: string
  from: 'sending'
  seq: number
  sent: SentReply
}

type Read = Written | Carried

type Fold = {
  /** The session's id. */
  id: string
  isOpen: boolean
  status: Status
  items: Map<string, Item>
  replies: Map<string, Reply>
  /** Delivered marks read before the reply they name, by reply. */
  early: Map<string, number>
  ids: Set<string>
  finished?: Finished
  /** The project the latest move names, by key. */
  movedTo?: string
  /** The status changes as derived, the oldest first. */
  history: StatusLine[]
  /** The replies carried in flight that reached their items on their way. */
  carried: Set<Reply>
  /** What Lee's snoozes hold, as the lines so far say. */
  asleep: Asleep
}

type Handler<T extends Body['type']> = (fold: Fold, entry: Extract<Written, { type: T }>) => void

const byName = <T>(files: Readonly<Record<string, T>>) =>
  Object.entries(files).sort(([a], [b]) => compareText(a, b))

const written = (files: Readonly<Record<string, string>>, from: Written['from']) =>
  byName(files).flatMap(([by, text]) =>
    parseEntries(text).map((entry): Written => ({ ...entry, by, from })),
  )

/** A writer's own file, its letters and its messages in flight count apart, so of its reads at one moment the file's come first, then the letters', whatever the counts. */
const inOrder = (a: Read, b: Read) =>
  a.at - b.at || compareText(a.by, b.by) || FROM[a.from] - FROM[b.from] || a.seq - b.seq

/** Posts an item unless its id is taken: the first line to use an id keeps it. */
const post = (fold: Fold, item: Item) => {
  if (fold.items.has(item.id) || fold.replies.has(item.id)) {
    return false
  }

  fold.items.set(item.id, item)

  return true
}

/** Lee's reply settles an ask still open, and ends his own snooze of it; one closing it says how, and leaves it no reason of Claude's. */
const settleAsk = (fold: Fold, ask: Ask, reply: Reply, at: number) => {
  if (ask.closedBy !== undefined) {
    return
  }

  ask.state = askAfter(ask, reply.verdict)
  ask.answer = reply
  endAskSnooze(fold.asleep, ask.id, at)

  if (!isOpen(ask)) {
    ask.closedAt = at
    ask.closedBy = reply.verdict === 'ignore' ? 'ignore' : 'answer'
    ask.reason = undefined
  }
}

/** A pick-up marks its item picked up. */
const settleParked = (parked: Parked, reply: Reply, at: number) => {
  if (parked.closedBy !== undefined) {
    return
  }

  parked.state = 'picked'
  parked.closedAt = at
  parked.closedBy = 'answer'
  parked.answer = reply
}

/** A reply on its way no more, delivered or void: its item's answer on its way no longer. */
const arrived = (item: Ask | Parked, reply: Reply) => {
  if (item.answerOnItsWay === reply) {
    item.answerOnItsWay = undefined
  }
}

/**
 * Whether a reply is one of the session's lines, which what the lines say
 * after it settles. A carried reply is no line yet: its line, once written,
 * is read after everything here, so no close, finish or edit read now voids
 * it, and nothing makes it history; only its place among the answers is
 * its claim's.
 */
const isLine = (fold: Fold, reply: Reply) => !fold.carried.has(reply)

/**
 * Why an item takes a reply no more, whatever else is on its way to it:
 * unfit; its session finished, no reply reaching it from the window holding
 * the session `held`, none for a line (`reaches`); or the item closed.
 */
const refusedBy = (
  fold: Fold,
  item: Ask | Parked,
  reply: ReplyFields,
  held?: string,
): Voided | undefined => {
  if (!fits(item, reply)) {
    return 'changed'
  }

  if (!reaches(held, { id: fold.id, isFinished: fold.finished !== undefined }, item)) {
    return 'finished'
  }

  return item.closedBy === undefined ? undefined : closedReason(item)
}

/** Whether a reply that fits its item answers it, and so is Lee's answer on its way there while nothing bars it. */
const isFittingAnswer = (item: Ask | Parked, reply: ReplyFields) =>
  fits(item, reply) && isAnswer(item, reply.verdict)

/** Why an answer is barred as it reaches its item: Lee's answer on its way there first. */
const barredByAnswer = (item: Ask | Parked, reply: ReplyFields): Voided | undefined =>
  isFittingAnswer(item, reply) && item.answerOnItsWay !== undefined ? 'answered' : undefined

/**
 * Why a reply is void as it reaches its item; undefined while it goes on its
 * way. A carried reply is judged here by its place among the answers alone;
 * whether its item takes it at all, once every line is read (`judgeCarried`).
 */
const voidedOnArrival = (fold: Fold, item: Ask | Parked, reply: Reply): Voided | undefined =>
  (isLine(fold, reply) ? refusedBy(fold, item, reply) : undefined) ?? barredByAnswer(item, reply)

/** A reply reaching its item at `at`, on its way or void as the item stands then: an answer on its way is Lee's answer on its way there. */
const arrive = (fold: Fold, item: Ask | Parked, reply: Reply, at: number) => {
  const voided = voidedOnArrival(fold, item, reply)

  if (voided !== undefined) {
    reply.delivery = 'void'
    reply.voided = voided
    reply.voidedAt = at

    return
  }

  reply.delivery = fold.isOpen ? 'waiting' : 'closed'
  reply.voided = undefined
  reply.voidedAt = undefined

  if (isFittingAnswer(item, reply)) {
    item.answerOnItsWay = reply
  }
}

/**
 * The answers `ahead`, Lee's answer on its way until now, barred, reaching
 * the item again, in order, as it stands now that it bars them no more. On
 * an open item a reply void `answered`, and not history, was barred by
 * that answer and nothing else: a delivered answer closes its item, and a
 * reopen makes history of every reply settled as it stood closed.
 */
const unbar = (fold: Fold, item: Ask | Parked, ahead: Reply, at: number) => {
  for (const reply of item.replies) {
    if (reply !== ahead && reply.voided === 'answered' && !reply.isHistory) {
      arrive(fold, item, reply, at)
    }
  }
}

/** Voids a reply not delivered; where it was Lee's answer on its way, what it barred reaches the item again, since it never goes in. */
const voidReply = (fold: Fold, item: Ask | Parked, reply: Reply, voided: Voided, at: number) => {
  const wasAhead = item.answerOnItsWay === reply

  reply.delivery = 'void'
  reply.voided = voided
  reply.voidedAt = at
  arrived(item, reply)

  if (wasAhead) {
    unbar(fold, item, reply, at)
  }
}

/**
 * An open item as an edit leaves it, the replies on their way reaching it
 * again in order: Lee's answer on its way is the first of them that is an
 * answer now, and bars the rest. One no longer the answer on its way, a
 * decide's comment once its ask wants a yes, bars nothing, and what it
 * barred reaches the item again.
 */
const reread = (fold: Fold, item: Ask | Parked, at: number) => {
  const ahead = item.answerOnItsWay

  item.answerOnItsWay = undefined

  for (const reply of item.replies) {
    if (isPending(reply)) {
      arrive(fold, item, reply, at)
    }
  }

  if (ahead !== undefined && item.answerOnItsWay !== ahead) {
    unbar(fold, item, ahead, at)
  }
}

/** Voids the replies on their way to an item that `isVoided` picks, saying why: none of them goes in from here. */
const voidOnItsWay = (
  fold: Fold,
  item: Ask | Parked,
  at: number,
  voided: Voided,
  isVoided: (reply: Reply) => boolean = () => true,
) => {
  for (const reply of item.replies) {
    if (isPending(reply) && isLine(fold, reply) && isVoided(reply)) {
      voidReply(fold, item, reply, voided, at)
    }
  }
}

/**
 * A reply Claude has, as a mark says, whatever else is true of it. One its
 * item changed under, or history, settles nothing, and stays as it was: the
 * item stands as it is now. Any other, one on its way across a reopen among
 * them, goes in as if never void, settling its item, and an answer voids
 * any other on its way there.
 */
const deliver = (fold: Fold, reply: Reply, at: number) => {
  const item = fold.items.get(reply.item)

  reply.delivery = 'delivered'
  reply.deliveredAt = at

  if (item === undefined) {
    return
  }

  arrived(item, reply)

  if (reply.voided === 'changed' || reply.isHistory) {
    return
  }

  reply.voided = undefined
  reply.voidedAt = undefined

  if (item.type === 'ask') {
    settleAsk(fold, item, reply, at)
  } else {
    settleParked(item, reply, at)
  }

  if (isAnswer(item, reply.verdict)) {
    voidOnItsWay(fold, item, at, 'answered', other => isAnswer(item, other.verdict))
  }
}

/** Voids every reply not delivered that fits its item no more, one void already among them, as an edit does. */
const voidUnfit = (fold: Fold, item: Ask | Parked, at: number) => {
  for (const reply of item.replies.filter(each => isLine(fold, each))) {
    if (reply.deliveredAt === undefined && reply.voided !== 'changed' && !fits(item, reply)) {
      voidReply(fold, item, reply, 'changed', at)
    }
  }
}

/** What an ask's line says it wants back: as it says, or, written by its kind, as the kind maps to. */
const wantsOf = (body: AskBody | KindAskBody): Pick<Ask, 'wants' | 'yes' | 'kind'> =>
  'wants' in body
    ? { wants: body.wants, yes: body.yes }
    : { kind: body.kind, ...kindShape(body.kind, body.needs) }

/**
 * An ask holding only what its shape takes: a yes its label, a choice its
 * options and the one recommended, while still among them, words what they
 * are. One read from its kind takes its shape from the kind and what it
 * needs back, as they stand, and keeps its yes's words.
 */
const fitShape = (ask: Ask) => {
  if (ask.kind !== undefined) {
    Object.assign(ask, kindShape(ask.kind, ask.needs))
  }

  ask.yes = ask.wants === 'yes' || ask.kind !== undefined ? ask.yes : undefined
  ask.options = ask.wants === 'choice' ? ask.options : undefined
  // An edit's empty `recommended` clears it, as one changing the options away from it does.
  ask.recommended =
    ask.recommended && ask.options ? offeredAs(ask.options, ask.recommended) : undefined
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

/** An item opening again, afresh, Lee's own snooze of an ask ended: where it stood closed, every reply then settled, void or delivered, is history from here; one on its way stays live. */
/** An ask waiting on Lee afresh, reopened or handed back: a new need, its time counting from `at`, his own snooze of it ended. */
const waitAfresh = (fold: Fold, ask: Ask, at: number) => {
  endAskSnooze(fold.asleep, ask.id, at)
  newNeed(fold.asleep, at)
  ask.openedAt = at
  ask.state = 'waiting'
}

const reopen = (fold: Fold, item: Item, at: number) => {
  if (item.closedBy !== undefined) {
    for (const reply of item.replies.filter(each => !isPending(each) && isLine(fold, each))) {
      reply.isHistory = true
    }
  }

  item.closedAt = undefined
  item.closedBy = undefined
  item.answer = undefined

  if (item.type === 'ask') {
    waitAfresh(fold, item, at)
  } else {
    item.openedAt = at
    item.state = 'parked'
  }
}

const HANDLERS: { [T in Body['type']]: Handler<T> } = {
  status: (fold, { name, summary, now, next, at, by }) => {
    const status = { name, summary, now, next, at, by }
    const change = statusChange(fold.status, status)

    if (change !== undefined) {
      fold.history.push({ at, by, ...change })
    }

    fold.status = status
  },

  ask: (fold, entry) => {
    const { id, title, where, options, recommended, needs, ref, at, by } = entry
    const ask: Ask = {
      type: 'ask',
      id,
      ...wantsOf(entry),
      title,
      where,
      options,
      recommended,
      needs,
      ref,
      by,
      at,
      openedAt: at,
      state: 'waiting',
      replies: [],
    }

    fitShape(ask)

    if (post(fold, ask)) {
      newNeed(fold.asleep, at)
    }
  },

  // A note's line from before notes went posts nothing: `take` keeps its id taken.
  note: () => {},

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

    if (item === undefined) {
      return
    }

    item.reason = reason
    endAskSnooze(fold.asleep, id, at)

    if (item.closedBy === undefined) {
      item.state = 'closed'
      item.closedAt = at
      item.closedBy = 'claude'
    }

    voidOnItsWay(fold, item, at, closedReason(item))
  },

  reopen: (fold, { item: id, reason, at }) => {
    const item = fold.items.get(id)

    if (item !== undefined) {
      reopen(fold, item, at)
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

      // It never closed, so nothing is history, and the comment stays its answer: what Lee said before.
      if (isHandedBack(item, changes)) {
        waitAfresh(fold, item, at)
      }
    }

    item.editedAt = at
    item.reason = reason
    voidUnfit(fold, item, at)

    if (item.closedBy === undefined) {
      reread(fold, item, at)
    }
  },

  reply: (fold, { id, item: target, verdict, option, note, to, at, by }) => {
    const item = fold.items.get(target)

    if (fold.replies.has(id) || fold.items.has(id) || item === undefined) {
      return
    }

    const reply: Reply = {
      id,
      item: target,
      verdict,
      option,
      note,
      to,
      by,
      at,
      delivery: 'waiting',
    }
    const early = fold.early.get(id)

    arrive(fold, item, reply, at)
    fold.replies.set(id, reply)
    item.replies.push(reply)

    replied(fold.asleep, item, at)

    if (early !== undefined) {
      deliver(fold, reply, early)
    }
  },

  delivered: (fold, { replies, at }) => {
    for (const id of replies) {
      const reply = fold.replies.get(id)

      if (reply === undefined && !fold.early.has(id)) {
        fold.early.set(id, at)
      } else if (reply !== undefined && reply.deliveredAt === undefined) {
        deliver(fold, reply, at)
      }
    }
  },

  drop: (fold, { item: id, at }) => {
    const item = fold.items.get(id)

    if (item?.type !== 'park' || item.closedBy !== undefined) {
      return
    }

    item.state = 'dropped'
    item.closedAt = at
    item.closedBy = 'drop'
    item.reason = undefined
    voidOnItsWay(fold, item, at, closedReason(item))
  },

  finish: (fold, { who, reason, at, by }) => {
    fold.finished = { at, by, who, reason }

    for (const item of fold.items.values()) {
      voidOnItsWay(fold, item, at, 'finished')
    }
  },

  unfinish: fold => {
    fold.finished = undefined
  },

  move: (fold, { project }) => {
    fold.movedTo = project
  },

  snoozeSession: (fold, { until, asks, at }) =>
    snoozeSession(fold.asleep, until ?? UNTIL_IT_MOVES, asks, at),

  wakeSession: fold => wakeSession(fold.asleep),

  snooze: (fold, { item: id, until, at }) => {
    const item = fold.items.get(id)

    if (item?.type === 'ask') {
      snoozeAsk(fold.asleep, item, until, fold.items.values(), at)
    }
  },

  wake: (fold, { item: id }) => wakeAsk(fold.asleep, id),

  snoozeTurn: (fold, { turn, until, at }) => {
    fold.asleep.turn = until === undefined ? { turn, at } : { turn, until, at }
  },

  wakeTurn: (fold, { turn }) => {
    if (fold.asleep.turn?.turn === turn) {
      fold.asleep.turn = undefined
    }
  },
}

/**
 * A reply a live window's message carries, taking its place among its
 * item's answers at its claim's time: on its way from the claim, as an
 * inbox reply is, so Lee's answer among them bars any later one, whatever
 * its source, and is barred by any earlier, until that one goes void.
 */
const carry = (fold: Fold, { sent, by, at }: Carried) => {
  const item = fold.items.get(sent.item)

  if (item === undefined) {
    return
  }

  const reply: Reply = { ...sent, by, at, delivery: 'waiting' }

  fold.carried.add(reply)
  item.replies.push(reply)
  arrive(fold, item, reply, at)
}

const take = (fold: Fold, entry: Read) => {
  if (entry.type === 'carried') {
    carry(fold, entry)

    return
  }

  const handle = HANDLERS[entry.type] as Handler<Body['type']>

  if ('id' in entry) {
    fold.ids.add(entry.id)
  }

  handle(fold, entry as never)
}

/**
 * The replies live windows' messages carry to the session, claimed and not
 * written down yet, each read as a line of its window's dated at its
 * message's claim. One whose line is written by now is that line, read once.
 * None is a reply of the session's own: no inbox delivers it, and its id is
 * no line's.
 */
const carriedIn = (presence: readonly Presence[], lines: readonly Written[], now: number) => {
  const ids = new Set(lines.flatMap(line => ('id' in line ? [line.id] : [])))

  const carried = ({ writer, sending = [] }: Presence): Carried[] =>
    sending
      .flatMap(({ at, replies }) => replies.map(sent => ({ at, sent })))
      .filter(({ sent }) => !ids.has(sent.id))
      .map(({ at, sent }, i) => ({
        type: 'carried',
        at,
        by: writer,
        from: 'sending',
        seq: i + 1,
        sent,
      }))

  return presence.filter(each => isLive(each, now)).flatMap(carried)
}

/**
 * Whether what barred a carried answer stands no more once every line is
 * read: nothing on its way to the item, and the item open, the answer that
 * barred it gone void, or delivered and its item reopened since.
 */
const isReleased = (item: Ask | Parked, reply: Reply) =>
  reply.voided === 'answered' && item.answerOnItsWay === undefined && item.closedBy === undefined

/** When what refused a carried reply happened: the session's finish, the item's last edit, or its close. */
const refusedAt = (fold: Fold, item: Ask | Parked, voided: Voided) => {
  switch (voided) {
    case 'finished':
      return fold.finished?.at
    case 'changed':
      return item.editedAt
    default:
      return item.closedAt
  }
}

/**
 * The carried replies judged once every line is read, against their items
 * as their lines will find them when written down, which is later than all
 * of it, in the order they took their places among the answers. One barred
 * by an answer that stands no more comes back. One still on its way that
 * its item takes no more goes void, and what it barred reaches the item
 * again, as of what refused it, to be judged in its turn; a finish voids
 * none, the window carrying it holding the session (`reaches`). A close or
 * an edit the lines have since undone leaves it on its way. Then
 * every carried reply void, barred or refused, leaves its item's replies:
 * no line of it is written yet to settle anything.
 */
const judgeCarried = (fold: Fold, item: Ask | Parked) => {
  for (const reply of item.replies.filter(each => !isLine(fold, each))) {
    if (isReleased(item, reply)) {
      arrive(fold, item, reply, reply.at)
    }

    // A carried reply is a live window's, read from its heartbeat in this session's own folder: the window holds this session.
    const refused = isPending(reply) ? refusedBy(fold, item, reply, fold.id) : undefined

    if (refused !== undefined) {
      voidReply(fold, item, reply, refused, refusedAt(fold, item, refused) ?? reply.at)
    }
  }

  item.replies = item.replies.filter(reply => isLine(fold, reply) || isPending(reply))
}

const presenceOf = (files: Readonly<Record<string, string>>, pauses: readonly Pause[]) =>
  byName(files).flatMap(([writer, text]) => {
    const beat = parsePresence(text, writer)

    return beat === undefined ? [] : [unpaused(beat, pauses)]
  })

const isAsk = (item: Item): item is Ask => item.type === 'ask'
const isParked = (item: Item): item is Parked => item.type === 'park' && item.state === 'parked'

/** Lee's snoozes and wakes of a session, an ask or a turn are never told to Claude, so they leave a session as recent as it was. */
const UNTOLD: ReadonlySet<Body['type']> = new Set([
  'snoozeSession',
  'wakeSession',
  'snooze',
  'wake',
  'snoozeTurn',
  'wakeTurn',
])

const isTold = (entry: Written) => !UNTOLD.has(entry.type)

/** Whether a reply the session has is a pick-up: one to a parked item. */
const isPickUp = (fold: Fold, id: string) => {
  const reply = fold.replies.get(id)

  return reply !== undefined && fold.items.get(reply.item)?.type === 'park'
}

/**
 * Whether a line is about parked items, judged by the item it names once
 * every line is read: one naming a parked item, or a mark whose every reply
 * is a pick-up; and a drop, whatever it names, since one naming anything
 * else changes nothing. Any other line naming an item or a reply the
 * session does not have is about none.
 */
const isAboutParked = (fold: Fold, entry: Written) => {
  if (entry.type === 'drop') {
    return true
  }

  if (entry.type === 'delivered') {
    return entry.replies.length > 0 && entry.replies.every(id => isPickUp(fold, id))
  }

  return 'item' in entry && fold.items.get(entry.item)?.type === 'park'
}

/** Whether a line moves the session's time: told to Claude, and about something but parked items, their parks aside, since a parked item is its project's. */
const movesTime = (fold: Fold, entry: Written) => isTold(entry) && !isAboutParked(fold, entry)

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
    id: meta.id,
    isOpen: presence.some(each => isLive(each, now)),
    status: { name: meta.name, summary: meta.summary, now: [], at: meta.created, by: meta.by },
    items: new Map(),
    replies: new Map(),
    early: new Map(),
    ids: new Set(),
    history: [],
    carried: new Set(),
    asleep: nothingAsleep(),
  }
  const letters = written(files.inbox ?? {}, 'letters').filter(entry => entry.type === 'reply')
  const lines = [...written(files.logs, 'file'), ...letters].sort(inOrder)

  for (const entry of [...lines, ...carriedIn(presence, lines, now)].sort(inOrder)) {
    take(fold, entry)
  }

  const updatedAt = Math.max(meta.created, lines.findLast(entry => movesTime(fold, entry))?.at ?? 0)

  const items = [...fold.items.values()]

  for (const item of items) {
    judgeCarried(fold, item)
  }

  const asks = items.filter(isAsk)
  const { snooze, asideUntil, turnSnooze, turnWithAsks } = standAsleep(fold.asleep, asks, now)

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
    history: fold.history.toReversed(),
    presence,
    isOpen: fold.isOpen,
    deliverer: deliverer(presence, now),
    waiting: waitingOnLee({ asks, finished: fold.finished }).length,
    finished: fold.finished,
    movedTo: fold.movedTo,
    snooze,
    asideUntil,
    turnSnooze,
    turnWithAsks,
    ids: fold.ids,
    updatedAt,
  }
}
