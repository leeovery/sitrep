import Foundation

/// One session's board, as `sitrep board --json` prints it (cli/output.ts's `boardJson`): the session in brief, its
/// open asks, what it parked, its latest log lines and its resolved asks. The SitRep window reads it for a session's
/// detail, which a line of `watch` leaves out.
public struct SessionBoard: Versioned, Sendable, Equatable {
    static let version = 2

    public struct Project: Decodable, Sendable, Equatable {
        public let key: String
        public let name: String
    }

    /// The session in brief, as `list --json` gives it.
    public struct Work: Decodable, Sendable, Equatable {
        public let id: String
        public let name: String
        public let summary: String
        public let now: [String]
        public let next: String?
        public let isOpen: Bool
        public let waiting: Int
        public let parked: Int
        public let updatedAt: Date
    }

    public struct Parked: Decodable, Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let `where`: String?
        public let ref: String?
        public let at: Date
    }

    /// A line of the log: a note Claude wrote, or a status change or pick-up the board noticed.
    public struct Line: Decodable, Sendable, Equatable {
        public enum Kind: String, Decodable, Sendable {
            case note, status, pickup
        }

        public let kind: Kind
        /// The note's id; a line the board derived has none.
        public let id: String?
        public let text: String
        public let detail: [String]
        public let ref: String?
        /// The writer that wrote it.
        public let by: String
        public let at: Date
    }

    /// A resolved ask: closed by Lee's answer or Claude's resolve, with when, and Claude's reason where Claude gave
    /// one.
    public struct Resolved: Decodable, Sendable, Equatable, Identifiable {
        public let ask: Board.Ask
        public let closedAt: Date?
        public let reason: String?

        public var id: String { ask.id }
    }

    public let project: Project
    public let work: Work
    /// Its open asks, oldest first: waiting, on Lee or on a window to deliver Lee's reply, or replied.
    public let asks: [Board.Ask]
    /// Oldest first.
    public let parked: [Parked]
    /// Its latest lines, newest first.
    public let log: [Line]
    /// The asks closed, those ignored aside, the newest closed first.
    public let resolved: [Resolved]
}

/// A resolved ask is an ask's fields, and its own two beside them.
extension SessionBoard.Resolved {
    private enum CodingKeys: String, CodingKey {
        case closedAt, reason
    }

    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            ask: try Board.Ask(from: decoder),
            closedAt: try fields.decode(Date?.self, forKey: .closedAt),
            reason: try fields.decode(String?.self, forKey: .reason)
        )
    }
}
