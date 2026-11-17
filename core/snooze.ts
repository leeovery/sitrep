/**
 * Snooze's times, worked out where it is pressed, on that Mac's calendar and
 * in its time zone, so 09:00 is 09:00 across a change of the clocks, from
 * the choices as Lee set them in SitRep, which the app writes to
 * `snooze.json`; and a snooze's time in words, as the pane and Claude say it
 * (see "Snooze" in DESIGN.md). What is pressed is stored as the instant it
 * comes to, and read as a local time again only to word it.
 */

import { isObject, parseVersioned } from './entries'
import { UNTIL_IT_MOVES } from './types'
import type { Upgrade } from './versions'

/** Snooze's choices, in the order every surface offers them: in an hour, later today, tonight, tomorrow, this weekend, or next week. */
export const SNOOZE_CHOICES = ['hour', 'later', 'tonight', 'tomorrow', 'weekend', 'week'] as const

export type SnoozeChoice = (typeof SNOOZE_CHOICES)[number]

/** The days a setting names, in the week's order, Monday first, as This weekend and Next week count it. */
export const SNOOZE_DAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const

export type SnoozeDay = (typeof SNOOZE_DAYS)[number]

/** The days This weekend wakes on. */
export const WEEKEND_DAYS = ['saturday', 'sunday'] as const satisfies readonly SnoozeDay[]

export type WeekendDay = (typeof WEEKEND_DAYS)[number]

/** How many hours on Later today wakes. */
export const LATER_HOURS = [1, 2, 3, 4] as const

export type LaterHours = (typeof LATER_HOURS)[number]

/** A local time of day, on the 24-hour clock. */
export type TimeOfDay = { hour: number; minute: number }

/** Each of Snooze's choices as Lee set it in SitRep: whether it is offered, and when it wakes. */
export type SnoozeSettings = {
  hour: { isOn: boolean }
  later: { isOn: boolean; hours: LaterHours }
  tonight: { isOn: boolean; at: TimeOfDay }
  tomorrow: { isOn: boolean; at: TimeOfDay }
  weekend: { isOn: boolean; day: WeekendDay; at: TimeOfDay }
  week: { isOn: boolean; day: SnoozeDay; at: TimeOfDay }
}

/** What every surface offers until Lee sets otherwise, and wherever his settings cannot be read. */
export const SNOOZE_DEFAULTS: SnoozeSettings = {
  hour: { isOn: true },
  later: { isOn: true, hours: 3 },
  tonight: { isOn: true, at: { hour: 18, minute: 0 } },
  tomorrow: { isOn: true, at: { hour: 9, minute: 0 } },
  weekend: { isOn: false, day: 'saturday', at: { hour: 9, minute: 0 } },
  week: { isOn: true, day: 'monday', at: { hour: 9, minute: 0 } },
}

/** How long In an hour snoozes for, and Later today for each of its hours. */
export const IN_AN_HOUR_MS = 60 * 60_000

const DAY_MS = 24 * 60 * 60_000

/** The days of a week; and the days a weekday words a time within, from today: past them, the weekday would name today's. */
const WEEK = 7

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const MIDNIGHT: TimeOfDay = { hour: 0, minute: 0 }

/**
 * That time, local, on the calendar day `days` after the one `at` falls on:
 * one the clocks skip read past the change, one they pass twice the first.
 */
const onDay = (at: number, days: number, { hour, minute } = MIDNIGHT) => {
  const date = new Date(at)

  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate() + days,
    hour,
    minute,
  ).getTime()
}

/** A day's place in the week, Monday 0 to Sunday 6. */
const placeOf = (day: SnoozeDay) => SNOOZE_DAYS.indexOf(day)

/** The place in the week of the day `at` falls on, local. */
const placeAt = (at: number) => (new Date(at).getDay() + WEEK - 1) % WEEK

/**
 * When a snooze chosen at `now` wakes, as `settings` time it: In an hour an
 * hour on, and Later today its hours on, of real time across a change of
 * the clocks; Tonight its time today, gone by then; Tomorrow its time the
 * next calendar day, so 09:00 pressed at 01:00 wakes 32 hours on; This
 * weekend its time on its day of this week, Monday to Sunday, gone once
 * that has passed; Next week its time on its day of the week after.
 */
export const snoozeAt = (choice: SnoozeChoice, now: number, settings: SnoozeSettings) => {
  switch (choice) {
    case 'hour':
      return now + IN_AN_HOUR_MS
    case 'later':
      return now + settings.later.hours * IN_AN_HOUR_MS
    case 'tonight':
      return onDay(now, 0, settings.tonight.at)
    case 'tomorrow':
      return onDay(now, 1, settings.tomorrow.at)
    case 'weekend':
      return onDay(now, placeOf(settings.weekend.day) - placeAt(now), settings.weekend.at)
    case 'week':
      return onDay(now, WEEK - placeAt(now) + placeOf(settings.week.day), settings.week.at)
  }
}

