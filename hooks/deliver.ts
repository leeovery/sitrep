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
 * holds by then, and a pick-up of an item another session of its project
 * parked into that session. Writing it down again finds its lines there and
 * writes nothing. A message refused is let go at once; one never heard is
 * let go once the window has been quiet a while without it since its
 * submit. Either way, and taken back, its replies are left as they were,
 * for Lee's next send or the inbox's next look. One refused because Lee
 * stopped Claude's turn is held again instead, and the window marked
 * stopped: nothing is submitted until Lee's input is heard, or he presses
 * send or send now, whose submit carries his press.
 *
 * Every change to the claims goes to the heartbeat as well, which says the
 * replies each send carries to its own session from its claim to its end, so
 * every reader has them on their way as soon as Lee sends them.
 */
import type { PromptOrigin, Timer } from 'claude-code'
import { deliveredMark, isObject, sentLines, type Body, type Session } from '../core'
import type {
  SitrepInFlight,
  SitrepQueued,
  SitrepReplyBody,
  SitrepSource,
  SitrepStoredFlights,
} from '../types'
import { betweenTurns } from './activity'
import { lookAround } from './around'
import { logFailure, type Host } from './host'
import { writeHeld, writeInto, type Into } from './into'
import { isCarriedBy, namedIn, queuing, repliedTo, unqueuing } from './queue'
import { LINGER_MS, tickAfter } from './scene'
import { changedKnown, postKnown, type ChangedThere } from './seen'
import {
  attached,
  dropPickUpsElsewhere,
  flightNow,
  isHoldOn,
  refresh,
  sayInFlight,
  serially,
} from './window'

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

/** Why an answer that went with Lee's prompt is gone from the board: it never went in, and its image went with the prompt. */
export const RIDE_LOST = "Your answer with the image didn't go in: write it again."

const UNWRITTEN = 'Claude has your replies, but the board could not write them down yet.'

const NEVER_WENT_IN = 'the message never went in'

/**
 * Claude Code's refusal of every plugin's prompt once Lee has stopped
 * Claude's turn, until he next sends input in the window: proven live 5
 * November 2026, Claude Code 2.1.318, whose `$.prompt.submit` gives the
 * reason as text alone.
 */
const STOPPED = 'the session was stopped and nobody has sent input since'

const isStoppedRefusal = (refusal: string) => refusal.includes(STOPPED)

/** The messages in flight `$.state` kept, in the order claimed: one alone, as builds before several sends kept it, or a list. */
const listed = (kept: SitrepStoredFlights): unknown[] => {
  if (kept === null) {
    return []
  }

  return Array.isArray(kept) ? kept : [kept]
}

/**
 * Whether a value `$.state` kept reads as a claim. A build before several
 * sends, switched back to, reads a list as one claim spread into an object
 * (`{ 0: …, 1: …, isHeld: false }`), which an update of its writes back: no
 * claim, and never read as one, nor as the claims inside it, whose replies
 * that build let Lee cancel or send again.
 */
const isClaimShaped = (value: unknown): value is SitrepInFlight =>
  isObject(value) &&
  (value.source === 'send' || value.source === 'inbox') &&
  typeof value.project === 'string' &&
  typeof value.session === 'string' &&
  typeof value.writer === 'string' &&
  typeof value.text === 'string' &&
  typeof value.claimedAt === 'number' &&
  Array.isArray(value.replies)

/**
 * The messages in flight as `$.state` kept them, each held only where it
 * says so: a load from before the window held messages (23 October 2026)
 * left its claim without `isHeld`, submitted as it was claimed.
 */
export const keptFlights = (kept: SitrepStoredFlights): SitrepInFlight[] =>
  listed(kept)
    .filter(isClaimShaped)
    .map(each => ({ ...each, isHeld: each.isHeld === true }))

