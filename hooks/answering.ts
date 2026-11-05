/**
 * Writing to an item in Lee's own prompt box (DESIGN.md, "Answering an
 * ask"). ✎ on the board puts the window in the mode for an ask or a parked
 * item, and the next Enter at the prompt is taken as the ask's answer, a
 * comment on it, or the note of the parked item's pick-up: queued in Ready
 * to send with everything else, and nothing of it goes to Claude.
 *
 * The mode is one-shot, and is the surface's it began on: only an Enter
 * there is taken, and only there does it show. It stands exactly while the
 * next Enter would be taken: while its item, as the board reads it, in full
 * or in its project's briefs, can still take the reply. Once it cannot
 * (closed or picked up, answered from elsewhere, its session finished, a send
 * carrying its reply) the next Enter goes to Claude as ever, and the mode
 * ends. An item whose session the board has not read yet leaves it standing,
 * unshown.
 *
 * A prompt carrying an attachment, an image, can't wait in Ready to send:
 * a plugin is given its kind, never its bytes or its path, and its own
 * prompts carry none. So Lee's prompt goes in at once, rewritten as the
 * board's own words for that one reply, its attachments with it: a message
 * in flight from the moment it is decided, as a send is from its claim, but
 * submitted by Lee's Enter, and written down once Claude Code takes it. It
 * goes into this window's Claude, so only for an item of the session the
 * window holds.
 *
 * Ended with nothing taken, the mode takes back the words it put in the
 * prompt box, so none of the board's words go to Claude unasked.
 */
import type { PromptOrigin, PromptSubmitInput, RenderSurface } from 'claude-code'
import {
  barredBy,
  boardMessage,
  isAnswer,
  takes,
  type Ask,
  type Parked,
  type Verdict,
} from '../core'
import type { SitrepAnswering, SitrepInFlight, SitrepQueued } from '../types'
import { claimRide, rideDropped, rideTaken } from './deliver'
import { logFailure, type Host } from './host'
import { unwrapPastes } from './paste'
import { briefOf, filedAt } from './places'
import {
  isCarried,
  queuedOn,
  queuing,
  replyBodies,
  unqueuing,
  whyLeft,
  type LeftOut,
} from './queue'
import { sceneOf, type Scene } from './scene'
import { refresh, serially } from './window'

/** The mode as it stands: what it writes, and the item it writes to. */
export type Answering = { answering: SitrepAnswering; item: Ask | Parked }

/** The mode as the board reads its item: standing, or over once the item can take the reply no longer. */
type Standing = Answering | 'over'

/**
 * Lee's prompt let in as the board's words for the reply, its attachments
 * with it, the reply claimed as a message in flight: `went` once Claude Code
 * takes the prompt, `dropped` once it goes nowhere.
 */
export type Riding = { text: string; went: () => Promise<void>; dropped: () => Promise<void> }

/** What the mode makes of Lee's prompt: dropped, taken or kept in the box, and why, for the transcript; or let in, riding. */
export type Captured = { drop: string } | Riding

/** What the next Enter queues, by what the mode was entered for. */
const VERDICT: Record<SitrepAnswering['as'], Verdict> = {
  answer: 'answer',
  comment: 'comment',
  pickup: 'pickup',
}

/** Where each of Lee's own prompts comes from: Enter at the terminal's prompt, or in Claude's app, through the Remote Control bridge. */
const SURFACE_OF: Partial<Record<PromptOrigin['kind'], SitrepAnswering['surface']>> = {
  composer: 'terminal',
  bridge: 'mobile',
}

export const DRAFT = 'The prompt has a draft in it: send or clear it first, then answer.'

/** Why a taken prompt went no further, as the transcript's one line, by what the reply does: an answer closes its ask. */
export const TAKEN: Record<SitrepAnswering['as'], string> = {
  answer: 'Your answer waits in Ready to send.',
  comment: 'Your comment waits in Ready to send.',
  pickup: 'Your pick-up waits in Ready to send.',
}

