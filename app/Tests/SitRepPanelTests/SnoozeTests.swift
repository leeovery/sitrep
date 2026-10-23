import Foundation
import SitRepPanel
import Testing

/// Snooze's times, worked out on the calendar in London, where the clocks go back at 02:00 on Sunday 25 October 2026,
/// to the cases core's `snoozeAt` is held to; and when a snooze wakes, in words.
struct SnoozeTests {
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// That day and time in London, October 2026 unless another month is given.
    private static func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        london.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func wakes(_ choice: SnoozeChoice, after now: Date) -> Date {
        choice.wakes(after: now, in: london)
    }

    @Test func laterTodayIsThreeHoursOn() {
        #expect(Self.wakes(.laterToday, after: Self.at(23, 14)) == Self.at(23, 17))
    }

    /// Friday: Tomorrow is Saturday 09:00; Next week Monday 09:00, past the clocks going back, still 09:00.
    @Test func fromAFridayTomorrowIsSaturdayAndNextWeekMondayAt0900() {
        #expect(Self.wakes(.tomorrow, after: Self.at(23, 14)) == Self.at(24, 9))
        #expect(Self.wakes(.nextWeek, after: Self.at(23, 14)) == Self.at(26, 9))
        #expect(Self.at(26, 9).timeIntervalSince(Self.at(23, 14)) == (3 * 24 - 5 + 1) * 3600)
    }

    @Test func fromAMondayNextWeekIsAWeekOn() {
        #expect(Self.wakes(.nextWeek, after: Self.at(26, 10)) == Self.at(2, 9, month: 11))
        #expect(Self.wakes(.tomorrow, after: Self.at(26, 10)) == Self.at(27, 9))
    }

    @Test func fromASundayNextWeekIsTheMorning() {
        #expect(Self.wakes(.nextWeek, after: Self.at(25, 12)) == Self.at(26, 9))
    }

    /// The day after today is the next calendar day: pressed at 01:00, Tomorrow wakes 32 hours on; pressed at 00:30 on
    /// the night the clocks go back, Monday 09:00, 33 and a half hours on.
    @Test func afterMidnightTomorrowIsTheNextCalendarDay() {
        #expect(Self.wakes(.tomorrow, after: Self.at(23, 1)).timeIntervalSince(Self.at(23, 1)) == 32 * 3600)
        #expect(Self.wakes(.tomorrow, after: Self.at(25, 0, 30)) == Self.at(26, 9))
        #expect(Self.at(26, 9).timeIntervalSince(Self.at(25, 0, 30)) == 33.5 * 3600)
    }

    // MARK: When it wakes, in words

    private static func words(_ wakes: Date, spoken: Bool = false) -> String {
        WakeTime.words(wakes, at: at(23, 14), in: london, spoken: spoken)
    }

    @Test func todayItIsItsTimeAlone() {
        #expect(Self.words(Self.at(23, 17, 42)) == "17:42")
        #expect(Self.words(Self.at(23, 23, 59)) == "23:59")
    }

    /// Within the six days after today, tomorrow among them, across the clocks going back too.
    @Test func withinTheWeekItIsItsWeekdayAndTime() {
        #expect(Self.words(Self.at(24, 9)) == "Sat 09:00")
        #expect(Self.words(Self.at(26, 9)) == "Mon 09:00")
        #expect(Self.words(Self.at(29, 9)) == "Thu 09:00")
    }

    /// A week on the weekday would name today's, so it is the date.
    @Test func furtherOutItIsItsDateAndTime() {
        #expect(Self.words(Self.at(30, 9)) == "30 Oct 09:00")
        #expect(Self.words(Self.at(3, 9, month: 11)) == "3 Nov 09:00")
    }

    @Test func spokenItsWeekdayAndMonthAreWhole() {
        #expect(Self.words(Self.at(24, 9), spoken: true) == "Saturday 09:00")
        #expect(Self.words(Self.at(3, 9, month: 11), spoken: true) == "3 November 09:00")
    }

    /// Its words change only at midnight.
    @Test func itsWordsChangeAtTheNextMidnight() {
        #expect(WakeTime.changes(after: Self.at(23, 14), in: Self.london) == Self.at(24, 0))
        #expect(WakeTime.changes(after: Self.at(25, 12), in: Self.london) == Self.at(26, 0))
    }

    // MARK: On another calendar

    /// A calendar of this kind in London, as the Mac may be set to.
    private static func london(_ kind: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: kind)

        calendar.timeZone = london.timeZone
        return calendar
    }

    /// On a Hebrew or an Islamic calendar the words and the times are core's, the Gregorian's: 6 September 2027 falls
    /// in Elul of a Hebrew leap year, its 13th month.
    @Test(arguments: [Calendar.Identifier.hebrew, .islamicUmmAlQura])
    func onAnotherCalendarTheyAreTheGregoriansInItsTimeZone(kind: Calendar.Identifier) {
        let calendar = Self.london(kind), now = Self.at(23, 14)
        let elul = Self.london.date(from: DateComponents(year: 2027, month: 9, day: 6, hour: 9))!

        #expect(WakeTime.words(elul, at: now, in: calendar) == "6 Sep 09:00")
        #expect(WakeTime.words(Self.at(3, 9, month: 11), at: now, in: calendar, spoken: true) == "3 November 09:00")
        #expect(WakeTime.words(Self.at(24, 9), at: now, in: calendar) == "Sat 09:00")
        #expect(SnoozeChoice.allCases.map { $0.wakes(after: now, in: calendar) }
            == SnoozeChoice.allCases.map { Self.wakes($0, after: now) })
        #expect(WakeTime.changes(after: now, in: calendar) == Self.at(24, 0))
    }

    /// The calendar the app works snoozes out on is the Gregorian in the Mac's time zone, whatever it is set to.
    @Test func theAppsCalendarIsTheGregorian() {
        #expect(WakeTime.calendar.identifier == .gregorian)
        #expect(WakeTime.calendar.timeZone.identifier == TimeZone.current.identifier)
    }

    /// A Snoozed row shows when it wakes in its time's place; any other row, its age.
    @Test func aSnoozedRowsTimeIsWhenItWakes() {
        let now = Self.at(23, 14).timeIntervalSince1970 * 1000
        let line = Session.Line(ask: "k1", title: "Review the plan", since: now - 3_600_000)
        let asleep = Session(
            id: "sr-4g01a7", project: "Harness", name: "Finish the Harness modernisation", kind: .snoozed,
            lines: [line], sub: "Harness", wakesAt: Self.at(24, 9).timeIntervalSince1970 * 1000
        )
        var waiting = asleep

        waiting.kind = .needs
        waiting.wakesAt = nil
        #expect(asleep.timeText(at: now, in: Self.london) == "Sat 09:00")
        #expect(waiting.timeText(at: now, in: Self.london) == "1h")
        #expect(asleep.title == "Finish the Harness modernisation")
        #expect(asleep.asks == ["k1"])
    }
}
