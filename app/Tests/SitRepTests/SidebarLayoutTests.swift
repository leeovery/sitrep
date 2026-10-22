import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar as the window lays it out, against Paper's board C ("Option B, one list") value for value: the Filter
/// field alone over one list; each line's height; a row's mark, title and age, a heading's name, count and chevron, in
/// their places; and the selection on the row it belongs to. Every x is from the glass's left and every y from the
/// window's top, as the drawing gives them.
@MainActor
struct SidebarLayoutTests {
    /// The rows of the first board `watch` printed, in order.
    private enum Row: Int {
        case needsYou, macAppAsking, dashboardAsking, goosematesAsking, sitrep, macApp, switchboard, dashboard, ledger
        case goosemates, goosematesSession, quietProjects, kit
    }

    /// A heading's row with no rule: 10 over its 24.
    private static let headingRow: CGFloat = 10 + 24

    nonisolated private static let downArrow: UInt16 = 125
    nonisolated private static let upArrow: UInt16 = 126

    @Test func theAccessoryIsTheFilterFieldAlone47TallTheListUnderIt() throws {
        let side = try HostedSidebar(HostedSidebar.opened())

        #expect(side.frame(of: try #require(side.field)) == CGRect(x: 10, y: 75, width: 276, height: WindowStyle.fieldHeight))
        #expect(WindowStyle.fieldHeight == 28)
        #expect(side.rows.first?.minY == 113)
    }

    /// Every heading 10 under what is before it, then 24, the first after Needs you carrying its rule, 12 and 0.5 more
    /// over that; a row under Needs you 39, the system's two-line row; a session's or a quiet project's 32.
    @Test func eachLineIsAsTallAsDrawnEachUnderTheLast() throws {
        let run = HostedSidebar.opened()
        let side = try HostedSidebar(run)
        let lines = run.sidebar(at: HostedSidebar.printed).lines
        let heights: [CGFloat] = lines.enumerated().map { place, line in
            switch line {
            case .needsYou: 10 + 24
            case .heading: place == Row.sitrep.rawValue ? 12 + 0.5 + 10 + 24 : 10 + 24
            case .asking: 39
            case .session, .quiet: 32
            }
        }

        #expect(side.rows.map(\.height) == heights)
        #expect(zip(side.rows, side.rows.dropFirst()).allSatisfy { $0.maxY == $1.minY })
        #expect(side.rows[Row.sitrep.rawValue].minY == 264)
    }

    /// The first heading, Needs you's or with no ask the first project's, 10 under the list's top as every heading sits
    /// 10 under what is before it: its row 10 under the Filter field, its 24 another 10 down.
    @Test(arguments: [true, false])
    func theFirstHeadingSits10UnderWhatIsBeforeIt(hasAsks: Bool) throws {
        let run = HostedSidebar.opened()
        var listed = run.listed(at: HostedSidebar.printed)

        if !hasAsks {
            listed.needsYou = []
        }

        let side = try HostedSidebar(run, listed: listed)
        let field = side.frame(of: try #require(side.field))
        let first = try #require(side.rows.first)
        let heads: Sidebar.Line.ID = hasAsks ? .needsYou : .spot(.board(.project("sitrep")))

        #expect(Sidebar(listed, folds: Folds()).lines.first?.id == heads)
        #expect(first.minY - field.maxY == 10)
        #expect(first.height == Self.headingRow)
        #expect(first.maxY - 24 - field.maxY == 20)
    }

    /// The foot's rule after Needs you: 0.5 in the separator's colour, 276 wide and 10 in, 12 under the last ask's row;
    /// SitRep's heading 10 under it, its words inside the heading's 24.
    @Test func aRuleSits12UnderNeedsYouTheNextHeading10UnderIt() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let last = Self.inDrawing(side.rows[Row.goosematesAsking.rawValue], of: side)
        let heading = Self.inDrawing(side.rows[Row.sitrep.rawValue], of: side)
        let gap = CGRect(x: 0, y: last.maxY, width: 296, height: 12 + 0.5 + 10)
        let rule = try #require(drawn.drawnBox(in: gap, ground: Self.ground(heading)))
        let words = CGRect(x: 0, y: rule.maxY, width: 200, height: heading.maxY - rule.maxY)
        let name = try #require(drawn.drawnBox(in: words, ground: Self.ground(heading)))
        let column = try HostedSidebar(HostedSidebar.opened())
        let footRule = try column.footRow().minY - column.glassTop - WindowStyle.footerTop - WindowStyle.rule
        let footPixel = try #require(try column.drawn().pixel(at: CGPoint(x: 148, y: footRule)))

        #expect(rule == CGRect(x: 10, y: last.maxY + 12, width: 276, height: 0.5))
        #expect(heading.maxY - 24 - rule.maxY == 10)
        #expect(name.minY > heading.maxY - 24)
        #expect(try #require(drawn.pixel(at: CGPoint(x: 148, y: rule.minY))) == footPixel)
    }

