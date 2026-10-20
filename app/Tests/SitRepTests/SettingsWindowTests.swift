import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepPanel
import Testing

/// The Settings window takes the main menu's ⌘W and ⌘M (`AppMenu`), which it validates by its style. It is made, never
/// shown.
@MainActor
struct SettingsWindowTests {
    private static let window = SettingsWindow.window(NSViewController.with(NSView()))

    @Test(arguments: [#selector(NSWindow.performClose(_:)), #selector(NSWindow.performMiniaturize(_:))])
    func itTakesTheMainMenusWindowKeys(action: Selector) {
        #expect(Self.window.validateMenuItem(NSMenuItem(title: "", action: action, keyEquivalent: "")))
    }

    @Test func itOpensOnTheSpaceLeeIsOn() {
        #expect(Self.window.collectionBehavior.contains(.moveToActiveSpace))
    }
}

/// The SitRep window, made, never shown.
@MainActor
struct SitRepWindowTests {
    @Test func itOpensOnTheSpaceLeeIsOn() {
        #expect(SitRepWindow.window(NSView()).collectionBehavior.contains(.moveToActiveSpace))
    }
}

/// What Lee sets, kept in one place: a change saves as it is made, but a drag's steps only once it ends.
@MainActor
struct PreferencesTests {
    /// Defaults of their own, gone after the test.
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func aChangeIsSavedAndTheEdgeTakesIt() {
        Self.withDefaults { defaults in
            let preferences = Preferences(defaults)
            var taken: [EdgeSettings.Show] = []

            preferences.onEdge = { taken.append($0.show) }
            preferences.edit { $0.show = .strip }

            #expect(taken == [.strip])
            #expect(SavedEdgeSettings(defaults).read().show == .strip)
        }
    }

    @Test func aDragsStepsReachTheEdgeAtOnceAndAreSavedOnceAsItEnds() {
        Self.withDefaults { defaults in
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
    }
}

private extension NSViewController {
    static func with(_ view: NSView) -> NSViewController {
        let controller = NSViewController()

        controller.view = view
        return controller
    }
}