/** The messages in flight as `$.state` keeps them: one alone, and none as null, as builds before several sends kept them, so a build switched back to still reads them. */
export const storedFlights = (flights: SitrepInFlight[]): SitrepStoredFlights => {
  const [only, ...more] = flights

  if (only === undefined) {
    return null
  }

  return more.length === 0 ? only : flights
}

/** A message as its source hands it over, to be claimed. */
export type Outgoing = Omit<SitrepInFlight, 'claimedAt' | 'isHeld' | 'isTaken'>

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

/** How often Lee's input has been heard since this load began: a refusal of a submit made before the latest is stale. */
let inputs = 0

/** How many slash commands Lee typed are running: nothing is submitted meanwhile. */
let commands = 0

/**
 * The message this load last submitted, or the answer it last let in with
 * Lee's prompt, by its text, while its turn is yet to be heard starting, and
 * the quiet that stops the wait should that start never be heard. Its submit
 * can resolve, and write it down, a few milliseconds before its turn's start
 * is heard, so the window would seem between turns meanwhile: no message
 * goes after it until its own turn starts, another's never counting, it is
 * let go, or the quiet passes. The quiet counts only from a moment between
 * turns: Lee's prompt typed while a turn runs waits in Claude Code's queue
 * until that turn ends, or is folded into it and starts no turn of its own.
 */
let awaiting: { text: string; quiet?: Timer } | undefined

/** Counts the wait's quiet from now, unless it counts one already. */
const quietAwaiting = (host: Host) => {
  const waiting = awaiting

  if (waiting === undefined || waiting.quiet !== undefined) {
    return
  }

  waiting.quiet = host.clock.after(QUIET_MS, () => {
    if (awaiting === waiting) {
      awaiting = undefined
    }
  })
}

const awaitTurn = (host: Host, text: string, isBetween: boolean) => {
  awaiting?.quiet?.cancel()
  awaiting = { text }

  if (isBetween) {
    quietAwaiting(host)
  }
}

const stopAwaiting = () => {
  awaiting?.quiet?.cancel()
  awaiting = undefined
}

/** A claim's identity, as `isClaim` compares claims. */
const claimKey = ({ claimedAt, text }: SitrepInFlight) => `${claimedAt}\n${text}`

/**
 * The answers this load claimed as they went in with Lee's own prompt
 * (`claimRide`), while the hook that let each in waits on Claude Code: no
 * quiet lets one go meanwhile, since Claude Code, not the window, delivers
 * it. One a load or the conversation's end leaves behind waits as any
 * message submitted and not yet heard.
 */
const hooked = new Set<string>()

const isHooked = (current: SitrepInFlight) => hooked.has(claimKey(current))

/** Whether a prompt is the board's own message: Lee's replies, from Ready to send or another session's inbox. */
export const isBoardMessage = (origin: PromptOrigin) =>
  origin.kind === 'plugin' && origin.name === PLUGIN

/**
 * Whether a prompt or a slash command is Lee's own input: typed at the
 * terminal, or sent from the Remote Control bridge. Claude Code 2.1.318
 * gives both of its human origin these names, and only that origin lifts
 * its refusal after a stop.
 */
export const isLeesInput = (origin: PromptOrigin) =>
  origin.kind === 'composer' || origin.kind === 'bridge'

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

/** Whether `current` is the claim of a message submitted and not yet heard taken. */
const isUnheard = (current: SitrepInFlight, delivery: SitrepInFlight) =>
  isClaim(current, delivery) && !current.isHeld && !current.isTaken

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
 * What follows a claim ending unwritten. The held session is folded again
 * once the heartbeat says the claim no more: the rewrite waits ahead of this
 * on the window's queue. So a send's replies wait on Lee again at once, not
 * on their way, its own answer barring them, until the watch's next look.
 * And a pick-up it carried leaves Ready to send where the window has since
 * taken up a session of another project than the item's.
 */
const endedUnwritten = async (host: Host) => {
  await serially(() => refresh(host))
  await dropPickUpsElsewhere(host)
}

