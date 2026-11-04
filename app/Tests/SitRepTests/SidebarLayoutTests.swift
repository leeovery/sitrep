import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar and the list beside the page as the window lays them out, against Paper's A1 revised: the Filter field
/// alone over the sidebar's list, the four places and the projects, each row's height; the list's rows, a line's, a
/// working row's, a your-turn row's and a fold's; each list's selection on the row it belongs to; and the keys. Every
/// x is from the column's left and every y from the window's top.
@MainActor
struct SidebarLayoutTests {
    nonisolated private static let downArrow: UInt16 = 125
    nonisolated private static let upArrow: UInt16 = 126

    // MARK: The sidebar

    @Test func theAccessoryIsTheFilterFieldAlone47TallTheListUnderIt() throws {
        let side = try HostedSidebar(HostedSidebar.opened())

        #expect(side.frame(of: try #require(side.field)) == CGRect(x: 10, y: 75, width: 216, height: WindowStyle.fieldHeight))
        #expect(WindowStyle.fieldHeight == 28)
        #expect(side.rows.first?.minY == 113)
    }

    /// With no foot under it, the list runs to the glass's foot, whatever bottom safe area a window on screen gives the
    /// sidebar: in a window too short for the board, scrolled to its end, its last row 12 over the glass's foot.
    @Test(arguments: [0, 10, 27.5])
    func theListRunsToTheGlasssFootItsLastRow12OverIt(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(HostedSidebar.opened(), height: 300, bottomSafeArea: bottomSafeArea)
        let scroll = try #require(side.board.enclosingScrollView)
        let clip = scroll.contentView

        try #require(side.board.frame.height > clip.bounds.height)
        clip.scroll(to: NSPoint(x: 0, y: side.board.frame.height - clip.bounds.height + scroll.contentInsets.bottom))
        scroll.reflectScrolledClipView(clip)

        let last = try #require(side.rows.last)

        #expect(side.frame(of: scroll).maxY == side.glassBottom)
        #expect(side.glassBottom - last.maxY == WindowStyle.listBottom)
        #expect(WindowStyle.listBottom == 12)
    }

    /// The four places, 32 each; Projects' heading 16 under them, 24 tall; then each project, 32; one under another.
    @Test func thePlacesThenTheProjectsEachAsTallAsDrawn() throws {
        let side = try HostedSidebar(HostedSidebar.opened())

        #expect(side.rows.map(\.height) == [32, 32, 32, 32, 40, 32, 32, 32, 32])
        #expect(zip(side.rows, side.rows.dropFirst()).allSatisfy { $0.maxY == $1.minY })
        #expect(side.rows.allSatisfy { $0.minY == $0.minY.rounded() })
    }

    /// The sidebar's selection is where the window is: Needs you's row, a project's, and the project still while a
    /// session pushed from it shows; never Projects' heading.
    @Test func theSidebarsSelectionIsWhereTheWindowIs() throws {
        let run = HostedSidebar.opened()

        #expect(try HostedSidebar(run).board.selectedRow == 0)
        run.click(.project("switchboard"))
        #expect(try HostedSidebar(run).board.selectedRow == 6)
        run.go(to: .session("sr-rq7dgr", from: .project("switchboard")), by: .projectSession)
        #expect(try HostedSidebar(run).board.selectedRow == 6)
    }

    /// A row selected, as the list's own click selects it, goes there; the heading is never selected.
    @Test func aRowClickedGoesThere() throws {
        let clicked = Clicked()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: WindowActions(click: { clicked.roots.append($0) }))

