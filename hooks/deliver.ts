/**
 * Lee's replies, delivered to Claude as Lee's own message: Lee's send of
 * the held session's replies (send.ts), or the replies other sessions left
 * in its inbox (receive.ts). One message is in flight per window, whatever
 * its source, claimed in `$.state` before it is submitted. The claim holds
 * what it takes to write the message down: the session it goes to, the
 * writer that claimed it, its text, and the replies it carries, their ids
 * fixed.
 *
 * Claude Code taking it is heard from the submit resolving with no drop, or
 * from the turn it starts, whose text is the message's; whichever comes
 * first writes it down, into the session it went to, whatever the window
 * holds by then, a send's replies as of its claim (`sentAt`). Writing it
 * down again finds its lines there and writes nothing. A message refused is
 * let go at once; one never heard is let go once the window has gone quiet
 * without it. Either way its replies are left as they were, for Lee's next
 * send or the inbox's next look.
 */
import type { PromptOrigin, Timer } from 'claude-code'
import { deliveredMark, sentAt, sentLines, type Body, type Session, type Stamp } from '../core'
import type { SitrepInFlight, SitrepSource } from '../types'
import { logFailure, type Host } from './host'
import { writeInto } from './into'
import { isCarried } from './queue'
import { LINGER_MS, tickAfter } from './scene'
import { postKnown } from './seen'
import { attached, refresh, serially } from './window'

/** The name Claude Code knows the mod by: what a prompt it submitted carries as its origin. */
const PLUGIN = 'sitrep'

/** How long the band flashes the replies that came in. */
export const FLASH_MS = 5_000

/**
 * How long the window stays quiet after a turn, no other turn starting,
 * before a message never heard is let go. A prompt waiting behind a turn
 * starts its own about 40 ms after that turn ends (live), once the prompt's
 * hooks have run, each plugin's held to its budget of seconds; one still
 * unheard this long after was never going in, so letting it go sends
 * nothing twice.
 */
export const QUIET_MS = 30_000

export const STILL_THERE = 'Your replies are still on the board.'

const UNWRITTEN = 'Claude has your replies, but the board could not write them down yet.'

const NEVER_WENT_IN = 'the message never went in'

/** A message as its source hands it over, to be claimed. */
type Outgoing = Omit<SitrepInFlight, 'claimedAt' | 'isTaken'>

/** What follows a message, by its source: once it is written down, and once it went nowhere. */
type After = {
  written: (host: Host, delivery: SitrepInFlight) => Promise<void>
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
    written: async (host, delivery) => {
      await host.state.queue.update(queue => queue.filter(each => !isCarried(delivery, each)))
      tickAfter(host, LINGER_MS)
    },
    notTaken: (host, why) => host.ui.toast(`Not sent: ${why}. ${STILL_THERE}`),
  },
  inbox: {
    written: (host, delivery) => flash(host, delivery.replies.length),
    notTaken: (host, why) =>
      host.log(`sitrep: the inbox's replies were not taken (${why}); trying again`),
  },
}

const isClaim = (current: SitrepInFlight, delivery: SitrepInFlight) =>
  current.claimedAt === delivery.claimedAt && current.text === delivery.text

/** Ends the message in flight where `isEnding` says so; whether it did. */
const endIf = async (host: Host, isEnding: (current: SitrepInFlight) => boolean) => {
  let isEnded = false

  await host.state.inFlight.update(current => {
    isEnded = current !== null && isEnding(current)

    return isEnded ? null : current
  })

  return isEnded
}

