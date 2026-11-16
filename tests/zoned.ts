/**
 * Local time in a time zone of the test's choosing. The kit runs every test
 * in the Mac's own zone, with no process to set `TZ` on and no `TZ` passed
 * down from the shell, so a test that needs another zone puts a `Date` of
 * that zone in the global's place while it runs: its local fields and its
 * local constructor read the zone through `Intl`, as the real one reads the
 * Mac's, and everything else is the real `Date`'s. Only what the code the
 * tests run in a zone uses is zoned (`snoozeAt`, `wakeWords`, `wholeTime`
 * and `boardText` through it, and `wakeAt` through `workOf` and
 * `turnStopped`): the other setters, `toString` and a local time given as a
 * string still read the Mac's zone.
 */

const RealDate = Date

const DAY_MS = 24 * 60 * 60_000

const formats = new Map<string, Intl.DateTimeFormat>()

const formatIn = (zone: string) => {
  const cached = formats.get(zone)

  if (cached) {
    return cached
  }

  const format = new Intl.DateTimeFormat('en-GB', {
    timeZone: zone,
    hourCycle: 'h23',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
  })

  formats.set(zone, format)
  return format
}

/** How far the zone's wall clock is ahead of UTC at an instant, ms. */
const offsetIn = (zone: string, at: number) => {
  const parts = formatIn(zone).formatToParts(at)
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find(each => each.type === type)?.value)
  const wall = RealDate.UTC(
    part('year'),
    part('month') - 1,
    part('day'),
    part('hour'),
    part('minute'),
    part('second'),
  )

  return wall - (at - (((at % 1000) + 1000) % 1000))
}

/**
 * The instant a wall-clock time in the zone comes to, as `Date`'s local
 * constructor reads one: of a time the clocks pass twice, the earlier; of one
 * they skip, the time read at the offset before the change, so it lands past
 * it. A day either side holds at most one change in any zone.
 */
const instantOf = (zone: string, wall: number) => {
  const candidates = [wall - offsetIn(zone, wall - DAY_MS), wall - offsetIn(zone, wall + DAY_MS)]
  const fits = candidates.filter(at => at + offsetIn(zone, at) === wall)

  return fits.length > 0 ? Math.min(...fits) : (candidates[0] ?? wall)
}

/** A `Date` whose local time is the zone's. */
const zonedDate = (zone: string) =>
  class extends RealDate {
    constructor(...args: number[]) {
      const [year = 0, month = 0, day = 1, hour = 0, minute = 0, second = 0, ms = 0] = args

      super(
        args.length === 0
          ? RealDate.now()
          : args.length === 1
            ? year
            : instantOf(zone, RealDate.UTC(year, month, day, hour, minute, second, ms)),
      )
    }

    /** This instant on the zone's wall clock, read through the UTC fields. */
    private wall() {
      return new RealDate(this.getTime() + offsetIn(zone, this.getTime()))
    }

    override getFullYear() {
      return this.wall().getUTCFullYear()
    }

    override getMonth() {
      return this.wall().getUTCMonth()
    }

    override getDate() {
      return this.wall().getUTCDate()
    }

    override getDay() {
      return this.wall().getUTCDay()
    }

    override getHours() {
      return this.wall().getUTCHours()
    }

    override getMinutes() {
      return this.wall().getUTCMinutes()
    }

    /** The seconds as `wakeAt` sets them: every zone's offset is whole minutes, so its seconds are UTC's. */
    override setSeconds(seconds: number, ms?: number) {
      return ms === undefined ? this.setUTCSeconds(seconds) : this.setUTCSeconds(seconds, ms)
    }

    override getTimezoneOffset() {
      // `0 -` rather than a minus: UTC's offset is 0, as the real Date gives it, and never -0.
      return 0 - offsetIn(zone, this.getTime()) / 60_000
    }
  }

/** The Mac's own time zone, the one the kit runs in. */
export const LOCAL_ZONE = Intl.DateTimeFormat().resolvedOptions().timeZone

/**
 * What `body` gives with local time the zone's, the `Date` it found put back
 * after, so one inside another's body hands that zone back. The body is
 * synchronous: the `Date` it found would be back at an async one's first
 * `await`, so a promise from it is refused.
 */
export const inZone = <T>(zone: string, body: () => T): T => {
  const global = globalThis as { Date: unknown }
  const found = global.Date
  let given: T

  global.Date = zonedDate(zone)
  try {
    given = body()
  } finally {
    global.Date = found
  }

  if (typeof (given as { then?: unknown } | null | undefined)?.then === 'function') {
    throw new Error(`inZone(${zone}) was given an async body: the real Date is back at its first await`)
  }

  return given
}

/** Lee's own zone, which a test of his local time pins. */
export const LONDON = 'Europe/London'

/** A zone of another offset, whose clocks change a week after London's. */
export const NEW_YORK = 'America/New_York'

/** The instant a wall-clock time in the zone comes to, its month counted from 1 as a test writes a date. */
export const wallClock =
  (zone: string) =>
  (year: number, month: number, day: number, hour = 0, minute = 0) =>
    inZone(zone, () => new Date(year, month - 1, day, hour, minute).getTime())