/** The messages in flight less the one at `at` and every one held behind it. */
const lessFrom = (flights: SitrepInFlight[], at: number) =>
  flights.filter((each, i) => i < at || (i > at && !each.isHeld))

/**
 * Lets go of a message Claude Code has not taken, refused or never heard,
 * and every send held behind it in the same update, one toast saying so:
 * none goes in ahead of the replies it would have followed, and none is
 * spent on a refusal sure to come again. Their replies are left as they
 * were, in the order Lee made them.
 */
const release = async (host: Host, delivery: SitrepInFlight, why: string) => {
  let isLet = false
  let behind: SitrepSource[] = []

  await changeFlight(host, flights => {
    const at = flights.findIndex(each => isUnheard(each, delivery))
    const left = at === -1 ? flights : lessFrom(flights, at)

    isLet = at !== -1
    behind = flights.filter((each, i) => i > at && !left.includes(each)).map(each => each.source)

    return left
  })

  if (isLet) {
    stopAwaiting()
    sayNotTaken(host, delivery, why, behind)
    await putBack(host, delivery)
    await endedUnwritten(host)
  }
}

/**
 * Ready to send as it was before an answer went in with Lee's prompt, once
 * it is let go without going in: the reply it displaced back on its item,
 * else none there. Nothing for any other message.
 */
const putBack = async (host: Host, delivery: SitrepInFlight) => {
  const { ride } = delivery

  if (ride === undefined) {
    return
  }

  const { session, item } = repliedTo(delivery, ride.item)

  await host.state.queue.update(queue =>
    ride.was === undefined ? unqueuing(queue, session, item) : queuing(queue, ride.was),
  )
}

/**
 * Says a message went nowhere, one way for each source: an answer that went
 * with Lee's prompt has to be written again, its image with it, and what was
 * let go behind it says so as its source does, sends' replies still on the
 * board and the inbox's tried again.
 */
const sayNotTaken = (
  host: Host,
  delivery: SitrepInFlight,
  why: string,
  behind: readonly SitrepSource[],
) => {
  if (delivery.ride === undefined) {
    AFTER[delivery.source].notTaken(host, why)

    return
  }

  host.ui.toast(RIDE_LOST)

  for (const source of new Set(behind)) {
    AFTER[source].notTaken(host, why)
  }
}

/** The window no longer stopped, Claude Code taking its prompts again; nothing written where it was not. */
export const liftStop = async (host: Host) => {
  if (await host.state.stopped.read()) {
    await host.state.stopped.write(false)
  }
}

/**
 * Holds again a message Claude Code refused because Lee stopped Claude's
 * turn, the window marked stopped first, so no look submits it meanwhile:
 * neither it nor any send behind it is let go. One gone by then marks
 * nothing. Lee's input heard since the
 * submit (`at`) leaves the window unmarked, the refusal predating it, and
 * so does input heard while the mark was being written. What its submit set
 * up is undone: no quiet lets it go as never taken, and no wait on its turn
 * keeps the window from carrying on.
 */
const holdForInput = async (host: Host, delivery: SitrepInFlight, at: number) => {
  const isThere = (await flightNow(host)).some(each => isUnheard(each, delivery))
  const isStopped = isThere && inputs === at
  let isHeldAgain = false

  if (isStopped) {
    await host.state.stopped.write(true)
  }

  await changeFlight(host, flights => {
    const found = flights.findIndex(each => isUnheard(each, delivery))

    isHeldAgain = found !== -1

    return isHeldAgain
      ? flights.map((each, i) => (i === found ? { ...each, isHeld: true } : each))
      : flights
  })

  if (isHeldAgain) {
    stopAwaiting()
    quiet?.cancel()
    quiet = undefined
  }

  if (isStopped && inputs !== at) {
    await liftStop(host)
  }

  host.log(
    inputs === at
      ? "sitrep: Claude was interrupted; nothing goes in until Lee's input"
      : "sitrep: refused as Claude was interrupted, before Lee's input; it goes as it can",
  )
}

