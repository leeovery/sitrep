import AppKit
@testable import SitRep
import Testing

/// The main menu no one sees: the key equivalents Settings and a SitRep window's editing and closing go through.
@MainActor
struct AppMenuTests {
    /// Each item of the built menu by its keys, as ⌘ and ⇧ with the key, and what it sends.
    private static let keys: [String: Selector] = {
        var keys: [String: Selector] = [:]

        for item in AppMenu.make().items.compactMap(\.submenu).flatMap(\.items) {
            let shift = item.keyEquivalentModifierMask.contains(.shift) ? "⇧" : ""

            if item.keyEquivalentModifierMask.contains(.command), let action = item.action {
                keys["⌘\(shift)\(item.keyEquivalent)"] = action
            }
        }
        return keys
    }()

    @Test func commandCommaBringsTheWindowForwardOnSettingsThroughTheAppsDelegate() {
        #expect(Self.keys["⌘,"] == #selector(AppDelegate.showSettings(_:)))
    }

    @Test func editingGoesToTheFirstResponderByTheStandardKeys() {
        #expect(Self.keys["⌘z"] == Selector(("undo:")))
        #expect(Self.keys["⌘⇧z"] == Selector(("redo:")))
        #expect(Self.keys["⌘x"] == #selector(NSText.cut(_:)))
        #expect(Self.keys["⌘c"] == #selector(NSText.copy(_:)))
        #expect(Self.keys["⌘v"] == #selector(NSText.paste(_:)))
        #expect(Self.keys["⌘a"] == #selector(NSText.selectAll(_:)))
    }

    @Test func aWindowClosesAndMinimisesByTheStandardKeys() {
        #expect(Self.keys["⌘w"] == #selector(NSWindow.performClose(_:)))
        #expect(Self.keys["⌘m"] == #selector(NSWindow.performMiniaturize(_:)))
    }

    @Test func itHasNoQuitSoACommandQAimedElsewhereCannotQuitSitRep() {
        #expect(Self.keys["⌘q"] == nil)
        #expect(!Self.keys.values.contains(#selector(NSApplication.terminate(_:))))
        #expect(Self.keys.count == 9)
    }

    /// About SitRep is the menu bar item's header's: an accessory app never shows this menu.
    @Test func itsFirstSubmenuIsTheAppsOwnSoEditIsNotTakenForItAndHoldsSettingsAlone() {
        #expect(AppMenu.make().items.map(\.title) == ["SitRep", "Edit", "Window"])
        #expect(AppMenu.make().items.first?.submenu?.items.map(\.title) == ["Settings…"])
    }
}
