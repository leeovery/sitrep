/**
 * What the board's buttons and fields do, bound to the host. A press does
 * not wait on its work, so each act runs in its own time and writes to the
 * debug log what failed.
 */
import { checkFinish, type Work } from '../core'
import type {
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
import { openBoard, type Focus } from './pane'
import { projectPlace } from './places'
import { clearing, queuing, unqueuing } from './queue'
import { send } from './send'
import { attached, serially } from './window'

/** What a saved comment field makes: a comment (an answer, on a decide), or a yes with its words. */
type Saved = 'comment' | 'yes'

export type Actions = {
  /** Opens an item, or a log line, under its line; or closes it again. */
  select: (id: string) => void
  /** Queues Lee's reply to an item, in place of any it had. */
  reply: (reply: SitrepQueued) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (work: string, item: string) => void
  /** Empties the queue, but for what a send is carrying. */
  cancelAll: () => void
  /** Opens the comment field on an ask. */
  comment: (at: SitrepItemRef) => void
  cancelComment: () => void
  /** What the field holds, from a surface with no text area of the mod's own. */
  type: (text: string) => void
  /** Queues the field's words as a reply; `typed`, where the field handed them over itself. */
  save: (at: SitrepItemRef, saved: Saved, typed?: string) => void
  send: () => void
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

/** The field's words as the reply: a comment needs some; a yes goes without. */
const saveField = async (host: Host, at: SitrepItemRef, saved: Saved, typed?: string) => {
  const note = (typed ?? (await host.state.draft.read())).trim()

  if (note === '' && saved === 'comment') {
    host.ui.toast(EMPTY)

    return
  }

  await queue(host, { ...at, verdict: saved, note: note === '' ? undefined : note })
  await host.state.draft.write('')
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
    comment: at =>
      run('opening the comment field', async () => {
        await host.state.draft.write('')
        await changePane(host, () => ({ commenting: at }))
      }),
    cancelComment: () =>
      run('closing the comment field', () => changePane(host, () => ({ commenting: null }))),
    type: text => run('keeping what was typed', () => host.state.draft.write(text)),
    save: (at, saved, typed) => run('saving the comment', () => saveField(host, at, saved, typed)),
    send: () => run('sending', () => send(host)),
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

/** A post from the comment field's text area: the words kept as typed, and saved as a comment on Enter. */
export const heardTyping = async (host: Host, element: string, data: unknown) => {
  const typing = typingOf(data)

  if (!element.startsWith(AREA) || typing === undefined) {
    return
  }

  await host.state.draft.write(typing.text)

  const { commenting } = await host.state.pane.read()

  if (typing.isSubmit && commenting?.item === element.slice(AREA.length)) {
    await saveField(host, commenting, 'comment', typing.text)
  }
}
