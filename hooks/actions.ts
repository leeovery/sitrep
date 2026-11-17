/**
 * What the board's buttons do, bound to the host. A press does not wait on
 * its work, so each act runs in its own time and writes to the debug log
 * what failed.
 */
import {
  checkFinish,
  checkSnooze,
  checkWake,
  isAsleepAt,
  isUntilItMoves,
  snoozeAt,
  snoozeChoicesAt,
  wakeWords,
  type Body,
  type Checked,
  type Session,
  type SnoozeChoice,
  type WakeSessionBody,
} from '../core'
import type {
  SitrepAnswering,
  SitrepInFlight,
  SitrepPane,
  SitrepPlace,
  SitrepQueued,
  SitrepSessionRef,
  SitrepShowing,
} from '../types'
import { beginAnswering, settleAnswering } from './answering'
import { lookAround } from './around'
import { fromTheTop } from './clip'
import { takeBack } from './deliver'
import { logFailure, type Host } from './host'
import { writeHeld, writeInto, writeOwnFile } from './into'
import { isProjectList } from './lists'
import { closeBoard } from './pane'
import { projectPlace } from './places'
import { clearing, queuing, unqueuing } from './queue'
import { send } from './send'
import { attached, post, serially } from './window'

export type Actions = {
  /** Opens an item, or a status change, under its line; or closes it again. */
  select: (id: string) => void
  /** Shows as much of a list of the board's past as asked, none being how it starts, closing an item opened among `hidden`, those it then no longer shows. */
  show: (list: string, showing: SitrepShowing | undefined, hidden: readonly string[]) => void
  /** Queues Lee's reply to an item, in place of any it had. */
  reply: (reply: SitrepQueued) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (session: string, item: string) => void
  /** Empties the queue, but for what the sends in flight carry. */
  cancelAll: () => void
  /** Has the next Enter in the prompt box answer an ask, comment on it, or pick a parked item up with a comment; `text` fills the box first, to edit the words already queued. */
  answer: (answering: SitrepAnswering, text?: string) => void
  /** Takes back a send the window holds for its turn, its replies back in Ready to send among those still to send; none once it has gone. */
  takeBack: (send: SitrepInFlight) => void
  /** Has Ready to send's one row for several held sends show the one named, by the ids of the replies it carries. */
  showHeld: (send: string) => void
  /** Takes the board somewhere in the tree, at its top there: elsewhere, or where it already is. */
  go: (place: SitrepPlace) => void
  /** Closes the board, by its own close where it sits inline. */
  close: () => void
  /** Finishes another session, as Lee confirmed on its view, and takes the board up off it. */
  finish: (at: SitrepSessionRef) => void
  /** Snoozes a session, its asks and its turn, until the time Lee chose, worked out at the press, the ask it was pressed on closed on the board; `asks` are those the board shows waiting there. */
  snooze: (at: SitrepSessionRef, asks: readonly string[], when: SnoozeChoice) => void
  /** Wakes a snoozed session now: everything it needs of Lee counts again. */
  wake: (at: SitrepSessionRef) => void
}

/**
 * Sends Ready to send, from the `ui.press` hook, inside Lee's press: so its
 * submit carries the press, which Claude Code takes though Lee stopped
 * Claude's turn. A board drawn inline closes once the send is claimed, as
 * on a phone.
 */
export const sendReady = (host: Host, isDock: boolean) =>
  send(host, async () => {
    // A send carrying the reply the mode would write ends it now, before its Enter.
    await settleAnswering(host)

    if (!isDock) {
      await closeBoard(host)
    }
  })

const changePane = (host: Host, change: (pane: SitrepPane) => Partial<SitrepPane>) =>
  host.state.pane.update(pane => ({ ...pane, ...change(pane) }))

/** A list of the board's past showing as much as asked, an opened item it stops showing closed with it. */
const shownAs = (
  pane: SitrepPane,
  list: string,
  showing: SitrepShowing | undefined,
  hidden: readonly string[],
): Partial<SitrepPane> => {
  const isHidden = pane.selected !== null && hidden.includes(pane.selected)

  return { shown: { ...pane.shown, [list]: showing }, selected: isHidden ? null : pane.selected }
}

/** A list of the board's past shown as asked; a project's has the look read again, which carries as much of it as it now shows. */
const show = async (
  host: Host,
  list: string,
  showing: SitrepShowing | undefined,
  hidden: readonly string[],
) => {
  await changePane(host, pane => shownAs(pane, list, showing, hidden))

  if (isProjectList(list)) {
    await lookAround(host)
  }
}

/** Has another session read in full, for the board to draw what Lee did to it; the held one is the watch's. */
const readIfElsewhere = async (host: Host, { session }: SitrepSessionRef) => {
  if (session !== attached()?.session) {
    await lookAround(host)
  }
}

/** Queues a reply; one to another session has that session read, for Ready to send to draw it. */
const queue = async (host: Host, reply: SitrepQueued) => {
  await host.state.queue.update(replies => queuing(replies, reply))
  await readIfElsewhere(host, reply)
}

/**
 * Has the next Enter write to an item, the mode standing from the press on
 * the item as drawn; one of another session's has that session read in
 * full, so the mode is checked against all of it, not only its project's
 * briefs.
 */
const answer = async (host: Host, answering: SitrepAnswering, text?: string) => {
  await beginAnswering(host, answering, text)
  await readIfElsewhere(host, answering)
}

