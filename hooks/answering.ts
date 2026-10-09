/**
 * Answering an ask in Lee's own prompt box (DESIGN.md, "Answering an ask").
 * ✎ on the board puts the window in the mode for that ask, and the next
 * Enter at the prompt is taken as its answer, or as a comment on it: queued
 * in Ready to send with everything else, and nothing of it goes to Claude.
 *
 * The mode is one-shot. The band shows it the whole time it stands, and it
 * stands exactly while the next Enter would be taken: while its ask can
 * still take the reply. Once it cannot (closed, answered from elsewhere, its
 * work done, a send carrying its reply) the next Enter goes to Claude as
 * ever, and the mode ends at the next look.
 */
import type { PromptOrigin, PromptSubmitInput } from 'claude-code'
import { isOpen, isPending, takes, type Ask, type Verdict } from '../core'
import type { SitrepAnswering, SitrepQueued } from '../types'
import { logFailure, type Host } from './host'
import { unwrapPastes } from './paste'
import { filedAt } from './places'
import { isCarried, queuedOn, queuing } from './queue'
import { sceneOf, type Filed, type Scene } from './scene'

/** The mode as it stands: what it answers, the ask, and the work the ask is in. */
export type Answering = { answering: SitrepAnswering; filed: Filed; ask: Ask }

/** What the next Enter queues, by what the mode was entered for. */
const VERDICT: Record<SitrepAnswering['as'], Verdict> = { answer: 'answer', comment: 'comment' }

/** Lee's own messages: Enter at the terminal's prompt, or in Claude's app (the Remote Control bridge). */
const LEES: readonly PromptOrigin['kind'][] = ['composer', 'bridge']

export const DRAFT = 'The prompt has a draft in it: send or clear it first, then answer.'

/** Why a taken prompt went no further, as the transcript's one line. */
export const TAKEN: Record<SitrepAnswering['as'], string> = {
  answer: 'Your answer waits in Ready to send.',
  comment: 'Your comment waits in Ready to send.',
}

/** Why a prompt the mode could not take went no further: back in the box, for Lee to put right. */
export const NOT_TAKEN = 'Kept in the prompt: the board is waiting for your answer.'

const EMPTY = 'Write your answer in the prompt first, or cancel it on the band.'

const ATTACHED =
  'An answer is words alone: take the attachment out, or cancel answering on the band.'

/** How long after a taken prompt is dropped the box is cleared: once the engine has put it back. */
export const CLEAR_AFTER_DROP_MS = 100

/** Whether the ask can take the reply: open, its work not done, nothing of Lee's on its way to it, and of a shape that takes it. */
const canTake = (scene: Scene, { work }: Filed, ask: Ask, { as }: SitrepAnswering) => {
  const queued = queuedOn(scene.queue, work.id, ask.id)

  return (
    work.finished === undefined &&
    isOpen(ask) &&
    !ask.replies.some(isPending) &&
    (queued === undefined || !isCarried(scene.inFlight, queued)) &&
    takes(ask, VERDICT[as])
  )
}

/** The mode, while it stands; undefined while the window is not answering, or its ask can no longer take the reply. */
export const answeringIn = (scene: Scene): Answering | undefined => {
  const { answering } = scene

  if (answering === null) {
    return undefined
  }

  const filed = filedAt(scene, answering.work)
  const ask = filed?.work.items.get(answering.item)

  return filed !== undefined && ask?.type === 'ask' && canTake(scene, filed, ask, answering)
    ? { answering, filed, ask }
    : undefined
}

/** Ends the mode. */
export const endAnswering = (host: Host) => host.state.answering.write(null)

/**
 * Puts the window in the mode for an ask, filling the prompt box with
 * `text` to edit a reply already queued. A box holding a draft is refused:
 * its Enter would answer the ask with that draft.
 */
export const beginAnswering = async (host: Host, answering: SitrepAnswering, text?: string) => {
  if ((await host.prompt.read()).trim() !== '') {
    host.ui.toast(DRAFT)

    return
  }

  if (text !== undefined) {
    await host.prompt.fill(text)
  }

  await host.state.answering.write(answering)
}

/** Ends the mode once it no longer stands, so its ask, opened again later, does not take it back up. */
export const settleAnswering = async (host: Host) => {
  if ((await host.state.answering.read()) === null) {
    return
  }

  const scene = await sceneOf(host)

  if (scene === undefined || answeringIn(scene) === undefined) {
    await endAnswering(host)
  }
}

/** What a reply of the mode's queues as: an answer; a comment, as the note of a yes or a choice queued on the ask, else on its own. */
const replyOf = (
  { project, work, item, as }: SitrepAnswering,
  queue: readonly SitrepQueued[],
  note: string,
): SitrepQueued => {
  const queued = queuedOn(queue, work, item)

  if (as === 'comment' && (queued?.verdict === 'yes' || queued?.verdict === 'choose')) {
    return { ...queued, note }
  }

  return { project, work, item, verdict: VERDICT[as], note }
}

/** What Lee wrote, as a reply's words: blank lines at either end dropped, the indent of the first line kept. */
const wordsOf = (text: string) =>
  unwrapPastes(text)
    .replace(/^\s*\n/, '')
    .trimEnd()

/**
 * Lee's prompt, taken as the answer the mode waits for, and why it went no
 * further, for the transcript; undefined where it goes to Claude as ever.
 * One with nothing in it, or with something attached, is not taken, and
 * the mode stands.
 */
export const captured = async (
  host: Host,
  { text, attachments = [], origin }: Pick<PromptSubmitInput, 'text' | 'attachments' | 'origin'>,
) => {
  if (!LEES.includes(origin.kind) || (await host.state.answering.read()) === null) {
    return undefined
  }

  const scene = await sceneOf(host)
  const standing = scene === undefined ? undefined : answeringIn(scene)

  if (standing === undefined) {
    await endAnswering(host)

    return undefined
  }

  const words = wordsOf(text)

  if (attachments.length > 0 || words.trim() === '') {
    host.ui.toast(attachments.length > 0 ? ATTACHED : EMPTY)

    return NOT_TAKEN
  }

  await host.state.queue.update(queue => queuing(queue, replyOf(standing.answering, queue, words)))
  await endAnswering(host)
  // The engine puts a dropped prompt back in the box, over a clear made while
  // the hook runs (live), so the box is cleared once the drop has settled.
  host.clock.after(
    CLEAR_AFTER_DROP_MS,
    () => void host.prompt.clear().catch(logFailure(host, 'clearing the prompt')),
  )

  return TAKEN[standing.answering.as]
}
