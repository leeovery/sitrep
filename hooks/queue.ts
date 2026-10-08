/**
 * Ready to send: Lee's replies waiting on the board, one to an item, until
 * a send carries them. Each names the work it answers and the project that
 * work is filed under, so it waits for that work whichever one the window
 * holds, and a send knows where to write it.
 *
 * Replies a send wrote into another work's inbox have left the queue: sent,
 * not yet delivered. Ready to send shows where they went until Claude has
 * them, and a while after.
 */
import {
  deliveryOf,
  fits,
  newItemId,
  type Ask,
  type Parked,
  type Reply,
  type ReplyBody,
  type Work,
} from '../core'
import type { SitrepQueued, SitrepSent, SitrepWorkRef } from '../types'
import { random } from './host'

type Queue = readonly SitrepQueued[]

/** How long Ready to send shows where replies went once Claude has them all, so `delivered 2m ago` can be read. */
export const SENT_LINGER_MS = 10 * 60_000

const isFor = (reply: SitrepQueued, work: string, item: string) =>
  reply.work === work && reply.item === item

/** The queue with `reply` at its end, in place of any reply its item had. */
export const queuing = (queue: Queue, reply: SitrepQueued) => [
  ...queue.filter(each => !isFor(each, reply.work, reply.item)),
  reply,
]

/** The queue less the reply to one item. */
export const unqueuing = (queue: Queue, work: string, item: string) =>
  queue.filter(each => !isFor(each, work, item))

/** The queue less every reply but those a send is carrying. */
export const clearing = (queue: Queue, sending: Queue) =>
  queue.filter(each => isSending(sending, each))

/** The queue less the replies a send carried. */
export const afterSend = (queue: Queue, replies: Queue) =>
  queue.filter(each => !replies.some(reply => isFor(each, reply.work, reply.item)))

/** Whether a reply is one a send is carrying. */
export const isSending = (sending: Queue, reply: SitrepQueued) =>
  sending.some(each => isFor(each, reply.work, reply.item))

/** The replies waiting for a work, in the order queued. */
export const queuedFor = (queue: Queue, work: string) => queue.filter(each => each.work === work)

/** The reply waiting on an item, if one is. */
export const queuedOn = (queue: Queue, work: string, item: string) =>
  queue.find(each => isFor(each, work, item))

/** Each work these replies go to, once, in the order first queued. */
export const destinations = (replies: readonly SitrepWorkRef[]): SitrepWorkRef[] => [
  ...new Map(replies.map(({ project, work }) => [work, { project, work }])).values(),
]

/** The ask or parked item a reply answers, as the work has it. */
export const answered = (work: Work, reply: SitrepQueued): Ask | Parked | undefined => {
  const item = work.items.get(reply.item)

  return item !== undefined && fits(item, reply) ? item : undefined
}

/** A work's replies that still fit their items: what a send carries. */
export const sendable = (work: Work, queue: Queue) =>
  queuedFor(queue, work.id).filter(reply => answered(work, reply) !== undefined)

/** The replies as lines of the work, each with an id unlike any the work uses. */
export const replyBodies = (work: Work, replies: Queue): ReplyBody[] => {
  const taken = new Set(work.ids)

  return replies.map(({ item, verdict, option, note }) => {
    const id = newItemId(random, taken)

    taken.add(id)

    return { type: 'reply', id, item, verdict, option, note }
  })
}

/** Where replies went, with more sent to one of those works added to its entry. */
export const withSent = (list: readonly SitrepSent[], to: SitrepWorkRef, replies: string[]) => {
  const earlier = list.find(each => each.work === to.work)?.replies ?? []

  return [
    ...list.filter(each => each.work !== to.work),
    { project: to.project, work: to.work, replies: [...earlier, ...replies] },
  ]
}

/** The replies sent to a work, as its fold has them: one it has not read yet is left out. */
export const sentIn = (work: Work, sent: SitrepSent): Reply[] =>
  sent.replies.flatMap(id => work.replies.find(reply => reply.id === id) ?? [])

/** Whether Ready to send still shows where these replies went: until Claude has them all, and `SENT_LINGER_MS` after. */
export const isShowing = (work: Work, sent: SitrepSent, now: number) => {
  if (deliveryOf(work, sent.replies) !== 'delivered') {
    return true
  }

  const last = Math.max(...sentIn(work, sent).map(reply => reply.deliveredAt ?? 0))

  return now - last < SENT_LINGER_MS
}
