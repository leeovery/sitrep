import Foundation

/// Snooze's choices, in the order a card row's menu offers them, each worked out as it is pressed on the Gregorian
/// calendar, as core's `snoozeAt` is, in the Mac's time zone, so 09:00 is 09:00 across a change of the clocks (DESIGN,
/// "Snooze").
public enum SnoozeChoice: CaseIterable, Sendable {
    case inAnHour, laterToday, tonight, tomorrow, nextWeek

    public var title: String {
        switch self {
        case .inAnHour: "In an hour"
        case .laterToday: "Later today"
        case .tonight: "Tonight"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next week"
        }
    }

    /// The choices offered at `now`, in their order, as core's `snoozeChoicesAt`: each whose time is still to come, so
    /// Tonight none from 18:00 to midnight.
    public static func offered(at now: Date, in calendar: Calendar) -> [SnoozeChoice] {
        allCases.filter { $0.isOffered(at: now, in: calendar) }
    }

    /// Whether it is offered at `now`: its time is still to come.
    private func isOffered(at now: Date, in calendar: Calendar) -> Bool {
        wakes(after: now, in: calendar) > now
    }

    /// When a snooze chosen at `now` wakes: In an hour an hour on, and Later today three hours on, of real time
    /// across a change of the clocks; Tonight 18:00 today, gone by then; Tomorrow 09:00 on the next calendar day, so
    /// pressed at 01:00 it wakes 32 hours on; Next week 09:00 on the Monday after today, a week on from a Monday.
    public func wakes(after now: Date, in calendar: Calendar) -> Date {
        let calendar = WakeTime.gregorian(like: calendar)

        return switch self {
        case .inAnHour: now.addingTimeInterval(Self.inAnHourInterval)
        case .laterToday: now.addingTimeInterval(Self.laterTodayInterval)
        case .tonight: Self.at(Self.tonightHour, days: 0, after: now, in: calendar)
        case .tomorrow: Self.at(Self.tomorrowHour, days: 1, after: now, in: calendar)
        case .nextWeek:
            Self.at(
                Self.nextWeekHour, days: Self.toMonday(calendar.component(.weekday, from: now)), after: now,
                in: calendar
            )
        }
    }

    /// How long In an hour snoozes for: an hour.
    private static let inAnHourInterval: TimeInterval = 60 * 60

    /// How long Later today snoozes for: three hours.
    private static let laterTodayInterval: TimeInterval = 3 * 60 * 60

    /// The hour Tonight wakes at, local time.
    private static let tonightHour = 18

    /// The hour Tomorrow wakes at, local time.
    private static let tomorrowHour = 9

    /// The hour Next week wakes at, local time.
    private static let nextWeekHour = 9

    /// The days from a weekday, the calendar's (Sunday 1), to the Monday after it: a week on from a Monday.
    private static func toMonday(_ weekday: Int) -> Int {
        let days = (9 - weekday) % 7

        return days == 0 ? 7 : days
    }

    /// That hour on the calendar day so many days after the one `now` falls on.
    private static func at(_ hour: Int, days: Int, after now: Date, in calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!

        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}

/// When a snooze chosen from a row's menu wakes: at one of Snooze's times, or never by the clock, until it moves, as
/// the session's next turn ends (DESIGN, "The row snoozes").
public enum SnoozeTime: Hashable, Sendable {
    case at(SnoozeChoice)
    case untilItMoves

    /// What every row's Snooze offers at `now`: Snooze's times still to come, then until it moves.
    public static func offered(at now: Date, in calendar: Calendar) -> [SnoozeTime] {
        SnoozeChoice.offered(at: now, in: calendar).map(SnoozeTime.at) + [.untilItMoves]
    }

    public var title: String {
        switch self {
        case let .at(choice): choice.title
        case .untilItMoves: "Until it moves"
        }
    }

    /// When it wakes, chosen at `now`; none until it moves.
    public func wakes(after now: Date, in calendar: Calendar) -> Date? {
        switch self {
        case let .at(choice): choice.wakes(after: now, in: calendar)
        case .untilItMoves: nil
        }
    }
}

extension Session {
    /// What its row says in its time's place at this time on the wall clock, ms: how long it has stood, or in Snoozed,
    /// when it wakes, or for one snoozed with no time, that it waits until it moves.
    public func timeText(at now: Double, in calendar: Calendar) -> String {
        guard let wakesAt else {
            return isSnoozed ? WakeTime.untilItMoves : ageText(at: now)
        }

        let wakes = Date(timeIntervalSince1970: wakesAt / 1000)

        return WakeTime.words(wakes, at: Date(timeIntervalSince1970: now / 1000), in: calendar)
    }
}

/// When a snooze wakes, in words, at a moment, on the 24-hour clock in local time: today's time alone, `17:42`; within
/// the six days after today, tomorrow among them, its weekday and time, `Sat 09:00`; further out, its date and time,
/// `3 Nov 09:00`. Spoken, VoiceOver's, the weekday and month whole: `Saturday 09:00`, `3 November 09:00`.
public enum WakeTime {
    /// What a row snoozed with no time says in a wake's place, on the card and to VoiceOver.
    public static let untilItMoves = "until it moves"

    /// Why a snooze to `until`, pressed at `now`, snoozes nothing, in the pane's words: its time has come already, as
    /// Tonight's has on a menu opened before 18:00 and chosen after. Nil while it is still to come, or with no time.
    public static func comeAlready(_ until: Date?, at now: Date, in calendar: Calendar) -> String? {
        guard let until, until <= now else {
            return nil
        }

        return "\(words(until, at: now, in: calendar)) has come already."
    }

    public static func words(_ wakes: Date, at now: Date, in calendar: Calendar, spoken: Bool = false) -> String {
        let calendar = gregorian(like: calendar)
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: wakes)
        let clock = String(format: "%02d:%02d", parts.hour!, parts.minute!)
        let today = calendar.startOfDay(for: now)

        switch calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: wakes)).day! {
        case 0:
            return clock
        case 1 ..< 7:
            return "\((spoken ? weekdays : shortWeekdays)[parts.weekday! - 1]) \(clock)"
        default:
            return "\(parts.day!) \((spoken ? months : shortMonths)[parts.month! - 1]) \(clock)"
        }
    }

    /// When on the wall clock the words for any wake next read differently: at the next local midnight, as today's
    /// time becomes tomorrow's weekday, and a date a weekday.
    public static func changes(after now: Date, in calendar: Calendar) -> Date {
        let calendar = gregorian(like: calendar)

        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    }

    /// The calendar a snooze is worked out and worded on: the Gregorian, as core's, in the Mac's time zone and locale,
    /// followed as they change, whatever calendar the Mac is set to.
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    /// The Gregorian calendar in another's time zone and locale, so 09:00, Monday and a month's name mean what core
    /// means on a Hebrew or an Islamic one too.
    static func gregorian(like calendar: Calendar) -> Calendar {
        guard calendar.identifier != .gregorian else {
            return calendar
        }

        var gregorian = Calendar(identifier: .gregorian)

        gregorian.timeZone = calendar.timeZone
        gregorian.locale = calendar.locale
        return gregorian
    }

    private static let shortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let months = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
        "December",
    ]
}