/**
 * Lee's input arriving in the window, which lifts Claude Code's refusal
 * after a stop before any hook hears it: a refusal coming back after it is
 * stale. Whether the window is stopped no longer is for what follows to say:
 * the turn it starts, or its going no further.
 */
export const inputArriving = () => {
  inputs += 1
}

/**
 * Lee's input heard in the window: a slash command of his, or a turn of the
 * window's own starting. The window is stopped no longer; refused again, it
 * is marked again.
 */
export const heardInput = async (host: Host) => {
  inputArriving()
  await liftStop(host)
}

/** Runs a slash command of Lee's through to its end, nothing submitted meanwhile: a prompt would wait on it, its quiet passing, or land in a conversation it replaces. */
export const duringCommand = async <T>(task: () => Promise<T>) => {
  commands += 1

  try {
    return await task()
  } finally {
    commands -= 1
  }
}

/** Replies of a taken message, and the writer's file in the session they are written down in. */
type Writing = Into & { replies: SitrepReplyBody[] }

/**
 * Where a taken message is written down: in the session it went to, and a
 * pick-up of an item another session of its project parked in that
 * session, each reply naming its item by its own id.
 */
const writingsOf = (delivery: SitrepInFlight): Writing[] => {
  const bySession = new Map<string, SitrepReplyBody[]>()

  for (const reply of delivery.replies) {
    const { session, item } = repliedTo(delivery, reply.item)

    bySession.set(session, [...(bySession.get(session) ?? []), { ...reply, item }])
  }

  return [...bySession].map(([session, replies]) => ({
    project: delivery.project,
    session,
    writer: delivery.writer,
    replies,
  }))
}

/** The lines a taken message's replies are written down as, in their session as it stands: none once they are there. */
const linesOf = (
  session: Session,
  source: SitrepSource,
  replies: readonly SitrepReplyBody[],
): Body[] =>
  source === 'send'
    ? sentLines(session, replies)
    : deliveredMark(
        session,
        replies.map(reply => reply.id),
      )

/** Whether this window's own reply to the item, by the id its claim drew, is in the session: in a file only this window writes. */
const isWritten = (session: Session, writer: string, { id, item }: SitrepReplyBody) =>
  session.replies.some(reply => reply.id === id && reply.item === item && reply.by === writer)

/**
 * The lines a taken message's pick-ups of items another session parked are
 * written down as, in that session as it stands, in this window's own file
 * there, by the ids the claim drew: each reply not there yet as this window
 * wrote it, and the mark naming them; none once every one is.
 */
const pickUpLines = (session: Session, { writer, replies }: Writing): Body[] => {
  const unwritten = replies.filter(reply => !isWritten(session, writer, reply))

  return unwritten.length === 0
    ? []
    : [...unwritten, { type: 'delivered', replies: unwritten.map(reply => reply.id) }]
}

/** The lines a taken message is written down as in the session of `writing`. */
const linesFor =
  (delivery: SitrepInFlight, writing: Writing) =>
  (session: Session): Body[] =>
    writing.session === delivery.session
      ? linesOf(session, delivery.source, writing.replies)
      : pickUpLines(session, writing)

/** Logs a session a taken message went to whose session.json is gone. */
const goneUnless = (host: Host, isThere: boolean, { session }: Writing) => {
  if (!isThere) {
    host.log(`sitrep: Claude has replies to ${session}, whose session.json is gone`)
  }
}

/** Writes a taken message's lines into the held session, through the hold, as lines Claude knows of: the replies it has just been sent. */
const writeHere = async (host: Host, delivery: SitrepInFlight, writing: Writing) => {
  const isThere = await writeHeld(host, linesFor(delivery, writing), (session, posted) =>
    postKnown(host, session, posted),
  )

  goneUnless(host, isThere, writing)
}

