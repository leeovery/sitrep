/**
 * Snooze's wake times, the one table core's `snoozeAt` and the app's
 * `SnoozeChoice.wakes(after:in:settings:)` are both held to, so the two
 * copies cannot drift (see "Snooze" in DESIGN.md). The app's tests read
 * this file from the source tree, the table between its backticks, so it
 * is text both can parse: a row is a time zone, a choice, its setting after
 * it where the row sets one (`later:+1`, `tonight:20:00`,
 * `weekend:sun:09:00`, `tomorrow:off`), the instant pressed and the instant
 * it wakes, ms since the epoch, or `-` where Snooze does not offer the
 * choice then, then both as local times, which core's tests hold to the
 * instants, and the case. A line led by `#` heads a group.
 */
import {
  LATER_HOURS,
  SNOOZE_CHOICES,
  SNOOZE_DAYS,
  SNOOZE_DEFAULTS,
  WEEKEND_DAYS,
  type SnoozeChoice,
  type SnoozeSettings,
  type TimeOfDay,
} from '../core'

const TABLE = `
# Europe/London, an ordinary weekday
Europe/London     later              1793196000000  1793206800000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 17:00 GMT+0: three hours on
Europe/London     tomorrow           1793196000000  1793264400000  Wed 28 Oct 2026 14:00 GMT+0 -> Thu 29 Oct 2026 09:00 GMT+0: 09:00 the next day
Europe/London     week               1793196000000  1793610000000  Wed 28 Oct 2026 14:00 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: 09:00 the Monday after
Europe/London     later              1793024400000  1793035200000  Mon 26 Oct 2026 14:20 GMT+0 -> Mon 26 Oct 2026 17:20 GMT+0: three hours on, to the minute
Europe/London     tomorrow           1793024400000  1793091600000  Mon 26 Oct 2026 14:20 GMT+0 -> Tue 27 Oct 2026 09:00 GMT+0: 09:00 the next day
Europe/London     tomorrow           1793059140000  1793091600000  Mon 26 Oct 2026 23:59 GMT+0 -> Tue 27 Oct 2026 09:00 GMT+0: a minute before midnight, the next day
Europe/London     tomorrow           1793062800000  1793178000000  Tue 27 Oct 2026 01:00 GMT+0 -> Wed 28 Oct 2026 09:00 GMT+0: pressed at 01:00, 32 hours on
Europe/London     tomorrow           1793448000000  1793523600000  Sat 31 Oct 2026 12:00 GMT+0 -> Sun 1 Nov 2026 09:00 GMT+0: into the next month
Europe/London     tomorrow           1793196037512  1793264400000  Wed 28 Oct 2026 14:00:37.512 GMT+0 -> Thu 29 Oct 2026 09:00 GMT+0: pressed with seconds and ms, waking on the hour
Europe/London     week               1793196037512  1793610000000  Wed 28 Oct 2026 14:00:37.512 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: pressed with seconds and ms, waking on the hour
Europe/London     later              1793196037512  1793206837512  Wed 28 Oct 2026 14:00:37.512 GMT+0 -> Wed 28 Oct 2026 17:00:37.512 GMT+0: three hours on, to the ms
Europe/London     hour               1793196000000  1793199600000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 15:00 GMT+0: an hour on
Europe/London     hour               1793196037512  1793199637512  Wed 28 Oct 2026 14:00:37.512 GMT+0 -> Wed 28 Oct 2026 15:00:37.512 GMT+0: an hour on, to the ms
Europe/London     hour               1793231940000  1793235540000  Wed 28 Oct 2026 23:59 GMT+0 -> Thu 29 Oct 2026 00:59 GMT+0: a minute before midnight, still offered, into the next day

# Europe/London, Tonight, offered until 18:00
Europe/London     tonight            1793196000000  1793210400000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 18:00 GMT+0: 18:00 today
Europe/London     tonight            1793205000000  1793210400000  Wed 28 Oct 2026 16:30 GMT+0 -> Wed 28 Oct 2026 18:00 GMT+0: after 15:00, before Later today's 19:30
Europe/London     later              1793205000000  1793215800000  Wed 28 Oct 2026 16:30 GMT+0 -> Wed 28 Oct 2026 19:30 GMT+0: after 15:00, after Tonight's 18:00
Europe/London     tonight            1793210340000  1793210400000  Wed 28 Oct 2026 17:59 GMT+0 -> Wed 28 Oct 2026 18:00 GMT+0: a minute before 18:00, still offered
Europe/London     tonight            1793210400000  -              Wed 28 Oct 2026 18:00 GMT+0 -> not offered: at 18:00, gone
Europe/London     tonight            1793231940000  -              Wed 28 Oct 2026 23:59 GMT+0 -> not offered: a minute before midnight, gone
Europe/London     tonight            1793062800000  1793124000000  Tue 27 Oct 2026 01:00 GMT+0 -> Tue 27 Oct 2026 18:00 GMT+0: just after midnight, offered again
Europe/London     tonight            1792884600000  1792951200000  Sun 25 Oct 2026 00:30 GMT+1 -> Sun 25 Oct 2026 18:00 GMT+0: the clocks going back, still 18:00
Europe/London     tonight            1774744200000  1774803600000  Sun 29 Mar 2026 00:30 GMT+0 -> Sun 29 Mar 2026 18:00 GMT+1: the clocks going forward, still 18:00

# Europe/London, Next week from each side of a Monday
Europe/London     week               1793001600000  1793610000000  Mon 26 Oct 2026 08:00 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: a Monday before 09:00, a week on
Europe/London     week               1793024400000  1793610000000  Mon 26 Oct 2026 14:20 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: a Monday, a week on
Europe/London     week               1793579400000  1794214800000  Mon 2 Nov 2026 00:30 GMT+0 -> Mon 9 Nov 2026 09:00 GMT+0: a Monday just after midnight, a week on
Europe/London     week               1793271600000  1793610000000  Thu 29 Oct 2026 11:00 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: a Thursday
Europe/London     week               1793484000000  1793610000000  Sat 31 Oct 2026 22:00 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: a Saturday night
Europe/London     week               1793563200000  1793610000000  Sun 1 Nov 2026 20:00 GMT+0 -> Mon 2 Nov 2026 09:00 GMT+0: a Sunday, the next day
Europe/London     week               1792929600000  1793005200000  Sun 25 Oct 2026 12:00 GMT+0 -> Mon 26 Oct 2026 09:00 GMT+0: a Sunday, the day the clocks went back, the next day

# Europe/London, the clocks going back at 02:00 on Sunday 25 October 2026
Europe/London     tomorrow           1792760400000  1792828800000  Fri 23 Oct 2026 14:00 GMT+1 -> Sat 24 Oct 2026 09:00 GMT+1: a Friday
Europe/London     week               1792760400000  1793005200000  Fri 23 Oct 2026 14:00 GMT+1 -> Mon 26 Oct 2026 09:00 GMT+0: a Friday, Monday past the change still 09:00
Europe/London     tomorrow           1792832400000  1792918800000  Sat 24 Oct 2026 10:00 GMT+1 -> Sun 25 Oct 2026 09:00 GMT+0: 09:00 on the day of the change
Europe/London     tomorrow           1792884600000  1793005200000  Sun 25 Oct 2026 00:30 GMT+1 -> Mon 26 Oct 2026 09:00 GMT+0: after midnight before the change, 33.5 hours on
Europe/London     week               1792879200000  1793005200000  Sat 24 Oct 2026 23:00 GMT+1 -> Mon 26 Oct 2026 09:00 GMT+0: across the change
Europe/London     later              1792884600000  1792895400000  Sun 25 Oct 2026 00:30 GMT+1 -> Sun 25 Oct 2026 02:30 GMT+0: three hours of real time, two on the wall clock
Europe/London     hour               1792888200000  1792891800000  Sun 25 Oct 2026 01:30 GMT+1 -> Sun 25 Oct 2026 01:30 GMT+0: an hour of real time, none on the wall clock

# Europe/London, the clocks going forward at 01:00 on Sunday 29 March 2026
Europe/London     tomorrow           1774692000000  1774771200000  Sat 28 Mar 2026 10:00 GMT+0 -> Sun 29 Mar 2026 09:00 GMT+1: 09:00 on the day of the change
Europe/London     tomorrow           1774744200000  1774857600000  Sun 29 Mar 2026 00:30 GMT+0 -> Mon 30 Mar 2026 09:00 GMT+1: after midnight before the change
Europe/London     week               1774735200000  1774857600000  Sat 28 Mar 2026 22:00 GMT+0 -> Mon 30 Mar 2026 09:00 GMT+1: across the change
Europe/London     later              1774744200000  1774755000000  Sun 29 Mar 2026 00:30 GMT+0 -> Sun 29 Mar 2026 04:30 GMT+1: three hours of real time, four on the wall clock
Europe/London     hour               1774744200000  1774747800000  Sun 29 Mar 2026 00:30 GMT+0 -> Sun 29 Mar 2026 02:30 GMT+1: an hour of real time, two on the wall clock

# America/New_York, the clocks going forward at 02:00 on Sunday 8 March 2026
America/New_York  tomorrow           1772895600000  1772974800000  Sat 7 Mar 2026 10:00 GMT-5 -> Sun 8 Mar 2026 09:00 GMT-4: 09:00 on the day of the change
America/New_York  tomorrow           1772947800000  1773061200000  Sun 8 Mar 2026 00:30 GMT-5 -> Mon 9 Mar 2026 09:00 GMT-4: after midnight before the change
America/New_York  week               1772938800000  1773061200000  Sat 7 Mar 2026 22:00 GMT-5 -> Mon 9 Mar 2026 09:00 GMT-4: across the change
America/New_York  later              1772947800000  1772958600000  Sun 8 Mar 2026 00:30 GMT-5 -> Sun 8 Mar 2026 04:30 GMT-4: three hours of real time, four on the wall clock
America/New_York  hour               1772951400000  1772955000000  Sun 8 Mar 2026 01:30 GMT-5 -> Sun 8 Mar 2026 03:30 GMT-4: an hour of real time, two on the wall clock
America/New_York  tonight            1772947800000  1773007200000  Sun 8 Mar 2026 00:30 GMT-5 -> Sun 8 Mar 2026 18:00 GMT-4: the clocks going forward, still 18:00

# America/New_York, the clocks going back at 02:00 on Sunday 1 November 2026
America/New_York  tomorrow           1793455200000  1793541600000  Sat 31 Oct 2026 10:00 GMT-4 -> Sun 1 Nov 2026 09:00 GMT-5: 09:00 on the day of the change
America/New_York  tomorrow           1793507400000  1793628000000  Sun 1 Nov 2026 00:30 GMT-4 -> Mon 2 Nov 2026 09:00 GMT-5: after midnight before the change
America/New_York  week               1793498400000  1793628000000  Sat 31 Oct 2026 22:00 GMT-4 -> Mon 2 Nov 2026 09:00 GMT-5: across the change
America/New_York  later              1793507400000  1793518200000  Sun 1 Nov 2026 00:30 GMT-4 -> Sun 1 Nov 2026 02:30 GMT-5: three hours of real time, two on the wall clock
America/New_York  hour               1793511000000  1793514600000  Sun 1 Nov 2026 01:30 GMT-4 -> Sun 1 Nov 2026 01:30 GMT-5: an hour of real time, none on the wall clock
America/New_York  tonight            1793507400000  1793574000000  Sun 1 Nov 2026 00:30 GMT-4 -> Sun 1 Nov 2026 18:00 GMT-5: the clocks going back, still 18:00
America/New_York  week               1793581200000  1793628000000  Sun 1 Nov 2026 20:00 GMT-5 -> Mon 2 Nov 2026 09:00 GMT-5: a Sunday evening, Monday already in UTC, the next day

# Pacific/Auckland, a day ahead of UTC
Pacific/Auckland  later              1791831600000  1791842400000  Tue 13 Oct 2026 08:00 GMT+13 -> Tue 13 Oct 2026 11:00 GMT+13: a Tuesday morning, Monday still in UTC
Pacific/Auckland  tomorrow           1791831600000  1791921600000  Tue 13 Oct 2026 08:00 GMT+13 -> Wed 14 Oct 2026 09:00 GMT+13: a Tuesday morning, Monday still in UTC
Pacific/Auckland  week               1791831600000  1792353600000  Tue 13 Oct 2026 08:00 GMT+13 -> Mon 19 Oct 2026 09:00 GMT+13: a Tuesday morning, Monday still in UTC
Pacific/Auckland  tonight            1791831600000  1791867600000  Tue 13 Oct 2026 08:00 GMT+13 -> Tue 13 Oct 2026 18:00 GMT+13: a Tuesday morning, Monday still in UTC, 18:00 its own day
Pacific/Auckland  week               1792350000000  1792958400000  Mon 19 Oct 2026 08:00 GMT+13 -> Mon 26 Oct 2026 09:00 GMT+13: a Monday morning, Sunday still in UTC, a week on
Pacific/Auckland  week               1792270800000  1792353600000  Sun 18 Oct 2026 10:00 GMT+13 -> Mon 19 Oct 2026 09:00 GMT+13: a Sunday morning, Saturday still in UTC, the next day

# Pacific/Auckland, the clocks going back at 03:00 on Sunday 5 April 2026
Pacific/Auckland  tomorrow           1775250000000  1775336400000  Sat 4 Apr 2026 10:00 GMT+13 -> Sun 5 Apr 2026 09:00 GMT+12: 09:00 on the day of the change
Pacific/Auckland  week               1775293200000  1775422800000  Sat 4 Apr 2026 22:00 GMT+13 -> Mon 6 Apr 2026 09:00 GMT+12: across the change
Pacific/Auckland  later              1775305800000  1775316600000  Sun 5 Apr 2026 01:30 GMT+13 -> Sun 5 Apr 2026 03:30 GMT+12: three hours of real time, two on the wall clock
Pacific/Auckland  hour               1775309400000  1775313000000  Sun 5 Apr 2026 02:30 GMT+13 -> Sun 5 Apr 2026 02:30 GMT+12: an hour of real time, none on the wall clock

# Pacific/Auckland, the clocks going forward at 02:00 on Sunday 27 September 2026
Pacific/Auckland  tomorrow           1790373600000  1790452800000  Sat 26 Sep 2026 10:00 GMT+12 -> Sun 27 Sep 2026 09:00 GMT+13: 09:00 on the day of the change
Pacific/Auckland  week               1790416800000  1790539200000  Sat 26 Sep 2026 22:00 GMT+12 -> Mon 28 Sep 2026 09:00 GMT+13: across the change
Pacific/Auckland  later              1790425800000  1790436600000  Sun 27 Sep 2026 00:30 GMT+12 -> Sun 27 Sep 2026 04:30 GMT+13: three hours of real time, four on the wall clock

# America/Santiago, the clocks going back at midnight on Sunday 5 April 2026, 23:00 to midnight passed twice
America/Santiago  tomorrow           1775307600000  1775394000000  Sat 4 Apr 2026 10:00 GMT-3 -> Sun 5 Apr 2026 09:00 GMT-4: 09:00 on the day after the change
America/Santiago  tomorrow           1775352600000  1775394000000  Sat 4 Apr 2026 22:30 GMT-3 -> Sun 5 Apr 2026 09:00 GMT-4: late on the night of the change, before it
America/Santiago  week               1775350800000  1775480400000  Sat 4 Apr 2026 22:00 GMT-3 -> Mon 6 Apr 2026 09:00 GMT-4: across the change
America/Santiago  tomorrow           1775363400000  1775480400000  Sun 5 Apr 2026 00:30 GMT-4 -> Mon 6 Apr 2026 09:00 GMT-4: just after midnight, after the change
America/Santiago  later              1775352600000  1775363400000  Sat 4 Apr 2026 22:30 GMT-3 -> Sun 5 Apr 2026 00:30 GMT-4: three hours of real time, two on the wall clock
America/Santiago  hour               1775356200000  1775359800000  Sat 4 Apr 2026 23:30 GMT-3 -> Sat 4 Apr 2026 23:30 GMT-4: an hour of real time, none on the wall clock
America/Santiago  tonight            1775352600000  -              Sat 4 Apr 2026 22:30 GMT-3 -> not offered: late on the night of the change, gone

# America/Santiago, the clocks going forward at midnight on Sunday 6 September 2026, its day starting at 01:00
America/Santiago  tomorrow           1788616800000  1788696000000  Sat 5 Sep 2026 10:00 GMT-4 -> Sun 6 Sep 2026 09:00 GMT-3: 09:00 on the day that starts at 01:00
America/Santiago  tomorrow           1788665400000  1788696000000  Sat 5 Sep 2026 23:30 GMT-4 -> Sun 6 Sep 2026 09:00 GMT-3: just before the skipped midnight
America/Santiago  week               1788660000000  1788782400000  Sat 5 Sep 2026 22:00 GMT-4 -> Mon 7 Sep 2026 09:00 GMT-3: across the change
America/Santiago  week               1788544800000  1788782400000  Fri 4 Sep 2026 14:00 GMT-4 -> Mon 7 Sep 2026 09:00 GMT-3: a Friday, across the change
America/Santiago  tomorrow           1788669000000  1788782400000  Sun 6 Sep 2026 01:30 GMT-3 -> Mon 7 Sep 2026 09:00 GMT-3: just after the skipped midnight
America/Santiago  week               1788669000000  1788782400000  Sun 6 Sep 2026 01:30 GMT-3 -> Mon 7 Sep 2026 09:00 GMT-3: a Sunday that started at 01:00, the next day
America/Santiago  later              1788661800000  1788672600000  Sat 5 Sep 2026 22:30 GMT-4 -> Sun 6 Sep 2026 02:30 GMT-3: three hours of real time, four on the wall clock
America/Santiago  hour               1788665400000  1788669000000  Sat 5 Sep 2026 23:30 GMT-4 -> Sun 6 Sep 2026 01:30 GMT-3: across the skipped midnight, two on the wall clock
America/Santiago  tonight            1788669000000  1788728400000  Sun 6 Sep 2026 01:30 GMT-3 -> Sun 6 Sep 2026 18:00 GMT-3: a Sunday that started at 01:00

# Asia/Kolkata, half an hour off the UTC hour, no changes
Asia/Kolkata      tomorrow           1791927000000  1792035000000  Wed 14 Oct 2026 03:00 GMT+5:30 -> Thu 15 Oct 2026 09:00 GMT+5:30: a Wednesday before dawn, Tuesday still in UTC
Asia/Kolkata      week               1792359000000  1792985400000  Mon 19 Oct 2026 03:00 GMT+5:30 -> Mon 26 Oct 2026 09:00 GMT+5:30: a Monday before dawn, Sunday still in UTC, a week on
Asia/Kolkata      later              1792427400000  1792438200000  Mon 19 Oct 2026 22:00 GMT+5:30 -> Tue 20 Oct 2026 01:00 GMT+5:30: three hours on, past midnight
Asia/Kolkata      hour               1792432800000  1792436400000  Mon 19 Oct 2026 23:30 GMT+5:30 -> Tue 20 Oct 2026 00:30 GMT+5:30: an hour on, past midnight
Asia/Kolkata      tonight            1791927000000  1791981000000  Wed 14 Oct 2026 03:00 GMT+5:30 -> Wed 14 Oct 2026 18:00 GMT+5:30: before dawn, Tuesday still in UTC, 18:00 its own day
Asia/Kolkata      tonight            1792427400000  -              Mon 19 Oct 2026 22:00 GMT+5:30 -> not offered: past 18:00, Monday afternoon in UTC

# Later today at 1, 2 or 4 hours on
Europe/London     later:+1           1793196000000  1793199600000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 15:00 GMT+0: an hour on
Europe/London     later:+4           1793196000000  1793210400000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 18:00 GMT+0: four hours on
Europe/London     later:+1           1792888200000  1792891800000  Sun 25 Oct 2026 01:30 GMT+1 -> Sun 25 Oct 2026 01:30 GMT+0: the clocks going back, an hour of real time, none on the wall clock
America/New_York  later:+2           1772947800000  1772955000000  Sun 8 Mar 2026 00:30 GMT-5 -> Sun 8 Mar 2026 03:30 GMT-4: the clocks going forward, two hours of real time, three on the wall clock

# Europe/London, Tonight at 20:00 or 20:30, offered until then
Europe/London     tonight:20:00      1793196000000  1793217600000  Wed 28 Oct 2026 14:00 GMT+0 -> Wed 28 Oct 2026 20:00 GMT+0: 20:00 today
Europe/London     tonight:20:00      1793212200000  1793217600000  Wed 28 Oct 2026 18:30 GMT+0 -> Wed 28 Oct 2026 20:00 GMT+0: after 18:00, still offered
Europe/London     tonight:20:00      1793217600000  -              Wed 28 Oct 2026 20:00 GMT+0 -> not offered: at its time, gone
Europe/London     tonight:20:30      1793218500000  1793219400000  Wed 28 Oct 2026 20:15 GMT+0 -> Wed 28 Oct 2026 20:30 GMT+0: to the minute
Europe/London     tonight:20:00      1792884600000  1792958400000  Sun 25 Oct 2026 00:30 GMT+1 -> Sun 25 Oct 2026 20:00 GMT+0: the clocks going back, still 20:00

# Tomorrow at another time, and at times the clocks skip or pass twice
Europe/London     tomorrow:07:30     1793196000000  1793259000000  Wed 28 Oct 2026 14:00 GMT+0 -> Thu 29 Oct 2026 07:30 GMT+0: 07:30 the next day
Europe/London     tomorrow:01:30     1774692000000  1774747800000  Sat 28 Mar 2026 10:00 GMT+0 -> Sun 29 Mar 2026 02:30 GMT+1: 01:30, which the clocks skip, read past the change
Europe/London     tomorrow:01:30     1792832400000  1792888200000  Sat 24 Oct 2026 10:00 GMT+1 -> Sun 25 Oct 2026 01:30 GMT+1: 01:30, which the clocks pass twice, the first
America/Santiago  tomorrow:00:30     1788616800000  1788669000000  Sat 5 Sep 2026 10:00 GMT-4 -> Sun 6 Sep 2026 01:30 GMT-3: 00:30, on the day that starts at 01:00, read past the change

# This weekend, off by default; on, offered from Monday until its day's time
Europe/London     weekend            1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: off by default
Europe/London     weekend:sat:09:00  1793024400000  1793437200000  Mon 26 Oct 2026 14:20 GMT+0 -> Sat 31 Oct 2026 09:00 GMT+0: a Monday, the Saturday of its week
Europe/London     weekend:sat:09:00  1793196000000  1793437200000  Wed 28 Oct 2026 14:00 GMT+0 -> Sat 31 Oct 2026 09:00 GMT+0: a Wednesday, the coming Saturday
Europe/London     weekend:sat:09:00  1793433600000  1793437200000  Sat 31 Oct 2026 08:00 GMT+0 -> Sat 31 Oct 2026 09:00 GMT+0: that Saturday before 09:00, still offered
Europe/London     weekend:sat:09:00  1793437200000  -              Sat 31 Oct 2026 09:00 GMT+0 -> not offered: that Saturday at 09:00, gone
Europe/London     weekend:sat:09:00  1793563200000  -              Sun 1 Nov 2026 20:00 GMT+0 -> not offered: the Sunday after, gone until Monday
Europe/London     weekend:sat:09:00  1793579400000  1794042000000  Mon 2 Nov 2026 00:30 GMT+0 -> Sat 7 Nov 2026 09:00 GMT+0: the Monday after, just after midnight, offered again
Europe/London     weekend:sun:09:00  1793448000000  1793523600000  Sat 31 Oct 2026 12:00 GMT+0 -> Sun 1 Nov 2026 09:00 GMT+0: set to Sunday, a Saturday afternoon, the next morning
Europe/London     weekend:sun:09:00  1793520000000  1793523600000  Sun 1 Nov 2026 08:00 GMT+0 -> Sun 1 Nov 2026 09:00 GMT+0: set to Sunday, that Sunday before 09:00
Europe/London     weekend:sun:09:00  1793534400000  -              Sun 1 Nov 2026 12:00 GMT+0 -> not offered: set to Sunday, that Sunday afternoon, gone
Europe/London     weekend:sun:10:30  1792760400000  1792924200000  Fri 23 Oct 2026 14:00 GMT+1 -> Sun 25 Oct 2026 10:30 GMT+0: a Friday, the clocks going back between
America/New_York  weekend:sun:09:00  1793498400000  1793541600000  Sat 31 Oct 2026 22:00 GMT-4 -> Sun 1 Nov 2026 09:00 GMT-5: a Saturday night, the clocks going back between
Pacific/Auckland  weekend:sat:09:00  1791831600000  1792180800000  Tue 13 Oct 2026 08:00 GMT+13 -> Sat 17 Oct 2026 09:00 GMT+13: a Tuesday morning, Monday still in UTC
Pacific/Auckland  weekend:sun:09:00  1792350000000  1792872000000  Mon 19 Oct 2026 08:00 GMT+13 -> Sun 25 Oct 2026 09:00 GMT+13: a Monday morning, Sunday still in UTC, the Sunday six days on

# Next week on another day, at another time
Europe/London     week:fri:09:00     1793196000000  1793955600000  Wed 28 Oct 2026 14:00 GMT+0 -> Fri 6 Nov 2026 09:00 GMT+0: a Wednesday, the Friday nine days on
Europe/London     week:fri:09:00     1793563200000  1793955600000  Sun 1 Nov 2026 20:00 GMT+0 -> Fri 6 Nov 2026 09:00 GMT+0: a Sunday, the Friday five days on
Europe/London     week:fri:09:00     1793347200000  1793955600000  Fri 30 Oct 2026 08:00 GMT+0 -> Fri 6 Nov 2026 09:00 GMT+0: a Friday, a week on
Europe/London     week:mon:07:00     1793196000000  1793602800000  Wed 28 Oct 2026 14:00 GMT+0 -> Mon 2 Nov 2026 07:00 GMT+0: Monday at 07:00
Europe/London     week:sun:18:00     1793196000000  1794160800000  Wed 28 Oct 2026 14:00 GMT+0 -> Sun 8 Nov 2026 18:00 GMT+0: the week after ends on its Sunday
Europe/London     week:fri:09:00     1792587600000  1793350800000  Wed 21 Oct 2026 14:00 GMT+1 -> Fri 30 Oct 2026 09:00 GMT+0: the clocks going back between
Asia/Kolkata      week:fri:09:00     1792359000000  1793331000000  Mon 19 Oct 2026 03:00 GMT+5:30 -> Fri 30 Oct 2026 09:00 GMT+5:30: a Monday before dawn, Sunday still in UTC

# Europe/London, a choice switched off
Europe/London     hour:off           1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: In an hour off
Europe/London     later:off          1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: Later today off
Europe/London     tonight:off        1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: Tonight off, its time to come
Europe/London     tomorrow:off       1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: Tomorrow off
Europe/London     week:off           1793196000000  -              Wed 28 Oct 2026 14:00 GMT+0 -> not offered: Next week off
`

