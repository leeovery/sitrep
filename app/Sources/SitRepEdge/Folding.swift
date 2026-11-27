import SitRepPanel

/// The sections Lee folded on the notch's card: the card reads it as it lays out, a click or an arrival changes it,
/// and it is kept across opens and launches under "card" where it is kept at all.
public final class Folding {
    public private(set) var folds: CardFolds {
        didSet {
            if folds != oldValue {
                kept?.save(CardSettings(folded: folds.sections))
            }
        }
    }

    private let kept: SavedSettings<CardSettings>?

    /// As kept, where it is; else Snoozed alone folded, as at first.
    public init(kept: SavedSettings<CardSettings>? = nil) {
        self.kept = kept
        folds = CardFolds(sections: kept?.read().folded ?? BoardSection.foldedAtFirst)
    }

    /// A section folded, or unfolded.
    public func toggle(_ section: BoardSection) {
        folds.toggle(section)
    }

    /// A section folded, or unfolded, as it is chosen.
    public func set(_ section: BoardSection, folded isFolded: Bool) {
        folds.set(section, folded: isFolded)
    }
}