        side.board.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        side.window.contentView?.layoutSubtreeIfNeeded()
        #expect(clicked.roots == [.place(.yourTurn)])
    }

    /// ↓ in the sidebar is the list's own, each row it selects a place or a project gone to.
    @Test func theArrowKeysWalkTheSidebarGoingToEachRow() throws {
        let clicked = Clicked()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: WindowActions(click: { clicked.roots.append($0) }))

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(Self.downArrow, in: side.window)))
        side.window.contentView?.layoutSubtreeIfNeeded()
        #expect(clicked.roots == [.place(.yourTurn)])
    }

    // MARK: The list

    /// Needs you's lines, 54 each, one under another, then its fold, 28, where asks sleep.
    @Test func aLinesRowIs54AndAFold28() throws {
        let run = HostedSidebar.opened(Lines.snoozed[0])
        let side = try HostedSidebar(run, column: .list)

        #expect(side.rows.map(\.height) == [54, 28])
        #expect(zip(side.rows, side.rows.dropFirst()).allSatisfy { $0.maxY == $1.minY })
    }

    /// Working's rows the system's two-line row, 39, as in the sidebar before them; Your turn's one line, 28.
    @Test(arguments: [(Place.working, CGFloat(39)), (.yourTurn, 28)])
    func workingAndYourTurnRowsAreAsTallAsBefore(place: Place, height: CGFloat) throws {
        let run = HostedSidebar.opened(Lines.bySession[0])

        run.click(.place(place))

        let side = try HostedSidebar(run, column: .list)

        #expect(!side.rows.isEmpty)
        #expect(side.rows.allSatisfy { $0.height == height })
    }

    /// The list's selection is the pick's row, the Mac app's newest line second; its line answered, nothing shows
    /// picked.
    @Test func theListsSelectionIsThePicksRowAndNoneOnceItLeavesTheList() throws {
        let run = HostedSidebar.opened()

        run.land("sr-macapp")
        #expect(try HostedSidebar(run, column: .list).board.selectedRow == 1)
        run.show(HostedSidebar.heard(Self.answered("sr-macapp")), at: HostedSidebar.printed, reducesMotion: false)
        #expect(try HostedSidebar(run, column: .list).board.selectedRow == -1)
    }

    /// A row selected, as the list's own click selects it, is picked.
    @Test func aRowClickedIsPicked() throws {
        let asked = Asked()
        let side = try HostedSidebar(HostedSidebar.opened(), column: .list, actions: asked.actions)

        side.board.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        side.window.contentView?.layoutSubtreeIfNeeded()
        #expect(asked.picks == [.line("ask:sr-dash02:k1")])
    }

    /// ↓ and ↑, bare, are the run's steps, which the list does not take as its own: its selection stays for the run
    /// to move.
    @Test(arguments: [(downArrow, true), (upArrow, false)])
    func theArrowKeysInTheListAreTheRunsSteps(key: UInt16, down: Bool) throws {
        let asked = Asked()
        let side = try HostedSidebar(HostedSidebar.opened(), column: .list, actions: asked.actions)

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(key, in: side.window)))
        side.window.contentView?.layoutSubtreeIfNeeded()
        #expect(asked.steps == [down])
        #expect(asked.picks.isEmpty)
        #expect(side.board.selectedRow == 0)
    }

    /// With a modifier held the keys are the list's own.
    @Test func anArrowWithAModifierIsTheListsOwn() throws {
        let asked = Asked()
        let side = try HostedSidebar(HostedSidebar.opened(), column: .list, actions: asked.actions)

        side.window.makeFirstResponder(side.board)
        side.window.sendEvent(try #require(Self.arrow(Self.downArrow, with: .command, in: side.window)))
        #expect(asked.steps.isEmpty)
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

    /// `watch`'s first line with nothing waiting on Lee in this session any more, its turn come.
    private static func answered(_ session: String) -> String {
        var board = try! JSONSerialization.jsonObject(with: Data(Lines.watch[0].utf8)) as! [String: Any]

        board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["session"] as? String != session }
        return String(decoding: try! JSONSerialization.data(withJSONObject: board), as: UTF8.self)
    }
}

extension HostedSidebar {
    /// What a run of `watch` said, one line.
    static func heard(_ line: String) -> LastBoard {
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(line), at: printed)
        return last
    }
}

/// Where the sidebar asked the window to go.
@MainActor
private final class Clicked {
    var roots: [Root] = []
}

/// What the list asked the window for: a row picked, or a step.
@MainActor
private final class Asked {
    var picks: [ListPick] = []
    var steps: [Bool] = []

    var actions: WindowActions {
        WindowActions(
            pickInList: { [unowned self] in picks.append($0) }, step: { [unowned self] in steps.append($0) }
        )
    }
}
