/**
 * Lee's replies: which verdicts fit which item, what a delivered one does to
 * it, which window submits them, the words Claude receives them in, and the
 * lines that record them once Claude has them.
 *
 * A reply changes nothing until it is delivered: the board never claims
 * Claude knows something it was not told.
 */
import type {
  Ask,
  AskKind,
  AskState,
  Barred,
  Body,
  DeliveredBody,
  Delivery,
  Item,
  Parked,
  Reply,
  ReplyBody,
  Verdict,
  Wants,
  Session,
} from './types'

/** What a reply says, whatever it is written as. */
export type ReplyFields = Pick<ReplyBody, 'item' | 'verdict' | 'option' | 'note'>

/** The verdicts each item takes, as its buttons offer them: by what an ask wants back. */
export const VERDICTS: Record<Wants | 'park', readonly Verdict[]> = {
  yes: ['yes', 'comment', 'ignore'],
  choice: ['choose', 'comment', 'ignore'],
  words: ['answer', 'ignore'],
  park: ['pickup'],
}

/** The verdicts an ask of a kind took, which replies written to it then keep: a decide's a choice's, the rest a yes's. */
const kindVerdicts = (kind: AskKind) => VERDICTS[kind === 'decide' ? 'choice' : 'yes']

/** The verdicts an item takes: an ask its shape's, and, read from its kind, the kind's too. */
const takenBy = (item: Ask | Parked) => {
  if (item.type === 'park') {
    return VERDICTS.park
  }

  return item.kind === undefined
    ? VERDICTS[item.wants]
    : [...VERDICTS[item.wants], ...kindVerdicts(item.kind)]
}

/** Whether an item takes a verdict at all, whatever goes with it. */
export const takes = (item: Ask | Parked, verdict: Verdict) => takenBy(item).includes(verdict)

/** The verdicts that carry words of Lee's, and fit only with some. */
const WORDED: readonly Verdict[] = ['answer', 'comment']

/** The verdicts that answer an ask whatever it was read from. */
const ANSWERS: readonly Verdict[] = ['yes', 'choose', 'answer', 'ignore']

/** A pick-up, in the board's words. */
const PICK_UP = 'pick it up'

/** What opens Lee's message carrying replies. */
export const FROM_THE_BOARD = 'From the board:'

/**
 * Whether a reply fits its item: a verdict the item offers, with the option
 * or the words that verdict needs. A yes or a choice fits with a comment as
 * its note, or without one.
 */
export const fits = (item: Item, reply: ReplyFields): item is Ask | Parked =>
  item.type !== 'note' &&
  takes(item, reply.verdict) &&
  (reply.verdict !== 'choose' || Boolean(reply.option)) &&
  (!WORDED.includes(reply.verdict) || Boolean(reply.note))

export const isOpen = (ask: Ask) => ask.state === 'waiting' || ask.state === 'replied'

/** A yes ask's yes, the button's words, as Lee gives it; a bare `yes` where its line gave none. */
export const yesOf = (ask: Pick<Ask, 'yes'>) => ask.yes ?? 'yes'

/** Whether a reply is on its way: neither delivered, nor void. */
export const isPending = (reply: Reply) =>
  reply.delivery === 'waiting' || reply.delivery === 'closed'

/**
 * Whether a verdict is Lee's answer to an item, which closes it once
 * delivered: a yes, a choice, an answer or an ignore to an ask, and a
 * comment to one read from its kind as a decide, whose comment was its
 * answer; a pick-up to a parked item. Any other comment leaves its ask open,
 * for Claude to act on.
 */
export const isAnswer = (item: Ask | Parked, verdict: Verdict) =>
  item.type === 'park'
    ? verdict === 'pickup'
    : ANSWERS.includes(verdict) || (verdict === 'comment' && item.kind === 'decide')

/** Where Lee's answer leaves an open ask: an ignore ignored, any other answer closed; a comment leaves it replied, Claude's to act on. */
export const askAfter = (ask: Ask, verdict: Verdict): AskState => {
  if (verdict === 'ignore') {
    return 'ignored'
  }

  return isAnswer(ask, verdict) ? 'closed' : 'replied'
}

/** The reply that closed an ask, where Lee's answer closed it. */
export const closingReply = (ask: Ask) => (ask.closedBy === 'answer' ? ask.answer : undefined)

/** The reply an item waits on Claude with, sent from a board into its session's inbox: Lee's answer, else the latest comment. */
export const replyOnItsWay = (item: Ask | Parked) =>
  item.answerOnItsWay ?? item.replies.findLast(isPending)

