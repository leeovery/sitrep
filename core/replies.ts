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
  Body,
  DeliveredBody,
  Delivery,
  Item,
  Parked,
  Reply,
  ReplyBody,
  Verdict,
  Work,
} from './types'

/** What a reply says, whatever it is written as. */
export type ReplyFields = Pick<ReplyBody, 'item' | 'verdict' | 'option' | 'note'>

/** The verdicts each item takes, as its buttons offer them. */
export const VERDICTS: Record<AskKind | 'park', readonly Verdict[]> = {
  review: ['yes', 'comment', 'ignore'],
  decide: ['choose', 'comment', 'ignore'],
  try: ['yes', 'comment', 'ignore'],
  do: ['yes', 'comment', 'ignore'],
  park: ['pickup'],
}

/** What a yes says, by the kind of ask it answers: its button's word. A decide ask offers no yes, so its word is never read. */
const YES: Record<AskKind, string> = {
  review: 'approved',
  decide: 'approved',
  try: 'it works',
  do: 'done',
}

/** A pick-up, in the board's words. */
const PICK_UP = 'pick it up'

/** What opens Lee's message carrying replies. */
export const FROM_THE_BOARD = 'From the board:'

/** Whether a reply fits its item: a verdict the item offers, with the option or comment that verdict needs. */
export const fits = (item: Item, reply: ReplyFields): item is Ask | Parked =>
  item.type !== 'note' &&
  VERDICTS[item.type === 'ask' ? item.kind : 'park'].includes(reply.verdict) &&
  (reply.verdict !== 'choose' || Boolean(reply.option)) &&
  (reply.verdict !== 'comment' || Boolean(reply.note))

export const isOpen = (ask: Ask) => ask.state === 'waiting' || ask.state === 'replied'

/** Whether a reply is on its way: neither delivered, nor void since its item changed under it. */
export const isPending = (reply: Reply) =>
  reply.delivery === 'waiting' || reply.delivery === 'closed'

/** Whether a verdict closes an ask of its kind once delivered: a yes, a choice, or an answer to a decide. */
const isClosing = (kind: AskKind, verdict: Verdict) =>
  verdict !== 'ignore' && (verdict !== 'comment' || kind === 'decide')

/**
 * Where a delivered reply leaves an ask. Ignore drops it; a comment on a
 * review, try or do leaves it with Claude to act on; a yes, a choice or an
 * answer closes it. An ask already closed stays as it is: only Claude
 * reopens one.
 */
export const askAfter = (ask: Ask, verdict: Verdict): AskState => {
  if (!isOpen(ask)) {
    return ask.state
  }

  if (verdict === 'ignore') {
    return 'ignored'
  }

  return isClosing(ask.kind, verdict) ? 'closed' : 'replied'
}

/** The reply that closed an ask, where Lee's answer closed it; undefined where Claude's resolve did. */
export const closingReply = (ask: Ask) =>
  ask.state === 'closed' && ask.answer !== undefined && isClosing(ask.kind, ask.answer.verdict)
    ? ask.answer
    : undefined

/** Where a delivered reply leaves a parked item: a pick-up picks it up. */
export const parkedAfter = (parked: Parked, verdict: Verdict): Parked['state'] =>
  parked.state === 'parked' && verdict === 'pickup' ? 'picked' : parked.state

const quoted = (note: string) => `“${note}”`

const withComment = (note: string | undefined) =>
  note === undefined || note === '' ? '' : `, with a comment: ${quoted(note)}`

/** A reply to an ask in a few words, bare of any arrow. */
const words = (kind: AskKind, { verdict, option, note }: ReplyFields): string => {
  switch (verdict) {
    case 'yes':
      return `${YES[kind]}${withComment(note)}`
    case 'choose':
      return `${option ?? ''}${withComment(note)}`
    case 'comment':
      return `${kind === 'decide' ? 'answer' : 'comment'}: ${quoted(note ?? '')}`
    case 'ignore':
      return 'ignored'
    case 'pickup':
      return PICK_UP
  }
}

/** A reply in a few words, as the board shows it under its item: a choice after an arrow. */
export const answerOf = (item: Ask | Parked, reply: ReplyFields) => {
  if (item.type === 'park') {
    return PICK_UP
  }

  const answer = words(item.kind, reply)

  return reply.verdict === 'choose' ? `→ ${answer}` : answer
}

/** A reply as a line of Lee's message: the item's title and the answer, no ids, since Lee sends it as their own. */
export const replyLine = (item: Ask | Parked, reply: ReplyFields) =>
  item.type === 'park'
    ? `- Pick up from parked: ${item.title}${reply.note ? `. ${reply.note}` : ''}`
    : `- ${item.title} → ${words(item.kind, reply)}`

/** The log line a delivered pick-up earns: what was picked up, and Lee's note with it. */
export const pickUpLog = (parked: Parked, reply: ReplyFields) => ({
  text: `Picked up from parked: ${parked.title}`,
  detail: reply.note ? [reply.note] : [],
})

/** Lee's message carrying replies to a work's items, and the replies it carries: those that fit an item the work has; undefined when none does. */
export const boardMessage = <R extends ReplyFields>(work: Work, replies: readonly R[]) => {
  const carried = replies.flatMap(reply => {
    const item = work.items.get(reply.item)

    return item !== undefined && fits(item, reply) ? [{ reply, line: replyLine(item, reply) }] : []
  })

  return carried.length === 0
    ? undefined
    : {
        text: [FROM_THE_BOARD, ...carried.map(({ line }) => line)].join('\n'),
        replies: carried.map(({ reply }) => reply),
      }
}

/** The replies a window submits now: every one on its way when it is the work's deliverer, else none. */
export const toDeliver = (work: Work, writer: string) =>
  work.deliverer === writer ? work.replies.filter(isPending) : []

const isDelivered = (work: Work, id: string) =>
  work.replies.some(reply => reply.id === id && reply.delivery === 'delivered')

/**
 * The lines recording Lee's replies to the work's own items once Claude
 * Code has taken the message carrying them: each reply, and the mark naming
 * them. None once their ids are written, so recording twice (a reload cut
 * the first short) writes once.
 */
export const sentLines = (work: Work, replies: readonly ReplyBody[]): Body[] =>
  replies.every(reply => work.ids.has(reply.id))
    ? []
    : [...replies, { type: 'delivered', replies: replies.map(reply => reply.id) }]

/** The mark that Claude has these inbox replies, naming those not marked yet; none once every one is. */
export const deliveredMark = (work: Work, ids: readonly string[]): DeliveredBody[] => {
  const unmarked = ids.filter(id => !isDelivered(work, id))

  return unmarked.length === 0 ? [] : [{ type: 'delivered', replies: unmarked }]
}

/**
 * Where replies sent into a work's inbox stand, by their ids: waiting for
 * its window's turn to end while any is on its way, or with no window open
 * for one to join; else delivered, unless every one went void. A reply the
 * fold has not read yet is on its way.
 */
export const deliveryOf = (work: Work, ids: readonly string[]): Delivery => {
  const sent = ids.map(id => work.replies.find(reply => reply.id === id))

  if (sent.some(reply => reply === undefined || isPending(reply))) {
    return work.isOpen ? 'waiting' : 'closed'
  }

  return sent.some(reply => reply?.delivery === 'delivered') ? 'delivered' : 'void'
}
