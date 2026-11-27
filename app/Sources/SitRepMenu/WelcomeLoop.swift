import CoreGraphics
import SitRepPanel

/// A loop the stage plays, on its own clock, ms from its start, its beats as data: the notch at rest; an ask landing,
/// which swells it twice and lights it; the pointer coming to it, so it pours into the panel, then on the ask's row,
/// which it lights; then, in step 1's, the pointer leaving, so it closes, and over again. Step 2's goes on as the ask
/// is answered: the row clicked, so the panel drains and the session's window comes forward, the pointer going into
/// it; the answer in its terminal; the ask leaving the board, so the light goes out; and a rest. Points are on the
/// edge's stage, x into the screen from its edge, y down from its top.
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
    /// The pointer sets off for the edge and reaches it; the stage starts to look for the ask's row on the poured
    /// panel; the pointer is on the row; then it leaves it.
    public let approach, arrive, seeks, onRow, leave: Double
    /// When it is gone, once it has glided off the row out through the panel's front, so the notch closes as it does
    /// when a hand leaves it; nil where it leaves the stage at once, as the jump takes Lee into the session.
    public let gone: Double?
    /// When the pointer presses the ask's row; the jump lands as it leaves. Nil where it only rests on the row.
    public let clicks: Double?
    /// When the answer shows in the session's terminal, and when the ask leaves the board: nil where it stays to the
    /// loop's end.
    public let answers: Double?
    public let resolves: Double?

    /// Step 1's: the ask lands, the panel pours, its row lit, and the pointer leaves.
    public static let hello = WelcomeLoop(
        length: 10_000, lands: 1_500, approach: 4_000, arrive: 4_700, seeks: 5_300, onRow: 5_700, leave: 8_200,
        gone: 8_700, clicks: nil, answers: nil, resolves: nil
    )

    /// Step 2's: the ask lands, the panel pours, its row clicked, the answer given in its session, and the ask gone.
    public static let ask = WelcomeLoop(
        length: 12_000, lands: 1_000, approach: 2_800, arrive: 3_500, seeks: 4_100, onRow: 4_500, leave: 5_600,
        gone: nil, clicks: 5_300, answers: 7_300, resolves: 8_800
    )

    /// Where the pointer sets off from, out from where it touches the edge; and where it glides off the ask's row to,
    /// at the row's own height, past the panel's front.
    static func from(_ home: CGPoint) -> CGPoint { CGPoint(x: 240, y: home.y + 60) }
    static func away(_ row: CGPoint) -> CGPoint { CGPoint(x: 520, y: row.y) }

    /// This far into its time, the loop's own.
    public func phase(_ time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: length)

        return phase < 0 ? phase + length : phase
    }

    /// Whether the ask is on the board at this time into the loop: from its landing until it is answered.
    public func asks(at time: Double) -> Bool {
        (lands ..< (resolves ?? length)).contains(phase(time))
    }

    /// Whether the stage looks for the ask's row at this time into the loop, as the panel pours and moves: from once
    /// it has poured until the pointer leaves the row.
    public func findsRow(at time: Double) -> Bool {
        (seeks ..< leave).contains(phase(time))
    }

    /// Whether the ask's row is pressed in at this time into the loop: from the click until the jump lands.
    public func presses(at time: Double) -> Bool {
        clicks.map { ($0 ..< leave).contains(phase(time)) } ?? false
    }

    /// The pointer on the stage at this time into the loop: gliding to where it touches the edge, `home`, and resting
    /// there as the panel pours; then on the ask's row's middle where the panel shows it, else still at home; then
    /// gliding off the row at its own height, or with no row or no glide, gone at once; nil while it is elsewhere,
    /// off the stage. It steps onto the row rather than gliding to it, and leaves level with it, so it crosses no
    /// other row, which would light as if a hidden pointer passed over it.
    public func pointer(at time: Double, home: CGPoint, row: CGPoint? = nil) -> CGPoint? {
        let time = phase(time)

        return switch time {
        case approach ..< arrive: Self.glide(Self.from(home), home, share(time, approach, arrive))
        case arrive ..< onRow: home
        case onRow ..< leave: row ?? home
        case leaving: row.map { Self.glide($0, Self.away($0), share(time, leaving.lowerBound, leaving.upperBound)) }
        default: nil
        }
    }

    /// Whether the pointer moves at this time into the loop: on its way to the edge, and off the row.
    public func pointerMoves(at time: Double) -> Bool {
        [approach ..< arrive, leaving].contains { $0.contains(phase(time)) }
    }

    /// The pointer's glide off the row: none where it leaves at once.
    private var leaving: Range<Double> { leave ..< (gone ?? leave) }

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
        let beats = [lands, approach, seeks, onRow, clicks, leave, answers, resolves, length].compactMap(\.self)

        return time + (beats.filter { $0 > phase }.min() ?? length) - phase
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
