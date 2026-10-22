@testable import SitRepCore
import SitRepMenu
import SitRepPanel
import Testing

struct MenuBoardTests {
    private static func menu(_ last: LastBoard) -> MenuBoard {
        MenuBoard(last, clock: london)
    }

    private static let board = menu(heard([.line(Watched.line())]))

    @Test func itListsThePanelsSessionsInCoresOrderWithTheHairlineUnderTheNeedsYou() {
        #expect(Self.board.items.map(\.key) == [
            "ask:sr-ledger:k1", "stop:sr-dash:w1:1792445500000", "ask:sr-plan:k2", "divider", "turn:sr-boot",
            "work:sr-diff",
        ])
    }

    @Test func eachRowCarriesThePanelsMark() {
        let sessions = Self.board.items.compactMap(\.session)

        #expect(sessions.map(\.kind) == [.needs, .needs, .needs, .turn, .working])
        #expect(sessions.map(\.away) == [false, false, true, false, false])
    }

    @Test func aRowsTitleIsItsFirstLineItsSubjectAndAQuestionsMoreInOne() {
        let question = Session(id: "q", project: "Goosemates", kind: .needs, title: "Which edge?", more: "+2", sub: "", since: 0)
        let titles = Self.board.items.compactMap(\.session).map { $0.menuTitle(at: 0) }

        #expect(titles[0] == "Choose how long the ledger keeps requests")
        #expect(titles[1] == "Allow Bash: gh pr create")
        #expect(titles[4] == "Reading StatusMenu.swift")
        #expect(question.menuTitle(at: 0) == "Which edge? +2")
    }

    @Test func aClickJumpsToTheRowsSessionButAnAwayRowJumpsNowhere() {
        let sessions = Self.board.items.compactMap(\.session)

        #expect(sessions.map(Self.board.jump) == ["sr-ledger", "sr-dash", nil, "sr-boot", "sr-diff"])
    }

    @Test func theHeadingIsThePanelHeadsWords() {
        #expect(Self.board.heading == "3 need you")
        #expect(Self.menu(heard([.line(Watched.line(needYou: 0, rows: [Watched.rows[3]]))])).heading == "All clear")
    }

    @Test func beforeAnyBoardItSaysItIsLooking() {
        let menu = Self.menu(LastBoard())

        #expect(menu.heading == "Looking for sessions…")
        #expect(menu.items.isEmpty)
        #expect(menu.unread == nil)
    }

    @Test func pastTwelveRowsItListsTwelveAndSaysHowManyMore() {
        let rows = (0 ..< 16).map {
            Watched.row("turn:s\($0)", "yourTurn", session: "s\($0)", project: "kit", lead: "Turn \($0)", second: "Kit · \($0)", since: 1_792_445_000_000)
        }
        let menu = Self.menu(heard([.line(Watched.line(needYou: 0, rows: rows))]))

        #expect(menu.items.count == 12)
        #expect(menu.more == 4)
        #expect(menu.moreTitle == "4 more…")
    }

    @Test func twelveRowsOrFewerSayNoMore() {
        let rows = (0 ..< 12).map {
            Watched.row("turn:s\($0)", "yourTurn", session: "s\($0)", project: "kit", lead: "Turn \($0)", second: "Kit · \($0)", since: 1_792_445_000_000)
        }
        let menu = Self.menu(heard([.line(Watched.line(needYou: 0, rows: rows))]))

        #expect(menu.items.count == 12)
        #expect(menu.moreTitle == nil)
    }

    @Test func itSpeaksUpWithEachWindowThatNeedsReloadPluginsAJumpToItsSession() {
        let windows = [
            Watched.window("w1", session: "sr-boot", name: "The bootstrap", project: "Kit", version: "0.1.0", needsReload: true),
            Watched.window("w2", session: "sr-diff", name: "Token-aware diff sizing", project: "Mint", version: "0.2.0", needsReload: false),
            Watched.window("w3", session: "sr-dash", name: "Dashboard memory", project: "Switchboard", version: nil, needsReload: true),
        ]
        let menu = Self.menu(heard([.line(Watched.line(windows: windows))]))

        #expect(menu.reloads.map(\.label) == ["Kit · The bootstrap", "Switchboard · Dashboard memory"])
        #expect(menu.reloads.map(\.session) == ["sr-boot", "sr-dash"])
    }

    @Test func withEveryWindowCurrentTheReloadHeadingGoes() {
        let windows = [Watched.window("w2", session: "sr-diff", name: "Diff", project: "Mint", version: "0.2.0", needsReload: false)]

        #expect(Self.menu(heard([.line(Watched.line(windows: windows))])).reloads.isEmpty)
    }

    @Test func whenWatchStopsItSaysWhyAndKeepsTheLastBoardSayingWhenItWasCurrent() {
        let menu = Self.menu(heard([.line(Watched.line()), .exited(.status(1), stderr: "sitrep: The state folder can't be read.\n")]))

        #expect(menu.unread == "The state folder can't be read.")
        #expect(menu.heading == "3 need you · as of 12:01")
        #expect(menu.items.count == 6)
    }

    @Test func watchStoppingBeforeAnyBoardSpeaksUpWithNoSessions() {
        let menu = Self.menu(heard([.unstartable("no such file")]))

        #expect(menu.unread == "sitrep watch could not start: no such file.")
        #expect(menu.heading == nil)
        #expect(menu.items.isEmpty)
    }

    @Test func withNoPluginToRunItSpeaksUpWithTheTroubleAlone() {
        let menu = MenuBoard(unrun: .noClaude)

        #expect(menu.trouble == .noClaude)
        #expect(menu.unread == nil)
        #expect(menu.heading == nil)
        #expect(menu.glyph == .rest)
    }

    @Test func overItsOwnCopysBoardTheTroubleStaysWithTheSessions() {
        let menu = MenuBoard(heard([.line(Watched.line())]), trouble: .noClaude, clock: london)

        #expect(menu.trouble == .noClaude)
        #expect(menu.heading == Self.board.heading)
        #expect(menu.items == Self.board.items)
    }

    @Test func theGlyphLightsWhileAnythingNeedsLee() {
        #expect(Self.board.glyph == .lit)
        #expect(Self.menu(heard([.line(Watched.line(needYou: 0, rows: [Watched.rows[3]]))])).glyph == .rest)
        #expect(Self.menu(LastBoard()).glyph == .rest)
    }

    @Test func theGlyphKeepsTheLastBoardsWordWhileItIsStale() {
        let menu = Self.menu(heard([.line(Watched.line()), .exited(.status(1), stderr: "")]))

        #expect(menu.glyph == .lit)
    }
}
