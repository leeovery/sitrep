@testable import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

struct MenuEntriesTests {
    private static func entries(
        _ rows: [WatchLine.Row] = Watched.rows, needYou: Int? = nil, windows: [WatchLine.Window] = [],
        show: EdgeSettings.Show = .notch
    ) -> [MenuEntry] {
        MenuBoard(heard([.line(Watched.line(needYou: needYou, rows: rows, windows: windows))]), clock: london)
            .entries(showing: show)
    }

    @Test func theMenuRunsFromTheHeaderThroughTheSessionsToQuit() {
        #expect(Self.entries().map(\.key) == [
            "header", "separator:header",
            "heading:sessions", "row:sr-l5c9tz", "row:sr-dash", "row:sr-plan",
            "row:sr-boot", "separator:hairline", "row:sr-diff", "separator:sessions",
            "heading:show", "show:notch", "show:strip", "show:nothing", "separator:show", "welcome",
            "settings", "separator:settings", "quit",
        ])
    }

    /// What the welcome's command does, said: it opens a window and asks nothing, so it has no ellipsis.
    @Test func theWelcomesCommandSaysItShowsTheWelcomeWindow() {
        #expect(MenuBoard.welcomeTitle == "Show Welcome Window")
    }

    @Test func itSpeaksUpFirstUnderTheHeader() {
        let window = WatchLine.Window(writer: "w1", session: "sr-boot", name: "The bootstrap", project: "Litware", version: nil, needsReload: true)
        let last = heard([.line(Watched.line(windows: [window])), .exited(.status(1), stderr: "")])
        let keys = MenuBoard(last, clock: london).entries(showing: .notch).map(\.key)

        #expect(Array(keys.prefix(7)) == [
            "header", "separator:header", "heading:reloads", "reload:w1", "separator:reloads", "unread", "separator:unread",
        ])
    }

    @Test func troubleWithThePluginSpeaksUpFirstOfAll() {
        let window = WatchLine.Window(writer: "w1", session: "sr-boot", name: "The bootstrap", project: "Litware", version: nil, needsReload: true)
        let last = heard([.line(Watched.line(windows: [window])), .exited(.status(1), stderr: "")])
        let entries = MenuBoard(last, trouble: .noClaude, clock: london).entries(showing: .notch)

        #expect(Array(entries.map(\.key).prefix(5)) == ["header", "separator:header", "trouble", "separator:trouble", "heading:reloads"])
        #expect(entries[2] == .trouble(.noClaude))
    }

    @Test func withNoPluginToRunTheTroubleIsAllItSpeaksUpWith() {
        let keys = MenuBoard(unrun: .noClaude).entries(showing: .notch).map(\.key)

        #expect(Array(keys.prefix(5)) == ["header", "separator:header", "trouble", "separator:trouble", "heading:show"])
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

        rows[3].lines = [.init("turn:sr-boot", .yourTurn, first: "Write round 5", since: 1_792_445_400_000)]

        let new = Self.entries(rows)
        let changes = MenuChanges(from: Self.entries(), to: new)

        #expect(changes.removals.isEmpty)
        #expect(changes.insertions.isEmpty)
        #expect(changes.changes == [MenuChanges.Placed(6, new[6])])
    }

    /// A session come to Lee's turn is put in at its place, and the count over it, which holds it, set again.
    @Test func aRowComeIsPutInAtItsPlaceAndCounted() {
        var rows = Watched.rows
        let turn = WatchLine.Row(
            session: "sr-new", name: "New", projectName: "Litware",
            lines: [.init("turn:sr-new", .yourTurn, first: "New", since: 1_792_445_400_000)]
        )

        rows.insert(turn, at: 4)

        let new = Self.entries(rows)
        let changes = MenuChanges(from: Self.entries(), to: new)

        #expect(changes.removals.isEmpty)
        #expect(changes.insertions == [MenuChanges.Placed(7, new[7])])
        #expect(changes.changes == [MenuChanges.Placed(2, new[2])])
        #expect(new[2] == .heading("sessions", title: "5 need you"))
    }

    @Test func aRowGoneIsTakenOutAlone() {
        var rows = Watched.rows

        rows.remove(at: 1)

        let changes = MenuChanges(from: Self.entries(), to: Self.entries(rows, needYou: 3))

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

        #expect(changes.changes.map(\.offset) == [11, 12])
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
        var tailspin = Session(
            id: "h", project: "Tailspin", name: "Migration", kind: .needs, title: "Allow Bash ", code: "gh pr create",
            more: "+2", sub: "", since: 0
        )

        tailspin.lines.append(Session.Line(title: "Approve the batch", since: 1))
        #expect(rows[1].menuLine(at: 0) == MenuTitle(words: "Dashboard memory", mono: nil, more: nil, isFaint: false))
        #expect(rows[4].menuLine(at: 0) == MenuTitle(words: "Reading ", mono: "StatusMenu.swift", more: nil, isFaint: true))
        #expect(tailspin.menuLine(at: 0) == MenuTitle(words: "Migration", mono: nil, more: " 2", isFaint: false))
    }
}
