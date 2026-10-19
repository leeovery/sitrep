import Foundation

/// The strip's settings: its prototype's fourteen dials, its length and its edge, defaulting to Lee's, who kept the
/// prototype's (18 October 2026) and passed Grows and the needs you fold (19 October). Its shape and its tabs' ways
/// are his choices, fixed: the ends are the board's S, at the top and mirrored at the bottom, never changing, a tab
/// fitting into them; between marks a tab glides; while marks slide it keeps with its mark.
public struct StripSettings: PanelSettings {
    public var bounce = 0.50
    /// How long the pointer rests on a mark before the first tab pours out.
    public var dwell = 120.0
    /// How far the strip's edge bows toward the pointer during the dwell.
    public var reach = 3.0
    /// How fast a tab pours out, glides along the strip, and draws back: 2× is twice as quick.
    public var pour = 1.00
    public var glide = 1.00
    /// How long the words take to cross as a tab glides.
    public var fade = 160.0
    public var close = 1.00
    /// How much further the first mark sits under the top end's S, and the last over the bottom end's, every mark
    /// moving with it, so a tab's edge meets the S under its bump with room for its fillet.
    public var room = 12.0
    /// How long a tab waits after the pointer leaves, down to a fifth of it on a fast leave.
    public var grace = 300.0
    /// How long after the pointer leaves the strip the marks re-sort.
    public var settle = 1000.0
    /// How fast the marks slide to their places.
    public var slide = 1.00
    /// Length, Grows: how far the strip's ends lead the marks as it grows, and follow them as it shrinks; 1× moves
    /// them together.
    public var lead = 1.25
    /// Length, Grows: the strip's longest, in marks, past which the last place is the count; 0 the full height.
    public var maxMarks = 0.0
    /// How many times a new mark's ring flashes.
    public var swells = 2.0
    public var length = StripLength.grows
    public var edge = Settings.Edge.left

    public static let name = "Strip"

    public init() {}

    public subscript(dial: StripDial) -> Double {
        get { self[keyPath: dial.key] }
        set { self[keyPath: dial.key] = newValue }
    }

    public var switches: KeyValuePairs<String, String> {
        ["length": length.rawValue, "edge": edge.rawValue]
    }

    public mutating func set(switch name: String, to value: String) {
        switch name {
        case "length": length = StripLength(rawValue: value) ?? length
        case "edge": edge = Settings.Edge(rawValue: value) ?? edge
        default: break
        }
    }

    public var bounceScale: Double { dampingScale(bounce: bounce) }

    /// A spring after Bounce, and as fast as its speed dial makes it (the prototype's `SP`).
    public func sp(_ kind: StripSpring) -> SpringParams {
        let speed = switch kind {
        case .reach, .pour, .grow: pour
        case .glide, .width: glide
        case .draw: close
        case .slide, .arrive: slide
        case .press, .morph: 1.0
        }
        return kind.listed.after(bounce: bounceScale, speed: speed)
    }

    /// Length, Grows: the ends' spring, the marks' slide quicker by Lead as the strip grows, so the black is there
    /// before the marks, and slower by it otherwise, so as it shrinks the marks are in before the black follows.
    public func ends(growing: Bool) -> SpringParams {
        let slide = sp(.slide)
        return SpringParams(response: slide.response * (growing ? 1 / lead : lead), damping: slide.damping)
    }

    /// The most marks the full strip holds on a screen, at Room: Max's slider's right end, which is Full.
    public func longest(on stage: StripStage) -> Int {
        let pad = StripTuning.topEnd + StripTuning.padTop + StripTuning.mark / 2 + room
        let run = stage.height - stage.menu - StripTuning.bottomEnd - 2 * pad
        return Swift.max(5, Int((run / StripTuning.pitch).rounded(.down)) + 1)
    }

    /// Every spring after Bounce and the speed dials as response·dampingFraction, and the ends' from Lead, as the
    /// prototype's Copy settings prints them under the JSON.
    public var derived: String {
        let springs = StripSpring.allCases.map { kind in
            let p = sp(kind)
            return "\(kind) \(fixed(p.response, 2))·\(fixed(p.damping, 2))"
        }
        let speeds = [("Pour", pour), ("Glide", glide), ("Close", close), ("Slide", slide)]
            .map { "\($0) \(fixed($1, 2))×" }
        let ends = [("growing", true), ("shrinking", false)].map { name, growing in
            let p = self.ends(growing: growing)
            return "\(fixed(p.response, 2))·\(fixed(p.damping, 2)) \(name)"
        }

        return "springs, response·damping after Bounce ×\(fixed(bounceScale, 2)), \(speeds.joined(separator: ", ")): "
            + springs.joined(separator: ", ") + ", ends " + ends.joined(separator: ", ")
    }
}

/// How long the strip is: as long as its marks need, centred where the notch sits, or the screen's full height.
public enum StripLength: String, Codable, CaseIterable, Sendable {
    case grows, full

