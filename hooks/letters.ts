/**
 * Lee's replies to other sessions, written into each session's inbox as
 * this window's letters: `inbox/<writer>.jsonl`, the window its single
 * writer, rewriting the whole file as it adds to it. Written, a reply has
 * left the queue: sent, not yet delivered, until the window delivering for
 * that session marks it. Ready to send shows where each went meanwhile.
 */
import { append, sessionPaths, type ReplyBody, type Session } from '../core'
import type { SitrepAttachment, SitrepQueued, SitrepSessionRef } from '../types'
import { foldAt, lookAround } from './around'
import { rootFor, type Host } from './host'
import { counted } from './look'
import {
  afterSend,
  destinations,
  isCarried,
  replyBodies,
  restoring,
  sendable,
  withSent,
} from './queue'
import { ownText } from './reader'
import { attached, serially } from './window'

/** What went to one session: its name, and how many replies. */
type Went = { name: string; count: number }

/** The window's letters as it last wrote them, by path; one not written since a reload is read back. */
const texts = new Map<string, string>()

const write = async (host: Host, path: string, bodies: readonly ReplyBody[]) => {
  const { text } = append(
    texts.get(path) ?? (await ownText(host, path)),
    bodies,
    await host.clock.now(),
  )

  await host.fs.write(path, text)
  texts.set(path, text)
}

/**
 * Takes a session's replies that still fit its items out of the queue, in one
 * change, so a second send finds them gone; never those a send in flight
 * carries, which are on their way as Lee's own message.
 */
const take = async (host: Host, session: Session) => {
  const inFlight = await host.state.inFlight.read()
  let taken: SitrepQueued[] = []

  await host.state.queue.update(waiting => {
    taken = sendable(session, waiting).filter(reply => !isCarried(inFlight, reply))

    return afterSend(waiting, taken)
  })

  return taken
}

/** Writes a session's replies that still fit its items into its inbox; a write that fails puts them back. */
const sendTo = async (
  host: Host,
  held: SitrepAttachment,
  to: SitrepSessionRef,
): Promise<Went | undefined> => {
  const root = await rootFor(host)
  const session = await foldAt(host, root, to, await host.clock.now())
  const replies = session === undefined ? [] : await take(host, session)

  if (session === undefined || replies.length === 0) {
    return undefined
  }

  const bodies = replyBodies(session, replies)

  try {
    await write(host, sessionPaths(root, to.project, to.session).letters(held.writer), bodies)
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

  return { name: session.status.name, count: replies.length }
}

const toastOf = (went: readonly Went[]) =>
  `Sent ${went.map(({ name, count }) => `${counted(count, 'reply', 'replies')} to ${name}`).join(' and ')}.`

/** Sends Ready to send's replies to sessions other than the held one, each into its session's inbox; whether any went. */
export const sendLetters = async (host: Host) => {
  const held = attached()

  if (held === undefined) {
    return false
  }

  const queue = await host.state.queue.read()
  const went: Went[] = []

  for (const to of destinations(queue).filter(each => each.session !== held.session)) {
    const one = await serially(() => sendTo(host, held, to))

    if (one !== undefined) {
      went.push(one)
    }
  }

  if (went.length > 0) {
    host.ui.toast(toastOf(went))
    await lookAround(host)
  }

  return went.length > 0
}
