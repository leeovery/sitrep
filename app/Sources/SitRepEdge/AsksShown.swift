import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel as a frame shows it (DESIGN, "Answering from the panel"), for the drawing: beside which row, one ask
/// of the row's session and its page among them, laid out, where it stands on the stage, the answer held for that ask,
/// what the pointer is on, and whether its answers show their keycaps.
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
    /// What the pointer is on, where it takes a click: nothing while it slides.
    public internal(set) var hover: AsksPart?
    /// How far, pt, its ask stands slid from its place as the asks page (`AsksSlide`): toward the next ask as it
    /// grows, the ask beside sliding in on that side.
    public internal(set) var slid = 0.0
    /// The ask beside its own as it slides, sliding in or out on the side it is slid toward; nil at rest, or past the
    /// first or the last ask.
    public internal(set) var beside: Beside?
    /// Whether its answers' rows show their numbers in keycaps: while the panel holds the keys, no menu holds the card
    /// and no answer is held, when the digits answer (DESIGN, "Keys").
    public internal(set) var keycaps = false

    /// An ask beside the one shown as the asks slide: its page among the session's, laid out, the answer held for it.
    public struct Beside: Equatable, Sendable {
        public let page: Int
        public let ask: PanelAsk
        public let layout: AsksLayout
        public let sending: Sending?
    }

    /// How far its ask has slid of the way to the ask beside, from 0 at rest to 1 as the ask beside takes its place.
    public var share: Double { beside == nil ? 0 : min(1, abs(slid) / AsksLayout.width) }

    /// Where its page dots stand as it slides: its page, a share of the way to the page beside.
    public var progress: Double { Double(page) + Double((beside?.page ?? page) - page) * share }

    /// How tall it is as it slides, from its ask's height toward the ask beside's.
    var height: Double { layout.height + ((beside?.layout.height ?? layout.height) - layout.height) * share }

    /// The ask beside as a showing of its own at rest, nothing under the pointer, for a drawing to draw its page as it
    /// draws the ask shown.
    public var shownBeside: AsksShown? {
        beside.map { beside in
            AsksShown(
                row: row, session: session, ask: beside.ask, page: beside.page, pages: pages, layout: beside.layout,
                frame: CGRect(origin: .zero, size: beside.layout.size), sending: beside.sending, hover: nil,
                keycaps: keycaps
            )
        }
    }

    /// Stood beside its row, as tall as it is as it slides, kept within the screen's visible frame (`AsksLayout.frame`).
    mutating func stand(besideRowAt rowTop: Double, front: Double, on stage: Stage) {
        stand(besideRowAt: rowTop, front: front, within: stage.visibleTop ... stage.visibleBottom)
    }

    /// Stood beside its row, as tall as it is as it slides, kept within `visible` on the stage.
    mutating func stand(besideRowAt rowTop: Double, front: Double, within visible: ClosedRange<Double>) {
        frame = layout.frame(besideRowAt: rowTop, front: front, within: visible, height: height)
    }

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

    /// The middle of a part in its own frame, its page dots where its slide has brought them; none where it has no such
    /// part.
    func middle(of part: AsksPart) -> CGPoint? {
        layout.box(of: part, progress: progress, of: pages).map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// A point in its own frame on the stage, as drawn through the edge's mirror: `ownPoint` the other way.
    func stagePoint(_ own: CGPoint, mirror: CGAffineTransform) -> CGPoint {
        let drawn = frame.applying(mirror)

        return CGPoint(x: drawn.minX + own.x, y: drawn.minY + own.y).applying(mirror.inverted())
    }

    /// The same showing at the stage's corner at rest: what its parts draw, wherever it stands and however far it has
    /// slid, for a drawing to tell whether they draw alike.
    public var unplaced: AsksShown {
        var unplaced = self

        unplaced.frame = .zero
        unplaced.slid = 0
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
