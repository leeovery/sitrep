import CoreGraphics
import SitRepEdge
import SitRepPanel

/// The made-up board the welcome's stage shows on SitRep's own edge, as Paper's board A lists it: Switchboard's ask
/// in Needs you, two sessions working, and one whose turn it is. Each row is made on its own, so no literal grows
/// large.
public enum WelcomeBoard {
    /// The session whose ask lands.
    public static let asking = "switchboard"

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
            id: asking, project: "Switchboard", name: "Keep a year of requests?", kind: .needs, ask: "ledger",
            title: "Shall the ledger keep requests for a year, or ninety days?", sub: "Switchboard · Usage", since: now
        )
    }

    private static func running(at now: Double) -> Session {
        Session(
            id: "sitrep", project: "SitRep", kind: .working, title: "Running ", code: "bun test",
            sub: "SitRep · The Mac app", since: now - 2 * minute
        )
    }

    private static func writing(at now: Double) -> Session {
        Session(
            id: "kit", project: "Kit", kind: .working, title: "Writing ", code: "DESIGN.md", sub: "Kit · The bootstrap",
            since: now - 6 * minute
        )
    }

    private static func review(at now: Double) -> Session {
        Session(
            id: "portal", project: "Portal", kind: .turn, title: "Review the picker's themes", sub: "Portal · Themes",
            since: now - 60 * minute
        )
    }
}

/// Step 1's loop, on the stage's own clock, ms from its start: the notch at rest; an ask landing, which swells it twice
/// and lights it; the pointer coming to it, so it pours into the panel; the pointer leaving, so it closes; then over
/// again, the ask answered. Points are on the edge's stage, x into the screen from its edge, y down from its top.
public enum WelcomeLoop {
    public static let length = 10_000.0
    /// When the ask lands.
    public static let lands = 1_500.0
    /// The pointer sets off for the notch, reaches it, sets off away, and is gone.
    static let approach = 4_000.0, arrive = 4_700.0, leave = 8_200.0, gone = 8_700.0

    /// Where the pointer starts and ends, off the notch, and where it rests on the panel, by the notch's home.
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

    /// The pointer on the stage at this time into the loop, the notch's home this far down it; nil while it is
    /// elsewhere, off the stage.
    public static func pointer(at time: Double, notchY: Double) -> CGPoint? {
        let time = phase(time)

        return switch time {
        case approach ..< arrive: glide(from(notchY), on(notchY), (time - approach) / (arrive - approach))
        case arrive ..< leave: on(notchY)
        case leave ..< gone: glide(on(notchY), away(notchY), (time - leave) / (gone - leave))
        default: nil
        }
    }

    /// Eased in and out, as a hand moves.
    private static func glide(_ start: CGPoint, _ end: CGPoint, _ share: Double) -> CGPoint {
        let eased = share * share * (3 - 2 * share)

        return CGPoint(x: start.x + (end.x - start.x) * eased, y: start.y + (end.y - start.y) * eased)
    }
}
