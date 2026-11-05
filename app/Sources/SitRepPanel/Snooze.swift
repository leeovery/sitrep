import Foundation

/// Snooze's choices, as the card's and the sidebar's menus and a card's Snooze on the session page offer them, each
/// worked out as it is pressed on the Gregorian calendar, as core's `snoozeAt` is, in the Mac's time zone, so 09:00 is
/// 09:00 across a change of the clocks (DESIGN, "Snooze").
public enum SnoozeChoice: CaseIterable, Sendable {
    case laterToday, tomorrow, nextWeek

    public var title: String {
        switch self {
        case .laterToday: "Later today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next week"
        }
    }

    /// When a snooze chosen at `now` wakes: Later today three hours on; Tomorrow 09:00 on the next calendar day, so
    /// pressed at 01:00 it wakes 32 hours on; Next week 09:00 on the Monday after today, a week on from a Monday.
    public func wakes(after now: Date, in calendar: Calendar) -> Date {
        let calendar = WakeTime.gregorian(like: calendar)

        return switch self {
        case .laterToday: now.addingTimeInterval(Self.later)
        case .tomorrow: Self.waking(days: 1, after: now, in: calendar)
        case .nextWeek:
            Self.waking(days: Self.toMonday(calendar.component(.weekday, from: now)), after: now, in: calendar)
        }
    }

    /// How long Later today snoozes for: three hours.
    static let later: TimeInterval = 3 * 60 * 60

    /// The hour Tomorrow and Next week wake at, local time.
    private static let wakingHour = 9

    /// The days from a weekday, the calendar's (Sunday 1), to the Monday after it: a week on from a Monday.
    private static func toMonday(_ weekday: Int) -> Int {
        let days = (9 - weekday) % 7

        return days == 0 ? 7 : days
    }

    /// 09:00 on the calendar day so many days after the one `now` falls on.
    private static func waking(days: Int, after now: Date, in calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!

        return calendar.date(bySettingHour: wakingHour, minute: 0, second: 0, of: day)!
    }
}

/// When a snooze chosen from a row's menu wakes: at one of Snooze's times, or, for a turn alone, never by the clock,
/// until the session takes another turn (DESIGN, "Snooze").
public enum SnoozeTime: Hashable, Sendable {
    case at(SnoozeChoice)
    case untilItMoves

    /// What a row's Snooze offers: Snooze's times, and on a turn's row, then until it moves.
    public static func offered(forTurn isTurn: Bool) -> [SnoozeTime] {
        SnoozeChoice.allCases.map(SnoozeTime.at) + (isTurn ? [.untilItMoves] : [])
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
    /// when it wakes, or for a turn snoozed with no time, that it waits until it moves.
    public func timeText(at now: Double, in calendar: Calendar) -> String {
        guard let wakesAt else {
            return kind == .snoozedTurn ? WakeTime.untilItMoves : ageText(at: now)
        }

        let wakes = Date(timeIntervalSince1970: wakesAt / 1000)

        return WakeTime.words(wakes, at: Date(timeIntervalSince1970: now / 1000), in: calendar)
    }
}

/// When a snooze wakes, in words, at a moment, on the 24-hour clock in local time: today's time alone, `17:42`; within
/// the six days after today, tomorrow among them, its weekday and time, `Sat 09:00`; further out, its date and time,
/// `3 Nov 09:00`. Spoken, VoiceOver's, the weekday and month whole: `Saturday 09:00`, `3 November 09:00`.
public enum WakeTime {
    /// What a turn snoozed with no time says in a wake's place, on the card and to VoiceOver.
    public static let untilItMoves = "until it moves"

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
