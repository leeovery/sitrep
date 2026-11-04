import Foundation

/// Whether a jump could reach a session: a terminal window of this Mac shows it, or tmux can make one show it; none
/// does; or not known, as tmux or `ps` gave no answer for its windows, or nothing has said.
public enum OnScreen: String, Decodable, Sendable {
    case on, off, unknown
}

/// Which sessions show on screen, as `sitrep screen --json` prints it (cli/output.ts's `screenJson`), its `v` 1: each
/// session a live window holds, by its id, and the programs asked that gave no answer.
public struct ScreenReading: Versioned, Sendable, Equatable {
    static let version = 1

    public struct Session: Decodable, Sendable, Equatable {
        public let id: String
        public let `is`: OnScreen
    }

    public let sessions: [Session]
    /// `tmux`, `ps`, or neither.
    public let unanswered: [String]

    /// Whether a jump could reach the session; unknown for one not listed, as no window holds it.
    public func onScreen(of session: String) -> OnScreen {
        sessions.first { $0.id == session }?.is ?? .unknown
    }
}
