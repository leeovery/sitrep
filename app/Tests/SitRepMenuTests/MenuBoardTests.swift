@testable import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

struct MenuBoardTests {
    private static func menu(_ last: LastBoard) -> MenuBoard {
        MenuBoard(last, clock: london)
    }

    private static let board = menu(heard([.line(Watched.line())]))

    /// Needs you's asks, then its turn, the hairline under them, as the panel has them.
    @Test func itListsThePanelsSessionsInThePanelsOrderWithTheHairlineUnderNeedsYou() {
        #expect(Self.board.items.map(\.key) == [
            "needs:sr-l5c9tz", "needs:sr-dash", "needs:sr-plan", "turn:sr-boot", "divider", "sr-diff",
        ])
    }

    @Test func eachRowCarriesThePanelsMark() {
        let sessions = Self.board.items.compactMap(\.session)

        #expect(sessions.map(\.kind) == [.needs, .needs, .needs, .turn, .working])
        #expect(sessions.map(\.away) == [false, false, true, false, false])
    }

    /// A session a window holds that this Mac does not show is drawn as an away one is, whatever its state, and in
    /// Needs you leads the away ones of its kind; the menu changes with it.
    @Test func aHeldSessionNotHereIsDrawnAwayAmongTheAwayOnes() {
        let last = heard([.line(Watched.line())])
        let notHere = MenuBoard(last, notHere: ["sr-l5c9tz", "sr-boot", "sr-diff"], clock: london)
        let sessions = notHere.items.compactMap(\.session)
        let dash = MenuBoard(last, notHere: ["sr-dash"], clock: london)

        #expect(sessions.map(\.id) == ["sr-dash", "sr-l5c9tz", "sr-plan", "sr-boot", "sr-diff"])
        #expect(sessions.map(\.kind) == [.needs, .needs, .needs, .turn, .working])
        #expect(sessions.map(\.away) == [false, true, true, true, true])
        #expect(notHere != Self.board)
        #expect(dash.items.compactMap(\.session).map(\.id) == ["sr-l5c9tz", "sr-dash", "sr-plan", "sr-boot", "sr-diff"])
    }

    /// A row needing Lee is titled by its session's name, away or not, a question's own "+2" nowhere; any other by its
    /// line, its subject in one with it.
    @Test func aRowsTitleIsItsSessionsNameOrElseItsLineAndItsSubjectInOne() {
        let question = Session(
            id: "q", project: "Lucerne", name: "Onboarding", kind: .needs, title: "Which page?", more: "+2", sub: "",
            since: 0
        )
        let titles = Self.board.items.compactMap(\.session).map { $0.menuTitle(at: 0) }

        #expect(titles[0] == "Usage")
        #expect(titles[1] == "Report caching")
        #expect(titles[2] == "Plan the launch")
        #expect(titles[4] == "Reading StatusMenu.swift")
        #expect(question.menuTitle(at: 0) == "Onboarding")
    }

    /// A session with several lines waiting is one item, as on the panel: its name, then "3" for its three lines
    /// waiting, in place of a question's own count.
    @Test func aSessionWithSeveralLinesIsOneItemItsNameThenHowManyWait() {
        let ledger = WatchLine.Row(
            session: "sr-l5c9tz", name: "Usage", projectName: "Woodgrove",
            lines: [
                .init(
                    "ask:sr-l5c9tz:k1", .ask, first: .init(lead: "Choose how long it keeps", more: "+4"),
                    since: 1_792_445_000_000
                ),
                .init("ask:sr-l5c9tz:k2", .ask, first: "Approve the schema", since: 1_792_444_900_000),
                .init("ask:sr-l5c9tz:k3", .ask, first: "Paste the log", since: 1_792_444_800_000),
            ]
        )
        let menu = Self.menu(heard([.line(Watched.line(rows: [ledger] + Watched.rows.dropFirst()))]))
        let sessions = menu.items.compactMap(\.session)

        #expect(sessions.filter { $0.id == "sr-l5c9tz" }.count == 1)
        #expect(sessions.first?.menuTitle(at: 0) == "Usage 3")
        #expect(sessions.first?.ageText(at: 1_792_445_000_000 + 60 * 60_000) == "1h")
    }

    /// Three asks and stops and one session at Lee's turn: "4 need you".
    @Test func theHeadingIsThePanelHeadsWords() {
        #expect(Self.board.heading == "4 need you")
        #expect(Self.menu(heard([.line(Watched.line(rows: [Watched.rows[4]]))])).heading == "All clear")
    }

    @Test func beforeAnyBoardItSaysItIsLooking() {
        let menu = Self.menu(LastBoard())

        #expect(menu.heading == "Looking for sessions…")
        #expect(menu.items.isEmpty)
        #expect(menu.unread == nil)
    }

    @Test func itListsEverySessionHoweverMany() {
        let rows = (0 ..< 16).map {
            WatchLine.Row(
                session: "s\($0)", name: "\($0)", projectName: "Litware",
                lines: [.init("turn:s\($0)", .yourTurn, first: "Turn \($0)", since: 1_792_445_000_000)]
            )
        }
        let menu = Self.menu(heard([.line(Watched.line(rows: rows))]))

        #expect(menu.items.compactMap(\.session?.id) == (0 ..< 16).map { "s\($0)" })
    }

    @Test func itSpeaksUpWithEachWindowThatNeedsReloadPluginsAJumpToItsSession() {
        let windows = [
            WatchLine.Window(writer: "w1", session: "sr-boot", name: "The installer", project: "Litware", version: "0.1.0", needsReload: true),
            WatchLine.Window(writer: "w2", session: "sr-diff", name: "Smaller diff batches", project: "Relecloud", version: "0.2.0", needsReload: false),
            WatchLine.Window(writer: "w3", session: "sr-dash", name: "Report caching", project: "Woodgrove", version: nil, needsReload: true),
        ]
        let menu = Self.menu(heard([.line(Watched.line(windows: windows))]))

        #expect(menu.reloads.map(\.label) == ["Litware · The installer", "Woodgrove · Report caching"])
        #expect(menu.reloads.map(\.session) == ["sr-boot", "sr-dash"])
    }

    @Test func withEveryWindowCurrentTheReloadHeadingGoes() {
        let windows = [WatchLine.Window(writer: "w2", session: "sr-diff", name: "Diff", project: "Relecloud", version: "0.2.0", needsReload: false)]

        #expect(Self.menu(heard([.line(Watched.line(windows: windows))])).reloads.isEmpty)
    }

    @Test func whenWatchStopsItSaysWhyAndKeepsTheLastBoardSayingWhenItWasCurrent() {
        let menu = Self.menu(heard([.line(Watched.line()), .exited(.status(1), stderr: "sitrep: The state folder can't be read.\n")]))

        #expect(menu.unread == "The state folder can't be read.")
        #expect(menu.heading == "4 need you · as of 12:01")
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
        #expect(Self.menu(heard([.line(Watched.line(rows: [Watched.rows[3]]))])).glyph == .turn)
        #expect(Self.menu(heard([.line(Watched.line(rows: [Watched.rows[4]]))])).glyph == .rest)
        #expect(Self.menu(LastBoard()).glyph == .rest)
    }

    @Test func theGlyphKeepsTheLastBoardsWordWhileItIsStale() {
        let menu = Self.menu(heard([.line(Watched.line()), .exited(.status(1), stderr: "")]))

        #expect(menu.glyph == .lit)
    }
}
