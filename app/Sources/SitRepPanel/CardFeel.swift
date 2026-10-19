/// How the card moves: Lee's settings from its round 2. It ships fixed, with no dials, as Meniscus's does; a test may
/// vary it.
struct CardFeel: Feel, Equatable, Sendable {
    var bounce = 0.70
    /// How far the notch eases out toward a pointer near it.
    var nudge = 8.0
    /// How fast the card slides out: 2× is twice as quick.
    var slide = 0.93
    /// How long into the slide the length starts, and into the shrink the depth starts home (÷ Slide opening,
    /// ÷ Close closing).
    var lag = 30.0
    /// How fast the card goes back in: 2× is twice as quick.
    var close = 0.88
    /// How far out a new ask pushes the notch, ...
    var swell = 25.0
    /// ... and how many times.
    var swells = 2

    static let lees = CardFeel()

    /// A spring after Bounce, Slide dividing the opening ones' responses and Close the closing ones' (the
    /// prototype's `SP`).
    func sp(_ kind: CardSpring) -> SpringParams {
        let speed = switch kind {
        case .slide, .length: slide
        case .shrink, .home: close
        case .follow, .nudge, .ask: 1.0
        }
        return kind.listed.after(bounce: bounceScale, speed: speed)
    }
}

/// The card prototype's springs (its `SPRINGS`), in its order.
enum CardSpring: CaseIterable, Sendable {
    case slide, length, follow, shrink, home, nudge, ask

    /// As listed, before Bounce, Slide and Close.
    var listed: SpringParams {
        switch self {
        // the depth out: there, about 3 past, at about 135ms
        case .slide: SpringParams(response: 0.18, damping: 0.80)
        // the length out: within 4 about 135ms after it starts
        case .length: SpringParams(response: 0.16, damping: 0.85)
        // the length after the content as rows come and go, and back to rest
        case .follow: SpringParams(response: 0.24, damping: 0.90)
        // closing: the length back to the notch's, ...
        case .shrink: SpringParams(response: 0.12, damping: 1.40)
        // ... and the depth home: 1.4 stays 0.98 or more at any Bounce
        case .home: SpringParams(response: 0.14, damping: 1.40)
        case .nudge: SpringParams(response: 0.25, damping: 0.90)
        // a push to Swell peaks about 60ms on, back through 15 by about 200ms
        case .ask: SpringParams(response: 0.32, damping: 0.60)
        }
    }
}
