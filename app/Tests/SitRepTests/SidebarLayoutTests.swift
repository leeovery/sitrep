import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
import enum SitRepPanel.BoardSection
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar as the window lays it out, against Paper's board D ("One list, two sizes") value for value, relative to
/// the built list: the Filter field alone over one list; each line's height; a heading's name, count and chevron, and
/// each row kind's mark, words and age, in their places; the selection on the row it belongs to, whatever its kind;
/// and the arrow keys. Every x is from the glass's left and every y from the window's top, as the drawing gives them.
@MainActor
struct SidebarLayoutTests {
    /// The lines of `watch`'s board by session: Harness's three asks, Switchboard's ask and prompt and Goosemates' away
    /// ask; SitRep working, Kit on its own work; Fumi's turn; Projects, folded.
    enum Row: Int, Sendable {
        case needsYou, harness, dashboard, goosemates, working, macApp, bootstrap, yourTurn, licensing, projects
    }

    /// A heading's row with no rule: 10 over its 24; with the rule after Needs you, 11.5, the rule's 0.5, then those.
    private static let headingRow: CGFloat = 10 + 24
    private static let ruledRow: CGFloat = 11.5 + 0.5 + 10 + 24

    nonisolated private static let downArrow: UInt16 = 125
    nonisolated private static let upArrow: UInt16 = 126

    private static func opened(folds: Folds = Folds(), wall: Date? = nil) -> WindowRun {
        HostedSidebar.opened(Lines.bySession[0], folds: folds, wall: wall)
    }

    @Test func theAccessoryIsTheFilterFieldAlone47TallTheListUnderIt() throws {
        let side = try HostedSidebar(Self.opened())

        #expect(side.frame(of: try #require(side.field)) == CGRect(x: 10, y: 75, width: 276, height: WindowStyle.fieldHeight))
        #expect(WindowStyle.fieldHeight == 28)
        #expect(side.rows.first?.minY == 113)
    }

    /// Every heading 10 under what is before it, then 24, the one after Needs you carrying its rule, 11.5 and 0.5 more
    /// over that; a Needs you row 39, the system's two-line row, however many lines wait, Harness's three asks as
    /// Goosemates' one; a working row 39; a your-turn row 28.
    @Test func eachLineIsAsTallAsDrawnEachUnderTheLast() throws {
        let run = Self.opened()
        let side = try HostedSidebar(run)
        let sidebar = run.sidebar(at: HostedSidebar.printed)
        let heights: [CGFloat] = sidebar.lines.map { line in
            switch line {
            case .heading: line.id == sidebar.ruled ? Self.ruledRow : Self.headingRow
            case let .session(row): row.section == .yourTurn ? 28 : 39
            case .earlier, .project: 28
            }
        }

        #expect(sidebar.lines.count == Row.projects.rawValue + 1)
        #expect(side.rows.map(\.height) == heights)
        #expect(heights == [34, 39, 39, 39, 46, 39, 39, 34, 28, 34])
        #expect(zip(side.rows, side.rows.dropFirst()).allSatisfy { $0.maxY == $1.minY })
        #expect(side.rows[Row.working.rawValue].minY == 264)
        #expect(side.rows.allSatisfy { $0.minY == $0.minY.rounded() })
    }

    /// "N earlier" and a project's row are one line, 28 tall, as Your turn's.
    @Test func nEarlierAndAProjectsRowAre28() throws {
        let run = Self.opened(folds: Folds(projects: false))
        let side = try HostedSidebar(run, listed: Self.withEarlier(run))
        let lines = Sidebar(Self.withEarlier(run), folds: run.folds).lines
        let earlier = try #require(lines.firstIndex { $0.id == .fold(.earlier) })
        let project = try #require(lines.firstIndex { $0.id == .pick(.project("kit")) })

        #expect(side.rows[earlier].height == 28)
        #expect(side.rows[project].height == 28)
    }

