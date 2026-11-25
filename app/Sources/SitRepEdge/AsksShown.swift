import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel as a frame shows it (DESIGN, "Answering from the panel"), for the drawing, black or glass: beside
/// which row, one ask of the row's session and its page among them, laid out, where it stands on the stage, the answer
/// held for that ask, and what the pointer is on.
public struct AsksShown: Equatable, Sendable {
    /// The row it opened beside, by its key: lit, its arrow lit, while it is open.
    public let row: String
    public let session: Session
    public let ask: PanelAsk
    /// The ask's place among the session's, and how many it has: its page dots.
    public let page: Int
    public let pages: Int
    public let layout: AsksLayout
    /// Where it stands on the stage.
    public private(set) var frame: CGRect
    /// The answer held for its ask, counting down; nil while none is.
    public let sending: Sending?
    /// What the pointer is on, where it takes a click.
    public internal(set) var hover: AsksPart?

    /// Whether a point on the stage is on it, its corners rounded.
    public func contains(_ point: CGPoint) -> Bool {
        CGPath(roundedRect: frame, cornerWidth: AsksLayout.radius, cornerHeight: AsksLayout.radius, transform: nil)
            .contains(point)
    }

    /// A point on the stage in its own frame, as drawn through the edge's mirror: it reads left to right on either
    /// edge.
    public func ownPoint(_ point: CGPoint, mirror: CGAffineTransform) -> CGPoint {
        let drawn = frame.applying(mirror), at = point.applying(mirror)
        return CGPoint(x: at.x - drawn.minX, y: at.y - drawn.minY)
    }

    /// The same showing at the stage's corner: what it draws, wherever it stands, for a drawing to tell whether it
    /// draws alike.
    public var unplaced: AsksShown {
        var unplaced = self

        unplaced.frame.origin = .zero
        return unplaced
    }
}

/// An answer held, as the sending line shows it, counting down.
public struct Sending: Equatable, Sendable {
    /// The answer's row, by its place among the ask's answers; nil for an ignore.
    public let row: Int?
    /// The answer's words, after "Sending"; nil for an ignore, "Ignoring".
    public let words: String?
    /// When it was held, and when it goes, ms on the wall clock: the countdown's.
    public let heldAt: Double
    public let goesAt: Double

    public init(row: Int?, words: String?, heldAt: Double, goesAt: Double) {
        self.row = row
        self.words = words
        self.heldAt = heldAt
        self.goesAt = goesAt
    }

    /// The answer held, where it is one to this ask.
    init?(_ held: HeldAnswer, to ask: PanelAsk, of session: String) {
        guard held.answering.ask == ask.id, held.answering.session == session else {
            return nil
        }

        switch held.answering.answer {
        case let .words(words):
            row = ask.answers.firstIndex(of: words)
            self.words = words
        case .ignore:
            row = nil
            words = nil
        }
        heldAt = held.heldAt.timeIntervalSince1970 * 1000
        goesAt = held.goesAt.timeIntervalSince1970 * 1000
    }

    /// How much of the countdown is left at this time on the wall clock, from 1 as it is held to 0 as it goes.
    public func left(at now: Double) -> Double {
        goesAt > heldAt ? min(1, max(0, (goesAt - now) / (goesAt - heldAt))) : 0
    }
}
