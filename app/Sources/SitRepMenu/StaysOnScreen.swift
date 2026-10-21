import SitRepPanel

/// What stays on screen (DESIGN, "Settings"): the rows of the card under the three pictures that apply to the choice,
/// in their order. With Nothing there is no card, and one line says what carries the board instead.
public enum StaysOnScreen {
    /// A row of the card.
    public enum Row: Hashable, Sendable {
        case edge, display, style, length, max, material, reduceMotion
    }

    public static let menuCarries = "The menu and the SitRep window carry the board."

    /// The rows for what Lee set: Style for the notch, Length and Max for the strip, Max only at Grows; Material only
    /// from macOS 26, before which the edge is black and there is no row.
    public static func rows(_ settings: EdgeSettings, hasGlass: Bool) -> [Row] {
        let look: [Row] = (hasGlass ? [.material] : []) + [.reduceMotion]

        return switch settings.show {
        case .notch: [.edge, .display, .style] + look
        case .strip: [.edge, .display, .length] + (settings.length == .grows ? [.max] : []) + look
        case .nothing: []
        }
    }
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
