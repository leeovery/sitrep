/// What in the window a jump was pressed from: a card's button, the session's "Open in Ghostty ↗", or a stop's
/// "Answer in Claude ↗".
public enum JumpPress: Hashable, Sendable {
    case card(AskAddress, Card.Button)
    case open(String)
    case stop(String)

    /// The session it jumps to.
    public var session: String {
        switch self {
        case let .card(ask, _): ask.session
        case let .open(session), let .stop(session): session
        }
    }
}

/// The window's jump under way: only the button it was pressed from shows it, while every other stays as it looks.
/// One jump runs at a time, so a press while any runs, the window's or the notch's, the strip's or the menu's, starts
/// none and changes nothing shown.
public struct Jumping: Equatable, Sendable {
    /// The button whose jump runs, nil with none of the window's.
    public private(set) var pressed: JumpPress?

    public init() {}

    /// A press, while a jump of the app's runs or not: whether it starts a jump.
    public mutating func press(_ press: JumpPress, isJumping: Bool) -> Bool {
        guard pressed == nil, !isJumping else {
            return false
        }

        pressed = press
        return true
    }

    /// The jump answered: the button shows as it did.
    public mutating func answered() {
        pressed = nil
    }
}
