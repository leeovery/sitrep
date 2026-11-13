/**
 * Snooze's times, worked out where it is pressed, on that Mac's calendar and
 * in its time zone, so 09:00 is 09:00 across a change of the clocks; and a
 * snooze's time in words, as the pane and Claude say it (see "Snooze" in
 * DESIGN.md). What is pressed is stored as the instant it comes to, and read
 * as a local time again only to word it.
 */

import { UNTIL_IT_MOVES } from './types'

/** Snooze's choices: later today, tomorrow, or next week. */
export type SnoozeChoice = 'later' | 'tomorrow' | 'week'

/** How long Later today snoozes for. */
export const LATER_MS = 3 * 60 * 60_000

/** The hour Tomorrow and Next week wake at, local time. */
const WAKING_HOUR = 9

const DAY_MS = 24 * 60 * 60_000

/** The days a weekday words a time within, from today: past them, the weekday would name today's. */
const WEEK = 7

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** `hour` o'clock, local time, on the calendar day `days` after the one `at` falls on. */
const onDay = (at: number, days: number, hour = 0) => {
  const date = new Date(at)

  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days, hour).getTime()
}

/** The days from a weekday to the Monday after it: a week on from a Monday. */
const toMonday = (weekday: number) => (8 - weekday) % WEEK || WEEK

/**
 * When a snooze chosen at `now` wakes: Later today three hours on; Tomorrow
 * 09:00 the next calendar day, so pressed at 01:00 it wakes 32 hours on;
 * Next week 09:00 the Monday after today.
 */
export const snoozeAt = (choice: SnoozeChoice, now: number) => {
  switch (choice) {
    case 'later':
      return now + LATER_MS
    case 'tomorrow':
      return onDay(now, 1, WAKING_HOUR)
    case 'week':
      return onDay(now, toMonday(new Date(now).getDay()), WAKING_HOUR)
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
