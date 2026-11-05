import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepPanel
import Testing

/// What Lee sets, kept in one place: a change saves as it is made, but a drag's steps only once it ends.
@MainActor
struct PreferencesTests {
    @Test func aChangeIsSavedAndTheEdgeTakesIt() {
        let defaults = MemoryDefaults()
        let preferences = Preferences(defaults)
        var taken: [EdgeSettings.Show] = []

        preferences.onEdge = { taken.append($0.show) }
        preferences.edit { $0.show = .strip }

        #expect(taken == [.strip])
        #expect(SavedEdgeSettings(defaults).read().show == .strip)
    }

    @Test func aDragsStepsReachTheEdgeAtOnceAndAreSavedOnceAsItEnds() {
        let defaults = MemoryDefaults()
        let preferences = Preferences(defaults)
        var taken: [Double] = []

        preferences.onEdge = { taken.append($0.maxLength.share) }
        preferences.edit(saving: false) { $0.maxLength = StripMax(share: 0.3) }
        preferences.edit(saving: false) { $0.maxLength = StripMax(share: 0.6) }

        #expect(taken == [0.3, 0.6])
        #expect(defaults.data(forKey: SavedEdgeSettings.key) == nil)

        preferences.save()

        #expect(SavedEdgeSettings(defaults).read().maxLength == StripMax(share: 0.6))
    }

    /// The SitRep window's keys go as it starts; the rest stay.
    @Test func whatTheWindowKeptIsTakenOutAtTheStart() {
        let defaults = MemoryDefaults()

        Preferences.retired.forEach { defaults.set(Data([1]), forKey: $0) }
        defaults.set(Data([1]), forKey: SavedEdgeSettings.key)
        _ = Preferences(defaults)

        #expect(Preferences.retired.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(defaults.object(forKey: SavedEdgeSettings.key) != nil)
    }
}