/**
 * Writes a taken message's lines into a session the window does not hold,
 * in this window's own file there: Claude's own change to it, as the
 * session stood before, where it is another of the held session's project.
 */
const writeThere = async (
  host: Host,
  delivery: SitrepInFlight,
  writing: Writing,
): Promise<ChangedThere[]> => {
  const lines = linesFor(delivery, writing)
  let before = undefined as Session | undefined
  const isThere = await writeInto(host, writing, session => {
    before = session

    return lines(session)
  })

  goneUnless(host, isThere, writing)

  return before === undefined || writing.project !== attached()?.project
    ? []
    : [{ before, items: writing.replies.map(reply => reply.item) }]
}

/**
 * Writes a taken message down in one turn of the window's queue, each
 * choice made there, from the hold and the files as they are then: the
 * session it went to, and the session that parked each item it picks up,
 * each through the hold where the window holds it now, else into this
 * window's own file there, and only the lines not there yet. The held
 * session's lines go first. The sessions written around the hold are read
 * again after, a pick-up's item having left Parked, and, Claude's own
 * message having carried them, the board counts as seen after them where
 * Claude had seen it as it stood before; a failure to keep it fails no
 * write.
 */
const writeTurn = async (host: Host, delivery: SitrepInFlight) => {
  const writings = writingsOf(delivery)
  const held = attached()
  const around = writings.filter(each => !isHoldOn(held, each))
  const changes: ChangedThere[] = []

  for (const writing of writings.filter(each => isHoldOn(held, each))) {
    await writeHere(host, delivery, writing)
  }

  for (const writing of around) {
    changes.push(...(await writeThere(host, delivery, writing)))
  }

  if (around.length > 0) {
    await lookAround(
      host,
      around.map(({ session }) => session),
    )
    await changedKnown(host, changes).catch(logFailure(host, 'keeping the board as seen'))
  }
}

/**
 * Writes a taken message down, then ends it; what follows its claim's end
 * follows once, by whichever write ended it. One message may be written
 * down twice: by two loads, as a file-watch reload can cut short a write
 * the last load began once the submit resolved (settled live), or by one
 * load hearing it as its receive timer takes it up. Each write finds what
 * the other wrote, the lines judged in its own turn of the window's queue.
 */
