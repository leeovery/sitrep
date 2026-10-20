import SitRepPanel

/// Which of the At the edge pane's sections apply to what Lee set (DESIGN, "Settings"): a section that no longer
/// applies fades out, and with Nothing shown one line says what carries the board instead.
public struct EdgePane: Equatable, Sendable {
    /// Edge and Display, for the notch and the strip alike.
    public let showsWhere: Bool
    /// Style.
    public let showsNotch: Bool
    /// Length.
    public let showsStrip: Bool
    /// Max, for Grows only.
    public let showsMax: Bool
    /// Material and Reduce motion.
    public let showsLook: Bool
    /// Material, Black or Glass: from macOS 26, before which the edge is black and there is no row.
    public let showsMaterial: Bool
    /// "The menu and the SitRep window carry the board", in the sections' place.
    public let saysMenuCarries: Bool

    public static let menuCarries = "The menu and the SitRep window carry the board."

    public init(_ settings: EdgeSettings, hasGlass: Bool) {
        let shows = settings.show != .nothing

        showsWhere = shows
        showsNotch = settings.show == .notch
        showsStrip = settings.show == .strip
        showsMax = showsStrip && settings.length == .grows
        showsLook = shows
        showsMaterial = shows && hasGlass
        saysMenuCarries = !shows
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
