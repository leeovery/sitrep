/**
 * Snooze's wake times as core's `snoozeAt` works them out, and the choices
 * `snoozeChoicesAt` offers, every row of the table the app's copy is held to
 * as well, each in its own time zone under its own settings; when Tonight
 * and This weekend are offered, hour by hour; and the zone the kit is given
 * for a row, proven to be that zone.
 */
import { expect, test } from './kit'
import {
  SNOOZE_CHOICES,
  SNOOZE_DEFAULTS,
  snoozeAt,
  snoozeChoicesAt,
  type SnoozeChoice,
  type SnoozeSettings,
} from '../core'
import { WAKES, type Wake } from './wakes'
import { inZone, LOCAL_ZONE, LONDON, NEW_YORK } from './zoned'

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

  expect(offsets(LONDON)).toEqual([0, -60])
  expect(offsets(NEW_YORK)).toEqual([300, 240])
  expect(offsets('America/Santiago')).toEqual([180, 240])
  expect(offsets('Pacific/Auckland')).toEqual([-780, -720])
  expect(offsets('Asia/Kolkata')).toEqual([-330, -330])
  expect(new Set(WAKES.map(wake => wake.zone))).toEqual(
    new Set([
      LONDON,
      NEW_YORK,
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
    inZone(LONDON, () =>
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
    const wakes = wake.wakes === undefined ? 'not offered' : wordsIn(wake.zone, wake.wakes)

    expect(wake.words, `${wake.zone} ${wake.choice}`).toStartWith(
      `${wordsIn(wake.zone, wake.pressed)} -> ${wakes}: `,
    )
  }
})

test('the table holds a row Snooze offers and one it does not, so neither half below passes for nothing', () => {
  expect(WAKES.some(wake => wake.wakes === undefined)).toBe(true)
  expect(WAKES.some(wake => wake.wakes !== undefined)).toBe(true)
})

/** When a row's choice wakes, worked out at its press, where Snooze offers it then; none where it does not. */
const wakeOf = ({ choice, pressed, settings }: Wake) =>
  snoozeChoicesAt(pressed, settings).includes(choice)
    ? snoozeAt(choice, pressed, settings)
    : undefined

test('Snooze offers each row its choice and wakes at the time the table gives, worked out in its zone under its settings; one it gives no time, it does not offer', () => {
  for (const wake of WAKES) {
    expect(
      inZone(wake.zone, () => wakeOf(wake)),
      `${wake.zone} ${wake.choice}, ${wake.words}`,
    ).toBe(wake.wakes)
  }
})

test("the table's rows set each choice in each way Lee can set it, and each reads its setting over the defaults, the rest left as they are", () => {
  const set = (field: string) => WAKES.find(wake => wake.words.endsWith(field))?.settings

  expect(set(': four hours on')).toEqual({ ...SNOOZE_DEFAULTS, later: { isOn: true, hours: 4 } })
  expect(set(': 20:00 today')).toEqual({
    ...SNOOZE_DEFAULTS,
    tonight: { isOn: true, at: { hour: 20, minute: 0 } },
  })
  expect(set(': a Monday, the Saturday of its week')).toEqual({
    ...SNOOZE_DEFAULTS,
    weekend: { isOn: true, day: 'saturday', at: { hour: 9, minute: 0 } },
  })
  expect(set(': Monday at 07:00')).toEqual({
    ...SNOOZE_DEFAULTS,
    week: { isOn: true, day: 'monday', at: { hour: 7, minute: 0 } },
  })
  expect(set(': Tomorrow off')).toEqual({
    ...SNOOZE_DEFAULTS,
    tomorrow: { ...SNOOZE_DEFAULTS.tomorrow, isOn: false },
  })
  expect(set(': off by default')).toEqual(SNOOZE_DEFAULTS)
  expect(
    new Set(WAKES.filter(wake => wake.settings !== SNOOZE_DEFAULTS).map(wake => wake.choice)),
  ).toEqual(new Set(SNOOZE_CHOICES))
})

/** The months of 2026 the table's zones change their clocks in, from 0: March, April, September, October and November. */
const CHANGING_MONTHS = [2, 3, 8, 9, 10]

/** Every hour of those months. */
const CHANGING_HOURS = HOURS_OF_2026.map(hour => Date.UTC(2026, 0, 1, hour)).filter(at =>
  CHANGING_MONTHS.includes(new Date(at).getUTCMonth()),
)

/** The Mondays, in UTC, of the weeks the table's zones change their clocks in 2026, each change on the Sunday that ends one. */
const CHANGING_MONDAYS = [
  [2, 2],
  [2, 23],
  [2, 30],
  [7, 31],
  [8, 21],
  [9, 19],
  [9, 26],
] as const

/** Every hour of those weeks, and of the Monday after each. */
const CHANGING_WEEKS = CHANGING_MONDAYS.flatMap(([month, day]) =>
  Array.from({ length: 8 * 24 }, (_, hour) => Date.UTC(2026, month, day, hour)),
)

/** Each of `hours` at which what Snooze offers in `zone` under `settings` is not what `expected` says of that local time, as a failure names it. */
const offerFaults = (
  zone: string,
  settings: SnoozeSettings,
  expected: (local: Date) => readonly SnoozeChoice[],
  hours = CHANGING_HOURS,
) =>
  inZone(zone, () =>
    hours.flatMap(at => {
      const offered = snoozeChoicesAt(at, settings)

      return JSON.stringify(offered) === JSON.stringify(expected(new Date(at)))
        ? []
        : [`${new Date(at).toString()}: ${offered.join(', ')}`]
    }),
  )

const ZONES = new Set(WAKES.map(wake => wake.zone))

test('by default Snooze offers every choice in its order, In an hour first and Tonight third, but This weekend, off, and Tonight from 18:00 to midnight, every hour of the months each zone of the table changes its clocks in', () => {
  expect(SNOOZE_CHOICES).toEqual(['hour', 'later', 'tonight', 'tomorrow', 'weekend', 'week'])

  for (const zone of ZONES) {
    const expected = (local: Date) =>
      SNOOZE_CHOICES.filter(
        choice => choice !== 'weekend' && !(choice === 'tonight' && local.getHours() >= 18),
      )

    expect(offerFaults(zone, SNOOZE_DEFAULTS, expected), zone).toEqual([])
  }
})

/** The days from Monday of a local date's weekday, Monday 0 to Sunday 6. */
const fromMonday = (local: Date) => (local.getDay() + 6) % 7

test("This weekend on is offered from Monday until its day's time, and from then until Monday not, on Saturday or on Sunday, every hour of the weeks each zone of the table changes its clocks in", () => {
  for (const [day, place] of [
    ['saturday', 5],
    ['sunday', 6],
  ] as const) {
    const settings = {
      ...SNOOZE_DEFAULTS,
      weekend: { isOn: true, day, at: { hour: 9, minute: 0 } },
    }
    const expected = (local: Date) => {
      const isComing =
        fromMonday(local) < place || (fromMonday(local) === place && local.getHours() < 9)

      return SNOOZE_CHOICES.filter(
        choice =>
          (choice !== 'weekend' || isComing) &&
          !(choice === 'tonight' && local.getHours() >= 18),
      )
    }

    for (const zone of ZONES) {
      expect(offerFaults(zone, settings, expected, CHANGING_WEEKS), `${zone} ${day}`).toEqual([])
    }
  }
})

const localRows = WAKES.filter(each => each.zone === LOCAL_ZONE)

testUnless(
  localRows.length > 0 ? undefined : `no row is in the Mac's zone, ${LOCAL_ZONE}`,
  "the rows in the Mac's own zone wake at their time on the real Date too, none put in its place",
  () => {
    for (const wake of localRows) {
      expect(wakeOf(wake), `${wake.choice}, ${wake.words}`).toBe(wake.wakes)
    }
  },
)
