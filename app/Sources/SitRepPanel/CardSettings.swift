import Foundation

/// The card's settings: its prototype's seven dials, its edge and its light, defaulting to Lee's (round 2).
public struct CardSettings: PanelSettings {
    public var bounce = 0.70
    /// How far the notch eases out toward a pointer near it.
    public var nudge = 8.0
    /// How fast the card slides out: 2× is twice as quick.
    public var slide = 0.93
    /// How long into the slide the length starts, and into the shrink the depth starts home (÷ Slide opening,
    /// ÷ Close closing).
    public var lag = 30.0
    /// How fast the card goes back in: 2× is twice as quick.
    public var close = 0.88
    /// How far out a new ask pushes the notch, ...
    public var swell = 25.0
    /// ... and how many times.
    public var swells = 2.0
    public var edge = Settings.Edge.left
    public var light = Settings.Light.live

    public static let name = "Card"

    public init() {}

    public subscript(dial: CardDial) -> Double {
        get {
            switch dial {
            case .bounce: bounce
            case .nudge: nudge
            case .slide: slide
            case .lag: lag
            case .close: close
            case .swell: swell
            case .swells: swells
            }
        }
        set {
            switch dial {
            case .bounce: bounce = newValue
            case .nudge: nudge = newValue
            case .slide: slide = newValue
            case .lag: lag = newValue
            case .close: close = newValue
            case .swell: swell = newValue
            case .swells: swells = newValue
            }
        }
    }

    public var bounceScale: Double { dampingScale(bounce: bounce) }

    /// A spring after Bounce, Slide dividing the opening ones' responses and Close the closing ones' (the
    /// prototype's `SP`).
    public func sp(_ kind: CardSpring) -> SpringParams {
        let speed = switch kind {
        case .slide, .length: slide
        case .shrink, .home: close
        case .follow, .nudge, .ask: 1.0
        }
        return kind.listed.after(bounce: bounceScale, speed: speed)
    }

    /// Every spring after Bounce, Slide and Close as response·dampingFraction, as the prototype's Copy settings
    /// prints them under the JSON.
    public var derived: String {
        let springs = CardSpring.allCases.map { kind in
            let p = sp(kind)
            return "\(kind.label) \(fixed(p.response, 2))·\(fixed(p.damping, 2))"
        }

        return "springs, response·damping after Bounce ×\(fixed(bounceScale, 2)), Slide \(fixed(slide, 2))×, "
            + "Close \(fixed(close, 2))×: \(springs.joined(separator: ", "))"
    }
}

/// One of the card prototype's dials (its `DIALS`), with its slider's range and step.
public enum CardDial: String, PanelDial {
    case bounce, nudge, slide, lag, close, swell, swells

    public var range: ClosedRange<Double> {
        switch self {
        case .bounce: 0 ... 1
        case .nudge: 0 ... 10
        case .slide, .close: 0.5 ... 2
        case .lag: 0 ... 200
        case .swell: 15 ... 30
        case .swells: 1 ... 3
        }
    }

    public var step: Double {
        switch self {
        case .bounce, .slide, .close: 0.01
        case .nudge: 0.5
        case .lag: 5
        case .swell, .swells: 1
        }
    }

    /// The value as the slider's label shows it: 0.70, 8px, 7.5px, 0.93×, 30ms.
    public func show(_ value: Double) -> String {
        switch self {
        case .bounce: json(value)
        case .nudge, .swell: (value.rounded() == value ? json(value) : fixed(value, 1)) + "px"
        case .slide, .close, .swells: json(value) + "×"
        case .lag: json(value) + "ms"
        }
    }

    /// The value as the JSON prints it: Bounce, Slide and Close to two decimals, the rest as JavaScript's `String`
    /// does, 8 or 7.5.
    public func json(_ value: Double) -> String {
        switch self {
        case .bounce, .slide, .close: fixed(value, 2)
        case .nudge, .lag, .swell, .swells: value.rounded() == value ? String(Int(value)) : String(value)
        }
    }
}

/// The card prototype's springs (its `SPRINGS`), in its order.
public enum CardSpring: CaseIterable, Sendable {
    case slide, length, follow, shrink, home, nudge, ask

    /// What the readout calls it.
    public var label: String { "\(self)" }

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

extension CardSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case bounce, nudge, slide, lag, close, swell, swells, edge, light
    }

    public init(from decoder: any Decoder) throws {
        try self.init(reading: decoder)
    }
}
