import Foundation

/// What VoiceOver reads of the window, in words, where its marks, counts and times would read as symbols.
public enum Spoken {
    /// A session's row in the sidebar, one element: its name, its project, its state and its time, as "The Mac app,
    /// SitRep, needs you, 5 hours". Away with something waiting, it needs Lee and is away.
    public static func row(_ row: Listed.Row, in project: String, at now: Date) -> String {
        let state = row.isAway && row.mark != .away ? "\(mark(row.mark)), away" : mark(row.mark)

        return "\(row.name), \(project), \(state), \(age(row.since, at: now))"
    }

    /// A project's heading in the sidebar: its name and what waits there.
    public static func project(_ project: Listed.Project) -> String {
        "\(project.name), \(project.waiting == 0 ? "nothing waiting" : Words.waiting(project.waiting))"
    }

    /// A project in the sidebar's foot, with nothing open.
    public static func quiet(_ project: Listed.Quiet) -> String {
        "\(project.name), quiet project"
    }

    /// What a session's mark means.
    public static func mark(_ mark: Mark) -> String {
        switch mark {
        case .needs: "needs you"
        case .turn: "your turn"
        case .working: "working"
        case .away: "away"
        }
    }

    /// A time as a panel row shows it, in words: "just now", then whole minutes, hours or days.
    public static func age(_ since: Date, at now: Date) -> String {
        let minutes = Int((now.timeIntervalSince(since) / 60).rounded(.down))
        let hours = minutes / 60

        if minutes < 1 {
            return "just now"
        }
        if minutes < 60 {
            return Words.count(minutes, "minute")
        }
        return hours < 24 ? Words.count(hours, "hour") : Words.count(hours / 24, "day")
    }

    /// A card, the container of its buttons: its ask's title, after its session's name where it is a project's.
    public static func card(_ card: Card, session: String?) -> String {
        session.map { "\($0): \(card.title)" } ?? card.title
    }

    /// A section's heading, and the few words on its right.
    public static func heading(_ name: String, note: String?) -> String {
        note.map { "\(name), \($0)" } ?? name
    }

    /// A closed ask's tick.
    public static let closed = "closed"
}
