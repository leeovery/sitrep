import Foundation
import os
import SitRepCore
import SitRepPanel

/// What Lee sets for the edge, kept as one value in the app's defaults: JSON, read leniently, so a value another
/// version saved keeps what it can and anything unreadable is the defaults (`EdgeSettings`).
public struct SavedEdgeSettings {
    static let key = "edge"

    private let defaults: UserDefaults
    private let logger = Logger(sitrep: "settings")

    public init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func read() -> EdgeSettings {
        guard let saved = defaults.data(forKey: Self.key) else {
            return EdgeSettings()
        }

        do {
            return try JSONDecoder().decode(EdgeSettings.self, from: saved)
        } catch {
            logger.error("The edge's settings are not JSON, so the defaults stand: \(error, privacy: .public)")

            return EdgeSettings()
        }
    }

    public func save(_ settings: EdgeSettings) {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.key)
        } catch {
            logger.error("The edge's settings were not saved: \(error, privacy: .public)")
        }
    }
}
