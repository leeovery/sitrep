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

    private static let defaults = SnoozeSettings()

    private static func wakes(_ choice: SnoozeChoice, after now: Date) -> Date {
        choice.wakes(after: now, in: london, settings: defaults)
    }

    /// A row of the table of wake times core's `snoozeAt` is held to as well, in `tests/wakes.ts`: its zone, its
    /// choice, the settings it gives, when it was pressed and when it wakes, none where Snooze does not offer it then,
    /// and the rest of its row in words, for a failure to name.
    private struct Wake {
        let zone: String, choice: SnoozeChoice, settings: SnoozeSettings, pressed: Date, wakes: Date?, words: String

        init(_ row: Substring, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let fields = row.split(whereSeparator: \.isWhitespace)
            let instant = { (field: Substring) in
                Date(timeIntervalSince1970: try #require(Double(field), sourceLocation: sourceLocation) / 1000)
            }

            try #require(fields.count > 4, "a row of the table: \(row)", sourceLocation: sourceLocation)

            let setting = fields[1].split(separator: ":").map(String.init)

            zone = String(fields[0])
            choice = try #require(Self.choices[setting[0]], "a choice: \(row)", sourceLocation: sourceLocation)
            settings = try #require(
                Self.settings(choice, Array(setting.dropFirst())), "a setting: \(row)", sourceLocation: sourceLocation
            )
            pressed = try instant(fields[2])
            wakes = fields[3] == "-" ? nil : try instant(fields[3])
            words = fields[4...].joined(separator: " ")
        }

        /// Each choice by core's name for it.
        static let choices: [String: SnoozeChoice] = [
            "hour": .inAnHour, "later": .laterToday, "tonight": .tonight, "tomorrow": .tomorrow,
            "weekend": .thisWeekend, "week": .nextWeek,
        ]

        /// The defaults with the row's own choice's setting over them: `off`; Later today's hours on (`+1`); Tonight's
        /// and Tomorrow's time (`20:00`); This weekend's and Next week's day, by its first three letters, and time
        /// (`sun:09:00`), each on. A choice alone is the defaults; nil for a setting the choice does not take.
        static func settings(_ choice: SnoozeChoice, _ setting: [String]) -> SnoozeSettings? {
            var settings = SnoozeSettings()

            guard !setting.isEmpty, setting != ["off"] else {
                settings.set(choice, on: setting.isEmpty && settings.isOn(choice))
                return settings
            }

            let hours = SnoozeSettings.HoursOn.choices.first { setting == ["+\($0)"] }
            let at = setting.count == 2 ? time(setting[0], setting[1]) : nil
            let day = setting.count == 3 ? Self.day(setting[0]) : nil
            let dayAt = setting.count == 3 ? time(setting[1], setting[2]) : nil

            switch choice {
            case .inAnHour:
                return nil
            case .laterToday:
                guard let hours else {
                    return nil
                }
                settings.laterToday = .init(isOn: true, hours: hours)
            case .tonight:
                guard let at else {
                    return nil
                }
                settings.tonight = .init(isOn: true, at: at)
            case .tomorrow:
                guard let at else {
                    return nil
                }
                settings.tomorrow = .init(isOn: true, at: at)
            case .thisWeekend:
                guard let day, Weekday.weekend.contains(day), let dayAt else {
                    return nil
                }
                settings.thisWeekend = .init(isOn: true, day: day, at: dayAt)
            case .nextWeek:
                guard let day, let dayAt else {
                    return nil
                }
                settings.nextWeek = .init(isOn: true, day: day, at: dayAt)
            }
            return settings
        }

        private static func day(_ short: String) -> Weekday? {
            Weekday.allCases.first { short.count == 3 && $0.rawValue.hasPrefix(short) }
        }

        /// A time as the file holds one, read as the settings read it, so one out of range is none.
        private static func time(_ hour: String, _ minute: String) -> TimeOfDay? {
            try? JSONDecoder().decode(TimeOfDay.self, from: Data("\"\(hour):\(minute)\"".utf8))
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

    /// Every row is offered and wakes at its time, worked out on the Gregorian calendar in its zone under its settings;
    /// one with no time is not offered.
    @Test func eachChoiceWakesAtTheTablesTimeInItsZone() throws {
        let table = try Self.table()

        #expect(table.contains { $0.wakes == nil } && table.contains { $0.wakes != nil })
        for wake in table {
            var calendar = Calendar(identifier: .gregorian)

            calendar.timeZone = try #require(TimeZone(identifier: wake.zone))

            let isOffered = SnoozeChoice.offered(at: wake.pressed, in: calendar, settings: wake.settings)
                .contains(wake.choice)
            let wakes = isOffered ? wake.choice.wakes(after: wake.pressed, in: calendar, settings: wake.settings) : nil

            #expect(wakes == wake.wakes, "\(wake.zone) \(wake.words)")
        }
    }

    /// The table sets every choice, each as its row says over the defaults: so the rows under settings of Lee's are
    /// read as such, not as the defaults.
    @Test func theTablesRowsSetEveryChoiceOverTheDefaults() throws {
        let table = try Self.table()
        let set = { (words: String) in table.first { $0.words.hasSuffix(words) }?.settings }
        var later = SnoozeSettings(), weekend = SnoozeSettings(), tomorrow = SnoozeSettings()

        later.laterToday = .init(isOn: true, hours: 4)
        weekend.thisWeekend = .init(isOn: true, day: .sunday, at: TimeOfDay(hour: 10, minute: 30))
        tomorrow.tomorrow.isOn = false
        #expect(set(": four hours on") == later)
        #expect(set(": a Friday, the clocks going back between") == weekend)
        #expect(set(": Tomorrow off") == tomorrow)
        #expect(Set(table.filter { $0.settings != Self.defaults }.map(\.choice)) == Set(SnoozeChoice.allCases))
    }

    /// Snooze's choices come in core's order, In an hour first and Tonight third, and by default every one is offered
    /// but This weekend, off, and Tonight from 18:00 to midnight, at every hour of October 2026 in London, the clocks
    /// going back among them.
    @Test func byDefaultEveryChoiceIsOfferedButThisWeekendAndTonightFromSixToMidnight() {
        let start = Self.at(1, 0)

        #expect(SnoozeChoice.allCases == [.inAnHour, .laterToday, .tonight, .tomorrow, .thisWeekend, .nextWeek])
        for hour in 0 ..< 31 * 24 {
            let now = start.addingTimeInterval(TimeInterval(hour) * 60 * 60)
            let isEvening = Self.london.component(.hour, from: now) >= 18
            let expected = SnoozeChoice.allCases.filter { $0 != .thisWeekend && !(isEvening && $0 == .tonight) }

            #expect(SnoozeChoice.offered(at: now, in: Self.london, settings: Self.defaults) == expected, "\(now)")
        }
    }

    /// This weekend on is offered from Monday until its day's time and not from then until Monday, on Saturday or on
    /// Sunday, at every hour of October 2026 in London.
    @Test(arguments: [(Weekday.saturday, 5), (.sunday, 6)])
    func thisWeekendIsOfferedFromMondayUntilItsDaysTime(day: Weekday, place: Int) {
        var settings = SnoozeSettings()
        let start = Self.at(1, 0)

        settings.thisWeekend = .init(isOn: true, day: day, at: TimeOfDay(hour: 9))
        for hour in 0 ..< 31 * 24 {
            let now = start.addingTimeInterval(TimeInterval(hour) * 60 * 60)
            let today = (Self.london.component(.weekday, from: now) + 5) % 7
            let isComing = today < place || (today == place && Self.london.component(.hour, from: now) < 9)

            #expect(
                SnoozeChoice.offered(at: now, in: Self.london, settings: settings).contains(.thisWeekend) == isComing,
                "\(now)"
            )
        }
    }

    /// What a row's Snooze offers: the choices offered then, and Until it moves always, after them.
    @Test func aRowsSnoozeOffersTheChoicesOfferedThenAndUntilItMoves() {
        var settings = SnoozeSettings()

        #expect(SnoozeTime.offered(at: Self.at(23, 17, 59), in: Self.london, settings: settings) == [
            .at(.inAnHour), .at(.laterToday), .at(.tonight), .at(.tomorrow), .at(.nextWeek), .untilItMoves,
        ])
        #expect(SnoozeTime.offered(at: Self.at(23, 18), in: Self.london, settings: settings) == [
            .at(.inAnHour), .at(.laterToday), .at(.tomorrow), .at(.nextWeek), .untilItMoves,
        ])
        settings.thisWeekend.isOn = true
        settings.inAnHour.isOn = false
        #expect(SnoozeTime.offered(at: Self.at(23, 18), in: Self.london, settings: settings) == [
            .at(.laterToday), .at(.tomorrow), .at(.thisWeekend), .at(.nextWeek), .untilItMoves,
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

    /// Tomorrow by name, across the clocks going back on the Sunday too, from Saturday and from Sunday into a new week.
    @Test func tomorrowItIsTomorrowAndItsTime() {
        #expect(Self.words(Self.at(24, 9)) == "tomorrow 09:00")
        #expect(WakeTime.words(Self.at(25, 9), at: Self.at(24, 0, 30), in: Self.london) == "tomorrow 09:00")
        #expect(WakeTime.words(Self.at(26, 9), at: Self.at(25, 12), in: Self.london) == "tomorrow 09:00")
    }

    /// Later in the calendar week, Monday to Sunday, after tomorrow: its weekday, across the clocks going back.
    @Test func laterThisWeekItIsItsWeekdayAndTime() {
        #expect(Self.words(Self.at(25, 9)) == "Sun 09:00")
        #expect(WakeTime.words(Self.at(28, 9), at: Self.at(26, 10), in: Self.london) == "Wed 09:00")
        #expect(WakeTime.words(Self.at(1, 9, month: 11), at: Self.at(26, 10), in: Self.london) == "Sun 09:00")
    }

    /// Any day of the next calendar week, its Monday to its Sunday, across the clocks going back: 7 days on from a
    /// Saturday among them.
    @Test func inTheNextWeekItIsNextWeek() {
        #expect(Self.words(Self.at(26, 9)) == "next week")
        #expect(Self.words(Self.at(1, 9, month: 11)) == "next week")
        #expect(WakeTime.words(Self.at(31, 9), at: Self.at(24, 12), in: Self.london) == "next week")
        #expect(WakeTime.words(Self.at(8, 9, month: 11), at: Self.at(26, 10), in: Self.london) == "next week")
    }

    /// From a Sunday, the last day of its week, any day past tomorrow up to the next Sunday is next week, and the
    /// Monday after it a date.
    @Test func fromASundayTheNextCalendarWeekRunsToTheNextSunday() {
        let sunday = Self.at(1, 12, month: 11)
        let words = { (wakes: Date) in WakeTime.words(wakes, at: sunday, in: Self.london) }

        #expect(words(Self.at(3, 9, month: 11)) == "next week")
        #expect(words(Self.at(8, 9, month: 11)) == "next week")
        #expect(words(Self.at(9, 9, month: 11)) == "9 Nov 09:00")
    }

    /// From the week after next on, and a day gone by, its date.
    @Test func furtherOutItIsItsDateAndTime() {
        #expect(Self.words(Self.at(2, 9, month: 11)) == "2 Nov 09:00")
        #expect(Self.words(Self.at(3, 9, month: 12)) == "3 Dec 09:00")
        #expect(WakeTime.words(Self.at(2, 9, month: 11), at: Self.at(24, 12), in: Self.london) == "2 Nov 09:00")
        #expect(Self.words(Self.at(21, 9)) == "21 Oct 09:00")
    }

    /// Going forward on Sunday 29 March: a day of 23 hours is one, and the weeks still end on their Sundays.
    @Test func theClocksGoingForwardMoveNoWeeksEdge() {
        #expect(WakeTime.words(Self.at(30, 9, month: 3), at: Self.at(29, 0, 30, month: 3), in: Self.london)
            == "tomorrow 09:00")
        #expect(WakeTime.words(Self.at(5, 9, month: 4), at: Self.at(28, 12, month: 3), in: Self.london) == "next week")
        #expect(WakeTime.words(Self.at(6, 9, month: 4), at: Self.at(28, 12, month: 3), in: Self.london) == "6 Apr 09:00")
    }

    @Test func spokenItsWeekdayAndMonthAreWhole() {
        #expect(Self.words(Self.at(23, 17, 42), spoken: true) == "17:42")
        #expect(Self.words(Self.at(24, 9), spoken: true) == "tomorrow 09:00")
        #expect(Self.words(Self.at(25, 9), spoken: true) == "Sunday 09:00")
        #expect(Self.words(Self.at(26, 9), spoken: true) == "next week")
        #expect(Self.words(Self.at(3, 9, month: 12), spoken: true) == "3 December 09:00")
    }

    /// Beside a choice on a row's Snooze menu: the time alone where its name fixes the day, though In an hour runs
    /// past midnight; the weekday and time beside This weekend and Next week.
    @Test func besideAChoiceItSaysOnlyWhatItsNameDoesNot() {
        let beside = { (choice: SnoozeChoice, wakes: Date) in
            WakeTime.besideChoice(choice, wakes: wakes, in: Self.london)
        }

        #expect(beside(.inAnHour, Self.at(23, 15, 42)) == "15:42")
        #expect(beside(.inAnHour, Self.at(24, 0, 30)) == "00:30")
        #expect(beside(.laterToday, Self.at(23, 18, 42)) == "18:42")
        #expect(beside(.tonight, Self.at(23, 19)) == "19:00")
        #expect(beside(.tomorrow, Self.at(24, 9)) == "09:00")
        #expect(beside(.thisWeekend, Self.at(24, 9)) == "Sat 09:00")
        #expect(beside(.nextWeek, Self.at(26, 9)) == "Mon 09:00")
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
        #expect(WakeTime.words(Self.at(25, 9), at: now, in: calendar) == "Sun 09:00")
        #expect(WakeTime.words(Self.at(26, 9), at: now, in: calendar) == "next week")
        #expect(WakeTime.besideChoice(.nextWeek, wakes: Self.at(26, 9), in: calendar) == "Mon 09:00")
        #expect(SnoozeChoice.allCases.map { $0.wakes(after: now, in: calendar, settings: Self.defaults) }
            == SnoozeChoice.allCases.map { Self.wakes($0, after: now) })
        #expect(SnoozeChoice.allCases.map { $0.wakes(after: now, in: calendar, settings: Self.leesOwn) }
            == SnoozeChoice.allCases.map { $0.wakes(after: now, in: Self.london, settings: Self.leesOwn) })
        #expect(WakeTime.changes(after: now, in: calendar) == Self.at(24, 0))
    }

    /// Settings of Lee's, every choice's time other than its default.
    private static let leesOwn: SnoozeSettings = {
        var settings = SnoozeSettings()

        settings.laterToday.hours = 1
        settings.tonight.at = TimeOfDay(hour: 20, minute: 30)
        settings.tomorrow.at = TimeOfDay(hour: 7)
        settings.thisWeekend = .init(isOn: true, day: .sunday, at: TimeOfDay(hour: 10))
        settings.nextWeek = .init(isOn: true, day: .friday, at: TimeOfDay(hour: 8, minute: 30))
        return settings
    }()

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
        #expect(asleep.timeText(at: now, in: Self.london) == "tomorrow 09:00")
        #expect(moves.timeText(at: now, in: Self.london) == "until it moves")
        #expect(waiting.timeText(at: now, in: Self.london) == "1h")
        #expect(asleep.title == "Finish the Tailspin migration")
        #expect(asleep.asks == ["k1"])
    }
}
