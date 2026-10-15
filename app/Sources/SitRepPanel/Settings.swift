import Foundation

/// The panel's settings: the prototype's seven dials and the swell, its edge and its light, defaulting to Lee's
/// (round 11, and the swell from his first feel of the app).
public struct Settings: Equatable, Sendable {
    public enum Edge: String, Codable, Sendable {
        case left, right
    }

    /// Which way the light in the lip is drawn: only Live has come over from the prototype.
    public enum Light: String, Codable, Sendable {
        case live
    }

    public var bounce = 0.90
    public var pull = 0.35
    public var hold = 35.0
    public var reach = 10.0
    public var push = 20.0
    public var land = 1.11
    public var close = 1.81
    /// How deep a new ask over-swells the lip, from its 15.
    public var swell = 22.0
    public var edge = Edge.left
    public var light = Light.live

    public init() {}

    public subscript(dial: Dial) -> Double {
        get {
            switch dial {
            case .bounce: bounce
            case .pull: pull
            case .hold: hold
            case .reach: reach
            case .push: push
            case .land: land
            case .close: close
            case .swell: swell
            }
        }
        set {
            switch dial {
            case .bounce: bounce = newValue
            case .pull: pull = newValue
            case .hold: hold = newValue
            case .reach: reach = newValue
            case .push: push = newValue
            case .land: land = newValue
            case .close: close = newValue
            case .swell: swell = newValue
            }
        }
    }

    /// The settings as the prototype's Copy settings prints them, so they paste either way:
    /// `{"bounce":0.90,"pull":0.35,"hold":35,"reach":10,"push":20,"land":1.11,"close":1.81,"swell":22,"edge":"left","light":"live"}`.
    public var json: String {
        let dials = Dial.allCases.map { "\"\($0.rawValue)\":\($0.json(self[$0]))" }
        let rest = ["\"edge\":\"\(edge.rawValue)\"", "\"light\":\"\(light.rawValue)\""]
        return "{\((dials + rest).joined(separator: ","))}"
    }

    /// The settings in that JSON; throws when it is not JSON.
    public init(json: String) throws {
        self = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    }

    /// What Pull makes of the attraction's reach from the edge.
    public var field: Double { Tuning.fieldR * pull }

    /// What Pull makes of the furthest the tongue reaches out of the lip.
    public var tongueReach: Double { Tuning.attractCap * pull }

    /// What Pull makes of the open edge's bow toward a pointer near it.
    public var clingReach: Double { Tuning.clingA * pull }

    /// What the settings make, as the prototype's Copy settings prints it under the JSON: every spring after
    /// Bounce as response·dampingFraction, and the field, the tongue and the cling from Pull.
    public var derived: String {
        let springs = SpringKind.allCases.map { kind in
            let p = sp(kind)
            return "\(kind.label) \(fixed(p.response, 2))·\(fixed(p.damping, 2))"
        }

        return "springs, response·damping after Bounce ×\(fixed(bounceScale, 2)): \(springs.joined(separator: ", "))"
            + " · from Pull: field \(Int(field.rounded()))px, tongue \(fixed(tongueReach, 1))px, cling \(fixed(clingReach, 1))px"
    }

    /// What Copy settings puts on the pasteboard, as the prototype's does: a header, the JSON, and what it makes.
    public var copied: String {
        "SitRep · Meniscus settings\n\(json)\n\(derived)"
    }
}

/// One of the prototype's dials (its `DIALS`), or the swell, with its slider's range and step.
public enum Dial: String, CaseIterable, Sendable {
    case bounce, pull, hold, reach, push, land, close, swell

    public var range: ClosedRange<Double> {
        switch self {
        case .bounce: 0 ... 1
        case .pull: 0 ... 2
        case .hold: 8 ... 44
        case .reach: 4 ... 24
        case .push: 0 ... 100
        case .land: 0 ... 2
        case .close: 0.5 ... 2
        case .swell: 15 ... 30
        }
    }

    public var step: Double {
        switch self {
        case .bounce, .pull, .land, .close: 0.01
        case .hold, .reach, .push, .swell: 1
        }
    }

    private var decimals: Int { step < 1 ? 2 : 0 }

    private var unit: String {
        switch self {
        case .bounce: ""
        case .pull, .land, .close: "×"
        case .hold, .reach, .swell: "px"
        case .push: "%"
        }
    }

    /// The slider's name: Bounce, Pull.
    public var name: String { rawValue.capitalized }

    /// The value as the slider's label shows it: 0.90, 0.35×, 35px, 20%.
    public func show(_ value: Double) -> String { json(value) + unit }

    func json(_ value: Double) -> String { fixed(value, decimals) }

    /// The value as the slider takes it: clamped to its range and onto its step, the nearest step up on a tie.
    public func stepped(_ value: Double) -> Double {
        let steps = ((clamp(value, range.lowerBound, range.upperBound) - range.lowerBound) / step).rounded()
        let scale = pow(10, Double(decimals))
        return ((range.lowerBound + steps * step) * scale).rounded() / scale
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case bounce, pull, hold, reach, push, land, close, swell, edge, light
    }

    /// As the prototype loads them: a key missing or unreadable keeps its default, and each dial goes onto its
    /// slider's range and step.
    public init(from decoder: any Decoder) throws {
        let given = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        for dial in Dial.allCases {
            let key = CodingKeys(rawValue: dial.rawValue)!
            if let value = try? given.decodeIfPresent(Double.self, forKey: key), value.isFinite {
                self[dial] = dial.stepped(value)
            }
        }

        edge = (try? given.decodeIfPresent(Edge.self, forKey: .edge)) ?? edge
        light = (try? given.decodeIfPresent(Light.self, forKey: .light)) ?? light
    }
}