/** Why a closed item takes no reply: `answered` where Lee closed it, `resolved` where Claude did. */
export const closedReason = (item: Pick<Item, 'closedBy'>): Barred =>
  item.closedBy === 'claude' ? 'resolved' : 'answered'

/**
 * What keeps an item from taking a reply of Lee's with this verdict now;
 * undefined while it takes one. A closed item takes none; an open one, no
 * second answer while Lee's is on its way.
 */
export const barredBy = (item: Ask | Parked, verdict: Verdict): Barred | undefined => {
  if (item.closedBy !== undefined) {
    return closedReason(item)
  }

  return isAnswer(item, verdict) && item.answerOnItsWay !== undefined ? 'answered' : undefined
}

/**
 * Whether an ask waits on Lee: open as posted, with no reply of Lee's on
 * its way to it, an answer or a comment. One Lee replied to waits on a
 * window to deliver the reply, and counts nowhere as needing Lee.
 */
export const waitsOnLee = (ask: Ask) => ask.state === 'waiting' && replyOnItsWay(ask) === undefined

/** A session's asks waiting on Lee, the oldest first; none once it is finished. */
export const waitingOnLee = (session: Pick<Session, 'asks' | 'finished'>): Ask[] =>
  session.finished === undefined ? session.asks.filter(waitsOnLee) : []

/**
 * Where Lee's reply to an ask stands: on its way, in its session's inbox
 * until a window of the session delivers it; delivered, Claude having it;
 * or not delivered, Claude having closed the ask first. `since` is when it
 * was sent, delivered, or left.
 */
export type ReplyState = {
  is: 'onItsWay' | 'delivered' | 'notDelivered'
  reply: Reply
  since: number
}

/** When a reply last moved: delivered, gone void, or else sent. */
const movedAt = (reply: Reply) => reply.deliveredAt ?? reply.voidedAt ?? reply.at

const standing = (is: ReplyState['is'], reply: Reply | undefined): ReplyState | undefined =>
  reply === undefined ? undefined : { is, reply, since: movedAt(reply) }

/** Where Lee's reply to an ask stands, from those written since it last opened; on one still open, an answer Claude has may be one an edit left unfit. */
export const replyState = (ask: Ask): ReplyState | undefined => {
  if (ask.closedBy === 'answer' || ask.closedBy === 'ignore') {
    return standing('delivered', ask.answer)
  }

  const since = ask.replies.filter(reply => reply.at >= ask.openedAt)
  const had = standing(
    'delivered',
    since.findLast(reply => reply.deliveredAt !== undefined && isAnswer(ask, reply.verdict)),
  )
  const left = since.findLast(reply => reply.voided === 'resolved')

  if (ask.closedBy === 'claude') {
    return had ?? standing('notDelivered', left)
  }

  return standing('onItsWay', replyOnItsWay(ask)) ?? had
}

const quoted = (note: string) => `“${note}”`

/** A note's first line: all of it the board shows on its one row. */
const firstLine = (note: string) => note.split('\n', 1)[0] ?? ''

/** How many lines a reply's words run to past their first: what the board's one row of them leaves out. */
export const moreLines = ({ note }: Pick<ReplyFields, 'note'>) =>
  note === undefined ? 0 : note.split('\n').length - 1

/** A note as it follows the words leading into it: on their line, or on the lines under them. */
type Quote = (note: string) => string

/** A note as the board shows it, on one row: its first line, quoted after its lead. */
const onTheBoard: Quote = note => ` ${quoted(firstLine(note))}`

