/**
 * What the board's buttons and fields do, bound to the host. A press does
 * not wait on its work, so each act runs in its own time and writes to the
 * debug log what failed.
 */
import type { PromptSubmitInput } from 'claude-code'
import { checkFinish, type Work } from '../core'
import type {
  SitrepField,
  SitrepItemRef,
  SitrepMode,
  SitrepPane,
  SitrepPlace,
  SitrepQueued,
  SitrepView,
  SitrepWorkRef,
} from '../types'
import { lookAround } from './around'
import { logFailure, type Host } from './host'
import { writeInto } from './into'
import { closeBoard, openBoard, type Focus } from './pane'
import { holdsFolded, pastedOnly } from './paste'
import { projectPlace } from './places'
import { clearing, queuing, unqueuing } from './queue'
import { send } from './send'
import { attached, serially } from './window'

/** What a saved field queues its words as, and whether it refuses to save none. */
export type Saved = Pick<SitrepQueued, 'verdict' | 'option'> & { isNoteNeeded: boolean }

/** A comment, an answer on a decide: it needs words. */
const AS_COMMENT: Saved = { verdict: 'comment', isNoteNeeded: true }

/** What a field saves its words as: the answer they go with, where its ask needs them back; else a comment. */
export const savedFrom = ({ answer }: SitrepField): Saved =>
  answer === undefined ? AS_COMMENT : { ...answer, isNoteNeeded: true }

export type Actions = {
  /** Opens an item, or a log line, under its line; or closes it again. */
  select: (id: string) => void
  /** Queues Lee's reply to an item, in place of any it had. */
  reply: (reply: SitrepQueued) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (work: string, item: string) => void
  /** Empties the queue, but for what a send is carrying. */
  cancelAll: () => void
  /** Opens the field on an ask: for a comment, or for what it needs back with an answer. */
  comment: (field: SitrepField) => void
  cancelComment: () => void
  /** What the field holds, from a surface with no text area of the mod's own. */
  type: (text: string) => void
  /** Takes what Lee's prompt box holds into the open field, under what it has, and empties the box. */
  take: (field: SitrepField) => void
  /** Queues the field's words as a reply; `typed`, where the field handed them over itself. */
  save: (at: SitrepItemRef, saved: Saved, typed?: string) => void
  /** Sends Ready to send; a board drawn inline closes once the send is claimed, as on a phone. */
  send: (isDock: boolean) => void
  /** Turns the board to a view of where it is looking, closing what was open in the last. */
  show: (view: SitrepView) => void
  /** Takes the board somewhere else in the tree, on its view of that place. */
  go: (place: SitrepPlace) => void
  /** Opens the board full or as the glance, on what was clicked. */
  open: (mode: SitrepMode, focus?: Focus) => void
  /** Marks another work done, as Lee confirmed on its view, and takes the board up off it. */
  finish: (at: SitrepWorkRef) => void
}

const EMPTY = 'Type something first, or cancel.'

const NOTHING_TO_TAKE = 'Paste into the prompt first.'

/** How long after a paste's prompt is dropped the box is cleared: once the engine has put it back. */
export const CLEAR_AFTER_DROP_MS = 100

const PRESS_ENTER = 'Press Enter in the prompt to send the paste here.'

/** What a paste sent into the field says, and why the prompt did not go to Claude. */
export const PASTED_HERE = 'Pasted into the field. Enter there saves it.'

const changePane = (host: Host, change: (pane: SitrepPane) => Partial<SitrepPane>) =>
  host.state.pane.update(pane => ({ ...pane, ...change(pane) }))

/** Queues a reply; one to another work has that work read, for Ready to send to draw it. */
const queue = async (host: Host, reply: SitrepQueued) => {
  await host.state.queue.update(replies => queuing(replies, reply))
  await changePane(host, () => ({ commenting: null }))

  if (reply.work !== attached()?.work) {
    await lookAround(host)
  }
}

/** The field's words as the reply: a comment needs some, as does what an ask needs back; a review's yes goes without. */
const saveField = async (host: Host, at: SitrepItemRef, saved: Saved, typed?: string) => {
  const note = (typed ?? (await host.state.draft.read())).trim()
  const { project, work, item } = at
  const { verdict, option, isNoteNeeded } = saved

  if (note === '' && isNoteNeeded) {
    host.ui.toast(EMPTY)

    return
  }

  await queue(host, { project, work, item, verdict, option, note: note === '' ? undefined : note })
  await host.state.draft.write('')
}

/** Puts text in the field, on a line under what it holds, for its text area to take up. */
const fill = async (host: Host, field: SitrepField, taken: string) => {
  const held = await host.state.draft.read()
  const text = held === '' ? taken : `${held}\n${taken}`
  const times = (field.filled?.times ?? 0) + 1

  await host.state.draft.write(text)
  await changePane(host, () => ({ commenting: { ...field, filled: { text, times } } }))
}

/**
 * What Lee's prompt box holds, taken into the field and the box emptied
 * once the field has it. A paste the box holds folded away is not taken:
 * the box hands over only its placeholder, so Enter sends it here instead.
 */
