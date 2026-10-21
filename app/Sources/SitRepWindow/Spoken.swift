import Foundation
import SitRepPanel

/// What VoiceOver reads of the window, in words, where its marks, counts and times would read as symbols.
public enum Spoken {
    /// A session's row in the sidebar, one element: its name, its project, its state and its time, as "The Mac app,
    /// SitRep, needs you, 5 hours", under Needs you or its project. Away with something waiting, it needs Lee and is
    /// away.
    public static func row(_ row: Listed.Row, at now: Date) -> String {
        let state = row.isAway && row.mark != .away ? "\(mark(row.mark)), away" : mark(row.mark)

        return "\(row.name), \(row.project), \(state), \(age(row.since, at: now))"
    }

    /// The sidebar's Filter field.
    public static let filter = "Filter sessions"

    /// A heading in the sidebar that folds: a project's, its name and what waits there, as "SitRep, 3 waiting", or the
    /// quiet projects'; and, folded, that it is.
    public static func heading(_ heading: Sidebar.Heading) -> String {
        let name = switch heading.fold {
        case .project: "\(heading.name), \(heading.waiting == 0 ? "nothing waiting" : Words.waiting(heading.waiting))"
        case .quiet: heading.name
        }

        return heading.isFolded ? "\(name), folded" : name
    }

    /// A quiet project's row in the sidebar, with nothing open.
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

    /// A time as a panel row counts it (`Age`), in words: "just now", then whole minutes, hours or days.
    public static func age(_ since: Date, at now: Date) -> String {
        switch Age(now.timeIntervalSince(since) * 1000) {
        case .now: "just now"
        case let .minutes(count): Words.count(count, "minute")
        case let .hours(count): Words.count(count, "hour")
        case let .days(count): Words.count(count, "day")
        }
    }

    /// A card, the container of its buttons: its ask's title, after its session's name where it is a project's.
    public static func card(_ card: Card, session: String?) -> String {
        session.map { "\($0): \(card.title)" } ?? card.title
    }

    /// A section's heading, and the few words on its right.
    public static func heading(_ name: String, note: String?) -> String {
        note.map { "\(name), \($0)" } ?? name
    }

    /// A card's head on a project's page, which closes it back to its line, its title said by the card.
    public static let closeCard = "Close"

    /// A closed ask's tick.
    public static let closed = "closed"
}
