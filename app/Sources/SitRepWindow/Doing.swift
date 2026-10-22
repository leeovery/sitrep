import SitRepCore

/// What a session is doing, as core words the line under its name (`watch`'s `doing`).
public typealias Doing = Board.Session.Doing

extension Board.Session.Doing {
    /// Its mark, in the panel row's lane.
    public var mark: Mark {
        switch kind {
        case .working: .working
        case .onItsWork: .onItsWork
        case .yourTurn: .turn
        case .permission, .question: .needs
        case .away: .away
        }
    }

    /// A permission prompt or a question, which is the window's state and not an ask: it takes the line's place,
    /// washed orange.
    public var isStopped: Bool {
        kind == .permission || kind == .question
    }

    /// No window holds the session: the one fact its jump, its finish and its answers' buttons follow.
    public var isAway: Bool {
        kind == .away
    }

    /// Mid-turn: a reply waits for the turn to end before it goes in.
    var isMidTurn: Bool {
        kind == .working || isStopped
    }
}