    /// The first heading, Needs you's or with no ask Working's, 10 under the list's top as every heading sits 10 under
    /// what is before it: its row 10 under the Filter field, its 24 another 10 down.
    @Test(arguments: [true, false])
    func theFirstHeadingSits10UnderWhatIsBeforeIt(hasAsks: Bool) throws {
        let run = Self.opened()
        var listed = run.listed(at: HostedSidebar.printed)

        if !hasAsks {
            listed.rows = listed.rows.filter { $0.section != .needsYou }
        }

        let side = try HostedSidebar(run, listed: listed)
        let field = side.frame(of: try #require(side.field))
        let first = try #require(side.rows.first)

        #expect(Sidebar(listed, folds: Folds()).lines.first?.id == .fold(.section(hasAsks ? .needsYou : .working)))
        #expect(first.minY - field.maxY == 10)
        #expect(first.height == Self.headingRow)
        #expect(first.maxY - 24 - field.maxY == 20)
    }

    /// The foot's rule after Needs you: 0.5 in the separator's colour, 276 wide and 10 in, 11.5 under the last ask's row;
    /// Working's heading 10 under it, its words inside the heading's 24.
    @Test func aRuleSits11AndAHalfUnderNeedsYouTheNextHeading10UnderIt() throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true)
        let drawn = try side.drawn()
        let last = Self.inDrawing(side.rows[Row.goosemates.rawValue], of: side)
        let heading = Self.inDrawing(side.rows[Row.working.rawValue], of: side)
        let gap = CGRect(x: 0, y: last.maxY, width: 296, height: 11.5 + 0.5 + 10)
        let rule = try #require(drawn.drawnBox(in: gap, ground: Self.ground(heading)))
        let words = CGRect(x: 0, y: rule.maxY, width: 200, height: heading.maxY - rule.maxY)
        let name = try #require(drawn.drawnBox(in: words, ground: Self.ground(heading)))
        let column = try HostedSidebar(Self.opened())
        let footRule = try column.footRow().minY - column.glassTop - WindowStyle.footerTop - WindowStyle.rule
        let footPixel = try #require(try column.drawn().pixel(at: CGPoint(x: 148, y: footRule)))

