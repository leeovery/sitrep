/**
 * What the board's buttons do, bound to the host. A press does not wait on
 * its work, so each act runs in its own time and writes to the debug log
 * what failed.
 */
import {
  checkDrop,
  checkFinish,
  checkSnoozeAsk,
  checkWakeAsk,
  heldSnooze,
  isSessionAsleepAt,
  isUntilItMoves,
  snoozeAt,
  wakeWords,
  type Body,
  type Checked,
  type ProjectKey,
  type Session,
  type SnoozeChoice,
  type WakeSessionBody,
} from '../core'
import type {
  SessionKey,
  SitrepAnswering,
  SitrepInFlight,
  SitrepItemRef,
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
import { inFolder } from './folders'
import { logFailure, rootFor, type Host } from './host'
import { writeHeld, writeInto, writeOwnFile } from './into'
import { isProjectList } from './lists'
import { changeQueue } from './media'
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
  reply: (reply: SitrepQueued<ProjectKey>) => void
  /** Takes the reply to one item out of the queue. */
  unqueue: (session: string, item: string) => void
  /** Empties the queue, but for what the sends in flight carry. */
  cancelAll: () => void
  /** Has the next Enter in the prompt box answer an ask, comment on it, or add a comment to a pick-up; `text` fills the box first, to edit the words already queued. */
  answer: (answering: SitrepAnswering<SessionKey>, text?: string) => void
  /** Takes back a send the window holds for its turn, its replies back in Ready to send among those still to send; none once it has gone. */
  takeBack: (send: SitrepInFlight) => void
  /** Has Ready to send's one row for several held sends show the one named, by the ids of the replies it carries. */
  showHeld: (send: string) => void
  /** Takes the board somewhere in the tree, at its top there: elsewhere, or where it already is. */
  go: (place: SitrepPlace<ProjectKey>) => void
  /** Closes the board, by its own close where it sits inline. */
  close: () => void
  /** Finishes another session, as Lee confirmed on its view, and takes the board up off it, to the project the view showed it in. */
  finish: (at: SitrepSessionRef<ProjectKey>) => void
  /** Snoozes an ask alone until the time Lee chose, worked out at the press, the ask closed on the board. */
  snooze: (at: SitrepItemRef<ProjectKey>, when: SnoozeChoice) => void
  /** Wakes a snoozed ask now: the ask alone where its own snooze holds it, its session where the session's does. */
  wake: (at: SitrepItemRef<ProjectKey>) => void
  /** Drops a parked item, as Lee confirmed on its row: off Parked, with nothing sent to Claude. */
  drop: (at: SitrepItemRef<ProjectKey>) => void
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

/** Has another session read afresh, off the board or not, for the board to draw what Lee did to it; the held one is the watch's. */
const readIfElsewhere = async (host: Host, { session }: Pick<SitrepSessionRef, 'session'>) => {
  if (session !== attached()?.session) {
    await lookAround(host, [session])
  }
}

/** Why a press wrote nothing, its session no longer there to write into. */
const GONE = 'its session is no longer on the board.'

/**
 * A ref a press carries as the window keeps it: naming the folder the
 * session's files are in, found by its id, where the view that drew it
 * named the project it shows the session in. Every press that keeps a ref,
 * or writes by one, comes through here. None where no folder holds the
 * session, a toast saying why after `refused`.
 */
const kept = async <T extends SitrepSessionRef<SessionKey>>(host: Host, at: T, refused: string) => {
  const keeping = await inFolder(host, await rootFor(host), at)

  if (keeping === undefined) {
    host.ui.toast(`${refused}: ${GONE}`)
  }

  return keeping
}

const UNQUEUED = 'Not queued'

/** Queues a reply; one to another session has that session read, for Ready to send to draw it. */
const queue = async (host: Host, reply: SitrepQueued<ProjectKey>) => {
  const keeping = await kept(host, reply, UNQUEUED)

  if (keeping !== undefined) {
    await changeQueue(host, replies => queuing(replies, keeping))
    await readIfElsewhere(host, reply)
  }
}

/**
 * Has the next Enter write to an item, the mode standing from the press on
 * the item as drawn; one of another session's has that session read in
 * full, so the mode is checked against all of it, not only its project's
 * briefs.
 */
const answer = async (host: Host, answering: SitrepAnswering<SessionKey>, text?: string) => {
  const keeping = await kept(host, answering, UNQUEUED)

  if (keeping !== undefined) {
    await beginAnswering(host, keeping, text)
    await readIfElsewhere(host, answering)
  }
}

/** The board on a place, nothing opened there, at its top, and what it shows read, the sessions `fresh` names afresh; a session no folder holds, nowhere. */
const go = async (host: Host, to: SitrepPlace<ProjectKey>, fresh: readonly string[] = []) => {
  const place = to.level === 'session' ? await kept(host, to, 'Not shown') : to

  if (place !== undefined) {
    await changePane(host, () => ({ place, selected: null }))
    await fromTheTop(host)
    await lookAround(host, fresh)
  }
}

/** Lee's finish: a line in this window's own file in the session, none once it is finished already. */
const finishing = (session: Session) => {
  const checked = checkFinish(session, 'lee')

  return checked.ok ? [checked.value] : []
}

/** Finishes a session the window does not hold, then goes up to the project the view `at` was drawn on shows it in, where it no longer shows, the session read afresh, as one idle past the views is read only on a whole look. */
const finish = async (host: Host, at: SitrepSessionRef<ProjectKey>) => {
  const keeping = await kept(host, at, 'Not finished')

  if (keeping !== undefined) {
    const into = { ...keeping, writer: await host.conversation.id() }

    await serially(() => writeInto(host, into, finishing))
  }

  await go(host, projectPlace(at.project), [at.session])
}

/** A check of Lee's press against an ask's session as it stands: the line it writes, or why it is refused. */
type Check = (session: Session) => Checked<Body>

/**
 * Writes what Lee's press makes of an ask's session as it stands into this
 * window's own file there, as checked; through the hold, a change Claude
 * did not make, so it rides into its next turn. A refusal, or a session no
 * longer there, writes nothing, a toast saying why after `refused`. Another
 * session is read again after.
 */
const writeLee = async (
  host: Host,
  at: SitrepSessionRef<ProjectKey>,
  refused: string,
  check: Check,
) => {
  const keeping = await kept(host, at, refused)

  if (keeping === undefined) {
    return
  }

  const into = { ...keeping, writer: await host.conversation.id() }
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
 * Lee's snooze of one ask, its time worked out at the press from the
 * settings as the pane last read them, checked against its session as it
 * stands. A time come already, Tonight drawn before its time and pressed
 * after, writes nothing, a toast saying why, and the question stays open,
 * drawn with what is offered now, or gives way to the ask's buttons where
 * nothing is.
 */
const snooze = async (host: Host, at: SitrepItemRef<ProjectKey>, when: SnoozeChoice) => {
  const [now, settings] = await Promise.all([host.clock.now(), host.state.snooze.read()])
  const until = snoozeAt(when, now, heldSnooze(settings))

  if (until <= now) {
    host.ui.toast(`${UNSNOOZED}: ${wakeWords(until, now)} has come already.`)
    return
  }

  await changePane(host, () => ({ selected: null }))
  await writeLee(host, at, UNSNOOZED, session => checkSnoozeAsk(session, at.item, until, now))
}

/** Lee's waking of a snoozed ask, checked against its session as it stands. */
const wake = (host: Host, at: SitrepItemRef<ProjectKey>) =>
  writeLee(host, at, 'Not woken', session => checkWakeAsk(session, at.item))

/**
 * Lee's drop of a parked item, checked against the session that parked it
 * as it stands, and written there, in this window's own file: through the
 * hold where that is the held session, so Claude reads its board changed.
 */
const drop = async (host: Host, at: SitrepItemRef<ProjectKey>) => {
  await changePane(host, () => ({ selected: null }))
  await writeLee(host, at, 'Not dropped', session => checkDrop(session, at.item))
}

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

/** Lee's own prompt in the window wakes his snooze of the session it holds, while it still holds: he has dealt with it. An ask he snoozed on its own sleeps on. */
export const wakeByLeesPrompt = (host: Host) => wakeHeldIf(host, isSessionAsleepAt)

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
        changeQueue(host, replies => unqueuing(replies, session, item)),
      ),
    cancelAll: () =>
      run('cancelling every reply', async () => {
        const flights = await host.state.inFlight.read()

        await changeQueue(host, replies => clearing(replies, flights))
      }),
    answer: (answering, text) =>
      run('answering in the prompt', () => answer(host, answering, text)),
    takeBack: send => run('taking a send back', () => takeBack(host, send)),
    showHeld: send =>
      run('stepping to the next held send', () => changePane(host, () => ({ heldShown: send }))),
    go: place => run('going elsewhere on the board', () => go(host, place)),
    close: () => run('closing the board', () => closeBoard(host)),
    finish: at => run('finishing a session', () => finish(host, at)),
    snooze: (at, when) => run('snoozing an ask', () => snooze(host, at, when)),
    wake: at => run('waking an ask', () => wake(host, at)),
    drop: at => run('dropping a parked item', () => drop(host, at)),
  }
}
