import Foundation
import SitRepCore

/// A parked item beside Parked's list (Paper's "Window redesign", A4 revised): its project and its session as a
/// breadcrumb; its title, when it was parked, and its `where` and its `ref` as its body; the session it was parked
/// from, with what it is doing now and its asks waiting, and the way back to its page; then its session's log lines
/// since it was parked.
public struct ParkedPage: Equatable, Sendable {
    /// The session it was parked from, as its card under "Parked from" shows it.
    public struct From: Equatable, Sendable {
        public let id: String
        public let name: String
        public let mark: Mark
        /// No window holds it: its words dim as one.
        public let isAway: Bool
        /// Its status's first now line.
        public let now: String?
        /// Its asks waiting.
        public let asks: Int

        /// Under its name: its now line, then its asks waiting, each left out where it is none, as "Holding the
        /// backfill for a window", "2 asks".
        public var parts: [String] {
            [now, asks > 0 ? Words.count(asks, "ask") : nil].compactMap { $0 }
        }
    }

    public let item: SessionBoard.Parked
    /// Its project, by its key, and its name, which opens the project.
    public let projectKey: String
    public let projectName: String
    public let from: From
    /// Its session's log lines written since it was parked, the newest first, of the lines its board carries.
    public let since: [Note]
    /// Every line its session's board carries came after it was parked, so more may have come since than show: a board
    /// carries a session's newest lines only (`SessionPage.logLines`).
    public let isSinceCut: Bool
    /// Where among those lines Lee last looked at its session, where lines stand on both sides of it: those from
    /// before are drawn dimmer, with no divider.
    public let looked: YouLooked?
    /// A board of its session is kept: its lines since show as last kept.
    public let hasBoard: Bool
    /// Why the latest line to carry its session's board carried none, over its board as last kept, if there is one.
    public let failure: String?
    /// The lines since it was parked opened in place.
    public let opened: Set<Item>

    /// Which page it is, by its session and its id, as its id is unique only within its session.
    public var pick: Pick { .parked(session: from.id, id: item.id) }
}

extension ParkedPage {
    /// A session's log lines written after this time, the newest first, of those given; and whether every one given
    /// came after it, the log as full as a board carries it, so more may have come than it holds.
    static func since(_ log: [Note], parkedAt at: Date) -> (lines: [Note], isCut: Bool) {
        let lines = log.filter { $0.at > at }

        return (lines, lines.count >= SessionPage.logLines)
    }
}

extension ParkedPage.From {
    /// A session on the board, its mark as a project's page marks it.
    init(_ session: Board.Session) {
        self.init(
            id: session.id, name: session.name, mark: Mark(session.state, isAway: session.doing.isAway),
            isAway: session.doing.isAway, now: session.now.first, asks: session.waiting
        )
    }
}
