/**
 * What the board's buttons and fields do, bound to the host. A press does
 * not wait on its work, so each act runs in its own time and writes to the
 * debug log what failed.
 */
import type { SitrepMode, SitrepPane, SitrepQueued, SitrepView } from '../types'
import { send } from './deliver'
import { logFailure, type Host } from './host'
import { openBoard, type Focus } from './pane'
import { clearing, queuing, unqueuing } from './queue'
import { attached } from './window'

/** What a saved comment field makes: a comment (an answer, on a decide), or a yes with its words. */
type Saved = 'comment' | 'yes'

export type Actions = {
  /** Opens an item, or a log line, under its line; or closes it again. */
  select: (id: string) => void
  /** Queues Lee's reply to an item, in place of any it had. */
  reply: (reply: SitrepQueued) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (work: string, item: string) => void
  /** Empties the queue of a work's replies. */
  cancelAll: (work: string) => void
  /** Opens the comment field on an ask. */
  comment: (item: string) => void
  cancelComment: () => void
  /** What the field holds, from a surface with no text area of the mod's own. */
  type: (text: string) => void
  /** Queues the field's words as a reply; `typed`, where the field handed them over itself. */
  save: (work: string, item: string, saved: Saved, typed?: string) => void
  send: () => void
  /** Turns the board to a view, closing what was open in the last. */
  show: (view: SitrepView) => void
  /** Opens the board full or as the glance, on what was clicked. */
  open: (mode: SitrepMode, focus?: Focus) => void
}

const EMPTY = 'Type something first, or cancel.'

const changePane = (host: Host, change: (pane: SitrepPane) => Partial<SitrepPane>) =>
  host.state.pane.update(pane => ({ ...pane, ...change(pane) }))

const queue = async (host: Host, reply: SitrepQueued) => {
  await host.state.queue.update(replies => queuing(replies, reply))
  await changePane(host, () => ({ commenting: null }))
}

/** The field's words as the reply: a comment needs some; a yes goes without. */
const saveField = async (host: Host, work: string, item: string, saved: Saved, typed?: string) => {
  const note = (typed ?? (await host.state.draft.read())).trim()

  if (note === '' && saved === 'comment') {
    host.ui.toast(EMPTY)

    return
  }

  await queue(host, { work, item, verdict: saved, note: note === '' ? undefined : note })
  await host.state.draft.write('')
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
    cancelAll: work =>
      run('cancelling every reply', () =>
        host.state.queue.update(replies => clearing(replies, work)),
      ),
    comment: item =>
      run('opening the comment field', async () => {
        await host.state.draft.write('')
        await changePane(host, () => ({ commenting: item }))
      }),
    cancelComment: () =>
      run('closing the comment field', () => changePane(host, () => ({ commenting: null }))),
    type: text => run('keeping what was typed', () => host.state.draft.write(text)),
    save: (work, item, saved, typed) =>
      run('saving the comment', () => saveField(host, work, item, saved, typed)),
    send: () => run('sending', () => send(host)),
    show: view =>
      run('turning the board', () =>
        changePane(host, () => ({ view, selected: null, commenting: null })),
      ),
    open: (mode, focus) => run('opening the board', () => openBoard(host, mode, focus)),
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

/** A post from the comment field's text area: the words kept as typed, and saved as a comment on Enter. */
export const heardTyping = async (host: Host, element: string, data: unknown) => {
  const typing = typingOf(data)
  const work = attached()?.work

  if (!element.startsWith(AREA) || typing === undefined) {
    return
  }

  await host.state.draft.write(typing.text)

  if (typing.isSubmit && work !== undefined) {
    await saveField(host, work, element.slice(AREA.length), 'comment', typing.text)
  }
}
