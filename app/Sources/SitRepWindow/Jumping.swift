/// What in the window a jump was pressed from: a card's button, the session's "Open in Ghostty ↗", a stop's "Answer
/// in Claude ↗", or a sidebar row's button under the pointer.
public enum JumpPress: Hashable, Sendable {
    case card(AskAddress, Card.Button)
    case open(String)
    case stop(String)
    case row(String)

    /// The session it jumps to.
    public var session: String {
        switch self {
        case let .card(ask, _): ask.session
        case let .open(session), let .stop(session), let .row(session): session
        }
    }
}

/// The window's jump under way: only the button it was pressed from shows it, while every other stays as it looks.
/// A press while any jump runs, the window's or the notch's, the strip's or the menu's, jumps in its place, the latest
/// click winning (4 November 2026): the button pressed shows it, and an answer to an earlier press changes nothing.
public struct Jumping: Equatable, Sendable {
    /// The button whose jump runs, nil with none of the window's.
    public private(set) var pressed: JumpPress?
    private var presses = 0

    public init() {}

    /// A press: it jumps, whatever jump runs. Which press it is, for its answer.
    public mutating func press(_ press: JumpPress) -> Int {
        pressed = press
        presses += 1
        return presses
    }

    /// The jump of this press answered: the button shows as it did, unless a later press jumps now.
    public mutating func answered(_ press: Int) {
        if press == presses {
            pressed = nil
        }
    }
}