/** Backticks enough to fence a note: more than any run of them in it, so none of its lines closes the fence. */
const fenceFor = (note: string) =>
  '`'.repeat(Math.max(3, ...(note.match(/`+/g) ?? []).map(run => run.length + 1)))

/** A note of several lines, fenced and indented to sit under its reply's line, every line as typed. */
const fenced = (note: string) => {
  const fence = fenceFor(note)

  return [fence, ...note.split('\n'), fence].map(line => `  ${line}`).join('\n')
}

/** A note as Lee's message carries it: one line as `inLine` puts it on its lead's line; several fenced under it. */
const inMessage =
  (inLine: (note: string) => string): Quote =>
  note =>
    note.includes('\n') ? `\n${fenced(note)}` : ` ${inLine(note)}`

const IN_MESSAGE = inMessage(quoted)

/** A pick-up's note, said after its title as it is rather than quoted. */
const PICK_UP_NOTE = inMessage(note => note)

/** A note with a yes, a choice or a pick-up: a comment, or, on an ask read from its kind, what it needed back. */
const withNote = (note: string | undefined, quote: Quote, needs?: string) =>
  note === undefined || note === '' ? '' : `, with ${needs ?? 'a comment'}:${quote(note)}`

/** A reply to an ask in a few words, bare of any arrow, its note put as `quote` puts it. */
const words = (ask: Ask, { verdict, option, note }: ReplyFields, quote: Quote): string => {
  switch (verdict) {
    case 'yes':
      return `${yesOf(ask)}${withNote(note, quote, ask.needs)}`
    case 'choose':
      return `${option ?? ''}${withNote(note, quote, ask.needs)}`
    case 'answer':
      return `${ask.needs ?? 'answer'}:${quote(note ?? '')}`
    case 'comment':
      return `${isAnswer(ask, verdict) ? 'answer' : 'comment'}:${quote(note ?? '')}`
    case 'ignore':
      return 'ignored'
    case 'pickup':
      return PICK_UP
  }
}

/** The verdicts the board shows after an arrow: what Lee gave, in the ask's own words. */
const ARROWED: readonly Verdict[] = ['yes', 'choose']

/**
 * A reply in a few words on one row, as the board shows it under its item:
 * a yes in its label's words and a choice after an arrow, an answer as its
 * words, each note, a pick-up's too, by its first line.
 */
export const answerOf = (item: Ask | Parked, reply: ReplyFields) => {
  if (item.type === 'park') {
    return `${PICK_UP}${withNote(reply.note, onTheBoard)}`
  }

  if (reply.verdict === 'answer') {
    return quoted(firstLine(reply.note ?? ''))
  }

  const answer = words(item, reply, onTheBoard)

  return ARROWED.includes(reply.verdict) ? `→ ${answer}` : answer
}

/** A reply as Lee's message carries it: the item's title and the answer on a line, a note of several lines under it; no ids, since Lee sends it as their own. */
export const replyLine = (item: Ask | Parked, reply: ReplyFields) =>
  item.type === 'park'
    ? `- Pick up from parked: ${item.title}${reply.note ? `.${PICK_UP_NOTE(reply.note)}` : ''}`
    : `- ${item.title} → ${words(item, reply, IN_MESSAGE)}`

/** The log line a delivered pick-up earns: what was picked up, and Lee's note with it. */
export const pickUpLog = (parked: Parked, reply: ReplyFields) => ({
  text: `Picked up from parked: ${parked.title}`,
  detail: reply.note ? [reply.note] : [],
})

/** Lee's message carrying replies to a session's items, and the replies it carries: those that fit an item the session has; undefined when none does. */
export const boardMessage = <R extends ReplyFields>(session: Session, replies: readonly R[]) => {
  const carried = replies.flatMap(reply => {
    const item = session.items.get(reply.item)

    return item !== undefined && fits(item, reply) ? [{ reply, line: replyLine(item, reply) }] : []
  })

  return carried.length === 0
    ? undefined
    : {
        text: [FROM_THE_BOARD, ...carried.map(({ line }) => line)].join('\n'),
        replies: carried.map(({ reply }) => reply),
      }
}

/** The replies a window submits now: every one on its way when it is the session's deliverer, else none. */
export const toDeliver = (session: Session, writer: string) =>
  session.deliverer === writer ? session.replies.filter(isPending) : []

const isDelivered = (session: Session, id: string) =>
  session.replies.some(reply => reply.id === id && reply.delivery === 'delivered')

/**
 * The lines recording Lee's replies to the session's own items once Claude
 * Code has taken the message carrying them: each reply, and the mark naming
 * them. None once their ids are written, so recording twice (a reload cut
 * the first short) writes once.
 */
export const sentLines = (session: Session, replies: readonly ReplyBody[]): Body[] =>
  replies.every(reply => session.ids.has(reply.id))
    ? []
    : [...replies, { type: 'delivered', replies: replies.map(reply => reply.id) }]

/** The mark that Claude has these inbox replies, naming those not marked yet; none once every one is. */
export const deliveredMark = (session: Session, ids: readonly string[]): DeliveredBody[] => {
  const unmarked = ids.filter(id => !isDelivered(session, id))

  return unmarked.length === 0 ? [] : [{ type: 'delivered', replies: unmarked }]
}

/**
 * Where replies sent into a session's inbox stand, by their ids: waiting for
 * its window's turn to end while any is on its way, or with no window open
 * for one to join; else delivered, unless every one went void. A reply the
 * fold has not read yet is on its way.
 */
export const deliveryOf = (session: Session, ids: readonly string[]): Delivery => {
  const sent = ids.map(id => session.replies.find(reply => reply.id === id))

  if (sent.some(reply => reply === undefined || isPending(reply))) {
    return session.isOpen ? 'waiting' : 'closed'
  }

  return sent.some(reply => reply?.delivery === 'delivered') ? 'delivered' : 'void'
}
