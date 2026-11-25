import Foundation
import SitRepPanel

/// What the strip's tabs say of the board, which it has no head to say: the notch at rest's title, nothing running or,
/// before any board, the panel head's words; while the board is stale, when it was last known current, in place of each
/// row's time; and the sessions whose tab takes the row's arrow, which its words make room for.
public struct StripNote: Equatable, Sendable {
    public var idle = StripFrame.Words.Content.idleTitle
    public var asOf: String?
    /// The sessions with an ask the asks panel answers, by their ids (`AsksPanel.asked`).
    public var arrows: Set<String> = []

    public init() {}

    /// What the tabs say of this board, these sessions' tabs taking the arrow.
    public init(_ board: PanelBoard, arrows: Set<String> = []) {
        idle = board.unread ?? StripFrame.Words.Content.idleTitle
        asOf = board.asOf
        self.arrows = arrows
    }

    /// Under the notch at rest's title: where sessions show, or while the board is stale, when it was last current.
    public var idleLine2: String { asOf ?? StripFrame.Words.Content.idleLine2 }

    /// A row's time: how long it has stood where it does at this time on the wall clock, or in Snoozed when it wakes,
    /// as the card's row says it; while the board is stale, when it was last current.
    public func age(_ session: Session, at now: Double, in calendar: Calendar = WakeTime.calendar) -> String {
        asOf ?? session.timeText(at: now, in: calendar)
    }

    /// Whether a session's tab takes the row's arrow, as its Needs you row on the card does: needing Lee, with an ask
    /// the asks panel answers.
    public func hasArrow(_ session: Session) -> Bool {
        session.needsLee && arrows.contains(session.id)
    }

    /// Whether it says what `other` says of every tab's words alike: the notch at rest's lines, and whether the board
    /// is stale. Which sessions take an arrow is each session's own (`saysAlike(_:of:)`).
    public func saysAlike(_ other: StripNote) -> Bool {
        idle == other.idle && asOf == other.asOf
    }

    /// Whether it says what `other` says of a session's words: of every tab's alike, and whether its tab takes the
    /// arrow.
    public func saysAlike(_ other: StripNote, of session: Session) -> Bool {
        saysAlike(other) && hasArrow(session) == other.hasArrow(session)
    }
}
