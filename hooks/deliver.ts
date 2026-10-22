/**
 * Lee's replies, delivered to Claude as Lee's own message: Lee's send of
 * the held session's replies (send.ts), or the replies other sessions left
 * in its inbox (receive.ts). One message is in flight per window, whatever
 * its source, claimed in `$.state` before it is submitted. The claim holds
 * what it takes to write the message down: the session it goes to, the
 * writer that claimed it, its text, and the replies it carries, their ids
 * fixed.
 *
 * The window holds the message while the main conversation is mid-turn, and
 * submits it once it is between turns: at once when it is at the claim, else
 * as the turn ends, however it ends. Nothing takes a prompt back out of
 * Claude Code's queue, but a send the window holds Lee can take back: one
 * update of the claim decides between the two, so a send is taken back or
 * goes, never both.
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
 * Every change to the claim goes to the heartbeat as well, which says the
 * replies a send carries to its own session from the claim to its end, so
 * every reader has them on their way as soon as Lee sends them.
 */
import type { PromptOrigin, Timer } from 'claude-code'
import { deliveredMark, sentLines, type Body, type Session } from '../core'
import type { SitrepInFlight, SitrepSource } from '../types'
import { betweenTurns } from './activity'
import { logFailure, type Host } from './host'
import { writeInto } from './into'
import { isCarried } from './queue'
import { LINGER_MS, tickAfter } from './scene'
import { postKnown } from './seen'
import { attached, isHoldOn, refresh, sayInFlight, serially } from './window'

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
      await host.state.queue.update(queue => queue.filter(each => !isCarried(delivery, each)))
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

/** Has the heartbeat say what the message in flight carries now; never waited on. */
const say = (host: Host, inFlight: SitrepInFlight | null) =>
  void sayInFlight(host, inFlight).catch(logFailure(host, 'saying the message in flight'))

/** Changes the message in flight as `change` makes it of what stands, and has the heartbeat say it: the message as it then stands. */
const changeFlight = async (
  host: Host,
  change: (current: SitrepInFlight | null) => SitrepInFlight | null,
): Promise<SitrepInFlight | null> => {
  let after: SitrepInFlight | null = null

  await host.state.inFlight.update(current => (after = change(current)))
  say(host, after)

  return after
}

