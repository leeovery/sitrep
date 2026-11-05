/**
 * Lee's replies, delivered to Claude as Lee's own message: Lee's sends of
 * the held session's replies (send.ts), or the replies other sessions left
 * in its inbox (receive.ts). Each message is claimed in `$.state` before it
 * is submitted, the window's messages in flight kept in the order claimed. A
 * send is claimed behind the sends ahead of it, never behind the inbox's;
 * the inbox's only with nothing in flight. The claim holds what it takes to
 * write the message down: the session it goes to, the writer that claimed
 * it, its text, and the replies it carries, their ids fixed.
 *
 * The window holds each message while the main conversation is mid-turn, and
 * submits the first once it is between turns: at once when it is at the
 * claim, else as the turn ends, however it ends. The next is held until that
 * one has ended, and goes once the conversation is between turns again, so
 * each goes in as its own prompt, in the order claimed. Nothing takes a
 * prompt back out of Claude Code's queue, but a send the window holds Lee
 * can take back: one update of the claims decides between the two, so a
 * send is taken back or goes, never both.
 *
 * Claude Code taking it is heard from the submit resolving with no drop, or
 * from the turn it starts, whose text is the message's; whichever comes
 * first writes it down, into the session it went to, whatever the window
 * holds by then. Writing it down again finds its lines there and writes
 * nothing. A message refused is let go at once; one never heard is let go
 * once the window has been quiet a while without it since its submit. Either
 * way, and taken back, its replies are left as they were, for Lee's next
 * send or the inbox's next look.
 *
 * Every change to the claims goes to the heartbeat as well, which says the
 * replies each send carries to its own session from its claim to its end, so
 * every reader has them on their way as soon as Lee sends them.
 */
import type { PromptOrigin, Timer } from 'claude-code'
import { deliveredMark, sentLines, type Body, type Session } from '../core'
import type { SitrepInFlight, SitrepSource } from '../types'
import { betweenTurns } from './activity'
import { logFailure, type Host } from './host'
import { writeOwnFile } from './into'
import { isCarriedBy } from './queue'
import { LINGER_MS, tickAfter } from './scene'
import { postKnown } from './seen'
import { flightNow, refresh, sayInFlight, serially } from './window'

/** The name Claude Code knows the mod by: what a prompt it submitted carries as its origin. */
const PLUGIN = 'sitrep'

/** How long the band flashes the replies that came in. */
export const FLASH_MS = 5_000

/**
 * How long the window stays quiet after a submit, or after a turn, no other
 * turn starting, before a message never heard is let go. A prompt submitted
 * between turns starts its own turn about 13 ms after (live), and one
 * waiting behind a turn about 40 ms after that turn ends, once the prompt's
 * hooks have run, each plugin's held to its budget of seconds; one still
 * unheard this long after was never going in, so letting it go sends
 * nothing twice.
 */
export const QUIET_MS = 30_000

export const STILL_THERE = 'Your replies are still on the board.'

const UNWRITTEN = 'Claude has your replies, but the board could not write them down yet.'

const NEVER_WENT_IN = 'the message never went in'

/** The messages in flight as `$.state` keeps them: one alone, several in a list, none as null. */
type Stored = SitrepInFlight | SitrepInFlight[] | null

/** The messages in flight `$.state` kept, in the order claimed: one alone, as builds before several sends kept it, or a list. */
const listed = (kept: Stored): SitrepInFlight[] => {
  if (kept === null) {
    return []
  }

  return Array.isArray(kept) ? kept : [kept]
}

/**
 * The messages in flight as `$.state` kept them, each held only where it
 * says so: a load from before the window held messages (23 October 2026)
 * left its claim without `isHeld`, submitted as it was claimed.
 */
export const keptFlights = (kept: Stored): SitrepInFlight[] =>
  listed(kept).map(each => ({ ...each, isHeld: each.isHeld === true }))

/** The messages in flight as `$.state` keeps them: one alone, and none as null, as builds before several sends kept them, so a build switched back to still reads them. */
export const storedFlights = (flights: SitrepInFlight[]): Stored => {
  const [only, ...more] = flights

  if (only === undefined) {
    return null
  }

  return more.length === 0 ? only : flights
}

/** A message as its source hands it over, to be claimed. */
type Outgoing = Omit<SitrepInFlight, 'claimedAt' | 'isHeld' | 'isTaken'>

/**
 * What follows a message, by its source: `written`, as each write puts it
 * down, before its claim ends, so nothing in between shows it otherwise;
 * `ended`, once, as its claim ends; `notTaken`, once it went nowhere.
 */
