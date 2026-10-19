/**
 * Ready to send: Lee's replies waiting on the board, one to an item, until
 * a send carries them. Each names the session it answers and the project
 * that session is filed under, so it waits for that session whichever one
 * the window holds, and a send knows where to write it.
 *
 * The held session's replies a send carries stay in the queue, frozen, until
 * Claude Code has taken the message. Replies a send wrote into another
 * session's inbox have left the queue: sent, not yet delivered. Ready to send
 * shows where they went until Claude has them, and a while after.
 */
import {
  deliveryOf,
  fits,
  newItemId,
  type Ask,
  type Parked,
  type Reply,
  type ReplyBody,
  type Session,
} from '../core'
import type { SitrepInFlight, SitrepQueued, SitrepSent, SitrepSessionRef } from '../types'
import { random } from './host'

type Queue = readonly SitrepQueued[]

/** How long Ready to send shows where replies went once Claude has them all, so `delivered 2m ago` can be read. */
export const SENT_LINGER_MS = 10 * 60_000

const isFor = (reply: SitrepQueued, session: string, item: string) =>
  reply.session === session && reply.item === item

/** The queue with `reply` in place of any reply its item had, else at its end. */
export const queuing = (queue: Queue, reply: SitrepQueued) =>
  queue.some(each => isFor(each, reply.session, reply.item))
    ? queue.map(each => (isFor(each, reply.session, reply.item) ? reply : each))
    : [...queue, reply]

/** The queue less the reply to one item. */
export const unqueuing = (queue: Queue, session: string, item: string) =>
  queue.filter(each => !isFor(each, session, item))

/** Whether a queued reply is one Lee's send in flight carries: frozen until Claude Code takes it. */
export const isCarried = (inFlight: SitrepInFlight | null, reply: SitrepQueued) =>
  inFlight?.source === 'send' &&
  inFlight.session === reply.session &&
  inFlight.replies.some(each => each.item === reply.item)

/** The queue less every reply but those a send in flight carries. */
export const clearing = (queue: Queue, inFlight: SitrepInFlight | null) =>
  queue.filter(each => isCarried(inFlight, each))

/** The queue less the replies a send carried. */
export const afterSend = (queue: Queue, replies: Queue) =>
  queue.filter(each => !replies.some(reply => isFor(each, reply.session, reply.item)))

/** The queue with replies taken from it put back, each whose item has had no other queued since. */
export const restoring = (queue: Queue, replies: Queue) => [
  ...queue,
  ...replies.filter(reply => queuedOn(queue, reply.session, reply.item) === undefined),
]

/** The replies waiting for a session, in the order queued. */
export const queuedFor = (queue: Queue, session: string) =>
  queue.filter(each => each.session === session)

/** The reply waiting on an item, if one is. */
export const queuedOn = (queue: Queue, session: string, item: string) =>
  queue.find(each => isFor(each, session, item))

/** Each session these replies go to, once, in the order first queued. */
export const destinations = (replies: readonly SitrepSessionRef[]): SitrepSessionRef[] => [
  ...new Map(replies.map(({ project, session }) => [session, { project, session }])).values(),
]

/** The ask or parked item a reply answers, as the session has it. */
export const answered = (session: Session, reply: SitrepQueued): Ask | Parked | undefined => {
  const item = session.items.get(reply.item)

  return item !== undefined && fits(item, reply) ? item : undefined
}

/** A session's replies that still fit their items: what a send carries. */
export const sendable = (session: Session, queue: Queue) =>
  queuedFor(queue, session.id).filter(reply => answered(session, reply) !== undefined)

/** The replies as lines of the session, each with an id unlike any the session uses. */
export const replyBodies = (session: Session, replies: Queue): ReplyBody[] => {
  const taken = new Set(session.ids)

  return replies.map(({ item, verdict, option, note }) => {
    const id = newItemId(random, taken)

    taken.add(id)

    return { type: 'reply', id, item, verdict, option, note }
  })
}

/** Where replies went, with more sent to one of those sessions added to its entry. */
export const withSent = (list: readonly SitrepSent[], to: SitrepSessionRef, replies: string[]) => {
  const earlier = list.find(each => each.session === to.session)?.replies ?? []

  return [
    ...list.filter(each => each.session !== to.session),
    { project: to.project, session: to.session, replies: [...earlier, ...replies] },
  ]
}

/** The replies sent to a session, as its fold has them: one it has not read yet is left out. */
export const sentIn = (session: Session, sent: SitrepSent): Reply[] =>
  sent.replies.flatMap(id => session.replies.find(reply => reply.id === id) ?? [])

/** Whether these replies have all gone where they go: to Claude, or void since their items changed. */
const isSettled = (session: Session, sent: SitrepSent) => {
  const delivery = deliveryOf(session, sent.replies)

  return delivery === 'delivered' || delivery === 'void'
}

/** Whether Ready to send still shows where these replies went: until each is delivered or void, and `SENT_LINGER_MS` after. */
export const isShowing = (session: Session, sent: SitrepSent, now: number) => {
  if (!isSettled(session, sent)) {
    return true
  }

  const last = Math.max(
    ...sentIn(session, sent).map(reply => reply.deliveredAt ?? reply.voidedAt ?? 0),
  )

  return now - last < SENT_LINGER_MS
}
