import AppKit
@testable import SitRep
import SitRepMenu
import Testing

/// The menu's header, a click on which opens About SitRep: it takes the menu's own highlight, as wide as the menu.
@MainActor
struct MenuHeaderTests {
    final class Target: NSObject {
        var clicks = 0

        @objc func about() {
            clicks += 1
        }
    }

    @Test func itIsAsWideAsTheMenuSoItsHighlightRunsAcrossIt() {
        #expect(abs(MenuHeaderView().frame.width - MenuCut.menuWidth) < 0.001)
    }

    @Test func highlightedItShowsTheMenusHighlightBehindItsWords() throws {
        let header = MenuHeaderView()
        let highlight = try #require(header.subviews.first as? NSVisualEffectView)

        #expect(highlight.isHidden)
        header.isHighlighted = true
        #expect(!highlight.isHidden)
        #expect(highlight.material == .selection && highlight.isEmphasized)
        header.isHighlighted = false
        #expect(highlight.isHidden)
    }

    @Test func aClickAnywhereOnItSendsItsItemsAction() throws {
        let target = Target()
        let menu = NSMenu()
        let item = NSMenuItem(title: "", action: #selector(Target.about), keyEquivalent: "")
        let header = MenuHeaderView()

        item.target = target
        item.view = header
        menu.addItem(item)
        #expect(header.hitTest(CGPoint(x: 20, y: 10)) === header)
        header.mouseUp(with: try #require(NSEvent.mouseEvent(
            with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 0
        )))
        #expect(target.clicks == 1)
    }

    /// Not "SitRep, Version 0.2.0": what a press does.
    @Test func toVoiceOverItIsOneButtonAboutSitRepThatPresses() {
        let target = Target()
        let menu = NSMenu()
        let item = NSMenuItem(title: "", action: #selector(Target.about), keyEquivalent: "")
        let header = MenuHeaderView()

        item.target = target
        item.view = header
        menu.addItem(item)
        #expect(header.isAccessibilityElement())
        #expect(header.accessibilityRole() == .button)
        #expect(header.accessibilityLabel() == "About SitRep")
        #expect(header.accessibilityChildren() == nil)
        #expect(header.accessibilityPerformPress())
        #expect(target.clicks == 1)
    }
}
