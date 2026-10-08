/**
 * Ready to send: Lee's replies waiting on the board, one to an item, until
 * a send carries them. Each names the work it answers, so it waits for
 * that work whichever one the window holds.
 */
import { fits, type Ask, type Parked, type Work } from '../core'
import type { SitrepQueued } from '../types'

type Queue = readonly SitrepQueued[]

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

/** The queue less every reply to a work. */
export const clearing = (queue: Queue, work: string) => queue.filter(each => each.work !== work)

/** The queue less the replies a send carried. */
export const sent = (queue: Queue, replies: Queue) =>
  queue.filter(each => !replies.some(reply => isFor(each, reply.work, reply.item)))

/** Whether a reply is one a send is carrying. */
export const isSending = (sending: Queue, reply: SitrepQueued) =>
  sending.some(each => isFor(each, reply.work, reply.item))

/** The replies waiting for a work, in the order queued. */
export const queuedFor = (queue: Queue, work: string) => queue.filter(each => each.work === work)

/** The reply waiting on an item, if one is. */
export const queuedOn = (queue: Queue, work: string, item: string) =>
  queue.find(each => isFor(each, work, item))

/** The ask or parked item a reply answers, as the work has it. */
export const answered = (work: Work, reply: SitrepQueued): Ask | Parked | undefined => {
  const item = work.items.get(reply.item)

  return item !== undefined && fits(item, reply) ? item : undefined
}

/** A work's replies that still fit their items: what a send carries. */
export const sendable = (work: Work, queue: Queue) =>
  queuedFor(queue, work.id).filter(reply => answered(work, reply) !== undefined)
