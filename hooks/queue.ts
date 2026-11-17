/**
 * Ready to send: Lee's replies waiting on the board, one to an item, until
 * a send carries them. Each names the session it answers and the project
 * that session is filed under, so it waits for that session whichever one
 * the window holds, and a send knows where to write it. A pick-up goes to
 * the held session, whichever session of its project parked the item: its
 * claim names the item by its address, and it is written down in the
 * session that parked it.
 *
 * The held session's replies a send carries stay in the queue, frozen, until
 * Claude Code has taken the message, or Lee takes the send back while the
 * window holds it, which leaves them as they were, among the rest in the
 * order queued. Those no send carries are the queue Lee still sends: one
 * queued while a send waits for Claude's turn goes in a send of its own.
 * Replies a send wrote into another session's inbox have left the queue:
 * sent, not yet delivered. Ready to send shows where they went until Claude
 * has them, and a while after.
 */
import {
  barredBy,
  deliveryOf,
  fits,
  newItemId,
  reaches,
  type Ask,
  type Barred,
  type Parked,
  type Random,
  type Reply,
  type ReplyBody,
  type Session,
} from '../core'
import type {
  SitrepInFlight,
  SitrepItemRef,
  SitrepQueued,
  SitrepSent,
  SitrepSessionRef,
} from '../types'
import { random } from './host'
import { addressed, canReach, itemKey } from './places'
import type { Scene } from './scene'

type Queue = readonly SitrepQueued[]

/** The sessions replies answer items of, by id, as read now. */
export type Folded = ReadonlyMap<string, Session>

/** How long Ready to send shows where replies went once Claude has them all, so `delivered 2m ago` can be read. */
export const SENT_LINGER_MS = 10 * 60_000

const isFor = (reply: Pick<SitrepQueued, 'session' | 'item'>, session: string, item: string) =>
  reply.session === session && reply.item === item

/**
 * The session a queued reply goes to from a window holding `held`: a
 * pick-up to the held session, whichever session of its project parked the
 * item; any other reply to its item's session. Ready to send holds no
 * pick-up of another project's item: one leaves it as the window comes to
 * hold a session of another project (window.ts's `dropPickUpsElsewhere`).
 */
export const goesTo = (held: SitrepSessionRef, reply: SitrepQueued): SitrepSessionRef =>
  reply.verdict === 'pickup' ? held : { project: reply.project, session: reply.session }

/** The item a reply names in a message to the session `to`: by its own id where it is that session's, else by its address. */
export const namedIn = (to: string, { session, item }: Pick<SitrepItemRef, 'session' | 'item'>) =>
  session === to ? item : itemKey(session, item)

/** The session and the item a reply a message in flight carries answers, as its claim names it: by its address, another session's of its project; by its own id, the message's own session's. */
export const repliedTo = (flight: SitrepSessionRef, item: string): SitrepItemRef => ({
  project: flight.project,
  ...(addressed(item) ?? { session: flight.session, item }),
})

/** The queue with `reply` in place of any reply its item had, else at its end. */
export const queuing = (queue: Queue, reply: SitrepQueued) =>
  queue.some(each => isFor(each, reply.session, reply.item))
    ? queue.map(each => (isFor(each, reply.session, reply.item) ? reply : each))
    : [...queue, reply]

/** The queue less the reply to one item. */
export const unqueuing = (queue: Queue, session: string, item: string) =>
  queue.filter(each => !isFor(each, session, item))

/** The messages in flight, in the order claimed. */
type Flights = readonly SitrepInFlight[]

/** Whether a reply to an item is one this message in flight carries, as a send of Lee's: frozen in the queue until Claude Code takes it. */
export const isCarriedBy = (
  flight: SitrepInFlight,
  reply: Pick<SitrepQueued, 'session' | 'item'>,
) =>
  flight.source === 'send' &&
  flight.replies.some(each => isFor(repliedTo(flight, each.item), reply.session, reply.item))

/** Whether a queued reply is one a send of Lee's in flight carries. */
export const isCarried = (flights: Flights, reply: SitrepQueued) =>
  flights.some(flight => isCarriedBy(flight, reply))

/** The queue less the replies sends in flight carry: those a send can still carry, and Lee still change. */
export const unsent = (queue: Queue, flights: Flights) =>
  queue.filter(each => !isCarried(flights, each))

/** What holds a queued reply back from a send: its item's session finished, no reply reaching it (`reaches`); else its item closed, or holding another answer of Lee's (`barredBy`). */
export type HeldBack = 'finished' | Barred

/** What holds a queued reply back from a send, as the board reads it (`reaches`, `barredBy`); nothing for one a send in flight carries. */
export const heldBack = (
  scene: Scene,
  item: Ask | Parked,
  reply: SitrepQueued,
): HeldBack | undefined => {
  if (isCarried(scene.inFlight, reply)) {
    return undefined
  }

  return canReach(scene, reply.session, item) ? barredBy(item, reply.verdict) : 'finished'
}

/** The queue less every reply but those sends in flight carry. */
export const clearing = (queue: Queue, flights: Flights) =>
  queue.filter(each => isCarried(flights, each))

/** The queue less the replies a send carried. */
export const afterSend = (queue: Queue, replies: Queue) =>
  queue.filter(each => !replies.some(reply => isFor(each, reply.session, reply.item)))

/** The queue with replies taken from it put back, each whose item has had no other queued since. */
export const restoring = (queue: Queue, replies: Queue) => [
  ...queue,
  ...replies.filter(reply => queuedOn(queue, reply.session, reply.item) === undefined),
]

