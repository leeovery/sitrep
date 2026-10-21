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

    nonisolated private static let downArrow: UInt16 = 125
    nonisolated private static let upArrow: UInt16 = 126

    @Test func theAccessoryIsTheFilterFieldAlone47TallTheListUnderIt() throws {
        let side = try HostedSidebar(HostedSidebar.opened())

        #expect(side.frame(of: try #require(side.field)) == CGRect(x: 10, y: 75, width: 276, height: 28))
        #expect(side.rows.first?.minY == 113)
    }

    /// Needs you's heading 2 under the list's top, each later heading 10 under the rows before it, then 24; a row
    /// under Needs you 39, the system's two-line row; a session's or a quiet project's 32.
    @Test func eachLineIsAsTallAsDrawnEachUnderTheLast() throws {
        let run = HostedSidebar.opened()
        let side = try HostedSidebar(run)
        let lines = run.sidebar(at: HostedSidebar.printed).lines
        let heights: [CGFloat] = lines.enumerated().map { place, line in
            switch line {
            case .needsYou, .heading: place == 0 ? 2 + 24 : 10 + 24
            case .asking: 39
            case .session, .quiet: 32
            }
        }

        #expect(side.rows.map(\.height) == heights)
        #expect(zip(side.rows, side.rows.dropFirst()).allSatisfy { $0.maxY == $1.minY })
        // the last ask's row ends at 256, and SitRep's heading starts 10 under it, at 266, as drawn
        #expect(side.rows[Row.sitrep.rawValue].minY == 256)
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

    @Test func aQuietProjectPickedShowsTheSelectionOnItsRow() throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("kit"))
        #expect(try HostedSidebar(run).board.selectedRow == Row.kit.rawValue)
    }

    @Test func theArrowKeysReachTheQuietProjectsRowsPastTheirHeading() throws {
        let run = HostedSidebar.opened()

        _ = run.pickInList(.board(.session("sr-gs7kq2")), at: HostedSidebar.printed)
        #expect(try Self.pressed(Self.downArrow, on: run) == [.board(.project("kit"))])
    }

    /// Switchboard's page open, its heading showing the pick, which the list holds no selection on.
    @Test(arguments: [
        (downArrow, Spot.board(.session("sr-dash02"))), (upArrow, .board(.session("sr-macapp"))),
    ])
    func fromAPickedHeadingTheArrowKeysGoToTheRowAfterItOrBeforeIt(key: UInt16, to spot: Spot) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.project("switchboard"))
        #expect(try Self.pressed(key, on: run) == [spot])
    }

    /// What the list asked to pick as this key was pressed once on it, focus on it.
    private static func pressed(_ key: UInt16, on run: WindowRun) throws -> [Spot] {
        let picked = Picked()
        let side = try HostedSidebar(run, actions: WindowActions(pickInList: { picked.spots.append($0) }))

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(key, in: side.window)))
        side.window.contentView?.layoutSubtreeIfNeeded()
        return picked.spots
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
    private static func arrow(_ key: UInt16, in window: NSWindow) -> NSEvent? {
        let characters = key == downArrow ? "\u{F701}" : "\u{F700}"

        return NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.numericPad, .function], timestamp: 0,
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
