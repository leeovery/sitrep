import Foundation
import SitRepPanel

/// What VoiceOver reads of the window, in words, where its marks, counts and times would read as symbols.
public enum Spoken {
    /// A row of the list beside the page, one element: a line, as `line(_:at:in:)` reads it; a session's row in Working
    /// or Your turn, its line's words, its project, its session, its state and its time, as "Drawing the ledger schema,
    /// Switchboard, Request ledger, your turn, 12 minutes".
    public static func row(_ row: PlaceList.Row, at now: Date, in calendar: Calendar = WakeTime.calendar) -> String {
        switch row {
        case let .line(line):
            return self.line(line, at: now, in: calendar)
        case let .session(row):
            return (row.lines.map { $0.words(at: now) } + [row.project, row.name, mark(row.mark), age(row.since, at: now)])
                .joined(separator: ", ")
        }
    }

    /// A line waiting on Lee, one element: its words, its session's project and name, away where no window holds it,
    /// and how long it has waited, as "Allow Bash gh pr create, Switchboard, Dashboard redesign, 3 minutes"; asleep
    /// under "N snoozed", when it wakes in its time's place, as "Review the plan, Harness, Finish the Harness
    /// modernisation, wakes Saturday 09:00".
    public static func line(_ row: PlaceList.LineRow, at now: Date, in calendar: Calendar) -> String {
        let away = row.session.isAway ? ["away"] : []
        let time = row.line.wakesAt.map { wakes($0, at: now, in: calendar) } ?? age(row.line.since, at: now)

        return ([row.line.words(at: now), row.session.project, row.session.name] + away + [time])
            .joined(separator: ", ")
    }

    /// When a snooze wakes, its weekday and month whole: "wakes Saturday 09:00".
    private static func wakes(_ wakes: Date, at now: Date, in calendar: Calendar) -> String {
        "wakes \(WakeTime.words(wakes, at: now, in: calendar, spoken: true))"
    }

    /// The actions VoiceOver offers on a line that is an ask waiting, one per choice of its menu's Snooze, each saying
    /// when it would wake, as "Snooze tomorrow, wakes Saturday 09:00"; none on a window's stop, nor on an ask asleep.
    public static func snooze(
        _ choice: SnoozeChoice, of row: PlaceList.LineRow, at now: Date, in calendar: Calendar
    ) -> String? {
        guard !row.isAsleep, !row.asks.isEmpty else {
            return nil
        }

        return "Snooze \(choice.title.lowercased()), \(wakes(choice.wakes(after: now, in: calendar), at: now, in: calendar))"
    }

    /// The action VoiceOver offers on an ask asleep under "N snoozed", which wakes it now, as its menu's Wake now does.
    public static func wake(_ row: PlaceList.LineRow) -> String? {
        row.isAsleep ? Words.wakeNow : nil
    }

    /// The action VoiceOver offers on a row of the list, which jumps to its session's window as the row's button under
    /// the pointer does, moving no pick: "Jump to the window" on a row of a session a window holds; none on an away
    /// one.
    public static func jump(_ row: PlaceList.Row) -> String? {
        row.jumps ? Words.jumpToWindow : nil
    }

    /// The sidebar's Filter field.
    public static let filter = "Filter sessions"

    /// A place in the sidebar: its name and its count, as "Needs you, 4 waiting", "Your turn, 3 sessions" or "Parked,
    /// 12 items".
    public static func place(_ place: Place, count: Int) -> String {
        let counted = switch place {
        case .needsYou: Words.waiting(count)
        case .yourTurn, .working: Words.count(count, "session")
        case .parked: Words.count(count, "item")
        }

        return "\(place.title), \(counted)"
    }

    /// A project's row in the sidebar, which opens its page: its name, what its mark says where something waits on
    /// Lee, and its sessions, but where it is quiet, as "Switchboard, project, needs you, 2 sessions" or "Kit,
    /// project".
    public static func project(_ project: Places.Project) -> String {
        let waits: [String] = switch project.mark {
        case .needs: [mark(.needs)]
        case .awayAsk: [mark(.awayAsk)]
        case .nothingWaiting: []
        }
        let sessions = project.count.map { [Words.count($0, "session")] } ?? []

        return ([project.name, "project"] + waits + sessions).joined(separator: ", ")
    }

    /// The fold at a list's foot: how many, and for "N earlier" their projects, as "2 snoozed" or "8 earlier,
    /// Switchboard, Fumi"; and, folded, that it is.
    public static func fold(_ fold: PlaceList.Fold) -> String {
        let projects = fold.kind == .earlier ? fold.earlier.projects : []
        let words = ([fold.title] + projects).joined(separator: ", ")

        return fold.isOpen ? words : "\(words), folded"
    }

    /// What a session's mark means.
    public static func mark(_ mark: Mark) -> String {
        switch mark {
        case .needs: "needs you"
        case .awayAsk: "needs you, away"
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
    public static func heading(_ name: String, note: String?, aside: String? = nil) -> String {
        ([name] + [note, aside].compactMap(\.self)).joined(separator: ", ")
    }

    /// A card's head on a project's page, which closes it back to its line, its title said by the card.
    public static let closeCard = "Close"

    /// A closed ask's tick.
    public static let closed = "closed"
}
