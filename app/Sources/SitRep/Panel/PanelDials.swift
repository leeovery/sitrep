import Foundation
import Observation
import SitRepPanel

/// Lee's dials for the panel's feel: the settings the running panel takes at once, kept in the user defaults as the
/// prototype's JSON, so they survive a restart and paste either way.
@MainActor
@Observable
final class PanelDials {
    private static let key = "panelSettings"

    var settings: Settings {
        didSet {
            defaults.set(settings.json, forKey: Self.key)
            onChange(settings)
        }
    }

    /// Told of every change, for the running panel.
    @ObservationIgnored var onChange: (Settings) -> Void = { _ in }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = defaults.string(forKey: Self.key).flatMap { try? Settings(json: $0) } ?? Settings()
    }

    /// Back to Lee's settings, and nothing kept, as the prototype's Reset.
    func reset() {
        settings = Settings()
        defaults.removeObject(forKey: Self.key)
    }
}
