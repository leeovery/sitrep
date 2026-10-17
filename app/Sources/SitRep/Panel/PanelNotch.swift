import SitRepPanel

/// Which notch the spike shows, for Lee to feel both on the display and choose between them.
enum NotchStyle: String, CaseIterable {
    case meniscus, card

    /// As the menu and the settings window name it.
    var name: String { rawValue.capitalized }
}

/// The notch on the display, in the style Lee chose, with its own settings.
@MainActor
enum PanelNotch {
    case meniscus(Meniscus)
    case card(Card)

    /// A notch at rest in the style the dials choose, from this frame's news.
    init(_ dials: PanelDials, _ input: Input) {
        switch dials.style {
        case .meniscus: self = .meniscus(Meniscus(settings: dials.settings, input))
        case .card: self = .card(Card(settings: dials.card, input))
        }
    }

    var style: NotchStyle {
        switch self {
        case .meniscus: .meniscus
        case .card: .card
        }
    }

    var model: any Notch {
        switch self {
        case let .meniscus(meniscus): meniscus
        case let .card(card): card
        }
    }

    /// Its settings, as the dials have them now.
    func retune(_ dials: PanelDials) {
        switch self {
        case let .meniscus(meniscus): meniscus.settings = dials.settings
        case let .card(card): card.settings = dials.card
        }
    }
}
