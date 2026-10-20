@testable import SitRepCore
import SitRepMenu
import SitRepPanel
import Testing

struct MenuEntriesTests {
    private static func entries(_ rows: [String] = Watched.rows, windows: [String] = [], show: EdgeSettings.Show = .notch) -> [MenuEntry] {
        MenuBoard(heard([.line(Watched.line(rows: rows, windows: windows))]), clock: london).entries(showing: show)
    }

    @Test func theMenuRunsFromTheHeaderThroughTheSessionsToQuit() {
        #expect(Self.entries().map(\.key) == [
            "header", "separator:header",
            "heading:sessions", "row:ask:sr-ledger:k1", "row:stop:sr-dash:w1:1792445500000", "row:ask:sr-plan:k2",
            "separator:hairline", "row:turn:sr-boot", "row:work:sr-diff", "separator:sessions",
            "openWindow", "separator:window",
            "heading:show", "show:notch", "show:strip", "show:nothing", "separator:show",
            "settings", "separator:settings", "quit",
        ])
    }

    @Test func itSpeaksUpFirstUnderTheHeader() {
        let window = Watched.window("w1", session: "sr-boot", name: "The bootstrap", project: "Kit", version: nil, needsReload: true)
        let last = heard([.line(Watched.line(windows: [window])), .exited(.status(1), stderr: "")])
        let keys = MenuBoard(last, clock: london).entries(showing: .notch).map(\.key)

        #expect(Array(keys.prefix(7)) == [
            "header", "separator:header", "heading:reloads", "reload:w1", "separator:reloads", "unread", "separator:unread",
        ])
    }

    @Test func showTicksTheOneInUse() {
        #expect(Self.entries(show: .strip).filter { $0.key.hasPrefix("show:") } == [
            .show(.notch, isTicked: false), .show(.strip, isTicked: true), .show(.nothing, isTicked: false),
        ])
    }

    @Test func theSameMenuChangesNothing() {
        #expect(MenuChanges(from: Self.entries(), to: Self.entries()).isEmpty)
    }

    @Test func aRowWhoseWordsChangedIsSetAgainInPlaceAndNothingElseMoves() {
        var rows = Watched.rows

        rows[3] = Watched.row("turn:sr-boot", "yourTurn", session: "sr-boot", project: "kit", lead: "Write round 5", second: "Kit · The bootstrap", since: 1_792_445_400_000)

        let new = Self.entries(rows)
        let changes = MenuChanges(from: Self.entries(), to: new)

        #expect(changes.removals.isEmpty)
        #expect(changes.insertions.isEmpty)
        #expect(changes.changes == [MenuChanges.Placed(7, new[7])])
    }

    @Test func aRowComeIsPutInAtItsPlaceAlone() {
        var rows = Watched.rows

        rows.insert(Watched.row("turn:sr-new", "yourTurn", session: "sr-new", project: "kit", lead: "New", second: "Kit · New", since: 1_792_445_400_000), at: 4)

        let new = Self.entries(rows)
        let changes = MenuChanges(from: Self.entries(), to: new)

        #expect(changes.removals.isEmpty)
        #expect(changes.insertions == [MenuChanges.Placed(8, new[8])])
        #expect(changes.changes.isEmpty)
    }

    @Test func aRowGoneIsTakenOutAlone() {
        var rows = Watched.rows

        rows.remove(at: 1)

        let changes = MenuChanges(from: Self.entries(), to: Self.entries(rows))

        #expect(changes.removals == [4])
        #expect(changes.insertions.isEmpty)
        #expect(changes.changes.isEmpty)
    }

    @Test func removalsComeLastFirstAndInsertionsFirstFirst() {
        let changes = MenuChanges(from: Self.entries(), to: Self.entries([Watched.rows[3]]))

        #expect(changes.removals == changes.removals.sorted(by: >))
        #expect(changes.removals.count == 5)
    }

    @Test func showChangedSetsItsTwoTicksAgainInPlace() {
        let new = Self.entries(show: .strip)
        let changes = MenuChanges(from: Self.entries(), to: new)

        #expect(changes.changes.map(\.offset) == [13, 14])
        #expect(changes.insertions.isEmpty && changes.removals.isEmpty)
    }

    @Test func anOpenMenusTimesTickAtTheNextMinuteOfAnyRowShowing() {
        let board = MenuBoard(heard([.line(Watched.line())]), clock: london)

        // the permission prompt, shown 50 seconds before, is the first to read a minute
        #expect(board.nextTick(after: 1_792_445_550_000) == 1_792_445_560_000)
        #expect(MenuBoard(LastBoard()).nextTick(after: 0) == nil)
    }

    @Test func aRowsLineSetsItsSubjectApartAndAWorkingRowsFainter() {
        let rows = MenuBoard(heard([.line(Watched.line())]), clock: london).items.compactMap(\.session)
        let question = Session(id: "q", project: "Goosemates", kind: .needs, title: "Which edge?", more: "+2", sub: "", since: 0)

        #expect(rows[1].menuLine == MenuTitle(words: "Allow Bash: ", mono: "gh pr create", more: nil, isFaint: false))
        #expect(rows[4].menuLine == MenuTitle(words: "Reading ", mono: "StatusMenu.swift", more: nil, isFaint: true))
        #expect(question.menuLine == MenuTitle(words: "Which edge?", mono: nil, more: " +2", isFaint: false))
    }
}