type After = {
  written: (host: Host, delivery: SitrepInFlight) => Promise<void>
  ended: (host: Host, delivery: SitrepInFlight) => Promise<void>
  notTaken: (host: Host, why: string) => void
}

let flashing: Timer | undefined

let quiet: Timer | undefined

/** How many turns have started since this load began: a quiet that saw one start never lets go. */
let turns = 0

/** Whether a prompt is the board's own message: Lee's replies, from Ready to send or another session's inbox. */
export const isBoardMessage = (origin: PromptOrigin) =>
  origin.kind === 'plugin' && origin.name === PLUGIN

const flash = async (host: Host, count: number) => {
  flashing?.cancel()
  await host.state.flash.write(count)
  flashing = host.clock.after(
    FLASH_MS,
    () => void host.state.flash.write(0).catch(logFailure(host, 'the flash')),
  )
}

const AFTER: Record<SitrepSource, After> = {
  send: {
    // Out of the queue before the claim ends, or between the two the reply
    // Claude has shows in Ready to send as not sent, its ask answered by it.
    written: async (host, delivery) => {
      await host.state.queue.update(queue => queue.filter(each => !isCarriedBy(delivery, each)))
    },
    ended: async host => {
      tickAfter(host, LINGER_MS)
    },
    notTaken: (host, why) => host.ui.toast(`Not sent: ${why}. ${STILL_THERE}`),
  },
  inbox: {
    written: async () => {},
    ended: (host, delivery) => flash(host, delivery.replies.length),
    notTaken: (host, why) =>
      host.log(`sitrep: the inbox's replies were not taken (${why}); trying again`),
  },
}

const isClaim = (current: SitrepInFlight, delivery: SitrepInFlight) =>
  current.claimedAt === delivery.claimedAt && current.text === delivery.text

/** Has the heartbeat say what the messages in flight carry now; never waited on. */
const say = (host: Host, flights: SitrepInFlight[]) =>
  void sayInFlight(host, flights).catch(logFailure(host, 'saying the messages in flight'))

/** Changes the messages in flight as `change` makes them of what stands, and has the heartbeat say them. */
const changeFlight = async (
  host: Host,
  change: (flights: SitrepInFlight[]) => SitrepInFlight[],
) => {
  let after: SitrepInFlight[] = []

  await host.state.inFlight.update(flights => (after = change(flights)))
  say(host, after)
}

/** Ends each message in flight `isEnding` picks; whether it ended any. */
const endIf = async (host: Host, isEnding: (current: SitrepInFlight) => boolean) => {
  let isEnded = false

  await changeFlight(host, flights => {
    const left = flights.filter(each => !isEnding(each))

    isEnded = left.length < flights.length

    return isEnded ? left : flights
  })

  return isEnded
}

/**
 * Folds the held session again as a claim ends unwritten, once the heartbeat
 * says it no more: the rewrite waits ahead of this on the window's queue. So
 * a send's replies wait on Lee again at once, not on their way, its own
 * answer barring them, until the watch's next look.
 */
const foldAgain = (host: Host) => serially(() => refresh(host))

/** Lets go of a message Claude Code has not taken, its replies left as they were. */
const release = async (host: Host, delivery: SitrepInFlight, why: string) => {
  if (await endIf(host, current => isClaim(current, delivery) && !current.isTaken)) {
    AFTER[delivery.source].notTaken(host, why)
    await foldAgain(host)
  }
}

/** The lines a taken message is written down as, in its session as it stands: none once they are there. */
const linesOf = (session: Session, delivery: SitrepInFlight): Body[] =>
  delivery.source === 'send'
    ? sentLines(session, delivery.replies)
    : deliveredMark(
        session,
        delivery.replies.map(reply => reply.id),
      )

/**
 * Writes a taken message down in the session it went to, then ends it; what
 * follows its claim's end follows once, by whichever write ended it. Two loads
 * may both write one down: a file-watch reload can cut short a write the
 * last load began once the submit resolved (settled live), and the next load
 * writes it again, finding its lines there or not.
 */
const writeDown = async (host: Host, delivery: SitrepInFlight) => {
  // Through the hold, as lines Claude knows of: the replies it has just been sent.
  const isThere = await writeOwnFile(
    host,
    delivery,
    session => linesOf(session, delivery),
    (session, lines) => postKnown(host, session, lines),
  )

  if (!isThere) {
    host.log(`sitrep: Claude has replies to ${delivery.session}, whose session.json is gone`)
  }

  await AFTER[delivery.source].written(host, delivery)

  if (await endIf(host, current => isClaim(current, delivery))) {
    await AFTER[delivery.source].ended(host, delivery)
  }
}