    /// As the menu and the settings window name it.
    public var name: String { rawValue.capitalized }
}

/// One of the strip prototype's dials (its `DIALS`), with its slider's range and step. Max's slider runs to as many
/// marks as the screen holds, its right end Full, which is kept as 0.
public enum StripDial: String, PanelDial {
    case bounce, dwell, reach, pour, glide, fade, close, room, grace, settle, slide, lead, max, swells

    fileprivate var key: WritableKeyPath<StripSettings, Double> {
        switch self {
        case .bounce: \.bounce
        case .dwell: \.dwell
        case .reach: \.reach
        case .pour: \.pour
        case .glide: \.glide
        case .fade: \.fade
        case .close: \.close
        case .room: \.room
        case .grace: \.grace
        case .settle: \.settle
        case .slide: \.slide
        case .lead: \.lead
        case .max: \.maxMarks
        case .swells: \.swells
        }
    }

    /// Max is set on its own, against the screen the strip is on.
    public static var sliders: [Self] { allCases.filter { $0 != .max } }

    /// Max keeps Full, its 0; any other number of marks is at least 5.
    public func stepped(_ value: Double) -> Double {
        self == .max && value == 0 ? 0 : onStep(value)
    }

    public var range: ClosedRange<Double> {
        switch self {
        case .bounce: 0 ... 1
        case .dwell: 0 ... 400
        case .reach: 0 ... 8
        case .pour, .glide, .close, .slide: 0.5 ... 2
        case .room: 0 ... 20
        case .lead: 1 ... 2
        case .max: 5 ... .infinity
        case .fade: 40 ... 400
        case .grace: 0 ... 800
        case .settle: 0 ... 3000
        case .swells: 1 ... 3
        }
    }

    public var step: Double {
        switch self {
        case .bounce, .pour, .glide, .close, .slide: 0.01
        case .lead: 0.05
        case .dwell, .fade, .grace: 10
        case .room, .max: 1
        case .reach: 0.5
        case .settle: 50
        case .swells: 1
        }
    }

    /// The value as the slider's label shows it: 0.50, 120ms, 3px, 2.5px, 12px, 1.00×, 6 marks, Full, 2×.
    public func show(_ value: Double) -> String {
        switch self {
        case .bounce: json(value)
        case .dwell, .fade, .grace, .settle: json(value) + "ms"
        case .reach, .room: (value.rounded() == value ? json(value) : fixed(value, 1)) + "px"
        case .pour, .glide, .close, .slide, .lead, .swells: json(value) + "×"
        case .max: value == 0 ? "Full" : json(value) + " marks"
        }
    }

    /// The value as the JSON prints it: Bounce and the speeds to two decimals, Max "full" at Full, the rest as
    /// JavaScript's `String` does, 3 or 2.5.
    public func json(_ value: Double) -> String {
        switch self {
        case .bounce, .pour, .glide, .close, .slide, .lead: fixed(value, 2)
        case .max where value == 0: #""full""#
        case .dwell, .reach, .room, .fade, .grace, .settle, .max, .swells:
            value.rounded() == value ? String(Int(value)) : String(value)
        }
    }
}

/// The strip prototype's springs (its `SPRINGS`), in its order.
public enum StripSpring: CaseIterable, Sendable {
    case reach, pour, grow, glide, width, draw, slide, arrive, press, morph

    /// As listed, before Bounce and the speed dials.
    var listed: SpringParams {
        switch self {
        // the edge bowing toward the pointer during the dwell
        case .reach: SpringParams(response: 0.20, damping: 0.70)
        // the tab's depth out of the strip, ...
        case .pour: SpringParams(response: 0.26, damping: 0.72)
        // ... and its body, from the mark's 24 to the row's 52
        case .grow: SpringParams(response: 0.22, damping: 0.80)
        // along the strip to the next mark, ...
        case .glide: SpringParams(response: 0.24, damping: 0.82)
        // ... its width and body after the next row
        case .width: SpringParams(response: 0.24, damping: 0.86)
        // back into the strip, a little past into a dent
        case .draw: SpringParams(response: 0.22, damping: 0.80)
        // the marks to their places
        case .slide: SpringParams(response: 0.36, damping: 0.80)
        // a new mark growing into its place
        case .arrive: SpringParams(response: 0.30, damping: 0.55)
        // a click pressing the tab, or the ring, in
        case .press: SpringParams(response: 0.10, damping: 0.70)
        // Grows: the column into the notch at rest, and back out
        case .morph: SpringParams(response: 0.42, damping: 0.86)
        }
    }
}

extension StripSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case bounce, dwell, reach, pour, glide, fade, close, room, grace, settle, slide, lead, swells, length, edge
        case maxMarks = "max"
    }

    public init(from decoder: any Decoder) throws {
        try self.init(reading: decoder)
    }
}