/** A row of the table. */
export type Wake = {
  zone: string
  choice: SnoozeChoice
  /** Snooze's choices as the row sets them: the defaults, its own choice's setting over them. */
  settings: SnoozeSettings
  pressed: number
  /** When it wakes; none where Snooze does not offer the choice when pressed. */
  wakes: number | undefined
  /** The rest of the row: `pressed -> wakes: the case`, both local times in the zone, or `pressed -> not offered: the case`. */
  words: string
}

const CHOICES: readonly string[] = SNOOZE_CHOICES

const isChoice = (word: string): word is SnoozeChoice => CHOICES.includes(word)

const NOT_OFFERED = '-'

/** A day as the table shortens it, to its first three letters. */
const dayOf = (short: string | undefined) =>
  SNOOZE_DAYS.find(day => short?.length === 3 && day.startsWith(short))

/** A time as the table words it, `20:00`, split at its colon. */
const timeOf = ([hour, minute]: readonly (string | undefined)[]): TimeOfDay | undefined => {
  const time = { hour: Number(hour), minute: Number(minute) }

  return Number.isInteger(time.hour) && time.hour >= 0 && time.hour < 24 &&
    Number.isInteger(time.minute) && time.minute >= 0 && time.minute < 60
    ? time
    : undefined
}

