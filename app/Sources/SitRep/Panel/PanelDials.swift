import Foundation
import Observation
import SitRepPanel

/// Lee's dials for the panel's feel: which form shows, the notch or the strip, which notch, and each one's settings,
/// which the running panel takes at once. They are kept in the user defaults, the settings as their prototype's JSON,
/// so they survive a restart and paste either way.
@MainActor
@Observable
final class PanelDials {
    private static let showKey = "panelShow", styleKey = "panelStyle"
    private static let meniscusKey = "panelSettings", cardKey = "panelCardSettings", stripKey = "panelStripSettings"

    var show: PanelForm {
        didSet {
            defaults.set(show.rawValue, forKey: Self.showKey)
            onChange()
        }
    }

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

    var strip: StripSettings {
        didSet {
            defaults.set(strip.json, forKey: Self.stripKey)
            onChange()
        }
    }

    /// Told of every change, for the running panel.
    @ObservationIgnored var onChange: () -> Void = {}

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        show = defaults.string(forKey: Self.showKey).flatMap(PanelForm.init) ?? .notch
        style = defaults.string(forKey: Self.styleKey).flatMap(NotchStyle.init) ?? .meniscus
        settings = Self.load(Self.meniscusKey, from: defaults)
        card = Self.load(Self.cardKey, from: defaults)
        strip = Self.load(Self.stripKey, from: defaults)
    }

    /// The dials shown back to Lee's settings, and nothing kept, as their prototype's Reset: the strip's, or the
    /// chosen notch's.
    func reset() {
        switch (show, style) {
        case (.strip, _):
            strip = StripSettings()
            defaults.removeObject(forKey: Self.stripKey)
        case (.notch, .meniscus):
            settings = Settings()
            defaults.removeObject(forKey: Self.meniscusKey)
        case (.notch, .card):
            card = CardSettings()
            defaults.removeObject(forKey: Self.cardKey)
        }
    }

    private static func load<S: PanelSettings>(_ key: String, from defaults: UserDefaults) -> S {
        defaults.string(forKey: key).flatMap { try? S(json: $0) } ?? S()
    }
}

/// Which form the panel takes on the display: the notch and its panel, or the strip in its place.
enum PanelForm: String, CaseIterable {
    case notch, strip

    /// As the menu and the settings window name it.
    var name: String { rawValue.capitalized }
}
