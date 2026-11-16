/**
 * What Lee's snoozes hold, as the fold reads them line by line (see
 * "Snooze" in DESIGN.md): his snooze of the session, which holds the asks
 * waiting on him as it was written, and his turn there; and the old lines'
 * snoozes of an ask or a turn, read as they always were, the turn sleeping
 * with old snoozes of asks while they hold every ask waiting on Lee.
 */
import { waitsOnLee } from './replies'
import type { Ask, Item, SessionSnooze, TurnSnooze } from './types'

export type Asleep = {
  /** Lee's latest snooze of the session, until a line wakes it. */
  session?: SessionSnooze
  /** From old lines: when Lee's latest snooze of each ask wakes, by ask, until a line ends it. */
  asks: Map<string, number>
  /** From old lines: whether their snoozes held every ask waiting on Lee as the last was written, so the turn sleeps with them, until one of them ends. */
  isTurnWithAsks: boolean
  /** From an old line: Lee's latest snooze of the turn, until a line wakes it. */
  turn?: TurnSnooze
}

export const nothingAsleep = (): Asleep => ({ asks: new Map(), isTurnWithAsks: false })

const isAsk = (item: Item): item is Ask => item.type === 'ask'

/** Lee's snooze of the session at `at`, holding `asks`, in place of whatever he snoozed of it before. */
export const snoozeSession = (
  asleep: Asleep,
  until: number,
  asks: readonly string[],
  at: number,
) => {
  wakeSession(asleep)
  asleep.session = { until, at, asks }
}

/** Lee's waking of the session: whatever he snoozed of it needs him again. */
export const wakeSession = (asleep: Asleep) => {
  asleep.session = undefined
  asleep.asks.clear()
  asleep.isTurnWithAsks = false
  asleep.turn = undefined
}

/** Ends the session's snooze at `at` while it holds then: one run out stays as it ran out, its asks carrying when they woke. */
const wakeEarly = (asleep: Asleep, at: number) => {
  if (asleep.session !== undefined && at < asleep.session.until) {
    asleep.session = undefined
  }
}

/** An ask posted or reopened at `at`: something new needing Lee wakes the session, and ends the old lines' snoozes of the turn. */
export const newNeed = (asleep: Asleep, at: number) => {
  wakeEarly(asleep, at)
  asleep.isTurnWithAsks = false
  asleep.turn = undefined
}

/** Lee's reply at `at` to an item: one to an ask the session's snooze holds wakes it; any ends an old line's snooze of the turn. */
export const replied = (asleep: Asleep, item: Item, at: number) => {
  if (asleep.session?.asks.includes(item.id) === true) {
    wakeEarly(asleep, at)
  }

  asleep.turn = undefined
}

/** Whether an old snooze, running out at `until`, woke its ask by `at` and after Lee's old snooze of the turn: it needed Lee since. */
const wokeSinceTurn = (asleep: Asleep, until: number | undefined, at: number) =>
  until !== undefined && asleep.turn !== undefined && asleep.turn.at < until && until <= at

/** An old snooze of an ask ended by a line at `at`, its ask settled, resolved, reopened or woken; the turn sleeps with the asks no more. */
export const endAskSnooze = (asleep: Asleep, id: string, at: number) => {
  if (!asleep.asks.has(id)) {
    return
  }

  if (wokeSinceTurn(asleep, asleep.asks.get(id), at)) {
    asleep.turn = undefined
  }

  asleep.asks.delete(id)
  asleep.isTurnWithAsks = false
}

/** An old line's snooze of an ask waiting as posted; the turn sleeps with the asks once they hold every one waiting on Lee. */
export const snoozeAsk = (asleep: Asleep, ask: Ask, until: number, items: Iterable<Item>) => {
  if (ask.state !== 'waiting') {
    return
  }

  asleep.asks.set(ask.id, until)
  asleep.isTurnWithAsks = [...items]
    .filter(isAsk)
    .filter(waitsOnLee)
    .every(each => asleep.asks.has(each.id))
}

/** An old line's waking of an ask: it ends the old snooze of the turn too, as it always did. */
export const wakeAsk = (asleep: Asleep, id: string) => {
  if (asleep.asks.delete(id)) {
    asleep.turn = undefined
    asleep.isTurnWithAsks = false
  }
}

/** Whether an old line's snooze holds an ask at `now`, its time still to come. */
const isHeldByOld = (asleep: Asleep, ask: Ask, now: number) => {
  const until = asleep.asks.get(ask.id)

  return until !== undefined && now < until
}

/** Until when what Lee snoozed holds an ask waiting as posted, its time to come or run out: the later where both his snooze of the session and an old line's hold it. */
const untilOf = (asleep: Asleep, session: SessionSnooze | undefined, ask: Ask) => {
  const untils = [
    session?.asks.includes(ask.id) === true ? session.until : undefined,
    asleep.asks.get(ask.id),
  ]
  const held = untils.filter(until => until !== undefined)

  return ask.state !== 'waiting' || held.length === 0 ? undefined : Math.max(...held)
}

/**
 * The session's snooze as it stands once every line is read: none while an
 * ask it does not hold, nor an old line holds, waits on Lee, as one whose
 * answer on its way then has since gone void or been taken back.
 */
const sessionAt = (asleep: Asleep, asks: readonly Ask[], now: number) => {
  const { session } = asleep

  if (session === undefined || now >= session.until) {
    return session
  }

  const isUnheld = (ask: Ask) =>
    waitsOnLee(ask) && !session.asks.includes(ask.id) && !isHeldByOld(asleep, ask, now)

  return asks.some(isUnheld) ? undefined : session
}

/** Lee's old snooze of the turn at `now`: none once an ask an old line snoozed has woken since it was written. */
const turnAt = (asleep: Asleep, now: number) =>
  [...asleep.asks.values()].some(until => wokeSinceTurn(asleep, until, now))
    ? undefined
    : asleep.turn

/** When the turn sleeping with the old lines' snoozes of asks wakes at `now`: as the first of them does, while they hold every ask waiting on Lee. */
const turnWithAsksAt = (asleep: Asleep, asks: readonly Ask[], now: number) => {
  const waiting = asks.filter(waitsOnLee).map(ask => asleep.asks.get(ask.id))
  const holding = waiting.filter((until): until is number => until !== undefined && now < until)

  return asleep.isTurnWithAsks && holding.length > 0 && holding.length === waiting.length
    ? Math.min(...holding)
    : undefined
}

/**
 * What Lee's snoozes hold at `now`, once every line is read: each ask they
 * hold is snoozed while its time is to come, `snoozedUntil`, and woken at
 * it once it has, `wokeAt`; with what the session carries of them, and when
 * his snooze of the session set aside meanwhile runs out. The wall clock's
 * instant, not a heartbeat's age: no pause holds it back.
 */
export const standAsleep = (asleep: Asleep, asks: readonly Ask[], now: number) => {
  const session = sessionAt(asleep, asks, now)

  for (const ask of asks) {
    const until = untilOf(asleep, session, ask)

    if (until === undefined) {
      continue
    }

    if (now < until) {
      ask.snoozedUntil = until
    } else {
      ask.wokeAt = until
    }
  }

  return {
    snooze: session,
    asideUntil: session === undefined ? asleep.session?.until : undefined,
    turnSnooze: turnAt(asleep, now),
    turnWithAsks: turnWithAsksAt(asleep, asks, now),
  }
}
