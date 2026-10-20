import Foundation

/// What Lee sets for the screen's edge: Settings' At the edge pane, and the menu's Show (DESIGN, "Settings"). How the
/// notch and the strip move is not among them; that ships fixed. Read leniently, so settings another version saved
/// keep what they can: a key missing or unreadable keeps its default, and anything but an object reads as the
/// defaults.
public struct EdgeSettings: Codable, Equatable, Sendable {
    /// What shows at the screen's edge: the notch and its light, the strip and its rings, or only the menu bar's glyph.
    public enum Show: String, Codable, CaseIterable, Sendable {
        case notch, strip, nothing
    }

    /// The screen's edge it sits on.
    public enum Edge: String, Codable, CaseIterable, Sendable {
        case left, right

        /// The screen's other side, where a drag let go past its middle takes the notch.
        public var other: Edge { self == .left ? .right : .left }
    }

    /// The notch's and the strip's black: the bezel's, or macOS 26's Liquid Glass.
    public enum Material: String, Codable, CaseIterable, Sendable {
        case black, glass
    }

    public var show = Show.notch
    public var edge = Edge.left
    /// How far down the screen the notch sits, from 0 at its top to 1 at its bottom: a little above the middle until
    /// Lee drags it.
    public var along = Tuning.notchAt
    /// The display it shows on, by the id the app gives it; nil for the main display.
    public var display: String?
    public var style = NotchStyle.meniscus
    public var length = StripLength.grows
    public var maxLength = StripMax.full
    public var material = Material.black
    /// SitRep's own Reduce motion: the app reduces motion when this or the Mac asks.
    public var reducesMotion = false

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = EdgeSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        show = given.value(.show, or: defaults.show)
        edge = given.value(.edge, or: defaults.edge)
        along = clamp(given.value(.along, or: defaults.along), 0, 1)
        display = given.value(.display, or: defaults.display)
        style = given.value(.style, or: defaults.style)
        length = given.value(.length, or: defaults.length)
        maxLength = given.value(.maxLength, or: defaults.maxLength)
        material = given.value(.material, or: defaults.material)
        reducesMotion = given.value(.reducesMotion, or: defaults.reducesMotion)
    }
}

/// Which notch: Meniscus, the design, or the card beside it.
public enum NotchStyle: String, Codable, CaseIterable, Sendable {
    case meniscus, card

    /// A notch of this style, from its first frame's input.
    public func notch(_ input: Input) -> any Notch {
        switch self {
        case .meniscus: Meniscus(input)
        case .card: Card(input)
        }
    }
}

/// How long the strip is: as long as its marks need, centred where the notch sits, or the screen's full height.
public enum StripLength: String, Codable, CaseIterable, Sendable {
    case grows, full
}

/// Max, for Grows: the strip's longest, on a slider from five marks' length to Full, kept as how far along the slider
/// it is. Lee never sees it in marks.
public struct StripMax: Codable, Equatable, Sendable {
    /// 0 at five marks' length, 1 at Full.
    public let share: Double

    public init(share: Double) {
        self.share = clamp(share, 0, 1)
    }

    public static let full = StripMax(share: 1)

    public var isFull: Bool { share == 1 }

    /// The most places it leaves a strip whose full height holds `longest`, never more; nil at Full, which leaves what
    /// fits.
    func places(longest: Int) -> Int? {
        isFull ? nil : min(longest, Self.fewest + Int((share * Double(max(0, longest - Self.fewest))).rounded()))
    }

    /// The slider's left end, in places.
    static let fewest = 5

    public init(from decoder: any Decoder) throws {
        try self.init(share: decoder.singleValueContainer().decode(Double.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(share)
    }
}

private extension KeyedDecodingContainer {
    /// The value under a key, or the fallback where it is missing or unreadable.
    func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