/**
 * Marks the message in flight `isIt` names taken, and writes it down;
 * nothing when it was heard already, or is held, never submitted, and no
 * write where the window knows of no such message, as at a turn starting
 * with another prompt.
 */
const heard = async (host: Host, isIt: (current: SitrepInFlight) => boolean) => {
  const isHeard = (current: SitrepInFlight) => !current.isHeld && !current.isTaken && isIt(current)
  let taken: SitrepInFlight | undefined

  if (!(await flightNow(host)).some(isHeard)) {
    return
  }

  await changeFlight(host, flights => {
    taken = undefined

    return flights.map(each => {
      if (taken !== undefined || !isHeard(each)) {
        return each
      }

      taken = { ...each, isTaken: true }

      return taken
    })
  })

  if (taken === undefined) {
    return
  }

  const delivery = taken

  await writeDown(host, delivery).catch(error => {
    logFailure(host, 'writing down the replies Claude has')(error)

    if (delivery.source === 'send') {
      host.ui.toast(UNWRITTEN)
    }
  })
}

/** Submits the message: undefined once Claude Code takes it, else why it did not. */
const refusalOf = async (host: Host, text: string) => {
  try {
    return (await host.prompt.submit(text)).drop
  } catch {
    return 'Claude Code refused it'
  }
}

/** Submits a message the window no longer holds: written down once Claude Code takes it, let go if refused. */
const submit = async (host: Host, delivery: SitrepInFlight) => {
  const refusal = await refusalOf(host, delivery.text)

  if (refusal === undefined) {
    await heard(host, current => isClaim(current, delivery))
  } else {
    await release(host, delivery, refusal)
  }
}

/** Lets a message submitted go once `QUIET_MS` pass with no turn starting, unless it was taken by then; a quiet counted before is done with. */
const quietFor = (host: Host, waiting: SitrepInFlight) => {
  const at = turns

  quiet?.cancel()
  quiet = host.clock.after(QUIET_MS, () => {
    if (turns === at) {
      void release(host, waiting, NEVER_WENT_IN).catch(logFailure(host, 'letting a message go'))
    }
  })
}

/**
 * Submits the first message in flight while the window holds it, should the
 * main conversation be between turns as the window has heard it, and not
 * while a turn runs, stopped on Lee or not. One behind a message submitted
 * and not yet ended stays held: it goes once that one has, at the next
 * between turns. A single update ends the hold, so a take-back racing it
 * lands first or finds it gone, and its quiet counts from the submit. With
 * nothing held first, as the window knows its claims, it writes nothing. The
 * submit is not waited on: a hook waiting on its own submit never ends, and
 * one made as a turn ends starts a turn of its own about 13 ms later (a live
 * probe). Whether it submitted one.
 *
 * Run at the claim, and at each look, for a message held between turns: its
 * update as the turn ended failed, no load ran it then, or the message ahead
 * of it ended since.
 */
export const sendHeld = async (host: Host) => {
  const isBetween = await betweenTurns(host)
  const isGoing = (flights: readonly SitrepInFlight[]) =>
    flights[0]?.isHeld === true && isBetween()

  if (!isGoing(await flightNow(host))) {
    return false
  }

  let going: SitrepInFlight | undefined

  await changeFlight(host, flights => {
    const [first, ...behind] = flights

    going = first !== undefined && isGoing(flights) ? { ...first, isHeld: false } : undefined

    return going === undefined ? flights : [going, ...behind]
  })

  if (going === undefined) {
    return false
  }

  quietFor(host, going)
  void submit(host, going).catch(logFailure(host, 'submitting the message'))

  return true
}

/**
 * Carries the messages in flight on as the main conversation comes to be
 * between turns: a turn of it ending however it ends (answered, stopped by
 * Lee, failed, refused), a `/clear`, or a load starting. The first goes
 * while the window holds it (`sendHeld`); submitted before and not taken,
 * it is let go once `QUIET_MS` pass with no turn starting. Nothing while a
 * turn runs.
 */
export const carryOn = async (host: Host) => {
  if (await sendHeld(host)) {
    return
  }

  const [first] = await flightNow(host)
  const isBetween = await betweenTurns(host)

  if (first !== undefined && !first.isHeld && !first.isTaken && isBetween()) {
    quietFor(host, first)
  }
}

