import SitRepPanel

/// Settings' Edge pane (DESIGN, "Settings"): under the Show row's card, the sections that apply to the choice, in
/// their order. A section named for the shape, Notch or Strip, holds the rows that tune it; Motion holds Reduce motion,
/// as it is about how SitRep moves whichever shape is at the edge. With Nothing there are none, and the Show row's line
/// says what carries the board instead.
public enum EdgePane {
    /// A row of a section.
    public enum Row: Hashable, Sendable {
        case edge, display, style, length, max, material, reduceMotion
    }

    /// A section: its header, and its card's rows.
    public struct Section: Hashable, Sendable {
        public let name: String
        public let rows: [Row]
    }

    public static let menuCarries = "The menu carries the board."

    /// The sections for what Lee set: Style for the notch, Length and Max for the strip, Max only at Grows; Material
    /// only from macOS 26, before which the edge is black and there is no row.
    public static func sections(_ settings: EdgeSettings, hasGlass: Bool) -> [Section] {
        let material: [Row] = hasGlass ? [.material] : []
        let max: [Row] = settings.length == .grows ? [.max] : []
        let motion = Section(name: "Motion", rows: [.reduceMotion])

        return switch settings.show {
        case .notch: [Section(name: "Notch", rows: [.edge, .display, .style] + material), motion]
        case .strip: [Section(name: "Strip", rows: [.edge, .display, .length] + max + material), motion]
        case .nothing: []
        }
    }
}

extension EdgeSettings.Edge {
    /// As Settings and the welcome name it.
    public var title: String { self == .left ? "Left" : "Right" }
}

extension NotchStyle {
    public var title: String { self == .meniscus ? "Meniscus" : "Card" }
}

extension StripLength {
    public var title: String { self == .grows ? "Grows" : "Full" }
}

extension EdgeSettings.Material {
    public var title: String { self == .black ? "Black" : "Glass" }
}

/// A display Lee can choose for the edge, by the id the edge knows it by; nil for the main display, whichever that is.
public struct DisplayChoice: Equatable, Sendable, Identifiable, Hashable {
    public let id: String?
    public let name: String

    public init(id: String?, name: String) {
        self.id = id
        self.name = name
    }

    /// A display that is connected: its id, its name, and whether it has the menu bar.
    public struct Connected: Sendable {
        public let id: String
        public let name: String
        public let isMain: Bool

        public init(id: String, name: String, isMain: Bool) {
            self.id = id
            self.name = name
            self.isMain = isMain
        }
    }

    public static let main = DisplayChoice(id: nil, name: "Main display")

    /// The choices: the main display first, then every other connected one by name, then the one chosen where it is
    /// neither, as the main display it has since become or one not connected, so the choice always shows.
    public static func choices(among connected: [Connected], chosen: String?) -> [DisplayChoice] {
        let others = connected.filter { !$0.isMain }.map { DisplayChoice(id: $0.id, name: $0.name) }
        guard let chosen, !others.contains(where: { $0.id == chosen }) else {
            return [main] + others
        }

        let name = connected.first { $0.id == chosen }?.name ?? "A display not connected"

        return [main] + others + [DisplayChoice(id: chosen, name: name)]
    }
}
