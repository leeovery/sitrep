import Foundation
import SitRepEdge

/// Where the window was left, kept across launches as one value of its own under "windowLocation", so it opens there
/// when nothing needs Lee (`Location.opening(on:remembered:)`); where its pick stood in its list is not kept. Until 4
/// November 2026 the window kept the session picked last under "windowLastSession", read once as that session's page.
public struct WhereLeft: SavedValue {
    public static let key = "windowLocation"
    /// The key the session picked last was kept under, before the window's places.
    static let lastSession = "windowLastSession"

    public var location: Location?

    public init() {}

    public init(_ location: Location?) {
        self.location = location
    }

    /// Where it was left, as these defaults keep it: the value saved; with none, the session picked last under the old
    /// key, its page, which it moves into the new key, so it is read once.
    public static func read(_ defaults: UserDefaults) -> Location? {
        let saved = SavedSettings<WhereLeft>(defaults)

        guard defaults.object(forKey: key) == nil, let session = defaults.string(forKey: lastSession) else {
            return saved.read().location
        }

        let location = Location.session(session, from: .place(.needsYou))

        save(location, in: defaults)
        defaults.removeObject(forKey: lastSession)
        return location
    }

    /// Where the window is, saved in these defaults as where it was left.
    public static func save(_ location: Location, in defaults: UserDefaults) {
        SavedSettings<WhereLeft>(defaults).save(WhereLeft(location))
    }
}