/**
 * The choices Snooze offers at `now`, in their order: each Lee has on whose
 * time is still to come, so Tonight none from its time to midnight, and
 * This weekend none from its day's time to Monday.
 */
export const snoozeChoicesAt = (now: number, settings: SnoozeSettings) =>
  SNOOZE_CHOICES.filter(choice => settings[choice].isOn && snoozeAt(choice, now, settings) > now)

/** How the app's `snooze.json` of each past version is brought to the next: none yet, the format being at its first. */
const UPGRADES: readonly Upgrade[] = []

/** A time of day as the file holds it: `HH:MM` on the 24-hour clock. */
const TIME_TEXT = /^([01]\d|2[0-3]):([0-5]\d)$/

/** A field of a choice as the file holds it; undefined where the choice is no object. */
const fieldOf = (choice: unknown, key: string) => (isObject(choice) ? choice[key] : undefined)

/** A value the file holds where it is one of `values`, else `fallback`. */
const oneOf = <T>(value: unknown, values: readonly T[], fallback: T) =>
  values.includes(value as T) ? (value as T) : fallback

const isOnOf = (choice: unknown, fallback: boolean) => {
  const on = fieldOf(choice, 'on')

  return typeof on === 'boolean' ? on : fallback
}

const timeOf = (choice: unknown, fallback: TimeOfDay): TimeOfDay => {
  const [, hour, minute] = TIME_TEXT.exec(String(fieldOf(choice, 'at'))) ?? []

  return hour === undefined ? fallback : { hour: Number(hour), minute: Number(minute) }
}

/**
 * Snooze's choices as the app's `snooze.json` sets them: the defaults where
 * there is no file, or it is not a JSON object of a version this reader
 * knows; within one, each choice and each field of it read on its own, one
 * missing or out of range taking its default.
 */
export const snoozeSettingsOf = (text: string | undefined): SnoozeSettings => {
  const file = text === undefined ? undefined : parseVersioned(text, UPGRADES)

  if (file === undefined) {
    return SNOOZE_DEFAULTS
  }

  const { hour, later, tonight, tomorrow, weekend, week } = SNOOZE_DEFAULTS

  return {
    hour: { isOn: isOnOf(file.hour, hour.isOn) },
    later: {
      isOn: isOnOf(file.later, later.isOn),
      hours: oneOf(fieldOf(file.later, 'hours'), LATER_HOURS, later.hours),
    },
    tonight: { isOn: isOnOf(file.tonight, tonight.isOn), at: timeOf(file.tonight, tonight.at) },
    tomorrow: {
      isOn: isOnOf(file.tomorrow, tomorrow.isOn),
      at: timeOf(file.tomorrow, tomorrow.at),
    },
    weekend: {
      isOn: isOnOf(file.weekend, weekend.isOn),
      day: oneOf(fieldOf(file.weekend, 'day'), WEEKEND_DAYS, weekend.day),
      at: timeOf(file.weekend, weekend.at),
    },
    week: {
      isOn: isOnOf(file.week, week.isOn),
      day: oneOf(fieldOf(file.week, 'day'), SNOOZE_DAYS, week.day),
      at: timeOf(file.week, week.at),
    },
  }
}

const twoDigits = (value: number) => String(value).padStart(2, '0')

/** A local time of day on the 24-hour clock: `09:00`. */
const clockOf = (date: Date) => `${twoDigits(date.getHours())}:${twoDigits(date.getMinutes())}`

const weekdayOf = (date: Date) => WEEKDAYS[date.getDay()] ?? ''

/** A local date, its day and month: `3 Nov`. */
const dateOf = (date: Date) => `${date.getDate()} ${MONTHS[date.getMonth()] ?? ''}`

/** The calendar days from the one `now` falls on to the one `at` does, local time, a day of 23 or 25 hours counting one. */
const daysTo = (at: number, now: number) => Math.round((onDay(at, 0) - onDay(now, 0)) / DAY_MS)

/**
 * When a snooze wakes, as the pane says it at `now`: today's time alone
 * (`15:42`), `tomorrow 09:00`, a weekday within the week (`Mon 09:00`), else
 * its date (`3 Nov 09:00`); one with no time, `it moves`.
 */
export const wakeWords = (until: number, now: number) => {
  if (until === UNTIL_IT_MOVES) {
    return 'it moves'
  }

  const date = new Date(until)
  const days = daysTo(until, now)
  const clock = clockOf(date)

  if (days === 0) {
    return clock
  }

  if (days === 1) {
    return `tomorrow ${clock}`
  }

  return days > 1 && days < WEEK ? `${weekdayOf(date)} ${clock}` : `${dateOf(date)} ${clock}`
}

/** A time whole and local, never relative, so its words never change at midnight: `Mon 26 Oct 09:00`, as Claude is told it. */
export const wholeTime = (at: number) => {
  const date = new Date(at)

  return `${weekdayOf(date)} ${dateOf(date)} ${clockOf(date)}`
}
