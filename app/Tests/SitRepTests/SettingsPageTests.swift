import AppKit
import Foundation
@testable import SitRep
import SitRepMenu
import SwiftUI
import Testing

/// The pictures of what stays on screen, drawn at a pose, which a pointer over them would move from rest.
struct PicturePoseTests {
    @Test func atRestTheNotchsCrestIsAStraightRun() {
        #expect(abs(NotchPicture.outline(reach: 0).boundingRect.maxX - 9) < 0.001)
        #expect(PicturePose.rest.reach == 0)
    }

    /// Its tip about 6.5 units past the crest, a little more than the lip's own 6-unit depth.
    @Test func atFullReachTheTongueReachesAboutSixAndAHalfUnitsPastTheCrest() {
        let tip = NotchPicture.outline(reach: 1).boundingRect.maxX

        #expect(tip > 15.3 && tip < 15.7)
    }

    @Test func atRestTheStripsWorkingRingsStandAtTwelveAndFortyFiveAndTheRestAreWhole() {
        #expect(PicturePose.rest.arcs == [nil, nil, 0, 45])
        #expect(StripPicture.rings.map(\.ring) == [.needs, .turn, .working, .working])
    }
}

struct DesktopCornerTests {
    /// The menu bar's own form, which DESIGN draws as "Tue 20 Oct 20:20".
    @Test func itsClockReadsAsTheMenuBarsInTheMacsLocale() {
        let evening = Date(timeIntervalSince1970: 1_792_524_000)

        #expect(DesktopCorner.clock(
            evening, locale: Locale(identifier: "en_GB"), timeZone: TimeZone(identifier: "Europe/London")!
        ) == "Tue 20 Oct 20:20")
    }
}

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
        #expect(abs(MenuHeader.view().frame.width - MenuCut.menuWidth) < 0.001)
    }

    @Test func highlightedItShowsTheMenusHighlightBehindItsWords() throws {
        let header = MenuHeader.view()
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
        let header = MenuHeader.view()

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
}
