import Foundation
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct SavedEdgeSettingsTests {
    @Test func nothingSavedIsTheDefaults() {
        let defaults = MemoryDefaults()

        #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
    }

    @Test func whatIsSavedIsReadBack() {
        let defaults = MemoryDefaults()
        var settings = EdgeSettings()

        settings.edge = .right
        settings.along = 0.7
        settings.style = .card
        SavedEdgeSettings(defaults).save(settings)

        #expect(SavedEdgeSettings(defaults).read() == settings)
    }

    @Test func itIsOneValueUnderOneKey() {
        let defaults = MemoryDefaults()

        SavedEdgeSettings(defaults).save(EdgeSettings())

        #expect(Set(defaults.dictionaryRepresentation().keys) == [SavedEdgeSettings.key])
        #expect(defaults.data(forKey: SavedEdgeSettings.key) != nil)
    }

    @Test func aValueAnotherVersionSavedKeepsWhatItCan() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"edge":"right","style":"lip","pin":true}"#.utf8), forKey: SavedEdgeSettings.key)

        let read = SavedEdgeSettings(defaults).read()

        #expect(read.edge == .right)
        #expect(read.style == .meniscus)
    }

    @Test(arguments: [Data("not json".utf8), Data()])
    func anUnreadableValueIsTheDefaults(_ saved: Data) {
        let defaults = MemoryDefaults()

        defaults.set(saved, forKey: SavedEdgeSettings.key)

        #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
    }
}

/// The card's folded sections, kept across launches under a key of their own.
@Suite(.backstop)
struct CardSettingsTests {
    @Test func onlySnoozedFoldedUntilLeeFoldsIt() {
        let defaults = MemoryDefaults()

        #expect(SavedSettings<CardSettings>(defaults).read().folded == [.snoozed])
    }

    /// Snoozed unfolded is kept as the others' folds are, by its saying so.
    @Test func snoozedUnfoldedIsSavedAndReadBack() {
        let defaults = MemoryDefaults()

        SavedSettings(defaults).save(CardSettings(folded: [.working]))

        #expect(SavedSettings<CardSettings>(defaults).read().folded == [.working])
    }

    @Test func theFoldsAreSavedUnderCardAndReadBack() {
        let defaults = MemoryDefaults()

        SavedSettings(defaults).save(CardSettings(folded: [.working, .needsYou]))

        #expect(defaults.data(forKey: "card") != nil)
        #expect(SavedSettings<CardSettings>(defaults).read().folded == [.working, .needsYou])
    }

    /// A section another version saved that this one doesn't know is passed over, Your turn among them since it joined
    /// Needs you (13 November 2026), and the folds it knows are kept; Snoozed, of which a value saved before it says
    /// nothing, folded.
    @Test func aSectionItDoesNotKnowIsPassedOverAndTheRestKept() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"folded":["working","projects","yourTurn"]}"#.utf8), forKey: "card")

        #expect(SavedSettings<CardSettings>(defaults).read().folded == [.working, .snoozed])
    }
}
