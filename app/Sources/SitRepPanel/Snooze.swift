import Foundation

/// Snooze's choices, in the order a card row's menu offers them, each worked out as it is pressed from the settings Lee
/// gave it, on the Gregorian calendar, as core's `snoozeAt` is, in the Mac's time zone, so 09:00 is 09:00 across a
/// change of the clocks (DESIGN, "Snooze").
public enum SnoozeChoice: CaseIterable, Sendable {
    case inAnHour, laterToday, tonight, tomorrow, thisWeekend, nextWeek

    public var title: String {
        switch self {
        case .inAnHour: "In an hour"
        case .laterToday: "Later today"
        case .tonight: "Tonight"
        case .tomorrow: "Tomorrow"
        case .thisWeekend: "This weekend"
        case .nextWeek: "Next week"
        }
    }

    /// The choices offered at `now`, in their order, as core's `snoozeChoicesAt`: each Lee has on whose time is still
    /// to come, so Tonight none from its time to midnight, and This weekend none from its day's time to Monday.
    public static func offered(at now: Date, in calendar: Calendar, settings: SnoozeSettings) -> [SnoozeChoice] {
        allCases.filter { settings.isOn($0) && $0.wakes(after: now, in: calendar, settings: settings) > now }
    }

    /// When a snooze chosen at `now` wakes, as `settings` time it: In an hour an hour on, and Later today its hours
    /// on, of real time across a change of the clocks; Tonight its time today, gone by then; Tomorrow its time on the
    /// next calendar day, so 09:00 pressed at 01:00 wakes 32 hours on; This weekend its time on its day of this week,
    /// Monday to Sunday, gone once that has passed; Next week its time on its day of the week after.
    public func wakes(after now: Date, in calendar: Calendar, settings: SnoozeSettings) -> Date {
        let calendar = WakeTime.gregorian(like: calendar)
        let today = Weekday.place(ofCalendarWeekday: calendar.component(.weekday, from: now))

        return switch self {
        case .inAnHour: now.addingTimeInterval(Self.inAnHourInterval)
        case .laterToday: now.addingTimeInterval(TimeInterval(settings.laterToday.hours) * Self.inAnHourInterval)
        case .tonight: Self.at(settings.tonight.at, days: 0, after: now, in: calendar)
        case .tomorrow: Self.at(settings.tomorrow.at, days: 1, after: now, in: calendar)
        case .thisWeekend:
            Self.at(settings.thisWeekend.at, days: settings.thisWeekend.day.place - today, after: now, in: calendar)
        case .nextWeek:
            Self.at(settings.nextWeek.at, days: 7 - today + settings.nextWeek.day.place, after: now, in: calendar)
        }
    }

    /// How long In an hour snoozes for, and Later today for each of its hours.
    private static let inAnHourInterval: TimeInterval = 60 * 60

    /// That time on the calendar day so many days after the one `now` falls on: one the clocks skip read past the
    /// change, one they pass twice the first, as core's `Date` reads them. Not `date(bySettingHour:)`: tried on 17
    /// November 2026 with `.nextTimePreservingSmallerComponents`, it put London's skipped 01:30 at 02:00.
    private static func at(_ time: TimeOfDay, days: Int, after now: Date, in calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: now)!
        var wall = calendar.dateComponents([.year, .month, .day], from: day)

        wall.hour = time.hour
        wall.minute = time.minute
        return calendar.date(from: wall)!
    }
}

/// When a snooze chosen from a row's menu wakes: at one of Snooze's times, or never by the clock, until it moves, as
/// the session's next turn ends (DESIGN, "The row snoozes").
public enum SnoozeTime: Hashable, Sendable {
    case at(SnoozeChoice)
    case untilItMoves

    /// What every row's Snooze offers at `now`: Snooze's times offered as Lee set them, then until it moves.
    public static func offered(at now: Date, in calendar: Calendar, settings: SnoozeSettings) -> [SnoozeTime] {
        offeredForAsk(at: now, in: calendar, settings: settings) + [.untilItMoves]
    }

    /// What one ask's Snooze offers at `now`, in the pane and the asks panel: Snooze's times offered as Lee set them,
    /// never until it moves (DESIGN, "An ask snoozes in the pane").
    public static func offeredForAsk(at now: Date, in calendar: Calendar, settings: SnoozeSettings) -> [SnoozeTime] {
        SnoozeChoice.offered(at: now, in: calendar, settings: settings).map(SnoozeTime.at)
    }

