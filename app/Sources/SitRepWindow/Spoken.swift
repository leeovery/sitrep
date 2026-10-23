import Foundation
import SitRepPanel

/// What VoiceOver reads of the window, in words, where its marks, counts and times would read as symbols.
public enum Spoken {
    /// A session's row in the sidebar, one element: under Needs you, as `needsYou(_:at:)` reads it; in Snoozed, as
    /// `snoozed(_:at:in:)` does; in Working or Your turn, its line's words, its project, its session, its state and its
    /// time, as "Drawing the ledger schema, Switchboard, Request ledger, your turn, 12 minutes".
    public static func row(_ row: Listed.Row, at now: Date, in calendar: Calendar = .autoupdatingCurrent) -> String {
        switch row.section {
        case .needsYou: return needsYou(row, at: now)
        case .snoozed: return snoozed(row, at: now, in: calendar)
        case .working, .yourTurn: break
        }

        return (row.lines.map { $0.words(at: now) } + [row.project, row.name, mark(row.mark), age(row.since, at: now)])
            .joined(separator: ", ")
    }

    /// A session's row under Needs you, one element: what waits on Lee first, how many where there are several, then
    /// each line's words; then its project and its session, away where no window holds it, and how long the oldest
    /// has waited, as "2 asks, Paste the load test's output, Allow Bash gh pr create, Switchboard, Dashboard redesign,
    /// 3 hours".
    public static func needsYou(_ row: Listed.Row, at now: Date) -> String {
        let count = row.lines.count > 1 ? [Words.count(row.lines.count, "ask")] : []
        let away = row.isAway ? ["away"] : []

        return (count + row.lines.map { $0.words(at: now) } + [row.project, row.name] + away + [age(row.since, at: now)])
            .joined(separator: ", ")
    }

    /// A session's row in Snoozed, one element, as a Needs you row reads, its time when it wakes: "2 asks, Review the
    /// plan, Pick when stage 2 runs, Harness, Finish the Harness modernisation, wakes Saturday 09:00".
    public static func snoozed(_ row: Listed.Row, at now: Date, in calendar: Calendar) -> String {
        let count = row.lines.count > 1 ? [Words.count(row.lines.count, "ask")] : []
        let away = row.isAway ? ["away"] : []
        let wakes = row.wakesAt.map { ["wakes \(WakeTime.words($0, at: now, in: calendar, spoken: true))"] } ?? []

        return (count + row.lines.map { $0.words(at: now) } + [row.project, row.name] + away + wakes)
            .joined(separator: ", ")
    }

    /// The action VoiceOver offers on a row in Snoozed, which wakes its asks now, as its menu's Wake now does.
    public static func wake(_ row: Listed.Row) -> String? {
        row.section == .snoozed ? Words.wakeNow : nil
    }

    /// The action VoiceOver offers on a session's row in the sidebar, which jumps to its window as the row's button
    /// under the pointer does, moving no pick: "Jump to the window" on a row a window holds; none on an away row.
    public static func jump(_ row: Listed.Row) -> String? {
        row.jumps ? Words.jumpToWindow : nil
    }

    /// The sidebar's Filter field.
    public static let filter = "Filter sessions"

    /// A heading in the sidebar, which folds: its name and its count, as "Needs you, 4 waiting", "Your turn, 3
    /// sessions" or "Projects, 6 projects"; and, folded, that it is.
    public static func heading(_ heading: Sidebar.Heading) -> String {
        let count = switch heading.fold {
        case .section(.needsYou): Words.waiting(heading.count)
        case .section(.snoozed): Words.count(heading.count, "ask")
        case .section: Words.count(heading.count, "session")
        case .projects, .earlier: Words.count(heading.count, "project")
        }

        return folded("\(heading.title), \(count)", heading.isFolded)
    }

    /// Your turn's "N earlier": how many, and their projects, as "8 earlier, Switchboard, Fumi"; and, folded, that it
    /// is.
    public static func earlier(_ earlier: Earlier) -> String {
        folded(([earlier.title] + earlier.projects).joined(separator: ", "), !earlier.isOpen)
    }

    /// A project's row in the sidebar, which opens its page.
    public static func project(_ project: Listed.Project) -> String {
        "\(project.name), project"
    }

    private static func folded(_ words: String, _ isFolded: Bool) -> String {
        isFolded ? "\(words), folded" : words
    }

    /// What a session's mark means.
    public static func mark(_ mark: Mark) -> String {
        switch mark {
        case .needs: "needs you"
        case .turn: "your turn"
        case .working: "working"
        case .onItsWork: "on its own work"
        case .away: "away"
        case .snoozed: "snoozed"
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
