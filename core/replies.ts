/**
 * Lee's replies: which verdicts fit which item, what a delivered one does to
 * it, which window submits them, and the words Claude receives them in.
 *
 * A reply changes nothing until it is delivered: the board never claims
 * Claude knows something it was not told.
 */
import type { Ask, AskKind, AskState, Item, Parked, ReplyBody, Verdict, Work } from './types'

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

  return verdict === 'comment' && ask.kind !== 'decide' ? 'replied' : 'closed'
}

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

/** A reply as a line of Lee's message: the item's title and the answer, no ids, since Lee sends it as his own. */
export const replyLine = (item: Ask | Parked, reply: ReplyFields) =>
  item.type === 'park'
    ? `- Pick up from parked: ${item.title}${reply.note ? `. ${reply.note}` : ''}`
    : `- ${item.title} → ${words(item.kind, reply)}`

/** The log line a delivered pick-up earns: what was picked up, and Lee's note with it. */
export const pickUpLog = (parked: Parked, reply: ReplyFields) => ({
  text: `Picked up from parked: ${parked.title}`,
  detail: reply.note ? [reply.note] : [],
})

/** Lee's message carrying replies to a work's items; undefined when none fits an item the work has. */
export const boardMessage = (work: Work, replies: readonly ReplyFields[]) => {
  const lines = replies.flatMap(reply => {
    const item = work.items.get(reply.item)

    return item !== undefined && fits(item, reply) ? [replyLine(item, reply)] : []
  })

  return lines.length === 0 ? undefined : [FROM_THE_BOARD, ...lines].join('\n')
}

/** The replies a window submits now: every one undelivered when it is the work's deliverer, else none. */
export const toDeliver = (work: Work, writer: string) =>
  work.deliverer === writer ? work.replies.filter(reply => reply.delivery !== 'delivered') : []
