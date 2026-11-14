import Foundation
import SitRepPanel

/// What the strip's tabs say of the board, which it has no head to say: the notch at rest's title, nothing running or,
/// before any board, the panel head's words; and while the board is stale, when it was last known current, in place
/// of each row's time.
public struct StripNote: Equatable, Sendable {
    public var idle = StripFrame.Words.Content.idleTitle
    public var asOf: String?

    public init() {}

    public init(_ board: PanelBoard) {
        idle = board.unread ?? StripFrame.Words.Content.idleTitle
        asOf = board.asOf
    }

    /// Under the notch at rest's title: where sessions show, or while the board is stale, when it was last current.
    public var idleLine2: String { asOf ?? StripFrame.Words.Content.idleLine2 }

    /// A row's time: how long it has stood where it does at this time on the wall clock, or in Snoozed when it wakes,
    /// as the card's row says it; while the board is stale, when it was last current.
    public func age(_ session: Session, at now: Double, in calendar: Calendar = WakeTime.calendar) -> String {
        asOf ?? session.timeText(at: now, in: calendar)
    }
}
