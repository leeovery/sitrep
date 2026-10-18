import CoreGraphics

/// A session as the strip shows it: a mark, and a tab of its panel row.
public struct StripSession: Equatable, Sendable {
    /// Where it stands.
    public enum Kind: Sendable {
        case needs, turn, working
    }

    public let id: String
    public var project: String
    public var kind: Kind
    /// An ask no window holds: its tab says so, and neither it nor its mark takes a click.
    public var away: Bool
    public var title: String
    /// Set in code type after the title, as in an ask to allow a command.
    public var code: String?
    /// How many more questions the ask holds: "+2".
    public var more: Int?
    /// Its project and work.
    public var sub: String
    /// When it came to stand where it does, ms on the wall clock.
    public var since: Double

    public init(
        id: String, project: String, kind: Kind, away: Bool = false, title: String, code: String? = nil,
        more: Int? = nil, sub: String, since: Double
    ) {
        self.id = id
        self.project = project
        self.kind = kind
        self.away = away
        self.title = title
        self.code = code
        self.more = more
        self.sub = sub
        self.since = since
    }

    /// The mark's letters: the project's two capitals where it has two (SitRep SR, DocMan DM), else its first two
    /// (Switchboard Sw, agntc ag).
    public var letters: String {
        let caps = project.filter { $0.isASCII && $0.isUppercase }
        return caps.count >= 2 ? String(caps.prefix(2)) : String(project.prefix(2))
    }

    /// A click on it jumps, unless no window holds it.
    public var jumps: Bool { !away }

    /// The tab's second line: its project and work, or for an away ask, why a click does nothing.
    public var line2: String { away ? "No window holds it. Carry it on in Claude." : sub }

    /// Its place in the panel's order: needs you, oldest first, away ones last; your turn, newest first; working,
    /// longest running first (the prototype's `cmpSessions`, but for its last tie, the order they came).
    var order: (rank: Int, age: Double) {
        switch kind {
        case .needs: (away ? 1 : 0, since)
        case .turn: (2, -since)
        case .working: (3, since)
        }
    }

    /// The sessions in the panel's order, those that came first first on a tie.
    static func sorted(_ sessions: [Self]) -> [Self] {
        func key(_ s: (offset: Int, element: Self)) -> (Int, Double, Int) {
            (s.element.order.rank, s.element.order.age, s.offset)
        }
        return sessions.enumerated().sorted { key($0) < key($1) }.map(\.element)
    }
}

/// The screen the strip is on, in its stage coordinates: x into the screen from its edge, y down from its top.
public struct StripStage: Equatable, Sendable {
    public var width: Double
    public var height: Double
    /// The menu bar's height: the strip starts under it.
    public var menu: Double

    public init(width: Double, height: Double, menu: Double) {
        self.width = width
        self.height = height
        self.menu = menu
    }
}

/// What the view tells the strip each frame.
public struct StripInput {
    /// A clock in ms that only runs forward. A frame more than 50ms after the last moves the model on by 50.
    public var time: Double
    /// The pointer in stage coordinates; nil while it is on another screen.
    public var pointer: CGPoint?
    public var stage: StripStage
    /// Whether to reduce motion, as the Mac or SitRep asks: then nothing springs, and shapes cross-fade.
    public var reducesMotion: Bool

    public init(time: Double, pointer: CGPoint?, stage: StripStage, reducesMotion: Bool = false) {
        self.time = time
        self.pointer = pointer
        self.stage = stage
        self.reducesMotion = reducesMotion
    }
}

/// How wide a tab's words are, as the view sets them, before the tab's slack and its limits: one session's row, or
/// the count's rows.
public struct StripMeasure {
    public var row: (StripSession) -> Double
    public var rows: ([StripSession]) -> Double

    public init(row: @escaping (StripSession) -> Double, rows: @escaping ([StripSession]) -> Double) {
        self.row = row
        self.rows = rows
    }
}

extension StripSession {
    /// The panel's sample sessions as the strip shows them, as of this time on the wall clock, ms: its project the
    /// part of its line before " · "; quiet, Lee's turn; and one no window shows, an away ask, which takes no click.
    public static func samples(at now: Double) -> [Self] {
        Item.samples.compactMap(\.session).map { s in
            let kind: Kind = switch s.kind {
            case .needs, .off: .needs
            case .turn, .quiet: .turn
            case .working: .working
            }
            let project = s.sub.components(separatedBy: " · ").first ?? s.sub
            return StripSession(
                id: s.id, project: project, kind: kind, away: s.kind == .off, title: s.title, code: s.code, sub: s.sub,
                since: now - s.age
            )
        }
    }
}