/** The replies waiting for a session, in the order queued, as each goes from a window holding `held`. */
export const queuedFor = (queue: Queue, held: SitrepSessionRef, session: string) =>
  queue.filter(each => goesTo(held, each).session === session)

/** The reply waiting on an item, if one is. */
export const queuedOn = (queue: Queue, session: string, item: string) =>
  queue.find(each => isFor(each, session, item))

/** Each session these replies go to, once, in the order first queued. */
export const destinations = (replies: readonly SitrepSessionRef[]): SitrepSessionRef[] => [
  ...new Map(replies.map(({ project, session }) => [session, { project, session }])).values(),
]

/** The ask or parked item a reply answers, as the session has it, while the reply fits it. */
export const answered = (session: Session, reply: SitrepQueued): Ask | Parked | undefined => {
  const item = session.items.get(reply.item)

  return item !== undefined && fits(item, reply) ? item : undefined
}

/** Why a send leaves a queued reply in Ready to send: its item changed past it, or is gone; or, as Ready to send says it (`HeldBack`), its session finished, no reply reaching it, or the item holding another answer of Lee's, or closed. */
export type LeftOut = 'changed' | HeldBack

/** Whether Lee's answer on its way to an item is one `own`, a message claimed with a reply to it, carries: its writer's, by its id. */
const isOwnAnswer = (item: Ask | Parked, own: SitrepInFlight) => {
  const ahead = item.answerOnItsWay

  return ahead?.by === own.writer && own.replies.some(each => each.id === ahead.id)
}

/** An item as it stands but for Lee's answer on its way there where `own`, a message claimed with a reply to it, carries that answer. */
export const apartFrom = (item: Ask | Parked, own: SitrepInFlight | undefined): Ask | Parked =>
  own !== undefined && isOwnAnswer(item, own) ? { ...item, answerOnItsWay: undefined } : item

/**
 * Why a send from the window holding `held` leaves a queued reply no send
 * in flight carries, its item read in `session`; undefined for one it
 * carries: one that fits its item, which a reply can reach (`reaches`) and
 * which takes it now. The answer on its way that `own`, the message claimed
 * with the reply, carries bars nothing.
 */
const whyLeft = (
  held: string,
  session: Session,
  reply: SitrepQueued,
  own?: SitrepInFlight,
): LeftOut | undefined => {
  const item = answered(session, reply)

  if (item === undefined) {
    return 'changed'
  }

  return reaches(held, { id: session.id, isFinished: session.finished !== undefined }, item)
    ? barredBy(apartFrom(item, own), reply.verdict)
    : 'finished'
}

/** Why a send from the window holding `held` leaves a queued reply, its item read in its own session as `folded` has it: one whose session is gone has changed. */
const whyLeftIn = (held: string, folded: Folded, reply: SitrepQueued, own?: SitrepInFlight) => {
  const session = folded.get(reply.session)

  return session === undefined ? 'changed' : whyLeft(held, session, reply, own)
}

/** The replies a send to a session would carry from a window holding `held`: those no send in flight carries, which go in their own message already. */
export const unsentTo = (queue: Queue, flights: Flights, held: SitrepSessionRef, to: string) =>
  queuedFor(unsent(queue, flights), held, to)

/**
 * Of a send's replies from the window holding `held`, those it carries,
 * each item read in its own session as `folded` has it. One whose item
 * changed under it, or closed, or holds another answer of Lee's on its way,
 * or whose session finished, no reply reaching it, stays in Ready to send,
 * unsent: Claude has one answer to an item, the first to reach it.
 */
export const sendable = (held: string, folded: Folded, replies: Queue) =>
  replies.filter(reply => whyLeftIn(held, folded, reply) === undefined)

/** Why a send from the window holding `held` leaves each of its replies it does not carry. */
export const leftOut = (held: string, folded: Folded, replies: Queue): LeftOut[] =>
  replies.flatMap(reply => whyLeftIn(held, folded, reply) ?? [])

/**
 * Why a message claimed with a reply leaves it out, its item read again in
 * its own session as `folded` has it, as a send would: the message's own
 * answer on its way, which its window's heartbeat says from the claim,
 * bars nothing.
 */
export const leftOutOnceClaimed = (folded: Folded, reply: SitrepQueued, claimed: SitrepInFlight) =>
  whyLeftIn(claimed.session, folded, reply, claimed)

/** Where a message's reply ids are drawn apart from: the sessions its items are in, and the messages in flight. */
export type Around = { folded?: Folded; flights?: Flights }

/**
 * The replies as lines of a message to the session `to`, each naming its
 * item as the message does (`namedIn`), with an id unlike any `to` uses,
 * nor any of the sessions `folded` holds, among them each item's own, nor
 * any the messages `flights` carry, not written down yet; a pick-up naming
 * `to` as the session it goes to, which Parked's picked up names it by.
 */
export const replyBodies = (
  to: Session,
  replies: Queue,
  { folded = new Map(), flights = [] }: Around = {},
  draw: Random = random,
): ReplyBody[] => {
  const taken = new Set([
    ...[to, ...folded.values()].flatMap(session => [...session.ids]),
    ...flights.flatMap(flight => flight.replies.map(each => each.id)),
  ])

  return replies.map(reply => {
    const { verdict, option, note } = reply
    const id = newItemId(draw, taken)

    taken.add(id)

    const goes = verdict === 'pickup' ? { to: to.id } : {}

    return { type: 'reply', id, item: namedIn(to.id, reply), verdict, option, note, ...goes }
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

/** Whether these replies have all gone where they go: to Claude, or void. */
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
