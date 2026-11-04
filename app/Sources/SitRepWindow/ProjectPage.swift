import Foundation
import SitRepCore

/// A project, opened from its name, as the pane's project view: its sessions, each with what it is doing and what
/// waits there; every session's asks, the newest first, each one line that opens in place into its card; their notes,
/// the newest first; their parked items, the oldest first. Each line names its session, unless the project has only
/// the one, which it can only name. There is no Resolved.
public struct ProjectPage: Equatable, Sendable {
    public struct Session: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let mark: Mark
        public let isAway: Bool
        public let doing: Doing
        /// Its rows that need Lee: asks and stops alike.
        public let waiting: Int
        public let since: Date
    }

    /// An ask, one line naming its session, or opened into its card.
    public struct Ask: Equatable, Sendable, Identifiable {
        public let session: String?
        public let card: Card
        public let isOpened: Bool

        public var id: AskAddress { card.id }
    }

    public let key: String
    public let name: String
    /// What waits on Lee there: its rows that need Lee.
    public let waiting: Int
    /// How many of its sessions a window holds.
    public let open: Int
    public let sessions: [Session]
    /// Its asks waiting on Lee.
    public let asksWaiting: Int
    public let asks: [Ask]
    public let notes: [Note]
    public let parked: [Parked]
    /// Its notes and parked items opened in place.
    public let opened: Set<Item>
}