/** The board on a place, nothing opened there, at its top, and what it shows read. */
const go = async (host: Host, place: SitrepPlace) => {
  await changePane(host, () => ({ place, selected: null }))
  await fromTheTop(host)
  await lookAround(host)
}

/** Lee's finish: a line in this window's own file in the session, none once it is finished already. */
const finishing = (session: Session) => {
  const checked = checkFinish(session, 'lee')

  return checked.ok ? [checked.value] : []
}

/** Finishes a session the window does not hold, then goes up to its project, where it no longer shows. */
const finish = async (host: Host, at: SitrepSessionRef) => {
  const writer = await host.conversation.id()

  await serially(() => writeInto(host, { ...at, writer }, finishing))
  await go(host, projectPlace(at.project))
}

/** Why a press on an ask wrote nothing, its session no longer there to write into. */
const GONE = 'its session is no longer on the board.'

/** A check of Lee's press against an ask's session as it stands: the line it writes, or why it is refused. */
type Check = (session: Session) => Checked<Body>

/**
 * Writes what Lee's press makes of an ask's session as it stands into this
 * window's own file there, as checked; through the hold, a change Claude
 * did not make, so it rides into its next turn. A refusal, or a session no
 * longer there, writes nothing, a toast saying why after `refused`. Another
 * session is read again after.
 */
const writeLee = async (host: Host, at: SitrepSessionRef, refused: string, check: Check) => {
  const into = { project: at.project, session: at.session, writer: await host.conversation.id() }
  const say = (why: string) => host.ui.toast(`${refused}: ${why}`)
  const isThere = await writeOwnFile(
    host,
    into,
    session => {
      const checked = check(session)

      if (!checked.ok) {
        say(checked.error)
      }

      return checked.ok ? [checked.value] : []
    },
    (session, lines) => post(host, lines),
  )

  if (!isThere) {
    say(GONE)
  }

  await readIfElsewhere(host, at)
}

const UNSNOOZED = 'Not snoozed'

/**
 * Lee's snooze of a session, its asks the board shows and its turn, its time
 * worked out at the press, checked as the CLI checks it. A choice no longer
 * offered at the press, Tonight drawn before 18:00 and pressed after, writes
 * nothing, a toast saying why.
 */
const snooze = async (
  host: Host,
  at: SitrepSessionRef,
  asks: readonly string[],
  when: SnoozeChoice,
) => {
  const now = await host.clock.now()
  const until = snoozeAt(when, now)

  await changePane(host, () => ({ selected: null }))

  if (!snoozeChoicesAt(now).includes(when)) {
    host.ui.toast(
      `${UNSNOOZED}: ${wakeWords(until, now)} has come already: pick a time still to come.`,
    )
    return
  }

  await writeLee(host, at, UNSNOOZED, session => checkSnooze(session, { ask: asks, until }, now))
}

/** Lee's waking of a snoozed session, checked as the CLI checks it. */
const wake = (host: Host, at: SitrepSessionRef) => writeLee(host, at, 'Not woken', checkWake)

const WAKE: WakeSessionBody = { type: 'wakeSession' }

/**
 * Wakes the session the window holds where `isDue` finds what Lee snoozed
 * of it to wake at the moment, through the hold, so Claude reads its asks
 * waiting again with what comes next; nothing written otherwise.
 */
const wakeHeldIf = (host: Host, isDue: (session: Session, now: number) => boolean) =>
  serially(async () => {
    const now = await host.clock.now()

    return writeHeld(
      host,
      session => (isDue(session, now) ? [WAKE] : []),
      (session, lines) => post(host, lines),
    )
  })

/** Lee's own prompt in the window wakes what he snoozed of the session it holds, while it still holds: he has dealt with it. */
export const wakeByLeesPrompt = (host: Host) => wakeHeldIf(host, isAsleepAt)

/** The window's turn ending wakes the session it holds where Lee snoozed it until it moves; a snooze with a time sleeps through. */
export const wakeByTurnEnd = (host: Host) => wakeHeldIf(host, isUntilItMoves)

export const actionsOf = (host: Host): Actions => {
  const run = (what: string, act: () => Promise<unknown>) =>
    void act().catch(logFailure(host, what))

  return {
    select: id =>
      run('opening an item', () =>
        changePane(host, pane => ({ selected: pane.selected === id ? null : id })),
      ),
    show: (list, showing, hidden) =>
      run('showing the past', () => show(host, list, showing, hidden)),
    reply: reply => run('queuing a reply', () => queue(host, reply)),
    unqueue: (session, item) =>
      run('taking a reply back', () =>
        host.state.queue.update(replies => unqueuing(replies, session, item)),
      ),
    cancelAll: () =>
      run('cancelling every reply', async () => {
        const flights = await host.state.inFlight.read()

        await host.state.queue.update(replies => clearing(replies, flights))
      }),
    answer: (answering, text) =>
      run('answering in the prompt', () => answer(host, answering, text)),
    takeBack: send => run('taking a send back', () => takeBack(host, send)),
    showHeld: send =>
      run('stepping to the next held send', () => changePane(host, () => ({ heldShown: send }))),
    go: place => run('going elsewhere on the board', () => go(host, place)),
    close: () => run('closing the board', () => closeBoard(host)),
    finish: at => run('finishing a session', () => finish(host, at)),
    snooze: (at, asks, when) => run('snoozing a session', () => snooze(host, at, asks, when)),
    wake: at => run('waking a session', () => wake(host, at)),
  }
}
