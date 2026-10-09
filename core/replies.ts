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

/**
 * Whether a reply fits its item: a verdict the item offers, with the option
 * or comment that verdict needs. A yes or a choice fits without a note even
 * on an ask that needs one: a surface with no field to type in answers it
 * bare, and an edit giving an ask its `needs` voids no yes Lee gave.
 */
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

/** A note as it follows the words leading into it: on their line, or on the lines under them. */
type Quote = (note: string) => string

/** A note as the board shows it: quoted after its lead, a line break in it breaking the row there. */
const onTheBoard: Quote = note => ` ${quoted(note)}`

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

/** A note with a yes or a choice: what the ask needs back, where it says, else a comment. */
const withNote = (ask: Ask, note: string | undefined, quote: Quote) =>
  note === undefined || note === '' ? '' : `, with ${ask.needs ?? 'a comment'}:${quote(note)}`

/** A reply to an ask in a few words, bare of any arrow, its note put as `quote` puts it. */
const words = (ask: Ask, { verdict, option, note }: ReplyFields, quote: Quote): string => {
  switch (verdict) {
    case 'yes':
      return `${YES[ask.kind]}${withNote(ask, note, quote)}`
    case 'choose':
      return `${option ?? ''}${withNote(ask, note, quote)}`
    case 'comment':
      return `${ask.kind === 'decide' ? 'answer' : 'comment'}:${quote(note ?? '')}`
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

  const answer = words(item, reply, onTheBoard)

  return reply.verdict === 'choose' ? `→ ${answer}` : answer
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
