import SitRepEdge
import SitRepPanel

/// The made-up board the welcome's stage shows on SitRep's own edge, in the panel's order (DESIGN, "The rows"): an ask
/// in Needs you, and two sessions working, each in placeholder words (`Sample`). Since 13 November 2026 it holds no
/// session at Lee's turn, which would light the notch blue where the loop rests unlit. Each row is made on its own, so
/// no literal grows large.
public enum WelcomeBoard {
    /// The session whose ask lands.
    public static let asking = "ask"

    /// Before the ask lands: nothing needs Lee, so the notch rests.
    public static func calm(at now: Double) -> PanelBoard {
        PanelBoard(rows: [running(at: now), writing(at: now)])
    }

    /// The ask on it: new as it lands, which swells the notch; else lit, as for needs you, with no swell.
    public static func asked(at now: Double, isNew: Bool) -> PanelBoard {
        PanelBoard(rows: [ask(at: now), running(at: now), writing(at: now)], new: isNew ? [asking] : [])
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
}