/** Lets go of a message Claude Code has not taken, its replies left as they were. */
const release = async (host: Host, delivery: SitrepInFlight, why: string) => {
  if (await endIf(host, current => isClaim(current, delivery) && !current.isTaken)) {
    AFTER[delivery.source].notTaken(host, why)
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

const isHeld = (delivery: SitrepInFlight) => {
  const held = attached()

  return (
    held?.project === delivery.project &&
    held.session === delivery.session &&
    held.writer === delivery.writer
  )
}

/** Writes through the hold, so its own text stays in step: lines Claude knows of. False when the session no longer folds. */
const writeHeld = async (host: Host, delivery: SitrepInFlight, at: Stamp) => {
  const session = await refresh(host)
  const lines = session === undefined ? [] : linesOf(session, delivery)

  if (session !== undefined && lines.length > 0) {
    await postKnown(host, session, lines, at)
  }

  return session !== undefined
}

/**
 * Writes a taken message down in the session it went to, then ends it; what
 * follows its source follows once, by whichever write ended it. Two loads
 * may both write one down: a file-watch reload can cut short a write the
 * last load began once the submit resolved (settled live), and the next load
 * writes it again, finding its lines there or not.
 */
const writeDown = async (host: Host, delivery: SitrepInFlight) => {
  const isThere = await serially(async () => {
    const at = sentAt(delivery.claimedAt, await host.clock.now())

    return isHeld(delivery)
      ? writeHeld(host, delivery, at)
      : writeInto(host, delivery, session => linesOf(session, delivery), at)
  })

  if (!isThere) {
    host.log(`sitrep: Claude has replies to ${delivery.session}, whose session.json is gone`)
  }

  if (await endIf(host, current => isClaim(current, delivery))) {
    await AFTER[delivery.source].written(host, delivery)
  }
}

/** Marks the message in flight taken where `isIt` names it, and writes it down; nothing when it was heard already. */
const heard = async (host: Host, isIt: (current: SitrepInFlight) => boolean) => {
  let taken: SitrepInFlight | undefined

  await host.state.inFlight.update(current => {
    taken =
      current !== null && !current.isTaken && isIt(current)
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

/**
 * Claims the window's one message in flight and submits it, waiting out
 * any turn of Claude's it waits behind. `claimed` runs once it is claimed,
 * before it is submitted, so it never waits on Claude Code taking it. Gives
 * back the message already in flight, when one is, and then submits nothing.
 */
export const deliver = async (
  host: Host,
  outgoing: Outgoing,
  claimed: () => Promise<void> = async () => {},
) => {
  const delivery: SitrepInFlight = {
    ...outgoing,
    claimedAt: await host.clock.now(),
    isTaken: false,
  }
  let ahead: SitrepInFlight | undefined

  await host.state.inFlight.update(current => {
    ahead = current ?? undefined

    return current ?? delivery
  })

  if (ahead !== undefined) {
    return ahead
  }

  await claimed().catch(logFailure(host, 'what follows a claimed send'))

  const refusal = await refusalOf(host, delivery.text)

  if (refusal === undefined) {
    await heard(host, current => isClaim(current, delivery))
  } else {
    await release(host, delivery, refusal)
  }

  return undefined
}

/**
 * A turn starts: the window is no longer quiet, and a message whose text
 * it carries has gone in. After a `/reload-plugins` typed mid-turn the last
 * load's submit never resolves (settled live), and this is all that hears it.
 */
export const heardTurn = async (host: Host, text: string) => {
  turns += 1
  quiet?.cancel()
  await heard(host, current => current.text === text)
}

/**
 * The window went quiet: a turn of the main conversation ended, or the
 * conversation did. A message not taken by then is let go once `QUIET_MS`
 * pass with no turn starting; one claimed later is another claim, left be.
 */
export const wentQuiet = async (host: Host) => {
  const at = turns
  const waiting = await host.state.inFlight.read()

  if (waiting === null || waiting.isTaken) {
    return
  }

  quiet?.cancel()
  quiet = host.clock.after(QUIET_MS, () => {
    if (turns === at) {
      void release(host, waiting, NEVER_WENT_IN).catch(logFailure(host, 'letting a message go'))
    }
  })
}

/** Writes down the message in flight when Claude Code has taken it: a write that failed, or one a reload cut short. */
export const writeTaken = async (host: Host) => {
  const delivery = await host.state.inFlight.read()

  if (delivery?.isTaken) {
    await writeDown(host, delivery)
  }
}

/** A load starting: no quiet of an earlier one runs on, and a message it left taken is written down. */
export const takeUpDelivery = async (host: Host) => {
  quiet?.cancel()
  quiet = undefined
  await writeTaken(host)
}
