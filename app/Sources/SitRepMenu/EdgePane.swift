import SitRepPanel

/// Settings' Edge pane (DESIGN, "Settings"): under the Show row's card, the sections that apply to the choice, in
/// their order. Notch holds the rows that tune it; Motion holds Reduce motion, as it is about how SitRep moves the
/// notch. With Nothing there are none, and the Show row's line says what carries the board instead.
public enum EdgePane {
    /// A row of a section.
    public enum Row: Hashable, Sendable {
        case edge, display, style, reduceMotion
    }

    /// A section: its header, and its card's rows.
    public struct Section: Hashable, Sendable {
        public let name: String
        public let rows: [Row]
    }

    public static let menuCarries = "The menu carries the board."

    /// The sections for what Lee set: Notch and Motion for the notch, none for Nothing.
    public static func sections(_ settings: EdgeSettings) -> [Section] {
        switch settings.show {
        case .notch:
            [Section(name: "Notch", rows: [.edge, .display, .style]), Section(name: "Motion", rows: [.reduceMotion])]
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
