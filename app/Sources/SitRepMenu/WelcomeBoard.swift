import CoreGraphics
import SitRepEdge
import SitRepPanel

/// The made-up board the welcome's stage shows on SitRep's own edge, laid out as Paper's board A lists it: an ask in
/// Needs you, two sessions working, and one whose turn it is, each in placeholder words (`Sample`). Each row is made
/// on its own, so no literal grows large.
public enum WelcomeBoard {
    /// The session whose ask lands.
    public static let asking = "ask"

    /// Before the ask lands: nothing needs Lee, so the notch rests.
    public static func calm(at now: Double) -> PanelBoard {
        PanelBoard(rows: [running(at: now), writing(at: now), review(at: now)])
    }

    /// The ask on it: new as it lands, which swells the notch; else lit, as for needs you, with no swell.
    public static func asked(at now: Double, isNew: Bool) -> PanelBoard {
        PanelBoard(
            rows: [ask(at: now), running(at: now), writing(at: now), review(at: now)], new: isNew ? [asking] : []
        )
    }

    private static let minute = 60_000.0

    private static func ask(at now: Double) -> Session {
        Session(
            id: asking, project: Sample.project, name: Sample.needsYou, kind: .needs, ask: asking, title: Sample.ask,
            sub: Sample.place, since: now
        )
    }

    private static func running(at now: Double) -> Session {
        working("running", Sample.running, since: now - 2 * minute)
    }

    private static func writing(at now: Double) -> Session {
        working("writing", Sample.writing, since: now - 6 * minute)
    }

    private static func working(_ id: String, _ line: Sample.Working, since: Double) -> Session {
        Session(
            id: id, project: Sample.project, kind: .working, title: line.title, code: line.code, sub: Sample.place,
            since: since
        )
    }

    private static func review(at now: Double) -> Session {
        Session(
            id: "review", project: Sample.project, kind: .turn, title: Sample.yourTurn, sub: Sample.place,
            since: now - 60 * minute
        )
    }
}

/// Step 1's loop, on the stage's own clock, ms from its start: the notch at rest; an ask landing, which swells it twice
/// and lights it; the pointer coming to it, so it pours into the panel, then moving onto the ask's row, which it
/// lights as Paper's board A draws it; the pointer leaving, so it closes; then over again, the ask answered. Points are
/// on the edge's stage, x into the screen from its edge, y down from its top.
public enum WelcomeLoop {
    public static let length = 10_000.0
    /// When the ask lands.
    public static let lands = 1_500.0
    /// The pointer sets off for the notch and reaches it; once the panel has poured, sets off for the ask's row and
    /// reaches it; then sets off away, and is gone.
    static let approach = 4_000.0, arrive = 4_700.0, toRow = 5_300.0, onRow = 5_700.0, leave = 8_200.0
    static let gone = 8_700.0

    /// Where the pointer starts and ends, off the notch, and where it touches the notch, by the notch's home.
    static func from(_ notchY: Double) -> CGPoint { CGPoint(x: 240, y: notchY + 60) }
    static func on(_ notchY: Double) -> CGPoint { CGPoint(x: 4, y: notchY) }
    static func away(_ notchY: Double) -> CGPoint { CGPoint(x: 520, y: notchY + 40) }

    /// This far into its time, the loop's own.
    public static func phase(_ time: Double) -> Double {
        let phase = time.truncatingRemainder(dividingBy: length)

        return phase < 0 ? phase + length : phase
    }

    /// Whether the ask is on the board at this time into the loop.
    public static func asks(at time: Double) -> Bool {
        phase(time) >= lands
    }

    /// Whether the panel is out to find the ask's row on, at this time into the loop.
    public static func findsRow(at time: Double) -> Bool {
        (toRow ..< gone).contains(phase(time))
    }

    /// The pointer on the stage at this time into the loop, the notch's home this far down it, and the ask's row's
    /// middle where the panel shows it; nil while the pointer is elsewhere, off the stage.
    public static func pointer(at time: Double, notchY: Double, row: CGPoint? = nil) -> CGPoint? {
        let time = phase(time), rests = row ?? on(notchY)

        return switch time {
        case approach ..< arrive: glide(from(notchY), on(notchY), share(time, approach, arrive))
        case arrive ..< toRow: on(notchY)
        case toRow ..< onRow: glide(on(notchY), rests, share(time, toRow, onRow))
        case onRow ..< leave: rests
        case leave ..< gone: glide(rests, away(notchY), share(time, leave, gone))
        default: nil
        }
    }

    /// Whether the pointer moves at this time into the loop.
    public static func pointerMoves(at time: Double) -> Bool {
        [approach ..< arrive, toRow ..< onRow, leave ..< gone].contains { $0.contains(phase(time)) }
    }

    /// When, after this time into the loop, it next changes of itself: the ask landing, the pointer setting off, or
    /// the loop starting again.
    public static func next(after time: Double) -> Double {
        let phase = phase(time), beats = [lands, approach, toRow, leave, length]

        return time + (beats.first { $0 > phase } ?? length) - phase
    }

    private static func share(_ time: Double, _ start: Double, _ end: Double) -> Double {
        (time - start) / (end - start)
    }

    /// Eased in and out, as a hand moves.
    private static func glide(_ start: CGPoint, _ end: CGPoint, _ share: Double) -> CGPoint {
        let eased = share * share * (3 - 2 * share)

        return CGPoint(x: start.x + (end.x - start.x) * eased, y: start.y + (end.y - start.y) * eased)
    }
}
