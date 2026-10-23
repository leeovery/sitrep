import AppKit
@testable import SitRep
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

    @Test func itShowsNoTitle() {
        #expect(Self.window.titleVisibility == .hidden)
    }

    /// It goes to the Space Lee is on only as SitRep brings it forward (`ForwardWindowTests`).
    @Test func itStaysOnItsOwnSpaceTillSitRepBringsItForward() {
        #expect(!Self.window.collectionBehavior.contains(.moveToActiveSpace))
    }

    @Test func itIsAsWideAsDrawnItsHeightFromWhatItShows() {
        let window = AboutWindow.window(NSHostingController(rootView: AboutView()))

        #expect(window.contentLayoutRect.width == 308)
        #expect(window.frame.height > 112 + 36)
    }
}