const writeDown = async (host: Host, delivery: SitrepInFlight) => {
  await serially(() => writeTurn(host, delivery))
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

/**
 * Submits a message the window no longer holds: written down once Claude
 * Code takes it, held again for Lee's input if refused as he stopped
 * Claude's turn, else let go.
 */
const submit = async (host: Host, delivery: SitrepInFlight) => {
  const at = inputs
  const refusal = await refusalOf(host, delivery.text)

  if (refusal === undefined) {
    await heard(host, current => isClaim(current, delivery))
  } else if (isStoppedRefusal(refusal)) {
    await holdForInput(host, delivery, at)
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
 * while a turn runs, stopped on Lee or not, nor while a slash command of
 * his runs. Nor while the window is stopped, Claude Code refusing it until
 * Lee's input, unless `host` is a press of his (`isPress`), whose submit
 * Claude Code takes: the message is taken first, so no look submits it
 * unvouched as the mark is lifted, then the mark, then the submit, all
 * before the press's hook returns. One behind a message submitted
 * and not yet ended stays held: it goes once that one has, and its turn has
 * been heard starting (`awaiting`), at the next between turns. A
 * single update ends the hold, so a take-back racing it lands first or
 * finds it gone, and its quiet counts from the submit. With nothing held
 * first, as the window knows its claims, it writes nothing. The submit is
 * not waited on: a hook waiting on its own submit never ends, and one made
 * as a turn ends starts a turn of its own about 13 ms later (a live probe).
 * Whether it submitted one.
 *
 * Run at the claim, and at each look, for a message held between turns: its
 * update as the turn ended failed, no load ran it then, or the message ahead
 * of it ended since.
 */
export const sendHeld = async (host: Host) => {
  const isBetween = await betweenTurns(host)
  const isPress = host.isPress === true
  const isStopped = !isPress && (await host.state.stopped.read())
  const isGoing = (flights: readonly SitrepInFlight[]) =>
    awaiting === undefined &&
    commands === 0 &&
    !isStopped &&
    flights[0]?.isHeld === true &&
    isBetween()

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

  if (isPress) {
    // A refusal marks the window again, so the submit goes whether or not this lands.
    await liftStop(host).catch(logFailure(host, 'ending the wait on your input'))
  }

  awaitTurn(host, going.text, true)
  quietFor(host, going)
  void submit(host, going).catch(logFailure(host, 'submitting the message'))

  return true
}

/**
 * Carries the messages in flight on as the main conversation comes to be
 * between turns: a turn of it ending however it ends (answered, stopped by
 * Lee, failed, refused), a `/clear`, or a load starting. The first goes
 * while the window holds it (`sendHeld`); submitted before and not taken,
 * it is let go once `QUIET_MS` pass with no turn starting, unless it is the
 * answer whose hook still waits on Claude Code (`hooked`). The wait on a
 * message's turn counts its quiet from here, should it count none yet.
 * Nothing while a turn runs.
 */
export const carryOn = async (host: Host) => {
  const isBetween = await betweenTurns(host)

  if (isBetween()) {
    quietAwaiting(host)
  }

  if (await sendHeld(host)) {
    return
  }

  const [first] = await flightNow(host)

  if (first !== undefined && !first.isHeld && !first.isTaken && !isHooked(first) && isBetween()) {
    quietFor(host, first)
  }
}

/** Whether a message in flight carries a reply to an item the outgoing one replies to. */
const carriesAny = (flight: SitrepInFlight, outgoing: Outgoing) =>
  outgoing.replies.some(({ item }) => isCarriedBy(flight, repliedTo(outgoing, item)))

/**
 * The message in flight a message is not claimed behind: for the inbox's,
 * any, since a look takes in nothing more while one is in flight; for a
 * send, the inbox's, or a send carrying a reply of its already, as a second
 * press of send meets the first's.
 */
const aheadOf = (flights: readonly SitrepInFlight[], outgoing: Outgoing) =>
  outgoing.source === 'inbox'
    ? flights[0]
    : flights.find(each => each.source === 'inbox' || carriesAny(each, outgoing))

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
 * Lets go of an answer that went with Lee's prompt but not in, silently:
 * Ready to send as it was before (`putBack`), and its ask waiting on Lee
 * again at once. Its hook waits no more, nor does anything on its turn.
 * Whether it let it go.
 */
export const letRideGo = async (host: Host, ride: SitrepInFlight) => {
  hooked.delete(claimKey(ride))

  if (awaiting?.text === ride.text) {
    stopAwaiting()
  }

  const isLet = await endIf(host, current => isClaim(current, ride))

  if (isLet) {
    await putBack(host, ride)
    await endedUnwritten(host)
  }

  return isLet
}

/**
 * Claims an answer going in with Lee's own prompt, rewritten as the board's
 * words for it (answering.ts), and freezes `reply` in Ready to send in place
 * of what was queued on its item (`was`), kept on the claim to be put back.
 * Submitted by his Enter, it is never held, nor ever submitted by the
 * window. It goes ahead of every message the window holds, which wait for it
 * to end, and for its turn to start, as behind any message submitted first.
 * While its hook waits on Claude Code no quiet lets it go (`hooked`).
 * Undefined, claiming nothing, where a send in flight carries a reply to its
 * item already; a claim whose freezing fails is let go again.
 */
export const claimRide = async (
  host: Host,
  outgoing: Outgoing,
  reply: SitrepQueued,
  was: SitrepQueued | undefined,
) => {
  const ride: SitrepInFlight = {
    ...outgoing,
    claimedAt: await host.clock.now(),
    isHeld: false,
    isTaken: false,
    ride: {
      item: namedIn(outgoing.session, reply),
      ...(was === undefined ? {} : { was }),
    },
  }
  const isBetween = await betweenTurns(host)
  let isClaimed = false

  await changeFlight(host, flights => {
    const held = flights.findIndex(each => each.isHeld)
    const at = held === -1 ? flights.length : held

    isClaimed = !flights.some(each => carriesAny(each, outgoing))

    if (!isClaimed) {
      hooked.delete(claimKey(ride))

      return flights
    }

    hooked.add(claimKey(ride))

    return [...flights.slice(0, at), ride, ...flights.slice(at)]
  })

  if (!isClaimed) {
    return undefined
  }

  awaitTurn(host, ride.text, isBetween())

  try {
    await host.state.queue.update(queue => queuing(queue, reply))
  } catch (error) {
    await letRideGo(host, ride)
    throw error
  }

  return ride
}

/** Claude Code took Lee's prompt carrying the answer: written down as any message taken, unless its turn, starting first, did that. */
export const rideTaken = async (host: Host, ride: SitrepInFlight) => {
  hooked.delete(claimKey(ride))
  await heard(host, current => isClaim(current, ride))
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
    await endedUnwritten(host)
  }

  return isLet
}

/** Takes back one send of Lee's while the window still holds it, any behind it held still; never the inbox's message, which Lee sent from elsewhere. Whether it was taken back. */
export const takeBack = (host: Host, send: SitrepInFlight) =>
  letGoHeld(host, current => current.source === 'send' && isClaim(current, send))

/** Lets go of a message the window holds, as a take-back does: the inbox's, held while the window is stopped, once this window no longer delivers it. Whether it let it go. */
export const letGoHeldOne = (host: Host, delivery: SitrepInFlight) =>
  letGoHeld(host, current => isClaim(current, delivery))

/**
 * The conversation ending, which ends any turn of it. After a `/clear` the
 * process goes on with the next conversation, so the messages the window
 * holds go into it, as a prompt queued across a `/clear` goes in after.
 * Any other end leaves no conversation for them: a resume puts another in
 * this one's place, which their replies are not for, and an exit or a
 * logout ends the process. So there each is let go, as a take-back lets it
 * go, and nothing is submitted. One submitted already is Claude Code's, its
 * quiet counted as at a turn's end, an answer that went in with Lee's
 * prompt among them, whatever its hook still waits on.
 */
export const conversationEnded = async (host: Host, isCleared: boolean) => {
  hooked.clear()

  if (!isCleared) {
    await letGoHeld(host, () => true)
  }

  await carryOn(host)
}

/**
 * The window's turn starts: it is no longer quiet, a message submitted
 * whose text it carries has gone in, and none waits on Lee's input, so as it
 * ends the first held goes. Mostly the turn is his input; one that leaves
 * the refusal standing, as a task's notification's, has the window marked
 * stopped again. After a `/reload-plugins` typed mid-turn the last load's
 * submit never resolves (settled live), and this is all that hears it.
 */
export const heardTurn = async (host: Host, text: string) => {
  turns += 1

  if (awaiting?.text === text) {
    stopAwaiting()
  }

  quiet?.cancel()
  await heard(host, current => current.text === text)
  await heardInput(host)
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
 * held while a turn runs, or while the window is stopped, as a reload no
 * one typed leaves Claude Code's refusal standing. It knows nothing of a
 * submit before it, so goes by the turn the window's state says, nor of a
 * hook an earlier load let an answer in from, which died with that load. The
 * heartbeat learns the messages in flight from the window's first need of
 * them (window.ts), never from `writeTaken`'s read, which is as old as the
 * load's first hook and may predate a send claimed since.
 */
export const takeUpDelivery = async (host: Host) => {
  quiet?.cancel()
  quiet = undefined
  stopAwaiting()
  hooked.clear()
  await writeTaken(host)
  await carryOn(host)
}
