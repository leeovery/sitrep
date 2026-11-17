/**
 * Lee's replies to other sessions, written into each session's inbox as
 * this window's letters: `inbox/<writer>.jsonl`, the window its single
 * writer, rewriting the whole file as it adds to it. Written, a reply has
 * left the queue: sent, not yet delivered, until the window delivering for
 * that session marks it. Ready to send shows where each went meanwhile. A
 * pick-up never goes this way: it goes to this window's Claude, whichever
 * session of the project parked its item (send.ts).
 */
import { append, type ReplyBody, type Session, type SessionPaths } from '../core'
import type { SitrepAttachment, SitrepQueued, SitrepSessionRef } from '../types'
import { foldAt, lookAround } from './around'
import { pathsOf } from './filing'
import { rootFor, type Host } from './host'
import { counted } from './look'
import {
  afterSend,
  destinations,
  goesTo,
  leftOut,
  replyBodies,
  restoring,
  sendable,
  unsentTo,
  withSent,
  type LeftOut,
} from './queue'
import { ownText } from './reader'
import { attached, serially } from './window'

/** What went to one session: its name, and how many replies. */
type Went = { name: string; count: number }

/** What a send did for one session: what went there, if any did, and why it left each reply it did not carry. */
type SentTo = { went?: Went; left: readonly LeftOut[] }

/** What a send did for every session but the held one: whether any of it went, and why it left each reply it did not carry. */
export type Lettered = { isLettered: boolean; left: readonly LeftOut[] }

/** The window's letters as it last wrote them, by path; one not written since a reload is read back. */
const texts = new Map<string, string>()

const write = async (
  host: Host,
  paths: SessionPaths,
  writer: string,
  bodies: readonly ReplyBody[],
) => {
  const path = paths.letters(writer)
  const { text } = append(
    texts.get(path) ?? (await ownText(host, path)),
    bodies,
    await host.clock.now(),
  )

  await host.fs.write(path, text)
  texts.set(path, text)
}

/**
 * Takes a session's replies its items take now out of the queue, in one
 * change, so a second send finds them gone; never those a send in flight
 * carries, which are on their way as Lee's own message. Says why it left
 * the rest.
 */
const take = async (host: Host, held: SitrepAttachment, session: Session) => {
  const flights = await host.state.inFlight.read()
  const folded = new Map([[session.id, session]])
  let taken: SitrepQueued[] = []
  let left: LeftOut[] = []

  await host.state.queue.update(waiting => {
    const replies = unsentTo(waiting, flights, held, session.id)

    taken = sendable(held.session, folded, replies)
    left = leftOut(held.session, folded, replies)

    return afterSend(waiting, taken)
  })

  return { taken, left }
}

/** Writes a session's replies its items take now into its inbox; a write that fails puts them back. */
const sendTo = async (
  host: Host,
  held: SitrepAttachment,
  to: SitrepSessionRef,
): Promise<SentTo> => {
  const root = await rootFor(host)
  const paths = await pathsOf(host, root, to)
  const session = await foldAt(host, root, to, await host.clock.now())

  if (session === undefined) {
    return { left: [] }
  }

  const { taken: replies, left } = await take(host, held, session)

  if (replies.length === 0) {
    return { left }
  }

  const bodies = replyBodies(session, replies)

  try {
    await write(host, paths, held.writer, bodies)
  } catch (error) {
    await host.state.queue.update(waiting => restoring(waiting, replies))

    throw error
  }

  await host.state.sent.update(list =>
    withSent(
      list,
      to,
      bodies.map(body => body.id),
    ),
  )

  return { went: { name: session.status.name, count: replies.length }, left }
}

const toastOf = (went: readonly Went[]) =>
  `Sent ${went.map(({ name, count }) => `${counted(count, 'reply', 'replies')} to ${name}`).join(' and ')}.`

/** Sends Ready to send's replies to sessions other than the held one, each into its session's inbox. */
export const sendLetters = async (host: Host): Promise<Lettered> => {
  const held = attached()

  if (held === undefined) {
    return { isLettered: false, left: [] }
  }

  const queue = await host.state.queue.read()
  const to = destinations(queue.map(reply => goesTo(held, reply)))
  const went: Went[] = []
  const left: LeftOut[] = []

  for (const other of to.filter(each => each.session !== held.session)) {
    const one = await serially(() => sendTo(host, held, other))

    if (one.went !== undefined) {
      went.push(one.went)
    }

    left.push(...one.left)
  }

  if (went.length > 0) {
    host.ui.toast(toastOf(went))
    await lookAround(host)
  }

  return { isLettered: went.length > 0, left }
}
