/**
 * Lee's replies to other sessions, written into each session's inbox as
 * this window's letters: `inbox/<writer>.jsonl`, the window its single
 * writer, rewriting the whole file under today's layout as it adds to it,
 * from its letters there under either. Written, a reply has
 * left the queue: sent, not yet delivered, until the window delivering for
 * that session marks it. Ready to send shows where each went meanwhile.
 */
import { append, sessionPaths, type ReplyBody, type Session, type SessionPaths } from '../core'
import type { SitrepAttachment, SitrepQueued, SitrepSessionRef } from '../types'
import { foldAt, lookAround } from './around'
import { rootFor, type Host } from './host'
import { counted } from './look'
import {
  afterSend,
  destinations,
  isCarried,
  leftOut,
  replyBodies,
  restoring,
  sendable,
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
    texts.get(path) ?? (await ownText(host, paths, folder => folder.letters(writer))),
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
const take = async (host: Host, session: Session) => {
  const inFlight = await host.state.inFlight.read()
  let taken: SitrepQueued[] = []
  let left: LeftOut[] = []

  await host.state.queue.update(waiting => {
    taken = sendable(session, waiting, inFlight).filter(reply => !isCarried(inFlight, reply))
    left = leftOut(session, waiting, inFlight)

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
  const session = await foldAt(host, root, to, await host.clock.now())

  if (session === undefined) {
    return { left: [] }
  }

  const { taken: replies, left } = await take(host, session)

  if (replies.length === 0) {
    return { left }
  }

  const bodies = replyBodies(session, replies)

  try {
    await write(host, sessionPaths(root, to.project, to.session), held.writer, bodies)
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
  const went: Went[] = []
  const left: LeftOut[] = []

  for (const to of destinations(queue).filter(each => each.session !== held.session)) {
    const one = await serially(() => sendTo(host, held, to))

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