/** Why a prompt the mode could not take went no further: back in the box, for Lee to put right. */
export const NOT_TAKEN = 'Kept in the prompt: the board is waiting for your answer.'

/** Why words the mode put in the prompt are still there once it ended: Lee changed them. */
export const LEFT =
  'The board is no longer waiting for your answer: the words you changed are left in the prompt.'

const EMPTY = 'Write your answer in the prompt first, or cancel it on the band.'

/** Why a prompt carrying an attachment is kept: it can go only into this window's Claude. */
export const ELSEWHERE =
  "An attachment goes only to this window's session: take it out to answer in words, or answer from that session's window."

/** Why a reply can't go in with Lee's prompt, as Ready to send would leave it out, its session read afresh. */
export const CANNOT_RIDE: Record<LeftOut, string> = {
  changed: 'Not sent: the ask has changed since your reply was queued.',
  answered: 'Not sent: the ask has an answer on its way already.',
  resolved: 'Not sent: Claude closed the ask.',
}

/** How long after a taken prompt is dropped the box is cleared: once the engine has put it back. */
export const CLEAR_AFTER_DROP_MS = 100

/** The surfaces whose band a survey holds, as each was last drawn: the mode is hidden there, so takes nothing there. */
const surveyed = new Set<RenderSurface>()

/** Records, as a surface's band is drawn, whether a survey holds it in the band's place. */
export const heardSurvey = (surface: RenderSurface, isHeld: boolean) => {
  if (isHeld) {
    surveyed.add(surface)
  } else {
    surveyed.delete(surface)
  }
}

/** The mode's item as the board reads it: in a session it has in full, else in its project's briefs, which list only open asks and what is still parked; undefined while it has read neither. */
const seenIn = (scene: Scene, { session, item }: SitrepAnswering) => {
  const filed = filedAt(scene, session)

  if (filed !== undefined) {
    const found = filed.session.items.get(item)

    return {
      item: found?.type === 'note' ? undefined : found,
      isFinished: filed.session.finished !== undefined,
    }
  }

  const brief = briefOf(scene, session)

  return brief === undefined
    ? undefined
    : {
        item: [...brief.asks, ...brief.parkedItems].find(each => each.id === item),
        isFinished: brief.isFinished,
      }
}

/** Whether the item can take the reply: open to it (`barredBy`), not carried by a send, and of a shape that takes it. */
const canTake = (scene: Scene, { session, as }: SitrepAnswering, item: Ask | Parked) => {
  const queued = queuedOn(scene.queue, session, item.id)

  return (
    barredBy(item, VERDICT[as]) === undefined &&
    (queued === undefined || !isCarried(scene.inFlight, queued)) &&
    takes(item, VERDICT[as])
  )
}

/** Where the mode stands: over once its item, or the item's session, is finished; undefined while the window is not answering, or the board has not read the item's session yet. */
const standingIn = (scene: Scene): Standing | undefined => {
  const { answering } = scene
  const seen = answering === null ? undefined : seenIn(scene, answering)

  if (answering === null || seen === undefined) {
    return undefined
  }

  return seen.item !== undefined && !seen.isFinished && canTake(scene, answering, seen.item)
    ? { answering, item: seen.item }
    : 'over'
}

/** The mode, while it stands, as the surface it began on shows it; undefined anywhere else, and while it does not stand. */
export const answeringIn = (scene: Scene, surface: RenderSurface): Answering | undefined => {
  const standing = standingIn(scene)

  return standing !== undefined && standing !== 'over' && standing.answering.surface === surface
    ? standing
    : undefined
}

/** A yes or a choice queued on the ask, which a comment goes with, as its note. */
const carrierOf = ({ session, item, as }: SitrepAnswering, queue: readonly SitrepQueued[]) => {
  const queued = queuedOn(queue, session, item)

  return as === 'comment' && (queued?.verdict === 'yes' || queued?.verdict === 'choose')
    ? queued
    : undefined
}

