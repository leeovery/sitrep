import Foundation

/// What Lee sets for the screen's edge: Settings' Edge pane, and the menu's Show (DESIGN, "Settings"). How
/// the notch moves is not among them; that ships fixed. Read leniently, so settings another version saved keep what
/// they can: a key missing or unreadable keeps its default, so a Show of the strip, gone since 26 November 2026, reads
/// as the notch; one no longer read is passed over, as Material's is since the edge is black alone, and the strip's
/// Length and Max since it went; and anything but an object reads as the defaults.
public struct EdgeSettings: Codable, Equatable, Sendable {
    /// What shows at the screen's edge: the notch and its light, or only the menu bar's glyph.
    public enum Show: String, Codable, CaseIterable, Sendable {
        case notch, nothing
    }

    /// The screen's edge it sits on.
    public enum Edge: String, Codable, CaseIterable, Sendable {
        case left, right

        /// The screen's other side, where a drag let go past its middle takes the notch.
        public var other: Edge { self == .left ? .right : .left }
    }

    public var show = Show.notch
    public var edge = Edge.left
    /// How far down the screen the notch sits, from 0 at its top to 1 at its bottom: a little above the middle until
    /// Lee drags it.
    public var along = Tuning.notchAt
    /// The display it shows on, by the id the app gives it; nil for the main display.
    public var display: String?
    public var style = NotchStyle.meniscus
    /// SitRep's own Reduce motion: the app reduces motion when this or the Mac asks.
    public var reducesMotion = false

    public init() {}

    /// Where a drag lets the notch go from these settings: this far down the screen, where it moved along the edge,
    /// and on the other edge where it was let go past the screen's middle.
    public func dropped(along: Double?, across: Bool) -> EdgeMove {
        EdgeMove(edge: across ? edge.other : edge, along: along.map { clamp($0, 0, 1) })
    }

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

/// Where a drag left the notch: its edge, and how far down the screen, where it moved along it. It is all a drag
/// decides, so it lands on the settings as they stand when it is saved, whatever else changed meanwhile.
public struct EdgeMove: Equatable, Sendable {
    public let edge: EdgeSettings.Edge
    public let along: Double?

    /// These settings, with the drag's place.
    public func applied(to settings: EdgeSettings) -> EdgeSettings {
        var moved = settings

        moved.edge = edge
        if let along {
            moved.along = along
        }

        return moved
    }
}

extension KeyedDecodingContainer {
    /// The value under a key, or the fallback where it is missing or unreadable: how every setting is read leniently.
    package func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