    public var title: String {
        switch self {
        case let .at(choice): choice.title
        case .untilItMoves: "Until it moves"
        }
    }

    /// When it wakes, chosen at `now`; none until it moves.
    public func wakes(after now: Date, in calendar: Calendar, settings: SnoozeSettings) -> Date? {
        switch self {
        case let .at(choice): choice.wakes(after: now, in: calendar, settings: settings)
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

/// When a snooze wakes, in words, at a moment, on the 24-hour clock in local time, by the calendar week, Monday to
/// Sunday, as core's `wakeWords` says it: today's time alone, `17:42`; tomorrow, `tomorrow 09:00`; later this week, its
/// weekday and time, `Sat 09:00`; in the next calendar week, `next week`; else its date and time, `3 Dec 09:00`.
/// Spoken, for VoiceOver, the weekday and month whole: `Saturday 09:00`, `3 December 09:00`, though no row hands
/// VoiceOver these yet.
public enum WakeTime {
    /// What a row snoozed with no time says in a wake's place, on the card and to VoiceOver.
    public static let untilItMoves = "until it moves"

    /// Why a snooze to `until`, pressed at `now`, snoozes nothing, in the pane's words: its time has come already, as
    /// Tonight's has on a menu opened before its time and chosen after. Nil while it is still to come, or with no
    /// time.
    public static func comeAlready(_ until: Date?, at now: Date, in calendar: Calendar) -> String? {
        guard let until, until <= now else {
            return nil
        }

        return "\(words(until, at: now, in: calendar)) has come already."
    }

    public static func words(_ wakes: Date, at now: Date, in calendar: Calendar, spoken: Bool = false) -> String {
        let calendar = gregorian(like: calendar)
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: wakes)
        let clock = Self.clock(parts)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: wakes)).day!
        let fromMonday = Weekday.place(ofCalendarWeekday: calendar.component(.weekday, from: now)) + days

        switch (days, fromMonday) {
        case (0, _):
            return clock
        case (1, _):
            return "tomorrow \(clock)"
        case (2..., ..<7):
            return "\(weekday(parts, spoken: spoken)) \(clock)"
        case (_, 7 ..< 14):
            return "next week"
        default:
            return "\(parts.day!) \((spoken ? months : shortMonths)[parts.month! - 1]) \(clock)"
        }
    }

    /// When a choice on a row's Snooze menu wakes, at its right, saying only what its name does not: the time alone
    /// where the name fixes the day, `09:00` beside Tomorrow; the weekday and time beside This weekend and Next week,
    /// `Mon 09:00`.
    public static func besideChoice(_ choice: SnoozeChoice, wakes: Date, in calendar: Calendar) -> String {
        let parts = gregorian(like: calendar).dateComponents([.weekday, .hour, .minute], from: wakes)

        return switch choice {
        case .inAnHour, .laterToday, .tonight, .tomorrow: clock(parts)
        case .thisWeekend, .nextWeek: "\(weekday(parts, spoken: false)) \(clock(parts))"
        }
    }

    /// When on the wall clock the words for any wake next read differently: at the next local midnight, as tomorrow's
    /// wake becomes today's time; a week's edge falls on one too.
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

    private static func clock(_ parts: DateComponents) -> String {
        String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }

    private static func weekday(_ parts: DateComponents, spoken: Bool) -> String {
        (spoken ? weekdays : shortWeekdays)[parts.weekday! - 1]
    }

    private static let shortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let months = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
        "December",
    ]
}

/// Whether one ask's Snooze offers a time (`SnoozeTime.offeredForAsk`), worked out again only as the minute or Lee's
/// settings change, as it is asked for every frame the notch draws; a time passing for today shows within the minute.
public struct SnoozeOffer: Sendable {
    private var known: (minute: Int, settings: SnoozeSettings, offers: Bool)?

    public init() {}

    public mutating func offers(at now: Date, in calendar: Calendar, settings: SnoozeSettings) -> Bool {
        let minute = Int((now.timeIntervalSince1970 / 60).rounded(.down))

        if let known, known.minute == minute, known.settings == settings {
            return known.offers
        }

        let offers = !SnoozeTime.offeredForAsk(at: now, in: calendar, settings: settings).isEmpty

        known = (minute, settings, offers)
        return offers
    }
}
