import CoreGraphics

/// A loop the stage plays, on its own clock, ms from its start, its beats as data: the notch at rest; an ask landing,
/// which swells it twice and lights it; the pointer coming to it, so it pours into the panel, then moving onto the
/// ask's row, which it lights; then, in step 1's, the pointer leaving, so it closes, and over again. Step 2's goes on
/// as the ask is answered: the row clicked, so the panel drains and the session's window comes forward, the pointer
/// going into it; the answer in its terminal; the ask leaving the board, so the light goes out; and a rest. Points
/// are on the edge's stage, x into the screen from its edge, y down from its top.
public struct WelcomeLoop: Equatable, Sendable {
    /// The three moments step 2's words name, each lit in step with its loop.
    public enum Moment: CaseIterable, Sendable {
        case lands, opens, answers

        public var words: String {
            switch self {
            case .lands: "An ask lands"
            case .opens: "Open it from the notch"
            case .answers: "Answer it in its session"
            }
        }
    }

    /// What the desktop round the edge shows at a time into the loop: the moment lit in the words, whether Lee is in
    /// the session's window, and whether the answer is in its terminal.
    public struct Scene: Equatable, Sendable {
        public var moment: Moment?
        public var isInSession: Bool
        public var isAnswered: Bool

        public init(moment: Moment? = nil, isInSession: Bool = false, isAnswered: Bool = false) {
            self.moment = moment
            self.isInSession = isInSession
            self.isAnswered = isAnswered
        }

        /// Before anything happens, and as nothing does.
        public static let rest = Scene()
    }

    public let length: Double
    /// When the ask lands.
    public let lands: Double
    /// The pointer sets off for the notch and reaches it; once the panel has poured, sets off for the ask's row and
    /// reaches it; then sets off away, and is gone.
    public let approach, arrive, toRow, onRow, leave, gone: Double
    /// When the pointer presses the ask's row; the jump lands as it sets off away. Nil where it only rests on the row.
    public let clicks: Double?
    /// When the answer shows in the session's terminal, and when the ask leaves the board: nil where it stays to the
    /// loop's end.
    public let answers: Double?
    public let resolves: Double?

    /// Step 1's: the ask lands, the panel pours, its row lit, and the pointer leaves.
    public static let hello = WelcomeLoop(
        length: 10_000, lands: 1_500, approach: 4_000, arrive: 4_700, toRow: 5_300, onRow: 5_700, leave: 8_200,
        gone: 8_700, clicks: nil, answers: nil, resolves: nil
    )

    /// Step 2's: the ask lands, the panel pours, its row clicked, the answer given in its session, and the ask gone.
    public static let ask = WelcomeLoop(
        length: 12_000, lands: 1_000, approach: 2_800, arrive: 3_500, toRow: 4_100, onRow: 4_500, leave: 5_600,
        gone: 6_300, clicks: 5_300, answers: 7_300, resolves: 8_800
    )

    /// Where the pointer starts and ends, off the notch, and where it touches the notch, by the notch's home.
    static func from(_ notchY: Double) -> CGPoint { CGPoint(x: 240, y: notchY + 60) }
    static func on(_ notchY: Double) -> CGPoint { CGPoint(x: 4, y: notchY) }
    static func away(_ notchY: Double) -> CGPoint { CGPoint(x: 520, y: notchY + 40) }

    /// This far into its time, the loop's own.
    public func phase(_ time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: length)

        return phase < 0 ? phase + length : phase
    }

    /// Whether the ask is on the board at this time into the loop: from its landing until it is answered.
    public func asks(at time: Double) -> Bool {
        (lands ..< (resolves ?? length)).contains(phase(time))
    }

    /// Whether the panel is out to find the ask's row on, at this time into the loop.
    public func findsRow(at time: Double) -> Bool {
        (toRow ..< gone).contains(phase(time))
    }

    /// Whether the ask's row is pressed in at this time into the loop: from the click until the jump lands.
    public func presses(at time: Double) -> Bool {
        clicks.map { ($0 ..< leave).contains(phase(time)) } ?? false
    }

    /// The pointer on the stage at this time into the loop, the notch's home this far down it, and the ask's row's
    /// middle where the panel shows it; nil while the pointer is elsewhere, off the stage.
    public func pointer(at time: Double, notchY: Double, row: CGPoint? = nil) -> CGPoint? {
        let time = phase(time), rests = row ?? Self.on(notchY)

        return switch time {
        case approach ..< arrive: Self.glide(Self.from(notchY), Self.on(notchY), share(time, approach, arrive))
        case arrive ..< toRow: Self.on(notchY)
        case toRow ..< onRow: Self.glide(Self.on(notchY), rests, share(time, toRow, onRow))
        case onRow ..< leave: rests
        case leave ..< gone: Self.glide(rests, Self.away(notchY), share(time, leave, gone))
        default: nil
        }
    }

    /// Whether the pointer moves at this time into the loop.
    public func pointerMoves(at time: Double) -> Bool {
        [approach ..< arrive, toRow ..< onRow, leave ..< gone].contains { $0.contains(phase(time)) }
    }

    /// The desktop at this time into the loop: the ask landing lit until the pointer sets off for the notch; opening
    /// it until the click; answering it until the ask leaves; Lee in the session from the jump on, the answer in its
    /// terminal from when it is given, until the loop starts again.
    public func scene(at time: Double) -> Scene {
        guard let clicks else {
            return .rest
        }

        let time = phase(time), resolves = resolves ?? length
        let moment: Moment? = switch time {
        case lands ..< approach: .lands
        case approach ..< clicks: .opens
        case clicks ..< resolves: .answers
        default: nil
        }

        return Scene(moment: moment, isInSession: time >= leave, isAnswered: answers.map { time >= $0 } ?? false)
    }

    /// When, after this time into the loop, it next changes of itself: a beat, or the loop starting again.
    public func next(after time: Double) -> Double {
        let phase = phase(time)
        let beats = [lands, approach, toRow, clicks, leave, answers, resolves, length].compactMap(\.self).sorted()

        return time + (beats.first { $0 > phase } ?? length) - phase
    }

    private func share(_ time: Double, _ start: Double, _ end: Double) -> Double {
        (time - start) / (end - start)
    }

    /// Eased in and out, as a hand moves.
    private static func glide(_ start: CGPoint, _ end: CGPoint, _ share: Double) -> CGPoint {
        let eased = share * share * (3 - 2 * share)

        return CGPoint(x: start.x + (end.x - start.x) * eased, y: start.y + (end.y - start.y) * eased)
    }
}