    /// With no ask, filtered to nothing under Needs you, or with nothing after it: no rule, every heading 10 under what
    /// is before it, with nothing drawn in those 10.
    @Test(arguments: Unruled.allCases)
    func noRuleShowsWithoutNeedsYouOrWithNothingAfterIt(unruled: Unruled) throws {
        let run = HostedSidebar.opened()
        let listed = unruled.listed(of: run)
        let side = try HostedSidebar(run, listAlone: true, listed: listed)
        let drawn = try side.drawn()
        let rows = side.rows.map { Self.inDrawing($0, of: side) }
        let lines = Sidebar(listed, folds: Folds()).lines
        let headings = zip(rows, lines).filter { _, line in
            switch line {
            case .needsYou, .heading: true
            case .asking, .session, .quiet: false
            }
        }

        #expect(rows.count == lines.count && !headings.isEmpty)
        for (row, _) in headings {
            let above = CGRect(x: 0, y: row.minY, width: 296, height: 10)

            #expect(row.height == Self.headingRow)
            #expect(drawn.drawnBox(in: above, ground: Self.ground(row)) == nil)
        }
    }

    /// The boards with no rule to show.
    enum Unruled: CaseIterable {
        case noAsk, filteredPastNeedsYou, nothingAfterNeedsYou

        @MainActor func listed(of run: WindowRun) -> Listed {
            var listed = run.listed(at: HostedSidebar.printed)

            switch self {
            case .noAsk:
                listed.needsYou = []
            case .filteredPastNeedsYou:
                run.filter = Filter("ledg")
                listed = run.listed(at: HostedSidebar.printed)
            case .nothingAfterNeedsYou:
                listed.projects = []
                listed.quiet = []
            }
            return listed
        }
    }