const takePrompt = async (host: Host, field: SitrepField) => {
  const box = await host.prompt.read()

  if (box.trim() === '' || holdsFolded(box)) {
    host.ui.toast(box.trim() === '' ? NOTHING_TO_TAKE : PRESS_ENTER)

    return
  }

  await fill(host, field, box)
  await host.prompt.clear()
}

/**
 * Whether Lee's prompt went into the open field rather than to Claude: one
 * typed at the composer, made of nothing but pasted text, with nothing
 * attached, while a field is open on the board. Anything else goes to Claude.
 */
export const tookPaste = async (
  host: Host,
  { text, attachments, origin }: Pick<PromptSubmitInput, 'text' | 'attachments' | 'origin'>,
) => {
  const pasted =
    origin.kind === 'composer' && (attachments ?? []).length === 0 ? pastedOnly(text) : undefined
  const { isOpen, commenting } = await host.state.pane.read()

  if (pasted === undefined || !isOpen || commenting === null) {
    return false
  }

  await fill(host, commenting, pasted)
  // The engine puts a dropped prompt back in the box, over a clear made while
  // the hook runs (live), so the box is cleared once the drop has settled.
  host.clock.after(
    CLEAR_AFTER_DROP_MS,
    () => void host.prompt.clear().catch(logFailure(host, 'clearing the prompt')),
  )

  return true
}

/** The board on its view of a place, nothing opened there, and what it shows read. */
const go = async (host: Host, place: SitrepPlace) => {
  await changePane(host, () => ({ place, view: 'board', selected: null, commenting: null }))
  await lookAround(host)
}

/** Lee's finish: a line in this window's own file in the work, none once it is done already. */
const finishing = (work: Work) => {
  const checked = checkFinish(work, 'lee')

  return checked.ok ? [checked.value] : []
}

/** Marks a work the window does not hold done, then goes up to its project, where it no longer shows. */
const finish = async (host: Host, at: SitrepWorkRef) => {
  const writer = await host.session.id()

  await serially(() => writeInto(host, { ...at, writer }, finishing))
  await go(host, projectPlace(at.project))
}

export const actionsOf = (host: Host): Actions => {
  const run = (what: string, act: () => Promise<unknown>) =>
    void act().catch(logFailure(host, what))

  return {
    select: id =>
      run('opening an item', () =>
        changePane(host, pane => ({ selected: pane.selected === id ? null : id })),
      ),
    reply: reply => run('queuing a reply', () => queue(host, reply)),
    unqueue: (work, item) =>
      run('taking a reply back', () =>
        host.state.queue.update(replies => unqueuing(replies, work, item)),
      ),
    cancelAll: () =>
      run('cancelling every reply', async () => {
        const inFlight = await host.state.inFlight.read()

        await host.state.queue.update(replies => clearing(replies, inFlight))
      }),
    comment: field =>
      run('opening the field', async () => {
        await host.state.draft.write('')
        await changePane(host, () => ({ commenting: field }))
      }),
    cancelComment: () =>
      run('closing the comment field', () => changePane(host, () => ({ commenting: null }))),
    type: text => run('keeping what was typed', () => host.state.draft.write(text)),
    take: field => run('taking what is in the prompt', () => takePrompt(host, field)),
    save: (at, saved, typed) => run('saving the field', () => saveField(host, at, saved, typed)),
    send: isDock =>
      run('sending', () =>
        send(host, async () => {
          if (!isDock) {
            await closeBoard(host)
          }
        }),
      ),
    show: view =>
      run('turning the board', () =>
        changePane(host, () => ({ view, selected: null, commenting: null })),
      ),
    go: place => run('going elsewhere on the board', () => go(host, place)),
    open: (mode, focus) => run('opening the board', () => openBoard(host, mode, focus)),
    finish: at => run('marking a work done', () => finish(host, at)),
  }
}

/** What the mod's text area posts as Lee types: the words, and whether Enter saved them. */
type Typing = { text: string; isSubmit: boolean }

const typingOf = (data: unknown): Typing | undefined => {
  if (typeof data !== 'object' || data === null) {
    return undefined
  }

  const { text, isSubmit } = data as { [key: string]: unknown }

  return typeof text === 'string' ? { text, isSubmit: isSubmit === true } : undefined
}

const AREA = 'area:'

/** The text area's key on the ask it comments on. */
export const areaKey = (item: string) => `${AREA}${item}`

/** A post from the field's text area: the words kept as typed, and saved on Enter as the field saves them. */
export const heardTyping = async (host: Host, element: string, data: unknown) => {
  const typing = typingOf(data)

  if (!element.startsWith(AREA) || typing === undefined) {
    return
  }

  await host.state.draft.write(typing.text)

  const { commenting } = await host.state.pane.read()

  if (typing.isSubmit && commenting?.item === element.slice(AREA.length)) {
    await saveField(host, commenting, savedFrom(commenting), typing.text)
  }
}
