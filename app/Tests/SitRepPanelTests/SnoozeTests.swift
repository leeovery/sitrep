import Foundation
import SitRepPanel
import SitRepTestSupport
import Testing

/// Snooze's times, worked out in each zone of the table of wake times core's `snoozeAt` is held to as well; and when a
/// snooze wakes, in words, in London, where the clocks go back at 02:00 on Sunday 25 October 2026. Serialized, as one
/// test moves the Mac's time zone, for the process, and back.
@Suite(.backstop, .serialized)
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

    /// A row of the table of wake times core's `snoozeAt` is held to as well, in `tests/wakes.ts`: its zone, its
    /// choice, when it was pressed and when it wakes, none where Snooze does not offer it then, and the rest of its row
    /// in words, for a failure to name.
    private struct Wake {
        let zone: String, choice: SnoozeChoice, pressed: Date, wakes: Date?, words: String

        init(_ row: Substring, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let fields = row.split(whereSeparator: \.isWhitespace)
            let instant = { (field: Substring) in
                Date(timeIntervalSince1970: try #require(Double(field), sourceLocation: sourceLocation) / 1000)
            }
            let choices: [Substring: SnoozeChoice] = [
                "hour": .inAnHour, "later": .laterToday, "tonight": .tonight, "tomorrow": .tomorrow, "week": .nextWeek,
            ]

            try #require(fields.count > 4, "a row of the table: \(row)", sourceLocation: sourceLocation)
            zone = String(fields[0])
            choice = try #require(choices[fields[1]], sourceLocation: sourceLocation)
            pressed = try instant(fields[2])
            wakes = fields[3] == "-" ? nil : try instant(fields[3])
            words = fields[4...].joined(separator: " ")
        }
    }

    /// The table, read from the source tree, its rows between the backticks of `TABLE`, each line led by `#` a
    /// group's heading.
    private static func table(sourceLocation: SourceLocation = #_sourceLocation) throws -> [Wake] {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../tests/wakes.ts")
        let text = try String(contentsOf: file, encoding: .utf8)
        let table = try #require(text.range(of: "const TABLE = `"), sourceLocation: sourceLocation)
        let rows = text[table.upperBound...].prefix { $0 != "`" }

        return try rows.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }.map { row in
            try Wake(row, sourceLocation: sourceLocation)
        }
    }

    /// Every row is offered and wakes at its time, worked out on the Gregorian calendar in its zone; one with no time
    /// is not offered.
    @Test func eachChoiceWakesAtTheTablesTimeInItsZone() throws {
        let table = try Self.table()

        #expect(table.contains { $0.wakes == nil } && table.contains { $0.wakes != nil })
        for wake in table {
            var calendar = Calendar(identifier: .gregorian)

            calendar.timeZone = try #require(TimeZone(identifier: wake.zone))

            let isOffered = SnoozeChoice.offered(at: wake.pressed, in: calendar).contains(wake.choice)
            let wakes = isOffered ? wake.choice.wakes(after: wake.pressed, in: calendar) : nil

            #expect(wakes == wake.wakes, "\(wake.zone) \(wake.words)")
        }
    }

    /// Snooze's choices come in core's order, In an hour first and Tonight third, and every one is offered but Tonight
    /// from 18:00 to midnight, at every hour of October 2026 in London, the clocks going back among them.
    @Test func everyChoiceIsOfferedButTonightFromSixToMidnight() {
        let start = Self.at(1, 0)

        #expect(SnoozeChoice.allCases == [.inAnHour, .laterToday, .tonight, .tomorrow, .nextWeek])
        for hour in 0 ..< 31 * 24 {
            let now = start.addingTimeInterval(TimeInterval(hour) * 60 * 60)
            let isEvening = Self.london.component(.hour, from: now) >= 18
            let expected = SnoozeChoice.allCases.filter { !(isEvening && $0 == .tonight) }

            #expect(SnoozeChoice.offered(at: now, in: Self.london) == expected, "\(now)")
        }
    }

    /// What a row's Snooze offers: the choices offered then, and Until it moves always, after them.
    @Test func aRowsSnoozeOffersTheChoicesOfferedThenAndUntilItMoves() {
        #expect(SnoozeTime.offered(at: Self.at(23, 17, 59), in: Self.london) == [
            .at(.inAnHour), .at(.laterToday), .at(.tonight), .at(.tomorrow), .at(.nextWeek), .untilItMoves,
        ])
        #expect(SnoozeTime.offered(at: Self.at(23, 18), in: Self.london) == [
            .at(.inAnHour), .at(.laterToday), .at(.tomorrow), .at(.nextWeek), .untilItMoves,
        ])
    }

    /// A snooze whose time has come snoozes nothing, in the pane's words; one still to come, or with none, does.
    @Test func aTimeComeAlreadyIsSaidInThePanesWords() {
        let six = Self.at(23, 18)

        #expect(WakeTime.comeAlready(six, at: six.addingTimeInterval(30), in: Self.london) == "18:00 has come already.")
        #expect(WakeTime.comeAlready(six, at: six, in: Self.london) == "18:00 has come already.")
        #expect(WakeTime.comeAlready(six, at: six.addingTimeInterval(-1), in: Self.london) == nil)
        #expect(WakeTime.comeAlready(nil, at: six, in: Self.london) == nil)
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

    /// The calendar the app works snoozes out on is the Gregorian, whatever the Mac is set to, in the Mac's time zone:
    /// one held since follows the zone as the Mac's changes, here through `TZ`, which the process's system zone is read
    /// from again on a reset.
    @Test func theAppsCalendarIsTheGregorianAndFollowsTheMacsTimeZoneAsItChanges() {
        let held = WakeTime.calendar
        let was = ProcessInfo.processInfo.environment["TZ"]

        defer {
            if let was {
                setenv("TZ", was, 1)
            } else {
                unsetenv("TZ")
            }
            NSTimeZone.resetSystemTimeZone()
        }
        setenv("TZ", "Pacific/Chatham", 1)
        NSTimeZone.resetSystemTimeZone()

        #expect(held.identifier == .gregorian)
        #expect(held.timeZone.identifier == "Pacific/Chatham")
    }

    /// A Snoozed row shows when it wakes in its time's place, or with none, that it waits until it moves, its asks' row
    /// as a turn's; any other row, its age.
    @Test func aSnoozedRowsTimeIsWhenItWakes() {
        let now = Self.at(23, 14).timeIntervalSince1970 * 1000
        let line = Session.Line(ask: "k1", title: "Review the plan", since: now - 3_600_000)
        let asleep = Session(
            id: "sr-4t2kq8", project: "Tailspin", name: "Finish the Tailspin migration", kind: .snoozed,
            lines: [line], sub: "Tailspin", wakesAt: Self.at(24, 9).timeIntervalSince1970 * 1000
        )
        var waiting = asleep

        var moves = asleep

        waiting.kind = .needs
        waiting.wakesAt = nil
        moves.wakesAt = nil
        #expect(asleep.timeText(at: now, in: Self.london) == "Sat 09:00")
        #expect(moves.timeText(at: now, in: Self.london) == "until it moves")
        #expect(waiting.timeText(at: now, in: Self.london) == "1h")
        #expect(asleep.title == "Finish the Tailspin migration")
        #expect(asleep.asks == ["k1"])
    }
}