/** What a reply of the mode's queues as: an answer; a comment, as the note of a yes or a choice queued on the ask, else on its own; a pick-up, its note the words. */
const replyOf = (
  answering: SitrepAnswering,
  queue: readonly SitrepQueued[],
  note: string,
): SitrepQueued => {
  const { project, session, item, as } = answering
  const carrier = carrierOf(answering, queue)

  return carrier === undefined
    ? { project, session, item, verdict: VERDICT[as], note }
    : { ...carrier, note }
}

/**
 * What the mode has Lee write, as the board words it, by what the reply
 * does: an answer where it closes the ask, as a comment on an ask read from
 * its kind as a decide does; else what it was entered for: a comment where
 * the ask stays open, or the words go with a yes or a choice; a pick-up.
 */
export const writtenAs = (
  { answering, item }: Answering,
  queue: readonly SitrepQueued[],
): SitrepAnswering['as'] =>
  item.type === 'ask' &&
  carrierOf(answering, queue) === undefined &&
  isAnswer(item, VERDICT[answering.as])
    ? 'answer'
    : answering.as

/** Lets the mode go, whatever it put in the prompt left there. */
const forget = (host: Host) => host.state.answering.write(null)

/** Empties the prompt box where it still holds just the words the mode put there; changed since, it is left as Lee has it, and a toast says so. */
const takeBack = async (host: Host, ended: SitrepAnswering | null) => {
  if (ended?.filled === undefined) {
    return
  }

  const box = await host.prompt.read()

  if (box === ended.filled) {
    await host.prompt.clear()
  } else if (box.trim() !== '') {
    host.ui.toast(LEFT)
  }
}

/** Ends the mode with nothing taken, taking back the words it put in the prompt box. */
export const endAnswering = async (host: Host) => {
  const ended = await host.state.answering.read()

  await forget(host)
  await takeBack(host, ended).catch(logFailure(host, 'taking the words back out of the prompt'))
}

/**
 * Puts the window in the mode for an item, filling the prompt box with
 * `text` to edit a reply already queued. A box holding a draft is refused:
 * its Enter would reply to the item with that draft. Words the mode itself
 * put there are no draft: they give way to the new mode's.
 */
export const beginAnswering = async (host: Host, answering: SitrepAnswering, text?: string) => {
  const [box, was] = await Promise.all([host.prompt.read(), host.state.answering.read()])
  const isOwn = box === was?.filled

  if (box.trim() !== '' && !isOwn) {
    host.ui.toast(DRAFT)

    return
  }

  if (text !== undefined) {
    await host.prompt.fill(text)
  } else if (isOwn) {
    await host.prompt.clear()
  }

  await host.state.answering.write(text === undefined ? answering : { ...answering, filled: text })
}

/** Ends the mode once the board reads that its item can take the reply no longer, so its item, opened again later, does not take it back up. */
export const settleAnswering = async (host: Host) => {
  if ((await host.state.answering.read()) === null) {
    return
  }

  const scene = await sceneOf(host)

  if (scene === undefined || standingIn(scene) === 'over') {
    await endAnswering(host)
  }
}

/** What Lee wrote, as a reply's words: blank lines at either end dropped, the indent of the first line kept. */
const wordsOf = (text: string) =>
  unwrapPastes(text)
    .replace(/^\s*\n/, '')
    .trimEnd()

/** Lee's words queued in Ready to send as the reply, nothing of them going to Claude; the prompt dropped, saying where they wait. */
const queued = async (host: Host, standing: Answering, words: string): Promise<Captured> => {
  const queue = await host.state.queue.read()
  const taken = TAKEN[writtenAs(standing, queue)]

  await host.state.queue.update(waiting =>
    queuing(waiting, replyOf(standing.answering, waiting, words)),
  )
  await forget(host)
  // The engine puts a dropped prompt back in the box, over a clear made while
  // the hook runs (live), so the box is cleared once the drop has settled.
  host.clock.after(
    CLEAR_AFTER_DROP_MS,
    () => void host.prompt.clear().catch(logFailure(host, 'clearing the prompt')),
  )

  return { drop: taken }
}

