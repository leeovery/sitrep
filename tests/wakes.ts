/**
 * Snooze's wake times, the one table core's `snoozeAt` and the app's
 * `SnoozeChoice.wakes(after:in:)` are both held to, so the two copies cannot
 * drift (see "Snooze" in DESIGN.md). The app's tests read this file from the
 * source tree, the table between its backticks, so it is text both can parse:
 * a row is a time zone, a choice, the instant pressed and the instant it
 * wakes, ms since the epoch, then both as local times and the case, for the
 * eye alone. A line led by `#` heads a group.
 */
import type { SnoozeChoice } from '../core'

const TABLE = `
# Europe/London, an ordinary weekday
Europe/London     later     1793196000000  1793206800000  Wed 28 Oct 2026 14:00 GMT -> Wed 28 Oct 2026 17:00 GMT: three hours on
Europe/London     tomorrow  1793196000000  1793264400000  Wed 28 Oct 2026 14:00 GMT -> Thu 29 Oct 2026 09:00 GMT: 09:00 the next day
Europe/London     week      1793196000000  1793610000000  Wed 28 Oct 2026 14:00 GMT -> Mon 2 Nov 2026 09:00 GMT: 09:00 the Monday after
Europe/London     later     1793024400000  1793035200000  Mon 26 Oct 2026 14:20 GMT -> Mon 26 Oct 2026 17:20 GMT: three hours on, to the minute
Europe/London     tomorrow  1793024400000  1793091600000  Mon 26 Oct 2026 14:20 GMT -> Tue 27 Oct 2026 09:00 GMT: 09:00 the next day
Europe/London     tomorrow  1793059140000  1793091600000  Mon 26 Oct 2026 23:59 GMT -> Tue 27 Oct 2026 09:00 GMT: a minute before midnight, the next day
Europe/London     tomorrow  1793062800000  1793178000000  Tue 27 Oct 2026 01:00 GMT -> Wed 28 Oct 2026 09:00 GMT: pressed at 01:00, 32 hours on
Europe/London     tomorrow  1793448000000  1793523600000  Sat 31 Oct 2026 12:00 GMT -> Sun 1 Nov 2026 09:00 GMT: into the next month

# Europe/London, Next week from each side of a Monday
Europe/London     week      1793001600000  1793610000000  Mon 26 Oct 2026 08:00 GMT -> Mon 2 Nov 2026 09:00 GMT: a Monday before 09:00, a week on
Europe/London     week      1793024400000  1793610000000  Mon 26 Oct 2026 14:20 GMT -> Mon 2 Nov 2026 09:00 GMT: a Monday, a week on
Europe/London     week      1793579400000  1794214800000  Mon 2 Nov 2026 00:30 GMT -> Mon 9 Nov 2026 09:00 GMT: a Monday just after midnight, a week on
Europe/London     week      1793484000000  1793610000000  Sat 31 Oct 2026 22:00 GMT -> Mon 2 Nov 2026 09:00 GMT: a Saturday night
Europe/London     week      1793563200000  1793610000000  Sun 1 Nov 2026 20:00 GMT -> Mon 2 Nov 2026 09:00 GMT: a Sunday, the next day
Europe/London     week      1792929600000  1793005200000  Sun 25 Oct 2026 12:00 GMT -> Mon 26 Oct 2026 09:00 GMT: a Sunday, the day the clocks went back, the next day

# Europe/London, the clocks going back at 02:00 on Sunday 25 October 2026
Europe/London     tomorrow  1792760400000  1792828800000  Fri 23 Oct 2026 14:00 BST -> Sat 24 Oct 2026 09:00 BST: a Friday
Europe/London     week      1792760400000  1793005200000  Fri 23 Oct 2026 14:00 BST -> Mon 26 Oct 2026 09:00 GMT: a Friday, Monday past the change still 09:00
Europe/London     tomorrow  1792832400000  1792918800000  Sat 24 Oct 2026 10:00 BST -> Sun 25 Oct 2026 09:00 GMT: 09:00 on the day of the change
Europe/London     tomorrow  1792884600000  1793005200000  Sun 25 Oct 2026 00:30 BST -> Mon 26 Oct 2026 09:00 GMT: after midnight before the change, 33.5 hours on
Europe/London     week      1792879200000  1793005200000  Sat 24 Oct 2026 23:00 BST -> Mon 26 Oct 2026 09:00 GMT: across the change
Europe/London     later     1792884600000  1792895400000  Sun 25 Oct 2026 00:30 BST -> Sun 25 Oct 2026 02:30 GMT: three hours of real time, two on the wall clock

# Europe/London, the clocks going forward at 01:00 on Sunday 29 March 2026
Europe/London     tomorrow  1774692000000  1774771200000  Sat 28 Mar 2026 10:00 GMT -> Sun 29 Mar 2026 09:00 BST: 09:00 on the day of the change
Europe/London     tomorrow  1774744200000  1774857600000  Sun 29 Mar 2026 00:30 GMT -> Mon 30 Mar 2026 09:00 BST: after midnight before the change
Europe/London     week      1774735200000  1774857600000  Sat 28 Mar 2026 22:00 GMT -> Mon 30 Mar 2026 09:00 BST: across the change
Europe/London     later     1774744200000  1774755000000  Sun 29 Mar 2026 00:30 GMT -> Sun 29 Mar 2026 04:30 BST: three hours of real time, four on the wall clock

# America/New_York, the clocks going forward at 02:00 on Sunday 8 March 2026
America/New_York  tomorrow  1772895600000  1772974800000  Sat 7 Mar 2026 10:00 EST -> Sun 8 Mar 2026 09:00 EDT: 09:00 on the day of the change
America/New_York  tomorrow  1772947800000  1773061200000  Sun 8 Mar 2026 00:30 EST -> Mon 9 Mar 2026 09:00 EDT: after midnight before the change
America/New_York  week      1772938800000  1773061200000  Sat 7 Mar 2026 22:00 EST -> Mon 9 Mar 2026 09:00 EDT: across the change
America/New_York  later     1772947800000  1772958600000  Sun 8 Mar 2026 00:30 EST -> Sun 8 Mar 2026 04:30 EDT: three hours of real time, four on the wall clock

# America/New_York, the clocks going back at 02:00 on Sunday 1 November 2026
America/New_York  tomorrow  1793455200000  1793541600000  Sat 31 Oct 2026 10:00 EDT -> Sun 1 Nov 2026 09:00 EST: 09:00 on the day of the change
America/New_York  tomorrow  1793507400000  1793628000000  Sun 1 Nov 2026 00:30 EDT -> Mon 2 Nov 2026 09:00 EST: after midnight before the change
America/New_York  week      1793498400000  1793628000000  Sat 31 Oct 2026 22:00 EDT -> Mon 2 Nov 2026 09:00 EST: across the change
America/New_York  later     1793507400000  1793518200000  Sun 1 Nov 2026 00:30 EDT -> Sun 1 Nov 2026 02:30 EST: three hours of real time, two on the wall clock
America/New_York  week      1793581200000  1793628000000  Sun 1 Nov 2026 20:00 EST -> Mon 2 Nov 2026 09:00 EST: a Sunday evening, Monday already in UTC, the next day

# Pacific/Auckland, a day ahead of UTC
Pacific/Auckland  later     1791831600000  1791842400000  Tue 13 Oct 2026 08:00 NZDT -> Tue 13 Oct 2026 11:00 NZDT: a Tuesday morning, Monday still in UTC
Pacific/Auckland  tomorrow  1791831600000  1791921600000  Tue 13 Oct 2026 08:00 NZDT -> Wed 14 Oct 2026 09:00 NZDT: a Tuesday morning, Monday still in UTC
Pacific/Auckland  week      1791831600000  1792353600000  Tue 13 Oct 2026 08:00 NZDT -> Mon 19 Oct 2026 09:00 NZDT: a Tuesday morning, Monday still in UTC
Pacific/Auckland  week      1792350000000  1792958400000  Mon 19 Oct 2026 08:00 NZDT -> Mon 26 Oct 2026 09:00 NZDT: a Monday morning, Sunday still in UTC, a week on
Pacific/Auckland  week      1792270800000  1792353600000  Sun 18 Oct 2026 10:00 NZDT -> Mon 19 Oct 2026 09:00 NZDT: a Sunday morning, Saturday still in UTC, the next day

# Pacific/Auckland, the clocks going back at 03:00 on Sunday 5 April 2026
Pacific/Auckland  tomorrow  1775250000000  1775336400000  Sat 4 Apr 2026 10:00 NZDT -> Sun 5 Apr 2026 09:00 NZST: 09:00 on the day of the change
Pacific/Auckland  week      1775293200000  1775422800000  Sat 4 Apr 2026 22:00 NZDT -> Mon 6 Apr 2026 09:00 NZST: across the change
Pacific/Auckland  later     1775305800000  1775316600000  Sun 5 Apr 2026 01:30 NZDT -> Sun 5 Apr 2026 03:30 NZST: three hours of real time, two on the wall clock

# Pacific/Auckland, the clocks going forward at 02:00 on Sunday 27 September 2026
Pacific/Auckland  tomorrow  1790373600000  1790452800000  Sat 26 Sep 2026 10:00 NZST -> Sun 27 Sep 2026 09:00 NZDT: 09:00 on the day of the change
Pacific/Auckland  week      1790416800000  1790539200000  Sat 26 Sep 2026 22:00 NZST -> Mon 28 Sep 2026 09:00 NZDT: across the change
Pacific/Auckland  later     1790425800000  1790436600000  Sun 27 Sep 2026 00:30 NZST -> Sun 27 Sep 2026 04:30 NZDT: three hours of real time, four on the wall clock

# Asia/Kolkata, half an hour off the UTC hour, no changes
Asia/Kolkata      tomorrow  1791927000000  1792035000000  Wed 14 Oct 2026 03:00 IST -> Thu 15 Oct 2026 09:00 IST: a Wednesday before dawn, Tuesday still in UTC
Asia/Kolkata      week      1792359000000  1792985400000  Mon 19 Oct 2026 03:00 IST -> Mon 26 Oct 2026 09:00 IST: a Monday before dawn, Sunday still in UTC, a week on
Asia/Kolkata      later     1792427400000  1792438200000  Mon 19 Oct 2026 22:00 IST -> Tue 20 Oct 2026 01:00 IST: three hours on, past midnight
`

/** A row of the table. */
export type Wake = {
  zone: string
  choice: SnoozeChoice
  pressed: number
  wakes: number
  /** The rest of the row, for a failure to name. */
  words: string
}

const CHOICES: readonly string[] = ['later', 'tomorrow', 'week'] satisfies SnoozeChoice[]

const isChoice = (word: string): word is SnoozeChoice => CHOICES.includes(word)

const rowOf = (line: string): Wake => {
  const [zone = '', choice = '', pressed, wakes, ...words] = line.split(/\s+/)

  if (!isChoice(choice)) {
    throw new Error(`no choice in the wake table's row: ${line}`)
  }

  return { zone, choice, pressed: Number(pressed), wakes: Number(wakes), words: words.join(' ') }
}

/** Every row of the table, in its order. */
export const WAKES: readonly Wake[] = TABLE.split('\n')
  .filter(line => line.trim() !== '' && !line.startsWith('#'))
  .map(rowOf)