/** A choice's setting as the row gives it after its name, on; undefined where it gives none this choice takes. */
const settingOf = (choice: SnoozeChoice, [first, ...rest]: readonly string[]) => {
  const hours = LATER_HOURS.find(each => first === `+${each}`)
  const day = dayOf(first)
  const weekendDay = WEEKEND_DAYS.find(each => each === day)
  const at = timeOf([first, ...rest])
  const dayAt = timeOf(rest)

  switch (choice) {
    case 'hour':
      return undefined
    case 'later':
      return hours === undefined || rest.length > 0 ? undefined : { isOn: true, hours }
    case 'tonight':
    case 'tomorrow':
      return at && { isOn: true, at }
    case 'weekend':
      return weekendDay && dayAt && { isOn: true, day: weekendDay, at: dayAt }
    case 'week':
      return day && dayAt && { isOn: true, day, at: dayAt }
  }
}

/**
 * The defaults with a row's own choice's setting over them: `off`; Later
 * today's hours on (`+1`); Tonight's and Tomorrow's time (`20:00`); This
 * weekend's and Next week's day and time (`sun:09:00`), each on. A choice
 * alone is the defaults.
 */
const settingsOf = (choice: SnoozeChoice, setting: readonly string[]) => {
  const set =
    setting.join(':') === 'off'
      ? { ...SNOOZE_DEFAULTS[choice], isOn: false }
      : settingOf(choice, setting)

  return setting.length === 0 ? SNOOZE_DEFAULTS : set && { ...SNOOZE_DEFAULTS, [choice]: set }
}

const rowOf = (line: string): Wake => {
  const [zone = '', field = '', pressed, wakes, ...words] = line.split(/\s+/)
  const [choice = '', ...setting] = field.split(':')
  const pressedAt = Number(pressed)
  const wakesAt = wakes === NOT_OFFERED ? undefined : Number(wakes)
  const settings = isChoice(choice) ? settingsOf(choice, setting) : undefined

  if (
    !isChoice(choice) ||
    settings === undefined ||
    ![pressedAt, wakesAt ?? 0].every(Number.isSafeInteger)
  ) {
    throw new Error(`not a row of the wake table: ${line}`)
  }

  return { zone, choice, settings, pressed: pressedAt, wakes: wakesAt, words: words.join(' ') }
}

/** Every row of the table, in its order. */
export const WAKES: readonly Wake[] = TABLE.split('\n')
  .filter(line => line.trim() !== '' && !line.startsWith('#'))
  .map(rowOf)