    @Test func aSessionsMarkCentresAt29AndItsTitleStartsAt46() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.macApp.rawValue], of: side)
        let dot = try #require(drawn.drawnBox(in: Self.band(row, x: 16 ... 42), ground: Self.ground(row)))
        let title = try #require(drawn.drawnBox(in: Self.band(row, x: 42 ... 200), ground: Self.ground(row)))

        #expect(abs(dot.midX - 29) <= 0.5)
        #expect(abs(dot.width - 7) <= 1)
        #expect((46 ... 47.5).contains(title.minX))
    }

    @Test func onlyARowWithAnAskShowsItsAgeEndingAt280() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let asking = Self.inDrawing(side.rows[Row.macApp.rawValue], of: side)
        let turn = Self.inDrawing(side.rows[Row.ledger.rawValue], of: side)
        let age = try #require(drawn.drawnBox(in: Self.band(asking, x: 220 ... 296), ground: Self.ground(asking)))

        #expect((278.5 ... 280.5).contains(age.maxX))
        #expect(drawn.drawnBox(in: Self.band(turn, x: 220 ... 296), ground: Self.ground(turn)) == nil)
    }

    /// The title's line 4 under the row's top and 16 tall, then 1, then the project's line, 14.
    @Test func aNeedsYouRowsTwoLinesSitFromItsTop() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.dashboardAsking.rawValue], of: side)
        let title = CGRect(x: 46, y: row.minY + 4, width: 150, height: 16)
        let project = CGRect(x: 46, y: row.minY + 21, width: 150, height: 14)
        let titleDrawn = try #require(drawn.drawnBox(in: title, ground: Self.ground(row)))
        let projectDrawn = try #require(drawn.drawnBox(in: project, ground: Self.ground(row)))

        #expect(drawn.drawnBox(in: CGRect(x: 46, y: row.minY + 20, width: 150, height: 1), ground: Self.ground(row)) == nil)
        #expect(titleDrawn.minY < project.minY)
        #expect(projectDrawn.maxY <= row.minY + 35)
    }

    /// Plain words, with no count and no chevron.
    @Test func needsYousHeadingIsItsNameAloneAt16() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.needsYou.rawValue], of: side)
        let heading = CGRect(x: 0, y: row.maxY - 24, width: 296, height: 24)
        let name = try #require(drawn.drawnBox(in: heading, ground: Self.ground(row)))

        #expect((16 ... 17.5).contains(name.minX))
        #expect(name.maxX < 90)
    }

    /// The chevron, open, 10 by 6, centred in its 15 by 24 slot at 269 to 284.
    @Test func aProjectsHeadingHasItsNameAt16AndItsChevronInItsSlot() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.sitrep.rawValue], of: side)
        let heading = CGRect(x: 0, y: row.maxY - 24, width: 296, height: 24)
        let name = try #require(drawn.drawnBox(in: heading.divided(atDistance: 200, from: .minXEdge).slice, ground: Self.ground(row)))
        let chevron = try #require(drawn.drawnBox(in: heading.divided(atDistance: 200, from: .minXEdge).remainder, ground: Self.ground(row)))

        #expect((16 ... 17.5).contains(name.minX))
        #expect(chevron.minX >= 270.5 && chevron.maxX <= 282.5)
        #expect(abs(chevron.width - 10) <= 1.5 && abs(chevron.height - 6) <= 1.5)
        #expect(abs(chevron.midY - heading.midY) <= 0.75)
    }

    /// Folded, SitRep's heading counts its one session with an ask in orange, before its chevron, which points right.
    @Test func aFoldedProjectsHeadingCountsItsAsksInOrangeItsChevronPointingRight() throws {
        let run = HostedSidebar.opened()

        run.toggle(.project("sitrep"))

        let side = try HostedSidebar(run, listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.sitrep.rawValue], of: side)
        let heading = CGRect(x: 0, y: row.maxY - 24, width: 296, height: 24)
        let chevron = try #require(drawn.drawnBox(in: CGRect(x: 269, y: heading.minY, width: 17, height: 24), ground: Self.ground(row)))
        let count = try #require(drawn.drawnBox(in: CGRect(x: 200, y: heading.minY, width: 69, height: 24), ground: Self.ground(row)))
        let orange = try drawn.brightest(in: count)

        #expect(abs(chevron.width - 6) <= 1.5 && abs(chevron.height - 10) <= 1.5)
        #expect(count.maxX <= chevron.minX)
        #expect(orange.redComponent > 0.8 && orange.blueComponent < 0.4)
        #expect(side.rows[Row.sitrep.rawValue + 1].height == 34)
    }

    /// The window opens on the Mac app's ask, which shows under Needs you; clicked under SitRep, it shows there.
    @Test func theSelectionIsOnTheRowOfTheSessionThatHoldsThePick() throws {
        let run = HostedSidebar.opened()

        #expect(try HostedSidebar(run).board.selectedRow == Row.macAppAsking.rawValue)
        _ = run.pickInList(.board(.session("sr-macapp")), at: HostedSidebar.printed)
        #expect(try HostedSidebar(run).board.selectedRow == Row.macApp.rawValue)
    }

    /// The list selects nothing it cannot pick, so the heading draws the selection on its own 24, 276 wide.
    @Test func aProjectsHeadingShowsItsPageAsPickedWhileTheListSelectsNothing() throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("switchboard"))

        let side = try HostedSidebar(run, listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.switchboard.rawValue], of: side)
        let picked = try #require(drawn.drawnBox(in: row, ground: Self.ground(row)))

        #expect(side.board.selectedRow == -1)
        #expect(picked == CGRect(x: 10, y: row.maxY - 24, width: 276, height: 24))
    }

    @Test func theArrowKeysWalkTheListsOwnRowsTheDoubledOnesAmongThem() throws {
        let picked = Picked()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: WindowActions(pickInList: { picked.spots.append($0) }))

        side.window.makeFirstResponder(side.board)
        for _ in 0 ..< 3 {
            side.window.sendEvent(try #require(Self.arrow(Self.downArrow, in: side.window)))
            side.window.contentView?.layoutSubtreeIfNeeded()
        }
        #expect(picked.spots == [.needsYou("sr-dash02"), .needsYou("sr-gs7kq2"), .board(.session("sr-macapp"))])
    }

    /// ↓ from the last row under Needs you passes the rule and SitRep's heading, to the Mac app's row under it.
    @Test func theArrowKeysGoFromNeedsYouPastTheRuleToTheNextRowThatPicks() throws {
        let run = HostedSidebar.opened()

        _ = run.pickInList(.needsYou("sr-gs7kq2"), at: HostedSidebar.printed)

        let pressed = try Self.pressed(Self.downArrow, on: run)

        #expect(pressed.spots == [.board(.session("sr-macapp"))])
        #expect(pressed.selectedRow == Row.macApp.rawValue)
    }

    @Test func aQuietProjectPickedShowsTheSelectionOnItsRow() throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("kit"))
        #expect(try HostedSidebar(run).board.selectedRow == Row.kit.rawValue)
    }

    @Test func theArrowKeysReachTheQuietProjectsRowsPastTheirHeading() throws {
        let run = HostedSidebar.opened()

        _ = run.pickInList(.board(.session("sr-gs7kq2")), at: HostedSidebar.printed)
        #expect(try Self.pressed(Self.downArrow, on: run).spots == [.board(.project("kit"))])
    }

    /// Switchboard's page open, its heading showing the pick, which the list holds no selection on.
    @Test(arguments: [
        (downArrow, Spot.board(.session("sr-dash02"))), (upArrow, .board(.session("sr-macapp"))),
    ])
    func fromAPickedHeadingTheArrowKeysGoToTheRowAfterItOrBeforeIt(key: UInt16, to spot: Spot) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("switchboard"))
        #expect(try Self.pressed(key, on: run).spots == [spot])
    }

    /// Request ledger picked, then Switchboard folded over it: its heading stands for the pick.
    @Test(arguments: [
        (downArrow, Spot.board(.session("sr-gs7kq2"))), (upArrow, .board(.session("sr-macapp"))),
    ])
    func fromAPickAFoldHidesTheArrowKeysGoFromItsHeading(key: UInt16, to spot: Spot) throws {
        let run = HostedSidebar.opened()

        _ = run.pickInList(.board(.session("sr-rq7dgr")), at: HostedSidebar.printed)
        run.toggle(.project("switchboard"))
        #expect(try Self.pressed(key, on: run).spots == [spot])
    }

    /// Filtered to Request ledger, Switchboard's heading is the list's first line, and nothing picks before it.
    @Test func fromAPickedHeadingWithNoRowBeforeItUpPicksNothing() throws {
        let run = HostedSidebar.opened()

        run.filter = Filter("ledg")
        _ = run.pick(.project("switchboard"))

        let pressed = try Self.pressed(Self.upArrow, on: run)

        #expect(pressed.spots == [])
        #expect(pressed.selectedRow == -1)
    }

    /// Goosemates folded, and the quiet projects too: nothing picks after Goosemates' heading.
    @Test func fromAPickedHeadingWithNoRowAfterItDownPicksNothing() throws {
        let run = HostedSidebar.opened()

        run.toggle(.project("goosemates"))
        run.toggle(.quiet)
        _ = run.pick(.project("goosemates"))

        let pressed = try Self.pressed(Self.downArrow, on: run)

        #expect(pressed.spots == [])
        #expect(pressed.selectedRow == -1)
    }

    /// With a modifier held the keys are the list's own, even from a picked heading.
    @Test func fromAPickedHeadingAnArrowWithAModifierIsTheListsOwn() throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("switchboard"))
        #expect(try Self.pressed(Self.downArrow, with: .command, on: run).spots != [.board(.session("sr-dash02"))])
    }

    /// What the list asked to pick as this key was pressed once on it, focus on it, and the row it then selects.
    private static func pressed(
        _ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], on run: WindowRun
    ) throws -> (spots: [Spot], selectedRow: Int) {
        let picked = Picked()
        let side = try HostedSidebar(run, actions: WindowActions(pickInList: { picked.spots.append($0) }))

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(key, with: modifiers, in: side.window)))
        side.window.contentView?.layoutSubtreeIfNeeded()
        return (picked.spots, side.board.selectedRow)
    }

    /// A row as the drawing has it, its y from the glass's top.
    private static func inDrawing(_ row: CGRect, of side: HostedSidebar) -> CGRect {
        row.offsetBy(dx: 0, dy: -side.glassTop)
    }

    /// The row's band between these xs.
    private static func band(_ row: CGRect, x: ClosedRange<CGFloat>) -> CGRect {
        CGRect(x: x.lowerBound, y: row.minY, width: x.upperBound - x.lowerBound, height: row.height)
    }

    /// The glass beside the row, left of its selection.
    private static func ground(_ row: CGRect) -> CGPoint {
        CGPoint(x: 4, y: row.midY)
    }

    /// ↓ or ↑, as the keyboard sends it.
    private static func arrow(
        _ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], in window: NSWindow
    ) -> NSEvent? {
        let characters = key == downArrow ? "\u{F701}" : "\u{F700}"

        return NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers.union([.numericPad, .function]), timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: key
        )
    }
}

/// What the list asked the window to pick.
@MainActor
private final class Picked {
    var spots: [Spot] = []
}
