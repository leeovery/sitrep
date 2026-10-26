import Foundation
import SitRepCore
import SitRepPanel

/// What the window says, in its words, of what the pages hold.
public enum Words {
    /// A time as a panel row shows it: now, then whole minutes, hours or days.
    public static func age(_ since: Date, at now: Date) -> String {
        Session.ageText(now.timeIntervalSince(since) * 1000)
    }

    /// The time after the state line's words: how long the turn has run, or since it ended.
    public static func turn(_ doing: Doing, at now: Date) -> String? {
        let age = age(doing.since, at: now)

        switch doing.kind {
        case .working: return age == "now" ? "· this turn just began" : "· \(age) into this turn"
        case .onItsWork, .yourTurn: return age == "now" ? "· its turn just ended" : "· its turn ended \(age) ago"
        case .permission, .question, .away: return nil
        }
    }

    /// What a line says plain after its lead at this time: a wake's countdown, "in 12m", else its subject, where it
    /// is no command.
    public static func subject(_ line: Board.Row.Words, at now: Date) -> String? {
        line.until.map { Session.untilText($0.timeIntervalSince(now) * 1000) } ?? line.subject
    }

    /// What a stop says under its line: that it is answered in Claude Code.
    public static func stopped(_ kind: Doing.Kind) -> String? {
        switch kind {
        case .permission: "Its window stopped on Claude Code's permission prompt. It is answered there."
        case .question: "Its window stopped on a question from Claude. It is answered there."
        case .working, .onItsWork, .yourTurn, .away: nil
        }
    }

    /// After the words of a button or a jump that leaves SitRep.
    public static let leaves = "↗"

    /// A button's words, as its pill shows them, ↗ after one that leaves SitRep.
    public static func button(_ button: Card.Button) -> String {
        button.leaves ? "\(label(button)) \(leaves)" : label(button)
    }

    /// A button's own words, without the ↗ of one that leaves.
    public static func label(_ button: Card.Button) -> String {
        switch button {
        case let .yes(words): "✓ \(words)"
        case let .option(words): words
        case .inClaude(.comment): "Comment in Claude"
        case .inClaude(.answer): "Answer in Claude"
        case .ignore: "Ignore"
        case .snooze: snooze
        }
    }

    /// A card's line: the answer, as the board shows it on one row, and where it is.
    public static func line(_ line: Card.Line) -> (answer: String?, words: String) {
        switch line {
        case let .waiting(pending): (pending.words, "sending · Esc to undo")
        case let .sending(answer): (answer, "sending")
        case let .onItsWay(answer, wait): (answer, onItsWay(wait))
        case let .commentOnItsWay(comment): (comment, "on its way")
        case let .changedSince(answer): (answer, "Claude has it, but the ask changed since: it waits on you again")
        case let .refused(why): (nil, why)
        case let .notSnoozed(why): (nil, "Not snoozed: \(why)")
        case let .notWoken(why): (nil, "Not woken: \(why)")
        case .inbox: (nil, "Your answer waits in its inbox, and goes in when a window takes the session up again.")
        case let .closed(how): (nil, closed(how))
        }
    }

    private static func onItsWay(_ wait: Card.Wait) -> String {
        switch wait {
        case .none: "on its way"
        case .turn: "on its way: waits for the turn to end"
        case .window: "on its way: waits in its inbox for a window"
        }
    }

    /// How an ask closed, as Resolved and a card kept in place say it.
    public static func closed(_ how: Card.Closed) -> String {
        switch how {
        case .sent: "sent, and Claude has it"
        case let .resolved(reason?): "resolved by Claude: \(reason)"
        case .resolved(nil): "resolved by Claude"
        case let .notDelivered(answer): "\(answer) never went in: Claude closed it first"
        case .ignored: "ignored"
        }
    }

    /// A resolved ask opened: Lee's answer, as the board words it, where his answer closed it, and how it closed.
    public static func howClosed(_ resolved: Resolved) -> (answer: String?, words: String) {
        (resolved.answer, closed(resolved.how))
    }

    /// The jump to the session's window, before the ↗ that marks it leaving SitRep.
    public static let jump = "Open in Ghostty"
    /// A row's jump: the card's right-click menu's, and VoiceOver's action on a sidebar row a window holds, as its
    /// button under the pointer jumps; and the card's menu's way into the window.
    public static let jumpToWindow = "Jump to the window"
    public static let openInSitRep = "Open in SitRep"

    /// A row's menu's way to snooze its asks, and a card's, before the times it offers; and its way to wake them.
    public static let snooze = "Snooze"
    public static let wakeNow = "Wake now"

    /// A card asleep: when it wakes, as the wake's words say it.
    public static func snoozedUntil(_ wakes: String) -> String {
        "Snoozed until \(wakes)"
    }

    /// The Asks heading's words after those waiting: how many are asleep, none where none are.
    public static func snoozed(_ count: Int) -> String? {
        count > 0 ? "\(count) snoozed" : nil
    }

    public static let finish = "✓ Finish this session"
    public static let finishWhy = "For a session left with things open when its window closed."

    public static func finishing(_ name: String) -> String {
        "Finish \(name)? Its open asks stop counting."
    }

    /// Under a project's name: what waits on Lee there, and how many of its sessions a window holds.
    public static func project(waiting: Int, open: Int) -> String {
        let waits = waiting == 0 ? "Nothing waiting on you" : "\(waiting) waiting on you"

        return open == 0 ? "\(waits), and no session open" : "\(waits), in \(count(open, "open session"))"
    }

    public static func waiting(_ count: Int) -> String {
        "\(count) waiting"
    }

    public static func updated(_ since: Date, at now: Date) -> String {
        let age = age(since, at: now)

        return age == "now" ? "updated just now" : "updated \(age) ago"
    }

    public static func parked(_ count: Int) -> String {
        "\(count) to come back to"
    }

    public static func resolved(_ count: Int) -> String {
        "\(count) resolved"
    }

    /// The heading over every project, at the foot of the sidebar's list.
    public static let projects = "Projects"

    /// The Filter field's placeholder.
    public static let filter = "Filter"

    /// The sidebar's one line in its list's place where the filter keeps nothing, the field's text in the quotes.
    public static func noMatch(_ filter: Filter) -> String {
        "No sessions match “\(filter.text.trimmingCharacters(in: .whitespacesAndNewlines))”"
    }

    /// A count of something, its noun made plural past one.
    static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