/** Ends the message in flight where `isEnding` says so; whether it did. */
const endIf = async (host: Host, isEnding: (current: SitrepInFlight) => boolean) => {
  let isEnded = false

  await changeFlight(host, current => {
    isEnded = current !== null && isEnding(current)

    return isEnded ? null : current
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

const isHeld = (delivery: SitrepInFlight) => isHoldOn(attached(), delivery)

/** Writes through the hold, so its own text stays in step: lines Claude knows of. False when the session no longer folds. */
const writeHeld = async (host: Host, delivery: SitrepInFlight) => {
  const session = await refresh(host)
  const lines = session === undefined ? [] : linesOf(session, delivery)

  if (session !== undefined && lines.length > 0) {
    await postKnown(host, session, lines)
  }

  return session !== undefined
}

/**
 * Writes a taken message down in the session it went to, then ends it; what
 * follows its claim's end follows once, by whichever write ended it. Two loads
 * may both write one down: a file-watch reload can cut short a write the
 * last load began once the submit resolved (settled live), and the next load
 * writes it again, finding its lines there or not.
 */
const writeDown = async (host: Host, delivery: SitrepInFlight) => {
  const isThere = await serially(() =>
    isHeld(delivery)
      ? writeHeld(host, delivery)
      : writeInto(host, delivery, session => linesOf(session, delivery)),
  )

  if (!isThere) {
    host.log(`sitrep: Claude has replies to ${delivery.session}, whose session.json is gone`)
  }

  await AFTER[delivery.source].written(host, delivery)

  if (await endIf(host, current => isClaim(current, delivery))) {
    await AFTER[delivery.source].ended(host, delivery)
  }
}

/** Marks the message in flight taken where `isIt` names it, and writes it down; nothing when it was heard already, or is held, never submitted. */
const heard = async (host: Host, isIt: (current: SitrepInFlight) => boolean) => {
  let taken: SitrepInFlight | undefined

  await changeFlight(host, current => {
    taken =
      current !== null && !current.isHeld && !current.isTaken && isIt(current)
        ? { ...current, isTaken: true }
        : undefined

    return taken ?? current
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
 * Carries the message in flight on, while the main conversation is between
 * turns as the window has heard it, and not while a turn runs, stopped on
 * Lee or not: one the window holds goes, a single update ending the hold,
 * so a take-back racing it lands first or finds it gone; and one submitted
 * and not taken, now or before, is let go once `QUIET_MS` pass with no turn
 * starting. The submit is not waited on: a hook waiting on its own submit
 * never ends, and one made as a turn ends starts a turn of its own about
 * 13 ms later (a live probe).
 *
 * Run at the claim, as a turn of the main conversation ends however it ends
 * (answered, stopped by Lee, failed, refused), as the conversation ends,
 * and as a load starts.
 */
export const carryOn = async (host: Host) => {
  const isBetween = await betweenTurns(host)
  let going: SitrepInFlight | undefined

  const after = await changeFlight(host, current => {
    going = current?.isHeld === true && isBetween() ? { ...current, isHeld: false } : undefined

    return going ?? current
  })

  if (after !== null && !after.isHeld && !after.isTaken && isBetween()) {
    quietFor(host, after)
  }

  if (going !== undefined) {
    void submit(host, going).catch(logFailure(host, 'submitting the message'))
  }
}

/**
 * Claims the window's one message in flight, held, and carries it on: it
 * goes at once while the main conversation is between turns, else as the
 * turn ends. `claimed` runs once it is claimed, before it is submitted, so
 * it never waits on Claude's turn or on Claude Code taking it. Gives back
 * the message already in flight, when one is, and then claims nothing.
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

  await changeFlight(host, current => {
    ahead = current ?? undefined

    return current ?? delivery
  })

  if (ahead !== undefined) {
    return ahead
  }

  await claimed().catch(logFailure(host, 'what follows a claimed send'))
  await carryOn(host)

  return undefined
}

/**
 * Takes back Lee's send while the window still holds it, unsubmitted: the
 * claim let go, its replies in Ready to send as they were before it, and
 * its asks waiting on Lee again. One update decides it against the send
 * going, so a send submitted already stays, as does the inbox's message,
 * which Lee sent from elsewhere. Whether it was taken back.
 */
export const takeBack = async (host: Host) => {
  const isBack = await endIf(host, current => current.source === 'send' && current.isHeld)

  if (isBack) {
    await foldAgain(host)
  }

  return isBack
}

/**
 * A turn starts: the window is no longer quiet, and a message submitted
 * whose text it carries has gone in. After a `/reload-plugins` typed
 * mid-turn the last load's submit never resolves (settled live), and this
 * is all that hears it.
 */
export const heardTurn = async (host: Host, text: string) => {
  turns += 1
  quiet?.cancel()
  await heard(host, current => current.text === text)
}

/** Writes down the message in flight when Claude Code has taken it: a write that failed, or one a reload cut short. */
export const writeTaken = async (host: Host) => {
  const delivery = await host.state.inFlight.read()

  if (delivery?.isTaken) {
    await writeDown(host, delivery)
  }
}

/**
 * A load starting: no quiet of an earlier one runs on, a message it left
 * taken is written down, and one it left otherwise is carried on, still
 * held while a turn runs. The heartbeat learns the message in flight from
 * the window's first need of it (window.ts), never from this read, which is
 * as old as the load's first hook and may predate a send claimed since.
 */
export const takeUpDelivery = async (host: Host) => {
  quiet?.cancel()
  quiet = undefined
  await writeTaken(host)
  await carryOn(host)
}
