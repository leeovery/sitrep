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

test("each row's zone is that zone: its offset from UTC in winter and in summer, as the zone's clocks have it", () => {
  const offsets = (zone: string) =>
    inZone(zone, () => [
      new Date(Date.UTC(2026, 0, 15)).getTimezoneOffset(),
      new Date(Date.UTC(2026, 6, 15)).getTimezoneOffset(),
    ])

  expect(offsets('Europe/London')).toEqual([0, -60])
  expect(offsets('America/New_York')).toEqual([300, 240])
  expect(offsets('Pacific/Auckland')).toEqual([-780, -720])
  expect(offsets('Asia/Kolkata')).toEqual([-330, -330])
  expect(new Set(WAKES.map(wake => wake.zone))).toEqual(
    new Set(['Europe/London', 'America/New_York', 'Pacific/Auckland', 'Asia/Kolkata']),
  )
})

/** The first hour of 2026 at which what `read` gives on the zoned Date of the Mac's own zone is not the real one's. */
const firstDifference = (read: (hour: number) => unknown) =>
  HOURS_OF_2026.find(
    hour => JSON.stringify(inZone(LOCAL_ZONE, () => read(hour))) !== JSON.stringify(read(hour)),
  )

test("in the Mac's own zone the zoned Date is the real one: every local field at every hour of 2026, and every half past on its wall clock read back to its instant, the hours the clocks skip and repeat among them", () => {
  expect(
    firstDifference(hour => fieldsOf(new Date(Date.UTC(2026, 0, 1, hour)))),
    'its fields',
  ).toBeUndefined()
  expect(
    firstDifference(hour => new Date(2026, 0, 1, hour, 30).getTime()),
    'its half pasts read back',
  ).toBeUndefined()
  expect(
    inZone('Europe/London', () =>
      [new Date(2026, 2, 29, 1, 30), new Date(2026, 9, 25, 1, 30)].map(date => date.getTime()),
    ),
    "London's half past one skipped, read past the change, and repeated, read as the first",
  ).toEqual([Date.UTC(2026, 2, 29, 1, 30), Date.UTC(2026, 9, 25, 0, 30)])
})

test('Snooze wakes at the time the table gives for each row, worked out in its zone', () => {
  for (const wake of WAKES) {
    expect(
      inZone(wake.zone, () => snoozeAt(wake.choice, wake.pressed)),
      `${wake.zone} ${wake.choice}, ${wake.words}`,
    ).toBe(wake.wakes)
  }
})

test("the rows in the Mac's own zone wake at their time on the real Date too, none put in its place", () => {
  for (const wake of WAKES.filter(each => each.zone === LOCAL_ZONE)) {
    expect(snoozeAt(wake.choice, wake.pressed), `${wake.choice}, ${wake.words}`).toBe(wake.wakes)
  }
})