/**
 * The message in flight a message is not claimed behind: for the inbox's,
 * any, since a look takes in nothing more while one is in flight; for a
 * send, the inbox's, or a send carrying a reply of its already, as a second
 * press of send meets the first's.
 */
const aheadOf = (flights: readonly SitrepInFlight[], outgoing: Outgoing) =>
  outgoing.source === 'inbox'
    ? flights[0]
    : flights.find(
        each =>
          each.source === 'inbox' ||
          outgoing.replies.some(({ item }) =>
            isCarriedBy(each, { session: outgoing.session, item }),
          ),
      )

/**
 * Claims a message, held behind any in flight, and sends it at once while it
 * is the first and the main conversation is between turns, else as its turn
 * comes. `claimed` runs once it is claimed, before it is submitted, so it
 * never waits on Claude's turn or on Claude Code taking it. Gives back the
 * message in flight it is not claimed behind (`aheadOf`), when there is one,
 * and then claims nothing.
 */
export const deliver = async (
  host: Host,
  outgoing: Outgoing,
  claimed: () => Promise<void> = async () => {},
) => {
  const delivery: SitrepInFlight = {
    ...outgoing,
    claimedAt: await host.clock.now(),
    isHeld: true,
    isTaken: false,
  }
  let ahead: SitrepInFlight | undefined

  await changeFlight(host, flights => {
    ahead = aheadOf(flights, outgoing)

    return ahead === undefined ? [...flights, delivery] : flights
  })

  if (ahead !== undefined) {
    return ahead
  }

  await claimed().catch(logFailure(host, 'what follows a claimed send'))
  await sendHeld(host)

  return undefined
}

/**
 * Lets go of each message the window holds, unsubmitted, that `isIt` picks:
 * its replies left as they were, a send's in Ready to send and the inbox's
 * in the inbox, and its asks waiting on Lee again. One update decides it
 * against the message going, so one submitted already stays; where the
 * window knows of none held, nothing is written. Whether it let one go.
 */
const letGoHeld = async (host: Host, isIt: (current: SitrepInFlight) => boolean) => {
  const isPicked = (current: SitrepInFlight) => current.isHeld && isIt(current)

  if (!(await flightNow(host)).some(isPicked)) {
    return false
  }

  const isLet = await endIf(host, isPicked)

  if (isLet) {
    await foldAgain(host)
  }

  return isLet
}

/** Takes back one send of Lee's while the window still holds it, any behind it held still; never the inbox's message, which Lee sent from elsewhere. Whether it was taken back. */
export const takeBack = (host: Host, send: SitrepInFlight) =>
  letGoHeld(host, current => current.source === 'send' && isClaim(current, send))

/**
 * The conversation ending, which ends any turn of it. After a `/clear` the
 * process goes on with the next conversation, so the messages the window
 * holds go into it, as a prompt queued across a `/clear` goes in after.
 * Any other end leaves no conversation for them: a resume puts another in
 * this one's place, which their replies are not for, and an exit or a
 * logout ends the process. So there each is let go, as a take-back lets it
 * go, and nothing is submitted. One submitted already is Claude Code's, its
 * quiet counted as at a turn's end.
 */
export const conversationEnded = async (host: Host, isCleared: boolean) => {
  if (!isCleared) {
    await letGoHeld(host, () => true)
  }

  await carryOn(host)
}

/**
 * The window's turn starts: it is no longer quiet, and a message submitted
 * whose text it carries has gone in. After a `/reload-plugins` typed
 * mid-turn the last load's submit never resolves (settled live), and this
 * is all that hears it.
 */
export const heardTurn = async (host: Host, text: string) => {
  turns += 1
  quiet?.cancel()
  await heard(host, current => current.text === text)
}

/** Writes down the message in flight Claude Code has taken: a write that failed, or one a reload cut short. */
export const writeTaken = async (host: Host) => {
  const delivery = (await host.state.inFlight.read()).find(each => each.isTaken)

  if (delivery !== undefined) {
    await writeDown(host, delivery)
  }
}

/**
 * A load starting: no quiet of an earlier one runs on, a message it left
 * taken is written down, and those it left otherwise are carried on, still
 * held while a turn runs. The heartbeat learns the messages in flight from
 * the window's first need of them (window.ts), never from `writeTaken`'s
 * read, which is as old as the load's first hook and may predate a send
 * claimed since.
 */
export const takeUpDelivery = async (host: Host) => {
  quiet?.cancel()
  quiet = undefined
  await writeTaken(host)
  await carryOn(host)
}