/**
 * Lets go of the ride as Lee's prompt went nowhere: the reply queued on its
 * item put back as it was, frozen until the claim ends, and the mode
 * standing again, unless Lee began another meanwhile.
 */
const unride = async (
  host: Host,
  ride: SitrepInFlight,
  answering: SitrepAnswering,
  was: SitrepQueued | undefined,
) => {
  const { session, item } = answering

  await host.state.queue.update(queue =>
    was === undefined ? unqueuing(queue, session, item) : queuing(queue, was),
  )
  await rideDropped(host, ride)
  await host.state.answering.update(now => now ?? answering)
}

/**
 * Lee's prompt, carrying an attachment, let in as the board's words for the
 * reply, so the attachment goes with it: only for an item of the session the
 * window holds, whose Claude it goes into, and only while the item, read
 * afresh, takes the reply as a send would carry it; else it is kept, a toast
 * saying why. Claimed as a message in flight before it goes, the reply
 * frozen in Ready to send in place of what was queued on its item, so no
 * send carries that too; and the mode is over. Where a send carries the
 * item's reply already, the mode is over and the prompt goes to Claude as
 * ever.
 */
const riding = async (
  host: Host,
  scene: Scene,
  { answering }: Answering,
  words: string,
): Promise<Captured | undefined> => {
  const held = await host.state.attachment.read()

  if (held?.session !== answering.session) {
    host.ui.toast(ELSEWHERE)

    return { drop: NOT_TAKEN }
  }

  const [now, queue] = await Promise.all([serially(() => refresh(host)), host.state.queue.read()])
  const session = now ?? scene.session
  const reply = replyOf(answering, queue, words)
  const why = whyLeft(session, reply)
  const message = why === undefined ? boardMessage(session, [reply]) : undefined

  if (message === undefined) {
    host.ui.toast(CANNOT_RIDE[why ?? 'changed'])

    return { drop: NOT_TAKEN }
  }

  const ride = await claimRide(host, {
    source: 'send',
    project: held.project,
    session: session.id,
    writer: held.writer,
    text: message.text,
    replies: replyBodies(session, message.replies),
  })

  await forget(host)

  if (ride === undefined) {
    return undefined
  }

  const was = queuedOn(queue, answering.session, answering.item)

  await host.state.queue.update(waiting => queuing(waiting, reply))

  return {
    text: message.text,
    went: () => rideTaken(host, ride),
    dropped: () => unride(host, ride, answering, was),
  }
}

/**
 * What the mode makes of Lee's prompt; undefined where it goes to Claude as
 * ever: a prompt not of Lee's own, one from a surface the mode is not shown
 * on, or one while a survey holds the band there. Words alone are queued,
 * the prompt dropped; words with an attachment ride in with it. One with
 * nothing in it is kept, and the mode stands.
 */
export const captured = async (
  host: Host,
  { text, attachments = [], origin }: Pick<PromptSubmitInput, 'text' | 'attachments' | 'origin'>,
): Promise<Captured | undefined> => {
  const surface = SURFACE_OF[origin.kind]

  if (surface === undefined || (await host.state.answering.read()) === null) {
    return undefined
  }

  const scene = await sceneOf(host)
  const standing = scene === undefined ? 'over' : standingIn(scene)

  if (scene === undefined || standing === 'over') {
    // The prompt in the box is the one going to Claude now: nothing to take back.
    await forget(host)

    return undefined
  }

  if (standing?.answering.surface !== surface || surveyed.has(surface)) {
    return undefined
  }

  const words = wordsOf(text)

  if (words.trim() === '') {
    host.ui.toast(EMPTY)

    return { drop: NOT_TAKEN }
  }

  return attachments.length > 0
    ? riding(host, scene, standing, words)
    : queued(host, standing, words)
}
