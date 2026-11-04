import Foundation
import SitRepCore

extension Words {
    /// A session's meta line, filling the window, under its name: the terminal app its window is in and whether a
    /// window of it is on screen, then when it started, as "Ghostty, on screen · started today, 09:12", its first word
    /// a capital; away, the away line alone. None with nothing to say.
    public static func meta(_ meta: SessionPage.Meta, at now: Date, in calendar: Calendar) -> String? {
        let parts = metaParts(meta, at: now, in: calendar)

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The meta line's parts: where its window is, and when it started, the first a capital where it is one of these
    /// words and not an app's name; away, the away line alone. Its app is the one the last look at the screen saw
    /// showing it, else the one its `$TERM_PROGRAM` names, where that is an app's (`terminal(_:)`).
    static func metaParts(_ meta: SessionPage.Meta, at now: Date, in calendar: Calendar) -> [String] {
        if let away = meta.away {
            return [away]
        }

        let app = meta.app ?? meta.terminal.flatMap(terminal)
        let window = [app, meta.onScreen.flatMap(onScreen)].compactMap(\.self)
        let started = meta.started.map { self.started($0, at: now, in: calendar) }

        let parts = [window.isEmpty ? nil : window.joined(separator: ", "), started].compactMap(\.self)

        return app == nil ? parts.enumerated().map { $0.offset == 0 ? capitalised($0.element) : $0.element } : parts
    }

    /// Words with their first letter a capital, as a line that starts "on screen" or "started" does.
    private static func capitalised(_ words: String) -> String {
        words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Whether a window of the session is on screen, in words: nothing where the look gave no answer.
    static func onScreen(_ onScreen: OnScreen) -> String? {
        switch onScreen {
        case .on: "on screen"
        case .off: "not on screen"
        case .unknown: nil
        }
    }

    /// A terminal as its `$TERM_PROGRAM` names it, by its app's name, as the jump's drivers name them (cli/apps.ts).
    /// None for any other program, as tmux, which names no app, or an editor's terminal, `vscode`, which would lead
    /// the line in its own lower case.
    public static func terminal(_ program: String) -> String? {
        terminals[program]
    }

    private static let terminals = [
        "ghostty": "Ghostty", "Apple_Terminal": "Terminal", "iTerm.app": "iTerm2", "WezTerm": "WezTerm",
        "WarpTerminal": "Warp",
    ]

    /// When a session started, on the 24-hour clock in local time: "started today, 09:12", "started yesterday, 18:40";
    /// within the week before, its weekday, "started Mon, 09:12"; further back, its date, "started 3 Nov, 09:12", and
    /// its year where that is not this one, "started 3 Nov 2025, 09:12".
    public static func started(_ started: Date, at now: Date, in calendar: Calendar) -> String {
        var calendar = calendar

        calendar.locale = Locale(identifier: "en_US_POSIX")

        let parts = calendar.dateComponents([.weekday, .day, .month, .year, .hour, .minute], from: started)
        let year = parts.year == calendar.component(.year, from: now) ? "" : " \(parts.year!)"
        let clock = String(format: "%02d:%02d", parts.hour!, parts.minute!)
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: started), to: calendar.startOfDay(for: now)
        ).day!
        let day = switch days {
        case ...0: "today"
        case 1: "yesterday"
        case 2 ..< 7: calendar.shortWeekdaySymbols[parts.weekday! - 1]
        default: "\(parts.day!) \(calendar.shortMonthSymbols[parts.month! - 1])\(year)"
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