        #expect(rule == CGRect(x: 10, y: last.maxY + 11.5, width: 276, height: 0.5))
        #expect(heading.maxY - 24 - rule.maxY == 10)
        #expect(name.minY > heading.maxY - 24)
        #expect(try #require(drawn.pixel(at: CGPoint(x: 148, y: rule.minY))) == footPixel)
    }

    /// Needs you folded: its heading alone, the rule still after it.
    @Test func withNeedsYouFoldedTheRuleStillFollowsIt() throws {
        let run = Self.opened()

        run.toggle(.section(.needsYou))

        let listed = run.listed(at: HostedSidebar.printed)
        let side = try HostedSidebar(run, listAlone: true)

        #expect(side.rows.prefix(2).map(\.height) == [Self.headingRow, Self.ruledRow])
        try Self.expectRuled(side, showing: listed, folds: run.folds)
    }

    /// With no ask, filtered to nothing under Needs you, or with nothing after it: no rule, every heading 10 under what
    /// is before it, with nothing drawn in those 10.
    @Test(arguments: Unruled.allCases)
    func noRuleShowsWithoutNeedsYouOrWithNothingAfterIt(unruled: Unruled) throws {
        let run = Self.opened()
        let listed = unruled.listed(of: run)
        let side = try HostedSidebar(run, listAlone: true, listed: listed)

        #expect(Sidebar(listed, folds: Folds()).ruled == nil)
        try Self.expectRuled(side, showing: listed)
    }

    /// A board changing under a list already showing: the first ask comes, Working goes so Your turn follows Needs
    /// you, then Working again, and the last ask goes. Each time the heading after Needs you, and only it, grows to
    /// carry the rule, and gives it back.
    @Test func theRuleFollowsTheBoardOnAListAlreadyShowing() throws {
        let run = Self.opened()
        let board = run.listed(at: HostedSidebar.printed)
        var noAsk = board
        var noWorking = board

        noAsk.rows = board.rows.filter { $0.section != .needsYou }
        noWorking.rows = board.rows.filter { $0.section != .working }

        let side = try HostedSidebar(run, listAlone: true, listed: noAsk)

        for listed in [noAsk, board, noWorking, board, noAsk] {
            side.show(listed)
            // the list first hosted, still showing, not one made anew
            #expect(side.board.window === side.window)
            try Self.expectRuled(side, showing: listed)
        }
    }

    /// Each heading of this board as the list shows it: the one `Sidebar.ruled` names 46 tall, its rule 11.5 under its
    /// top, 276 wide and 10 in; every other 34, nothing drawn over its words.
    private static func expectRuled(_ side: HostedSidebar, showing listed: Listed, folds: Folds = Folds()) throws {
        let sidebar = Sidebar(listed, folds: folds)
        let drawn = try side.drawn()
        let rows = side.rows.map { inDrawing($0, of: side) }

        #expect(rows.count == sidebar.lines.count)
        for (row, line) in zip(rows, sidebar.lines) {
            guard case .heading = line else {
                continue
            }

            let isRuled = line.id == sidebar.ruled
            let above = CGRect(x: 0, y: row.minY, width: 296, height: row.height - 24)
            let rule = CGRect(x: 10, y: row.minY + 11.5, width: 276, height: 0.5)

            #expect(row.height == (isRuled ? ruledRow : headingRow))
            #expect(drawn.drawnBox(in: above, ground: ground(row)) == (isRuled ? rule : nil))
        }
    }

    /// The boards with no rule to show.
    enum Unruled: CaseIterable {
        case noAsk, filteredPastNeedsYou, nothingAfterNeedsYou

        @MainActor func listed(of run: WindowRun) -> Listed {
            var listed = run.listed(at: HostedSidebar.printed)

            switch self {
            case .noAsk:
                listed.rows = listed.rows.filter { $0.section != .needsYou }
            case .filteredPastNeedsYou:
                run.filter = Filter("licen")
                listed = run.listed(at: HostedSidebar.printed)
            case .nothingAfterNeedsYou:
                listed.rows = listed.needsYou
                listed.projects = []
            }
            return listed
        }
    }

    /// Each heading's name at 16, its count 6 after it, and its chevron in the 15 by 24 slot at 269 to 284: down while
    /// open, 10 by 6; right while folded, 6 by 10, as Projects is at first.
    @Test(arguments: [Row.needsYou, .working, .yourTurn, .projects])
    func aHeadingHasItsNameItsCountAndItsChevronInTheirPlaces(row: Row) throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true)
        let drawn = try side.drawn()
        let line = Self.inDrawing(side.rows[row.rawValue], of: side)
        let heading = CGRect(x: 0, y: line.maxY - 24, width: 296, height: 24)
        let words = try #require(drawn.drawnBox(in: CGRect(x: 0, y: heading.minY, width: 269, height: 24), ground: Self.ground(line)))
        let chevron = try #require(drawn.drawnBox(in: CGRect(x: 269, y: heading.minY, width: 17, height: 24), ground: Self.ground(line)))
        let size: CGSize = row == .projects ? CGSize(width: 6, height: 10) : CGSize(width: 10, height: 6)

        #expect((16 ... 17.5).contains(words.minX))
        #expect(chevron.minX >= 270.5 && chevron.maxX <= 282.5)
        #expect(abs(chevron.width - size.width) <= 1.5 && abs(chevron.height - size.height) <= 1.5)
        #expect(abs(chevron.midY - heading.midY) <= 0.75)
    }

    /// Working's count, "2", stands 6 after its name: the widest gap between what its words draw, letter to letter.
    @Test func aHeadingsCountStands6AfterItsName() throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true)
        let drawn = try side.drawn()
        let line = Self.inDrawing(side.rows[Row.working.rawValue], of: side)
        let ground = Self.ground(line)
        let words = try #require(
            drawn.drawnBox(in: CGRect(x: 0, y: line.maxY - 24, width: 269, height: 24), ground: ground)
        )
        let inked = stride(from: words.minX, to: words.maxX, by: 0.5).filter { x in
            drawn.drawnBox(in: CGRect(x: x, y: words.minY, width: 0.5, height: words.height), ground: ground) != nil
        }
        let gaps = zip(inked, inked.dropFirst()).map { $1 - $0 - 0.5 }

        #expect((5 ... 7.5).contains(try #require(gaps.max())))
    }

    /// A working row, two lines as Needs you's one: its arc centred at 29, its verb from 46 and what it acts on after
    /// it, its time ending at 280; its project and session 1 under, 14 tall.
    @Test(arguments: [Row.macApp, .bootstrap])
    func aWorkingRowsPartsSitAsANeedsYouRowsDo(row: Row) throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true)
        let drawn = try side.drawn()
        let line = Self.inDrawing(side.rows[row.rawValue], of: side)
        let top = line.minY + 4
        let ground = Self.ground(line)
        let mark = try #require(drawn.drawnBox(in: CGRect(x: 16, y: top, width: 26, height: 16), ground: ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 42, y: top, width: 178, height: 16), ground: ground))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 264, y: top, width: 32, height: 16), ground: ground))
        let second = try #require(drawn.drawnBox(in: CGRect(x: 42, y: top + 17, width: 200, height: 14), ground: ground))

        #expect(abs(mark.midX - 29) <= 0.5 && abs(mark.midY - (top + 8)) <= 0.5)
        #expect((46 ... 47.5).contains(words.minX))
        #expect((278.5 ... 280.5).contains(age.maxX))
        #expect((46 ... 47.5).contains(second.minX))
        #expect(drawn.drawnBox(in: CGRect(x: 42, y: top + 16, width: 238, height: 1), ground: ground) == nil)
    }

    /// Fumi's turn on one line: its ring centred at 29 and on the row's middle, its words from 46, its project at its
    /// right ending 4 before the 30 lane its time ends in, at 280.
    @Test func aYourTurnRowIsOneLineItsProjectAtItsRightBeforeItsTime() throws {
        let side = try HostedSidebar(Self.opened(), listAlone: true)
        let drawn = try side.drawn()
        let line = Self.inDrawing(side.rows[Row.licensing.rawValue], of: side)
        let ground = Self.ground(line)
        let ring = try #require(drawn.drawnBox(in: Self.band(line, x: 16 ... 42), ground: ground))
        let words = try #require(drawn.drawnBox(in: Self.band(line, x: 42 ... 180), ground: ground))
        let project = try #require(drawn.drawnBox(in: Self.band(line, x: 214 ... 250), ground: ground))
        let time = try #require(drawn.drawnBox(in: Self.band(line, x: 250 ... 296), ground: ground))

        #expect(abs(ring.midX - 29) <= 0.5 && abs(ring.midY - line.midY) <= 0.5)
        #expect(abs(ring.width - 9) <= 1)
        #expect((46 ... 47.5).contains(words.minX))
        #expect(project.maxX <= 246.5 && project.maxX >= 244)
        #expect((278.5 ... 280.5).contains(time.maxX))
    }

    /// "1 earlier", from 46 after its ring at 29, its project 9 after it, and its chevron, right, in the heading's slot.
    @Test func nEarliersPartsSitInTheirPlaces() throws {
        let run = Self.opened()
        let listed = Self.withEarlier(run)
        let side = try HostedSidebar(run, listAlone: true, listed: listed)
        let place = try #require(Sidebar(listed, folds: run.folds).lines.firstIndex { $0.id == .fold(.earlier) })
        let drawn = try side.drawn()
        let line = Self.inDrawing(side.rows[place], of: side)
        let ground = Self.ground(line)
        let ring = try #require(drawn.drawnBox(in: Self.band(line, x: 16 ... 42), ground: ground))
        let title = try #require(drawn.drawnBox(in: Self.band(line, x: 42 ... 100), ground: ground))
        let chevron = try #require(drawn.drawnBox(in: Self.band(line, x: 269 ... 286), ground: ground))

        #expect(abs(ring.midX - 29) <= 0.5)
        #expect((46 ... 47.5).contains(title.minX))
        #expect(abs(chevron.width - 6) <= 1.5 && abs(chevron.height - 10) <= 1.5)
        #expect(chevron.minX >= 270.5 && chevron.maxX <= 282.5)
    }

    /// Harness's three asks are one row, board F's: its dot centred in the 26 slot at 29, its session's name from 46
    /// with its count after it and its age ending at 280, on the row's first line; then its project, 1 under, 14; none
    /// of its asks' words.
    @Test func aNeedsYouRowIsItsSessionOnOneLineOverItsProject() throws {
        let run = Self.opened()

        _ = run.pickInList(.session("sr-macapp"), at: HostedSidebar.printed)

        let side = try HostedSidebar(run, listAlone: true)
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[Row.harness.rawValue], of: side)
        let ground = Self.ground(row)
        let top = row.minY + 4
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 16, y: top, width: 26, height: 16), ground: ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 42, y: top, width: 220, height: 16), ground: ground))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 262, y: top, width: 34, height: 16), ground: ground))
        let second = CGRect(x: 42, y: top + 17, width: 200, height: 14)
        let project = try #require(drawn.drawnBox(in: second, ground: ground))
        let alone = NSAttributedString(string: "Harness", attributes: [.font: NSFont.systemFont(ofSize: 11)]).size()

        #expect(abs(dot.midX - 29) <= 0.5 && abs(dot.midY - (top + 8)) <= 0.5)
        #expect((46 ... 47.5).contains(words.minX))
        #expect((278.5 ... 280.5).contains(age.maxX))
        #expect((46 ... 47.5).contains(project.minX) && abs(project.width - alone.width) <= 1.5)
        #expect(project.minY >= second.minY && project.maxY <= second.maxY)
        #expect(row.height == 39)
    }

    /// The pick on every row kind: the list's selection fills the whole of it, 276 wide and 10 in, as one row.
    @Test(arguments: [Pick.session("sr-4g01a7"), .session("sr-macapp"), .session("sr-k7bt2s"), .session("sr-v3t7a0"), .project("kit")])
    func thePickFillsTheWholeRowWhateverItsKind(pick: Pick) throws {
        let run = Self.opened()

        _ = run.pick(pick)

        let side = try HostedSidebar(run, listAlone: true)
        let place = try #require(run.sidebar(at: HostedSidebar.printed).lines.firstIndex { $0.pick == pick })
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[place], of: side)
        let picked = try #require(drawn.drawnBox(in: row, ground: Self.ground(row)))

        #expect(side.board.selectedRow == place)
        #expect(picked == CGRect(x: 10, y: row.minY, width: 276, height: row.height))
    }

    /// A project's page, from a project's name on a session's page: Projects unfolds, every project a row of it, the
    /// one open picked.
    @Test func projectsListsEveryProjectItsPageShowingPicked() throws {
        let run = Self.opened()

        _ = run.pick(.project("sitrep"))

        let side = try HostedSidebar(run)
        let projects = Array(run.sidebar(at: HostedSidebar.printed).lines.suffix(6))

        #expect(projects.map(\.pick) == ["harness", "switchboard", "goosemates", "sitrep", "kit", "fumi"].map(Pick.project))
        #expect(side.board.selectedRow == Row.projects.rawValue + 4)
    }

    /// Projects folded over a project's page: the list selects nothing, and the page stays.
    @Test func withProjectsFoldedOverItsPageNothingShowsPicked() throws {
        let run = Self.opened()

        _ = run.pick(.project("sitrep"))
        run.toggle(.projects)
        #expect(try HostedSidebar(run).board.selectedRow == -1)
    }

    /// The Mac app picked under Working, then its turn ends on an ask: its row, now under Needs you, is still the
    /// list's selection.
    @Test func theSelectionStaysOnASessionMovingBetweenSections() throws {
        let run = Self.opened()

        _ = run.pickInList(.session("sr-macapp"), at: HostedSidebar.printed)

        let side = try HostedSidebar(run, listAlone: true)
        let board = run.listed(at: HostedSidebar.printed)
        var asking = board

        #expect(side.board.selectedRow == Row.macApp.rawValue)
        asking.rows = board.rows.map { row in
            guard row.id == "sr-macapp" else {
                return row
            }
            return Listed.Row(
                id: row.id, name: row.name, project: row.project, section: .needsYou, mark: .needs, isAway: false,
                since: row.since, lines: row.lines
            )
        }
        asking.rows = BoardSection.allCases.flatMap { asking.rows(in: $0) }
        side.show(asking)
        #expect(side.board.selectedRow == Row.goosemates.rawValue + 1)
    }

    /// Working folded when the window last closed, and the menu opens the Mac app: Working unfolds and shows it picked.
    @Test func aPickMadeOutsideTheListShowsItsRowUnfolded() throws {
        let run = Self.opened(folds: Folds(sections: [.working]))

        _ = run.pick(.session("sr-macapp"))
        #expect(try HostedSidebar(run).board.selectedRow == Row.macApp.rawValue)
    }

    /// The window opens on Harness's asks; ↓ walks the rows in order, past the rule and Working's heading.
    @Test func theArrowKeysWalkTheRowsInOrderPastTheHeadings() throws {
        let picked = Picked()
        let side = try HostedSidebar(Self.opened(), actions: WindowActions(pickInList: { picked.picks.append($0) }))

        side.window.makeFirstResponder(side.board)
        for _ in 0 ..< 3 {
            side.window.sendEvent(try #require(Self.arrow(Self.downArrow, in: side.window)))
            side.window.contentView?.layoutSubtreeIfNeeded()
        }
        #expect(picked.picks == [.session("sr-dash02"), .session("sr-gs7kq2"), .session("sr-macapp")])
    }

    /// Working folded: ↓ from Goosemates' ask skips its rows, to Fumi's turn.
    @Test func theArrowKeysSkipAFoldedSectionsRows() throws {
        let run = Self.opened(folds: Folds(sections: [.working]))

        _ = run.pickInList(.session("sr-gs7kq2"), at: HostedSidebar.printed)

        let pressed = try Self.pressed(Self.downArrow, on: run)

        // Working's heading alone, then Your turn's: Fumi's row is the list's seventh line
        #expect(pressed.picks == [.session("sr-v3t7a0")])
        #expect(pressed.selectedRow == 6)
    }

    /// ↑ from the first project passes Projects' heading and "N earlier", to the last row of Your turn.
    @Test func theArrowKeysPassNEarlier() throws {
        let run = Self.opened(folds: Folds(projects: false))
        let listed = Self.withEarlier(run)

        _ = run.pickInList(.project("harness"), at: HostedSidebar.printed)

        let picked = Picked()
        let side = try HostedSidebar(run, actions: WindowActions(pickInList: { picked.picks.append($0) }), listed: listed)

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(Self.upArrow, in: side.window)))
        #expect(picked.picks == [.session("sr-v3t7a0")])
    }

    /// The Mac app picked, then Working folded over it: the pick stands at Working's heading.
    @Test(arguments: [(downArrow, Pick.session("sr-v3t7a0")), (upArrow, .session("sr-gs7kq2"))])
    func fromAPickAFoldHidesTheArrowKeysGoFromItsHeading(key: UInt16, to pick: Pick) throws {
        let run = Self.opened()

        _ = run.pickInList(.session("sr-macapp"), at: HostedSidebar.printed)
        run.toggle(.section(.working))
        #expect(try Self.pressed(key, on: run).picks == [pick])
    }

    /// Needs you folded over Harness's asks, the list's first line: nothing picks before it.
    @Test func fromAHiddenPickWithNoRowBeforeItUpPicksNothing() throws {
        let run = Self.opened()

        run.toggle(.section(.needsYou))

        let pressed = try Self.pressed(Self.upArrow, on: run)

        #expect(pressed.picks == [])
        #expect(pressed.selectedRow == -1)
    }

    /// With a modifier held the keys are the list's own, even from a hidden pick.
    @Test func fromAHiddenPickAnArrowWithAModifierIsTheListsOwn() throws {
        let run = Self.opened()

        _ = run.pickInList(.session("sr-macapp"), at: HostedSidebar.printed)
        run.toggle(.section(.working))
        #expect(try Self.pressed(Self.downArrow, with: .command, on: run).picks != [.session("sr-v3t7a0")])
    }

    /// Kit's away session, with no row of its own, picked from Kit's page on `watch`'s first board: Projects unfolds,
    /// and Kit's row, the last of Projects, stands in for it, filled as any row picked though the list selects none; or
    /// SitRep's, the first, the session counted SitRep's.
    @Test(arguments: ["kit", "sitrep"])
    func aSessionWithNoRowShowsPickedOnItsProjectsRow(project: String) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.session("sr-k7t001"))

        let listed = Self.rowless(run, in: project)
        let side = try HostedSidebar(run, listAlone: true, listed: listed)
        let place = try #require(Sidebar(listed, folds: run.folds).lines.firstIndex { $0.pick == .project(project) })
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[place], of: side)
        let picked = try #require(drawn.drawnBox(in: row, ground: Self.ground(row)))

        #expect(!run.folds.projects)
        #expect(side.board.selectedRow == -1)
        #expect(picked == CGRect(x: 10, y: row.minY, width: 276, height: row.height))
    }

    /// Request ledger picked, Projects open, then its row goes, nothing waiting on Lee in it any more: the list lets go
    /// of its selection, and Switchboard's row stands in for it, drawn picked.
    @Test func aPickedSessionLosingItsRowStandsAtItsProjectsRow() throws {
        let run = HostedSidebar.opened(folds: Folds(projects: false))

        _ = run.pickInList(.session("sr-rq7dgr"), at: HostedSidebar.printed)

        let side = try HostedSidebar(run, listAlone: true)
        let own = run.sidebar(at: HostedSidebar.printed).lines.firstIndex { $0.pick == .session("sr-rq7dgr") }
        var rowless = run.listed(at: HostedSidebar.printed)

        #expect(side.board.selectedRow == own)
        rowless.rows.removeAll { $0.id == "sr-rq7dgr" }
        rowless.rowless["sr-rq7dgr"] = "switchboard"
        side.show(rowless, folds: run.folds)

        let lines = Sidebar(rowless, folds: run.folds).lines
        let place = try #require(lines.firstIndex { $0.pick == .project("switchboard") })
        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[place], of: side)
        let picked = try #require(drawn.drawnBox(in: row, ground: Self.ground(row)))

        #expect(side.board.selectedRow == -1)
        #expect(picked == CGRect(x: 10, y: row.minY, width: 276, height: row.height))
    }

    /// SitRep's selection on the stand-in, as the system's on a row: its grey until the list has the key window's
    /// focus, then the accent, Kit's name white on it.
    @Test(arguments: [(false, true), (true, false), (true, true)])
    func aStandInsSelectionIsTheSystemsGreyUntilTheListHasTheKeyWindowsFocus(
        isKey: Bool, isFocused: Bool
    ) async throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.session("sr-k7t001"))

        let side = try HostedSidebar(run, listAlone: true, isKey: isKey)
        let isEmphasized = isKey && isFocused
        let place = try #require(run.sidebar(at: HostedSidebar.printed).lines.firstIndex { $0.pick == .project("kit") })

        side.window.makeFirstResponder(isFocused ? side.board : nil)
        await Task.yield()

        let drawn = try side.drawn()
        let row = Self.inDrawing(side.rows[place], of: side)
        let fill = try #require(drawn.stored(at: CGPoint(x: 270, y: row.midY)))
        let name = try drawn.brightest(in: CGRect(x: 40, y: row.minY + 6, width: 30, height: 16))
        let system: NSColor = isEmphasized
            ? .selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor

        #expect(fill.isAlike(system.dark(in: drawn.bitmap.colorSpace)))
        #expect(name.isWhite == isEmphasized)
    }

    /// A click on Kit's row standing in for Kit's away session, which the list holds no selection on: it selects the
    /// row, and Kit's page opens.
    @Test func aClickOnTheRowStandingInForASessionPicksItsProject() throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.session("sr-k7t001"))

        let picked = Picked()
        let side = try HostedSidebar(run, actions: WindowActions(pickInList: { picked.picks.append($0) }))
        let place = try #require(run.sidebar(at: HostedSidebar.printed).lines.firstIndex { $0.pick == .project("kit") })

        #expect(side.board.selectedRow == -1)
        // as the list's own click selects a row
        side.board.selectRowIndexes(IndexSet(integer: place), byExtendingSelection: false)
        side.window.contentView?.layoutSubtreeIfNeeded()
        #expect(picked.picks == [.project("kit")])
        #expect(side.board.selectedRow == place)
    }

    /// Kit's away session picked, standing at its project's row: ↑ and ↓ go from that row, at either end of Projects.
    @Test(arguments: [
        ("kit", upArrow, [Pick.project("goosemates")]), ("kit", downArrow, []),
        ("sitrep", upArrow, [.session("sr-rq7dgr")]), ("sitrep", downArrow, [.project("switchboard")]),
    ])
    func fromASessionWithNoRowTheArrowKeysGoFromItsProjectsRow(project: String, key: UInt16, to picks: [Pick]) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.session("sr-k7t001"))
        #expect(try Self.pressed(key, on: run, listed: Self.rowless(run, in: project)).picks == picks)
    }

    /// Projects folded over Kit's away session: it stands at Projects' heading, the list's last line.
    @Test(arguments: [(upArrow, [Pick.session("sr-rq7dgr")]), (downArrow, [])])
    func fromASessionWithNoRowUnderProjectsFoldedTheArrowKeysGoFromItsHeading(key: UInt16, to picks: [Pick]) throws {
        let run = HostedSidebar.opened()

        _ = run.pick(.session("sr-k7t001"))
        run.toggle(.projects)

        let pressed = try Self.pressed(key, on: run)

        #expect(pressed.picks == picks)
        #expect(pressed.selectedRow == -1)
    }

    /// The run's board with Kit's away session, which has no row of its own, counted this project's.
    private static func rowless(_ run: WindowRun, in project: String) -> Listed {
        var listed = run.listed(at: HostedSidebar.printed)

        listed.rowless["sr-k7t001"] = project
        return listed
    }

    /// The run's board with a your-turn session of Kit's past the fold period, under "N earlier", typed small.
    private static func withEarlier(_ run: WindowRun) -> Listed {
        var listed = run.listed(at: HostedSidebar.printed)
        let since = HostedSidebar.printed.addingTimeInterval(-3 * 3600)
        let line = Listed.Line(id: "turn:sr-old", lead: "Left the bootstrap's notes", code: nil, more: nil, since: since)

        listed.rows.append(Listed.Row(
            id: "sr-old", name: "Old notes", project: "Kit", section: .yourTurn, mark: .turn, isAway: false, since: since,
            lines: [line], isEarlier: true
        ))
        return listed
    }

    /// What the list asked to pick as this key was pressed once on it, focus on it, and the row it then selects; over
    /// `listed`, where given, in place of the run's board.
    private static func pressed(
        _ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], on run: WindowRun, listed: Listed? = nil
    ) throws -> (picks: [Pick], selectedRow: Int) {
        let picked = Picked()
        let side = try HostedSidebar(run, actions: WindowActions(pickInList: { picked.picks.append($0) }), listed: listed)

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(key, with: modifiers, in: side.window)))
        side.window.contentView?.layoutSubtreeIfNeeded()
        return (picked.picks, side.board.selectedRow)
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
    var picks: [Pick] = []
}
