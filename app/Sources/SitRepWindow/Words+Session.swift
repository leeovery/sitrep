import Foundation
import SitRepCore

extension Words {
    /// A session's meta line, filling the window, under its name: its terminal and whether a window of it is on screen,
    /// then when it started, as "Ghostty, on screen · started today, 09:12"; away, the away line alone. None with
    /// nothing to say.
    public static func meta(_ meta: SessionPage.Meta, at now: Date, in calendar: Calendar) -> String? {
        let parts = metaParts(meta, at: now, in: calendar)

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The meta line's parts: where its window is, and when it started; away, the away line alone.
    static func metaParts(_ meta: SessionPage.Meta, at now: Date, in calendar: Calendar) -> [String] {
        if let away = meta.away {
            return [away]
        }

        let window = [meta.terminal.map(terminal), meta.onScreen.flatMap(onScreen)].compactMap(\.self)
        let started = meta.started.map { self.started($0, at: now, in: calendar) }

        return [window.isEmpty ? nil : window.joined(separator: ", "), started].compactMap(\.self)
    }

    /// Whether a window of the session is on screen, in words: nothing where the look gave no answer.
    static func onScreen(_ onScreen: OnScreen) -> String? {
        switch onScreen {
        case .on: "on screen"
        case .off: "not on screen"
        case .unknown: nil
        }
    }

    /// A terminal as its `$TERM_PROGRAM` names it, by its app's name, as the jump's drivers name them (cli/apps.ts);
    /// one unknown, as named.
    public static func terminal(_ program: String) -> String {
        terminals[program] ?? program
    }

    private static let terminals = [
        "ghostty": "Ghostty", "Apple_Terminal": "Terminal", "iTerm.app": "iTerm2", "WezTerm": "WezTerm",
        "WarpTerminal": "Warp",
    ]

    /// When a session started, on the 24-hour clock in local time: "started today, 09:12", "started yesterday, 18:40";
    /// within the week before, its weekday, "started Mon, 09:12"; further back, its date, "started 3 Nov, 09:12".
    public static func started(_ started: Date, at now: Date, in calendar: Calendar) -> String {
        var calendar = calendar

        calendar.locale = Locale(identifier: "en_US_POSIX")

        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: started)
        let clock = String(format: "%02d:%02d", parts.hour!, parts.minute!)
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: started), to: calendar.startOfDay(for: now)
        ).day!
        let day = switch days {
        case ...0: "today"
        case 1: "yesterday"
        case 2 ..< 7: calendar.shortWeekdaySymbols[parts.weekday! - 1]
        default: "\(parts.day!) \(calendar.shortMonthSymbols[parts.month! - 1])"
        }

        return "started \(day), \(clock)"
    }

    /// Before Now's next, quieter.
    public static let next = "next"
    /// Before Now's "N parked", quieter.
    public static let later = "later"

    /// Now's parked items, which open Parked narrowed to the session.
    public static func parkedCount(_ count: Int) -> String {
        "\(count) parked"
    }

    /// Before an ask still open in What happened, quieter.
    public static let asked = "Asked"
}

extension Spoken {
    /// A session's meta line, its parts read as one: "Ghostty, on screen, started today, 09:12".
    public static func meta(_ meta: SessionPage.Meta, at now: Date, in calendar: Calendar) -> String {
        Words.metaParts(meta, at: now, in: calendar).joined(separator: ", ")
    }

    /// When a session's status last changed, in words: "updated just now", "updated 1 hour ago".
    public static func updated(_ since: Date, at now: Date) -> String {
        let age = age(since, at: now)

        return age == "just now" ? "updated \(age)" : "updated \(age) ago"
    }
}
