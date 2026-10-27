/**
 * Snooze's wake times as core's `snoozeAt` works them out, every row of the
 * table the app's copy is held to as well, each in its own time zone; and the
 * zone the kit is given for a row, proven to be that zone.
 */
import { expect, test } from 'claude-code/testing'
import { snoozeAt } from '../core'
import { WAKES } from './wakes'
import { inZone, LOCAL_ZONE } from './zoned'

/** Every hour of 2026, counted from its start: each of a zone's changes that year falls among them. */
const HOURS_OF_2026 = Array.from({ length: 365 * 24 }, (_, hour) => hour)

/** Each local field of a date, as `snoozeAt` and the pane read them. */
const fieldsOf = (date: Date) => [
  date.getFullYear(),
  date.getMonth(),
  date.getDate(),
  date.getDay(),
  date.getHours(),
  date.getMinutes(),
  date.getTimezoneOffset(),
]

/** A test run where there is no reason to skip it; else skipped, saying why, rather than passing for nothing. */
const testUnless = (reason: string | undefined, name: string, body: () => void) =>
  reason === undefined ? test(name, body) : test(`${name} (skipped: ${reason})`, () => {})

test("each row's zone is that zone: its offset from UTC in winter and in summer, as the zone's clocks have it", () => {
  const offsets = (zone: string) =>
    inZone(zone, () => [
      new Date(Date.UTC(2026, 0, 15)).getTimezoneOffset(),
      new Date(Date.UTC(2026, 6, 15)).getTimezoneOffset(),
    ])

  expect(offsets('Europe/London')).toEqual([0, -60])
  expect(offsets('America/New_York')).toEqual([300, 240])
  expect(offsets('America/Santiago')).toEqual([180, 240])
  expect(offsets('Pacific/Auckland')).toEqual([-780, -720])
  expect(offsets('Asia/Kolkata')).toEqual([-330, -330])
  expect(new Set(WAKES.map(wake => wake.zone))).toEqual(
    new Set([
      'Europe/London',
      'America/New_York',
      'America/Santiago',
      'Pacific/Auckland',
      'Asia/Kolkata',
    ]),
  )
})

/** The first hour of 2026 at which what `read` gives on the zoned Date of the Mac's own zone is not the real one's. */
const firstDifference = (read: (hour: number) => unknown) =>
  HOURS_OF_2026.find(
    hour => JSON.stringify(inZone(LOCAL_ZONE, () => read(hour))) !== JSON.stringify(read(hour)),
  )

const NEW_YEAR_OFFSET = new Date(2026, 0, 1).getTimezoneOffset()

const changesClocksIn2026 = HOURS_OF_2026.some(
  hour => new Date(Date.UTC(2026, 0, 1, hour)).getTimezoneOffset() !== NEW_YEAR_OFFSET,
)

testUnless(
  changesClocksIn2026 ? undefined : `the Mac's zone, ${LOCAL_ZONE}, changes no clock in 2026`,
  "in the Mac's own zone the zoned Date is the real one: every local field at every hour of 2026, and every half past on its wall clock read back to its instant, the hours the clocks skip and repeat among them",
  () => {
    expect(
      firstDifference(hour => fieldsOf(new Date(Date.UTC(2026, 0, 1, hour)))),
      'its fields',
    ).toBeUndefined()
    expect(
      firstDifference(hour => new Date(2026, 0, 1, hour, 30).getTime()),
      'its half pasts read back',
    ).toBeUndefined()
  },
)

test("a local time the zone's clocks skip is read past the change, and one they pass twice as the first, as the real Date reads them", () => {
  expect(
    inZone('Europe/London', () =>
      [new Date(2026, 2, 29, 1, 30), new Date(2026, 9, 25, 1, 30)].map(date => date.getTime()),
    ),
  ).toEqual([Date.UTC(2026, 2, 29, 1, 30), Date.UTC(2026, 9, 25, 0, 30)])
})

test('an async body is refused, since the real Date would be back at its first await, and the real Date is back after', () => {
  const real = Date

  expect(() => inZone('Pacific/Auckland', async () => new Date().getHours())).toThrow(
    'async body',
  )
  expect(Date).toBe(real)
})

const pad = (value: number, digits = 2) => String(value).padStart(digits, '0')

/**
 * An instant as the table words it in a zone, read through `Intl`:
 * `Wed 28 Oct 2026 14:00 GMT+0`, its seconds and ms only where it has them
 * (`14:00:37.512`), its offset as `GMT+1`, `GMT-4` or `GMT+5:30`.
 */
const wordsIn = (zone: string, at: number) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    hourCycle: 'h23',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    timeZoneName: 'shortOffset',
  }).formatToParts(at)
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find(each => each.type === type)?.value ?? ''
  const ms = ((at % 60_000) + 60_000) % 60_000
  const seconds = ms === 0 ? '' : `:${pad(Math.floor(ms / 1000))}.${pad(ms % 1000, 3)}`
  const clock = `${pad(Number(part('hour')))}:${part('minute')}${seconds}`

  return `${part('weekday')} ${part('day')} ${part('month')} ${part('year')} ${clock} ${part('timeZoneName')}`
}

test("each row's local times say its instants in its zone, so a failure names the case it is", () => {
  for (const wake of WAKES) {
    expect(wake.words, `${wake.zone} ${wake.choice}`).toStartWith(
      `${wordsIn(wake.zone, wake.pressed)} -> ${wordsIn(wake.zone, wake.wakes)}: `,
    )
  }
})

test('Snooze wakes at the time the table gives for each row, worked out in its zone', () => {
  for (const wake of WAKES) {
    expect(
      inZone(wake.zone, () => snoozeAt(wake.choice, wake.pressed)),
      `${wake.zone} ${wake.choice}, ${wake.words}`,
    ).toBe(wake.wakes)
  }
})

const localRows = WAKES.filter(each => each.zone === LOCAL_ZONE)

testUnless(
  localRows.length > 0 ? undefined : `no row is in the Mac's zone, ${LOCAL_ZONE}`,
  "the rows in the Mac's own zone wake at their time on the real Date too, none put in its place",
  () => {
    for (const wake of localRows) {
      expect(snoozeAt(wake.choice, wake.pressed), `${wake.choice}, ${wake.words}`).toBe(wake.wakes)
    }
  },
)
