import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// Settings at the sidebar's foot as the window lays it out, against spec 2.5: a rule of 0.5, 276 wide and centred, 8
/// under it the row, 32 tall, then 10 to the glass's foot; the list running on under it, its last row 12 over the rule.
/// A window on screen gives the sidebar a bottom safe area that an offscreen one does not: with it, round 7's foot, a
/// bar over the list, rose by the safe area and its row with it, 20 over the glass's foot as Lee's window showed it
/// (10 reproduces his capture's row exactly). So each holds whatever bottom safe area the sidebar has.
@MainActor
struct SettingsFooterTests {
    @Test(arguments: [0, 10, 27.5])
    func theFootIsARuleThen8ThenItsRow32Then10ToTheGlasssFoot(bottomSafeArea: CGFloat) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.settings)

        let side = try HostedSidebar(run, bottomSafeArea: bottomSafeArea)
        let row = try side.footRow()
        let drawn = try side.drawn()
        let above = CGRect(x: 0, y: row.minY - 20 - side.glassTop, width: 296, height: 20)
        let rule = try #require(drawn.drawnBox(in: above, ground: CGPoint(x: 4, y: above.midY)))

        #expect(row.height == 32)
        #expect(side.glassBottom - row.maxY == 10)
        #expect(rule.height == 0.5)
        #expect(rule.minX == 10 && rule.maxX == 286)
        #expect(row.minY - side.glassTop - rule.maxY == 8)
        #expect(side.foot?.selectedRow == 0)
    }

    /// In a window too short for the board, scrolled to its end.
    @Test(arguments: [0, 10, 27.5])
    func theListRunsOnUnderTheFootItsLastRow12OverTheRule(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(HostedSidebar.opened(), height: 400, bottomSafeArea: bottomSafeArea)
        let scroll = try #require(side.board.enclosingScrollView)
        let clip = scroll.contentView
        let end = side.board.frame.height - clip.bounds.height + scroll.contentInsets.bottom

        clip.scroll(to: NSPoint(x: 0, y: end))
        scroll.reflectScrolledClipView(clip)

        let last = try #require(side.rows.last)
        let rule = try side.footRow().minY - WindowStyle.footerTop - WindowStyle.footerRule

        #expect(side.frame(of: scroll).maxY == side.glassBottom)
        #expect(rule - last.maxY == 12)
    }

    /// The gear centred on the mark's slot, at 29, in the accent; "Settings" at a title's 46.
    @Test func itsRowIsASessionRowsGearAndWord() throws {
        let side = try HostedSidebar(HostedSidebar.opened())
        let drawn = try side.drawn()
        let row = try side.footRow().offsetBy(dx: 0, dy: -side.glassTop)
        let ground = CGPoint(x: 4, y: row.midY)
        let gear = try #require(drawn.drawnBox(in: CGRect(x: 16, y: row.minY, width: 26, height: 32), ground: ground))
        let word = try #require(drawn.drawnBox(in: CGRect(x: 42, y: row.minY, width: 150, height: 32), ground: ground))
        let accent = try drawn.brightest(in: gear)

        #expect(abs(gear.midX - 29) <= 0.5 && abs(gear.width - 15) <= 1)
        #expect(abs(gear.midY - row.midY) <= 0.5)
        #expect((46 ... 47.5).contains(word.minX))
        #expect(accent.blueComponent > 0.8 && accent.redComponent < 0.4)
    }
}
