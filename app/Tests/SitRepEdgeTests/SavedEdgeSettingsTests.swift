import Foundation
@testable import SitRepEdge
import SitRepPanel
import Testing

struct SavedEdgeSettingsTests {
    /// Defaults of their own, gone after the test.
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func nothingSavedIsTheDefaults() {
        Self.withDefaults { defaults in
            #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
        }
    }

    @Test func whatIsSavedIsReadBack() {
        Self.withDefaults { defaults in
            var settings = EdgeSettings()

            settings.edge = .right
            settings.along = 0.7
            settings.style = .card
            SavedEdgeSettings(defaults).save(settings)

            #expect(SavedEdgeSettings(defaults).read() == settings)
        }
    }

    @Test func itIsOneValueUnderOneKey() {
        Self.withDefaults { defaults in
            SavedEdgeSettings(defaults).save(EdgeSettings())

            #expect(defaults.dictionaryRepresentation().keys.filter { $0 == SavedEdgeSettings.key }.count == 1)
            #expect(defaults.data(forKey: SavedEdgeSettings.key) != nil)
        }
    }

    @Test func aValueAnotherVersionSavedKeepsWhatItCan() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"edge":"right","style":"lip","pin":true}"#.utf8), forKey: SavedEdgeSettings.key)

            let read = SavedEdgeSettings(defaults).read()

            #expect(read.edge == .right)
            #expect(read.style == .meniscus)
        }
    }

    @Test(arguments: [Data("not json".utf8), Data()])
    func anUnreadableValueIsTheDefaults(_ saved: Data) {
        Self.withDefaults { defaults in
            defaults.set(saved, forKey: SavedEdgeSettings.key)

            #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
        }
    }
}

/// The card's folded sections, kept across launches under a key of their own.
struct CardSettingsTests {
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func nothingFoldedUntilLeeFoldsIt() {
        Self.withDefaults { defaults in
            #expect(SavedSettings<CardSettings>(defaults).read().folded.isEmpty)
        }
    }

    @Test func theFoldsAreSavedUnderCardAndReadBack() {
        Self.withDefaults { defaults in
            SavedSettings(defaults).save(CardSettings(folded: [.working, .yourTurn]))

            #expect(defaults.data(forKey: "card") != nil)
            #expect(SavedSettings<CardSettings>(defaults).read().folded == [.working, .yourTurn])
        }
    }

    /// A section another version saved that this one doesn't know leaves nothing folded.
    @Test func aSectionItDoesNotKnowFoldsNothing() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"folded":["projects"]}"#.utf8), forKey: "card")

            #expect(SavedSettings<CardSettings>(defaults).read() == CardSettings())
        }
    }
}
