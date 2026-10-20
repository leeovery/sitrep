/// How Meniscus moves: Lee's settings from round 11, with the swell from his first feel of the app. It ships fixed,
/// with no dials (DESIGN, "The app ships these values fixed"); a test may vary it.
struct MeniscusFeel: Feel, Equatable, Sendable {
    var bounce = 0.90
    /// The field, the tongue's reach and the cling.
    var pull = 0.35
    /// How far the edge stretches before it breaks.
    var hold = 35.0
    /// The gap at which the notch snaps open.
    var reach = 10.0
    /// When the collapse starts, as a share of the way from the line to the deepest dent, in percent.
    var push = 20.0
    /// The landing's dip.
    var land = 1.11
    /// The collapse's speed.
    var close = 1.81
    /// How deep a new ask over-swells the notch, from its 15, ...
    var swell = 25.0
    /// ... and how many times.
    var swells = 2

    static let lees = MeniscusFeel()

    /// The attraction's reach from the edge.
    var field: Double { Tuning.fieldR * pull }

    /// A spring after Bounce (the prototype's `SP`).
    func sp(_ kind: MeniscusSpring) -> SpringParams { kind.listed.after(bounce: bounceScale) }
}

/// The prototype's springs (its `SPRINGS`), in its order; Bounce scales every one's damping.
enum MeniscusSpring: CaseIterable, Sendable {
    case attract, relax, home, pourH, pourW, cling, clingY, tongue, ret, ring, letGo, drain, land, rebound, ask

    /// As listed, before Bounce.
    var listed: SpringParams {
        switch self {
        case .attract: SpringParams(response: 0.20, damping: 0.75)
        case .relax: SpringParams(response: 0.45, damping: 0.55)
        case .home: SpringParams(response: 0.60, damping: 0.80)
        case .pourH: SpringParams(response: 0.40, damping: 0.75)
        case .pourW: SpringParams(response: 0.34, damping: 0.72)
        case .cling: SpringParams(response: 0.24, damping: 0.72)
        case .clingY: SpringParams(response: 0.16, damping: 0.86)
        case .tongue: SpringParams(response: 0.08, damping: 0.80)
        case .ret: SpringParams(response: 0.30, damping: 0.38)
        case .ring: SpringParams(response: 0.17, damping: 0.38)
        case .letGo: SpringParams(response: 0.30, damping: 0.50)
        // ×Bounce and capped at 1: about critical, so it eases in and never swings; the landing bounces.
        case .drain: SpringParams(response: 0.60, damping: 1.25)
        case .land: SpringParams(response: 0.19, damping: 0.31)
        case .rebound: SpringParams(response: 0.20, damping: 0.55)
        case .ask: SpringParams(response: 0.42, damping: 0.50)
        }
    }
}
