import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SwiftUI
import Testing

/// About SitRep, made, never shown: its close button and the main menu's ⌘W shut it (`AppMenu`), which it validates by
/// its style; it neither minimises nor zooms.
@MainActor
struct AboutWindowTests {
    private static let window = AboutWindow.window(NSViewController.with(NSView()))

    @Test func itClosesByItsButtonAndTheMainMenusCommandW() {
        #expect(Self.window.styleMask.contains(.closable))
        #expect(Self.window.validateMenuItem(NSMenuItem(title: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "")))
    }

    @Test func itNeitherMinimisesNorZooms() {
        #expect(!Self.window.styleMask.contains(.miniaturizable))
        #expect(!Self.window.styleMask.contains(.resizable))
        #expect(!Self.window.validateMenuItem(NSMenuItem(title: "", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")))
    }

    @Test func itShowsNoTitleAndOpensOnTheSpaceLeeIsOn() {
        #expect(Self.window.titleVisibility == .hidden)
        #expect(Self.window.collectionBehavior.contains(.moveToActiveSpace))
    }

    @Test func itIsAsWideAsDrawnItsHeightFromWhatItShows() {
        let window = AboutWindow.window(NSHostingController(rootView: AboutView()))

        #expect(window.contentLayoutRect.width == 308)
        #expect(window.frame.height > 112 + 36)
    }
}

/// The SitRep window, made, never shown. What macOS draws of it, its glass and the traffic lights' place, shows only
/// on the screen; its parts can be read here.
@MainActor
struct SitRepWindowTests {
    private static func split() -> NSSplitViewController {
        SitRepWindow.split(sidebar: NSViewController.with(NSView()), page: NSViewController.with(NSView()))
    }

    @Test func itOpensOnTheSpaceLeeIsOn() {
        #expect(SitRepWindow.window(Self.split()).collectionBehavior.contains(.moveToActiveSpace))
    }

    @Test func theBoardIsTheSystemsOwnSidebarAndThePageSitsBesideIt() {
        #expect(Self.split().splitViewItems.map(\.behavior) == [.sidebar, .default])
    }

    /// With no toggle to bring it back, it can neither be dragged shut nor shut by the window narrowing.
    @Test func theSidebarNeverCollapses() throws {
        let sidebar = try #require(Self.split().splitViewItems.first)

        #expect(!sidebar.canCollapse)
        #expect(!sidebar.canCollapseFromWindowResize)
    }

    @Test func theSidebarKeepsTheDrawingsWidth() throws {
        let split = Self.split()
        let window = SitRepWindow.window(split)

        window.layoutIfNeeded()

        let sidebar = try #require(split.splitViewItems.first)

        #expect(sidebar.minimumThickness == WindowStyle.boardWidth)
        #expect(sidebar.maximumThickness == WindowStyle.boardWidth)
        #expect(sidebar.viewController.view.frame.width == WindowStyle.boardWidth)
    }

    /// The toolbar's titlebar is what macOS 26 sets the traffic lights inside the sidebar's glass by, which only the
    /// screen shows.
    @Test func itHasAnEmptyUnifiedToolbarOverItsFullSizeContent() throws {
        let window = SitRepWindow.window(Self.split())
        let toolbar = try #require(window.toolbar)

        #expect(toolbar.items.isEmpty)
        #expect(!toolbar.allowsUserCustomization)
        #expect(window.toolbarStyle == .unified)
        #expect(window.styleMask.contains(.fullSizeContentView))
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
