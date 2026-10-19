import Foundation

/// A panel's settings as its prototype's dials and switches set them and its Copy settings prints them, so they paste
/// either way.
public protocol PanelSettings: Codable, Equatable, Sendable {
    associatedtype Dial: PanelDial

    /// The form's name, as its Copy settings' header gives it.
    static var name: String { get }

    /// Lee's.
    init()

    subscript(dial: Dial) -> Double { get set }
    /// The switches after the dials, by their JSON names, in the order the JSON prints them.
    var switches: KeyValuePairs<String, String> { get }
    /// A switch as the JSON gives it: a value it doesn't take leaves it as it was.
    mutating func set(switch name: String, to value: String)
    /// What the settings make, as the prototype's Copy settings prints it under the JSON.
    var derived: String { get }
}

/// A notch's settings: after its dials, its edge and its light.
public protocol NotchSettings: PanelSettings {
    var edge: Settings.Edge { get set }
    var light: Settings.Light { get set }
}

extension NotchSettings {
    public var switches: KeyValuePairs<String, String> { ["edge": edge.rawValue, "light": light.rawValue] }

    public mutating func set(switch name: String, to value: String) {
        switch name {
        case "edge": edge = Settings.Edge(rawValue: value) ?? edge
        case "light": light = Settings.Light(rawValue: value) ?? light
        default: break
        }
    }
}

/// One of a prototype's dials: its slider's range and step, its name, and its value as the slider's label and the
/// JSON show it.
public protocol PanelDial: RawRepresentable<String>, CaseIterable, Hashable, Sendable where AllCases == [Self] {
    var range: ClosedRange<Double> { get }
    var step: Double { get }
    /// The slider's name: Bounce, Pull.
    var name: String { get }
    func show(_ value: Double) -> String
    func json(_ value: Double) -> String
    /// The value as the dial takes it, read from the JSON or moved on its slider.
    func stepped(_ value: Double) -> Double
    /// The dials the settings window shows as plain sliders, in their order.
    static var sliders: [Self] { get }
}

extension PanelDial {
    public var name: String { rawValue.capitalized }

    public static var sliders: [Self] { allCases }

    public func stepped(_ value: Double) -> Double { onStep(value) }

    /// The value as the slider takes it: clamped to its range and onto its step, the nearest step up on a tie.
    public func onStep(_ value: Double) -> Double {
        let steps = ((clamp(value, range.lowerBound, range.upperBound) - range.lowerBound) / step).rounded()
        // to the step's own decimals, so 70 steps of 0.01 are 0.7 and not 0.7000000000000001
        let scale = pow(10, max(0, (-log10(step)).rounded(.up)))
        return ((range.lowerBound + steps * step) * scale).rounded() / scale
    }
}

extension PanelSettings {
    /// The settings as the prototype's Copy settings prints them: each dial, then each switch.
    public var json: String {
        let dials = Dial.allCases.map { "\"\($0.rawValue)\":\($0.json(self[$0]))" }
        let rest = switches.map { "\"\($0.key)\":\"\($0.value)\"" }
        return "{\((dials + rest).joined(separator: ","))}"
    }

    /// The settings in that JSON; throws when it is not JSON.
    public init(json: String) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }

    /// What Copy settings puts on the pasteboard, as the prototype's does: a header, the JSON, and what it makes.
    public var copied: String {
        "SitRep · \(Self.name) settings\n\(json)\n\(derived)"
    }

    /// As the prototype loads them: a key missing or unreadable keeps its default, and each dial goes onto its
    /// slider's range and step.
    init(reading decoder: any Decoder) throws {
        let given = try decoder.container(keyedBy: Key.self)
        self.init()

        for dial in Dial.allCases {
            if let value = try? given.decodeIfPresent(Double.self, forKey: Key(dial.rawValue)), value.isFinite {
                self[dial] = dial.stepped(value)
            }
        }

        for name in switches.map(\.key) {
            if let value = try? given.decodeIfPresent(String.self, forKey: Key(name)) {
                set(switch: name, to: value)
            }
        }
    }
}

/// A key in the settings' JSON, by its name.
private struct Key: CodingKey {
    let stringValue: String

    init(_ name: String) {
        stringValue = name
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    var intValue: Int? { nil }

    init?(intValue: Int) {
        nil
    }
}

/// The panel's settings: the prototype's seven dials and a new ask's swell, its edge and its light, defaulting to
/// Lee's (round 11, and the swell from his first feel of the app).
public struct Settings: NotchSettings {
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
    /// How deep a new ask over-swells the lip, from its 15, ...
    public var swell = 25.0
    /// ... and how many times.
    public var swells = 2.0
    public var edge = Edge.left
    public var light = Light.live

    public static let name = "Meniscus"

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
            case .swells: swells
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
            case .swells: swells = newValue
            }
        }
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
}

/// One of the prototype's dials (its `DIALS`), or a new ask's swell, with its slider's range and step.
public enum Dial: String, PanelDial {
    case bounce, pull, hold, reach, push, land, close, swell, swells

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
        case .swells: 1 ... 3
        }
    }

    public var step: Double {
        switch self {
        case .bounce, .pull, .land, .close: 0.01
        case .hold, .reach, .push, .swell, .swells: 1
        }
    }

    private var decimals: Int { step < 1 ? 2 : 0 }

    private var unit: String {
        switch self {
        case .bounce: ""
        case .pull, .land, .close, .swells: "×"
        case .hold, .reach, .swell: "px"
        case .push: "%"
        }
    }

    /// The value as the slider's label shows it: 0.90, 0.35×, 35px, 20%.
    public func show(_ value: Double) -> String { json(value) + unit }

    public func json(_ value: Double) -> String { fixed(value, decimals) }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case bounce, pull, hold, reach, push, land, close, swell, swells, edge, light
    }

    public init(from decoder: any Decoder) throws {
        try self.init(reading: decoder)
    }
}
