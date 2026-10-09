/**
 * What the board's buttons do, bound to the host. A press does not wait on
 * its work, so each act runs in its own time and writes to the debug log
 * what failed.
 */
import { checkFinish, type Work } from '../core'
import type {
  SitrepAnswering,
  SitrepPane,
  SitrepPlace,
  SitrepQueued,
  SitrepWorkRef,
} from '../types'
import { beginAnswering } from './answering'
import { lookAround } from './around'
import { logFailure, type Host } from './host'
import { writeInto } from './into'
import { closeBoard } from './pane'
import { projectPlace } from './places'
import { clearing, queuing, unqueuing } from './queue'
import { send } from './send'
import { attached, serially } from './window'

export type Actions = {
  /** Opens an item, or a log line, under its line; or closes it again. */
  select: (id: string) => void
  /** Queues Lee's reply to an item, in place of any it had. */
  reply: (reply: SitrepQueued) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (work: string, item: string) => void
  /** Empties the queue, but for what a send is carrying. */
  cancelAll: () => void
  /** Has the next Enter in the prompt box answer an ask, or comment on it; `text` fills the box first, to edit the words already queued. */
  answer: (answering: SitrepAnswering, text?: string) => void
  /** Sends Ready to send; a board drawn inline closes once the send is claimed, as on a phone. */
  send: (isDock: boolean) => void
  /** Takes the board somewhere else in the tree. */
  go: (place: SitrepPlace) => void
  /** Marks another work done, as Lee confirmed on its view, and takes the board up off it. */
  finish: (at: SitrepWorkRef) => void
}

const changePane = (host: Host, change: (pane: SitrepPane) => Partial<SitrepPane>) =>
  host.state.pane.update(pane => ({ ...pane, ...change(pane) }))

/** Queues a reply; one to another work has that work read, for Ready to send to draw it. */
const queue = async (host: Host, reply: SitrepQueued) => {
  await host.state.queue.update(replies => queuing(replies, reply))

  if (reply.work !== attached()?.work) {
    await lookAround(host)
  }
}

/** The board on a place, nothing opened there, and what it shows read. */
const go = async (host: Host, place: SitrepPlace) => {
  await changePane(host, () => ({ place, selected: null }))
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
    answer: (answering, text) =>
      run('answering in the prompt', () => beginAnswering(host, answering, text)),
    send: isDock =>
      run('sending', () =>
        send(host, async () => {
          if (!isDock) {
            await closeBoard(host)
          }
        }),
      ),
    go: place => run('going elsewhere on the board', () => go(host, place)),
    finish: at => run('marking a work done', () => finish(host, at)),
  }
}
