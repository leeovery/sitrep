import Foundation
import Observation
import SitRepPanel

/// Lee's dials for the panel's feel: which notch, and each notch's settings, which the running panel takes at once.
/// They are kept in the user defaults, the settings as their prototype's JSON, so they survive a restart and paste
/// either way.
@MainActor
@Observable
final class PanelDials {
    private static let styleKey = "panelStyle", meniscusKey = "panelSettings", cardKey = "panelCardSettings"

    var style: NotchStyle {
        didSet {
            defaults.set(style.rawValue, forKey: Self.styleKey)
            onChange()
        }
    }

    /// Meniscus's.
    var settings: Settings {
        didSet {
            defaults.set(settings.json, forKey: Self.meniscusKey)
            onChange()
        }
    }

    var card: CardSettings {
        didSet {
            defaults.set(card.json, forKey: Self.cardKey)
            onChange()
        }
    }

    /// Told of every change, for the running panel.
    @ObservationIgnored var onChange: () -> Void = {}

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        style = defaults.string(forKey: Self.styleKey).flatMap(NotchStyle.init) ?? .meniscus
        settings = Self.load(Self.meniscusKey, from: defaults)
        card = Self.load(Self.cardKey, from: defaults)
    }

    /// The chosen notch's dials back to Lee's settings, and nothing kept, as its prototype's Reset.
    func reset() {
        switch style {
        case .meniscus:
            settings = Settings()
            defaults.removeObject(forKey: Self.meniscusKey)
        case .card:
            card = CardSettings()
            defaults.removeObject(forKey: Self.cardKey)
        }
    }

    private static func load<S: PanelSettings>(_ key: String, from defaults: UserDefaults) -> S {
        defaults.string(forKey: key).flatMap { try? S(json: $0) } ?? S()
    }
}
