import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel, drawn by the real run into the real surface at the README desktop's left edge,
/// to read beside Paper's boards E2, F, H3 and A2: the pointer on a Needs you row's words, then on its arrow; the asks
/// panel on a session's choice, and on a words ask; and an answer sending, its countdown under way; a choice whose
/// pick wraps to two lines, the pointer off it and on it; and a choice mid-swipe, the yes beside it sliding in. At the
/// right edge, the pointer on a row's arrow at its left end, and the asks panel open from it. While the panel holds the
/// keys: the choice and the two-line pick with their keycaps, an answer sending with them gone, and the choice on the
/// right edge. Only when `SITREP_STILLS` names a folder for them, so a run of the tests writes nothing.
@MainActor
@Suite(.backstop, .enabled(if: stills != nil))
struct AsksPanelStillsTests {
    private static let frameMS = 1000.0 / 60
    private static let minute = 60_000
    /// The wall clock the stills are drawn at, ms: Wednesday 18 November 2026, 10:30 UTC.
    private static let now = 1_794_997_800_000.0
    private static let settings = EdgeSettings()
    private static let edge = edge(.left)
    private static let setting = setting(on: edge)

    /// The README desktop's screen, its edge on this side.
    private static func edge(_ side: EdgeSettings.Edge) -> ScreenEdge {
        ScreenEdge(
            frame: CGRect(origin: .zero, size: ReadmeDesktop.screen),
            visible: CGRect(
                x: 0, y: 0, width: ReadmeDesktop.screen.width,
                height: ReadmeDesktop.screen.height - ReadmeDesktop.menuBar
            ),
            edge: side, along: settings.along
        )
    }

    /// What the run runs in on this edge, the Mac letting the panel take keys where it `takesKeys`.
    private static func setting(on edge: ScreenEdge, takesKeys: Bool = false) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: edge.stage, mirror: edge.mirror(wide: true), style: settings.style, reducesMotion: false,
            takesKeys: takesKeys
        )
    }
    private static let helpDesk = "needs:sr-nw0001", shifts = "needs:sr-ct0002", onboarding = "needs:sr-tw0006"
    /// Onboarding flow's pick, long enough to wrap to a second line.
    private static let pairing = "Pair each one with a lead for five shifts, then let them take tickets alone"

    @Test
    func thePointerOnARowsWords() throws {
        let run = try Self.opened()

        try Self.shoot(run, pointer: try Self.words(Self.helpDesk, run), as: "1-row-words")
    }

    @Test
    func thePointerOnTheRowsArrow() throws {
        let run = try Self.opened()

        try Self.shoot(run, pointer: try Self.arrow(Self.helpDesk, run), as: "2-row-arrow")
    }

    @Test
    func theAsksPanelOnAChoice() throws {
        let run = try Self.opened()

        try Self.open(Self.helpDesk, run)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "3-asks-choice")
    }

    @Test
    func theAsksPanelOnAWordsAsk() throws {
        let run = try Self.opened()

        try Self.open(Self.shifts, run)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "4-asks-words")
    }

    /// "Sending Threaded", held 800ms before the still is drawn, so its ring has 60% to run.
    @Test
    func anAnswerSending() throws {
        let run = try Self.opened(), at = Date(timeIntervalSince1970: Self.now / 1000 - 0.8)
        let threaded = Answering(.words("Threaded"), to: "k1", of: "sr-nw0001", wanting: .choice)

        try Self.open(Self.helpDesk, run)
        run.heard(
            .held(HeldAnswer(answering: threaded, heldAt: at, goesAt: at.addingTimeInterval(2))),
            NotchRun.Moment(time: run.time + Self.frameMS, pointer: try Self.onTitle(run), setting: Self.setting)
        )
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "5-sending")
    }

    @Test
    func theAsksPanelOnATwoLinePick() throws {
        let run = try Self.opened()

        try Self.open(Self.onboarding, run)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "6-asks-pick")
    }

    @Test
    func thePointerOnATwoLinePick() throws {
        let run = try Self.opened()

        try Self.open(Self.onboarding, run)
        try Self.shoot(run, pointer: try Self.onAnswer(0, run), as: "7-asks-pick-hover")
    }

    /// Help desk redesign's choice slid 150 points toward its yes under two fingers still on the trackpad, both asks
    /// showing.
    @Test
    func theAsksPanelMidSwipe() throws {
        let run = try Self.opened()

        try Self.open(Self.helpDesk, run)

        let title = try Self.onTitle(run)
        let scrolls = [Scroll(down: 0, phase: .began)]
            + Array(repeating: Scroll(down: 0, along: 5, phase: .changed), count: 30)

        for scroll in scrolls {
            run.scroll(scroll, NotchRun.Moment(time: run.time + Self.frameMS, pointer: title, setting: Self.setting))
        }
        try Self.shoot(run, pointer: title, as: "8-asks-mid-swipe")
    }

    // MARK: The right edge

    @Test
    func onTheRightEdgeThePointerOnTheRowsArrow() throws {
        let edge = Self.edge(.right), setting = Self.setting(on: edge), run = try Self.opened(setting)

        try Self.shoot(run, pointer: try Self.arrow(Self.helpDesk, run, setting), as: "9-right-row-arrow", on: edge)
    }

    @Test
    func onTheRightEdgeTheAsksPanelOpenFromTheArrow() throws {
        let edge = Self.edge(.right), setting = Self.setting(on: edge), run = try Self.opened(setting)

        try Self.open(Self.helpDesk, run, setting)
        try Self.shoot(run, pointer: try Self.onTitle(run, setting), as: "10-right-asks-choice", on: edge)
    }

    // MARK: Keycaps

    private static let keys = setting(on: edge, takesKeys: true)

    @Test
    func theKeycapsOnAChoice() throws {
        let run = try Self.opened(Self.keys)

        try Self.open(Self.helpDesk, run, Self.keys)
        try #require(run.asksShown?.keycaps == true)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "11-keys-choice", in: Self.keys)
    }

    @Test
    func theKeycapsOnATwoLinePick() throws {
        let run = try Self.opened(Self.keys)

        try Self.open(Self.onboarding, run, Self.keys)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "12-keys-pick", in: Self.keys)
    }

    /// "Sending" the two-line pick, held 800ms before, the panel holding the keys: the keycaps gone, the held row's
    /// check in its keycap's room on its first line.
    @Test
    func anAnswerSendingWhileThePanelHoldsTheKeys() throws {
        let run = try Self.opened(Self.keys), at = Date(timeIntervalSince1970: Self.now / 1000 - 0.8)
        let pairing = Answering(.words(Self.pairing), to: "k1", of: "sr-tw0006", wanting: .choice)

        try Self.open(Self.onboarding, run, Self.keys)
        run.heard(
            .held(HeldAnswer(answering: pairing, heldAt: at, goesAt: at.addingTimeInterval(2))),
            NotchRun.Moment(time: run.time + Self.frameMS, pointer: try Self.onTitle(run), setting: Self.keys)
        )
        try #require(run.holdsKeys && run.asksShown?.keycaps == false)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "13-keys-sending", in: Self.keys)
    }

    @Test
    func onTheRightEdgeTheKeycapsOnAChoice() throws {
        let edge = Self.edge(.right), setting = Self.setting(on: edge, takesKeys: true)
        let run = try Self.opened(setting)

        try Self.open(Self.helpDesk, run, setting)
        try Self.shoot(run, pointer: try Self.onTitle(run, setting), as: "14-keys-right-choice", on: edge, in: setting)
    }

    // MARK: Three asks

    /// Help desk redesign asking three, the panel holding the keys, its asks lying out from the notch: on the left
    /// edge left to right, the first ask's dot wide at the dots' left; on the right right to left, wide at their
    /// right.
    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func threeAsksTheirDotsLyingOutFromTheNotch(_ side: EdgeSettings.Edge) throws {
        let edge = Self.edge(side), setting = Self.setting(on: edge, takesKeys: true)
        let run = try Self.opened(setting, thirdAsk: true)

        try Self.open(Self.helpDesk, run, setting)
        try #require(run.asksShown?.pages == 3)
        try Self.shoot(
            run, pointer: try Self.onTitle(run, setting), as: "15-three-asks-\(side)", on: edge, in: setting
        )
    }

    /// The arrow pointing away from the notch pressed on the right edge, shot 100ms into its slide: the second ask
    /// coming in from the left, the first going out toward the notch, the wide dot passing leftward.
    @Test
    func onTheRightEdgeTheOutwardArrowMidSlide() throws {
        let edge = Self.edge(.right), setting = Self.setting(on: edge, takesKeys: true)
        let run = try Self.opened(setting, thirdAsk: true)

        try Self.open(Self.helpDesk, run, setting)

        let title = try Self.onTitle(run, setting)

        try #require(
            run.key(.left, NotchRun.Moment(time: run.time + Self.frameMS, pointer: title, setting: setting)) == .asks
        )
        try Self.shoot(run, pointer: title, as: "16-three-asks-right-sliding", on: edge, in: setting)
    }

    // MARK: The run

    /// The run over the board, Help desk redesign asking a third where it has a `thirdAsk`, its panel poured out and
    /// settled under the pointer held at the notch's home.
    private static func opened(_ setting: NotchRun.Setting = setting, thirdAsk: Bool = false) throws -> NotchRun {
        let run = NotchRun(at: 0, in: setting, measure: AsksMeasure.drawn)
        let home = CGPoint(x: 4, y: setting.stage.notchY)

        _ = run.show(board(thirdAsk: thirdAsk), NotchRun.Moment(time: 0, pointer: nil, setting: setting))
        step(run, for: 5000, pointer: home, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        return run
    }

    private static func open(_ row: String, _ run: NotchRun, _ setting: NotchRun.Setting = setting) throws {
        let arrow = try arrow(row, run, setting)

        step(run, for: frameMS, pointer: arrow, setting)
        try #require(run.press(NotchRun.Moment(time: run.time + frameMS, pointer: arrow, setting: setting)) == .asks)
    }

    private static func step(
        _ run: NotchRun, for ms: Double, pointer: CGPoint, _ setting: NotchRun.Setting = setting,
        until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            let time = run.time + frameMS

            run.step(NotchRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting))
        }
    }

    /// A point in a row's own frame, read left to right, on the stage: through the edge's mirror.
    private static func onRow(
        _ key: String, _ x: Double, _ y: Double, _ run: NotchRun, _ setting: NotchRun.Setting
    ) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: key))
        let row = run.list.content.drawnFrame(index)

        return panel.stagePoint(CGPoint(x: row.minX + x, y: row.minY + y), mirror: setting.mirror, scroll: run.scroll)
    }

    private static func words(_ key: String, _ run: NotchRun) throws -> CGPoint {
        let index = try #require(run.list.index(of: key))

        return try onRow(key, 90, run.list.content.drawnFrame(index).height / 2, run, setting)
    }

    private static func arrow(_ key: String, _ run: NotchRun, _ setting: NotchRun.Setting = setting) throws -> CGPoint {
        let index = try #require(run.list.index(of: key)), row = run.list.content.drawnFrame(index)
        let box = RowArrow.box(in: row.size, pointsLeft: setting.mirror.a < 0)

        return try onRow(key, box.midX, box.midY, run, setting)
    }

    /// On the asks panel's title, where nothing lifts.
    private static func onTitle(_ run: NotchRun, _ setting: NotchRun.Setting = setting) throws -> CGPoint {
        let asks = try #require(run.asksShown), title = asks.layout.title

        return CGPoint(
            x: setting.mirror.a < 0 ? asks.frame.maxX - title.midX : asks.frame.minX + title.midX,
            y: asks.frame.minY + title.midY
        )
    }

    /// On the middle of an answer's row.
    private static func onAnswer(_ row: Int, _ run: NotchRun) throws -> CGPoint {
        let asks = try #require(run.asksShown), box = asks.layout.answers[row]

        return CGPoint(x: asks.frame.minX + box.midX, y: asks.frame.minY + box.midY)
    }

    /// The run moved on a few frames with the pointer here, drawn, and shot from the screen's edge past the asks panel,
    /// over the panel's height and the asks panel's, with room round them.
    private static func shoot(
        _ run: NotchRun, pointer: CGPoint, as name: String, on edge: ScreenEdge = edge, in setting: NotchRun.Setting? = nil
    ) throws {
        let folder = try #require(stills), surface = NotchSurface(), setting = setting ?? Self.setting(on: edge)
        let window = edge.window(wide: true).size, onRight = edge.edge == .right

        step(run, for: 6 * frameMS, pointer: pointer, setting)
        surface.appearance = NSAppearance(named: .darkAqua)
        surface.frame = CGRect(origin: .zero, size: window)
        surface.draw(run, in: setting, mirror: edge.mirror(wide: true), now: now)

        let outline = run.frame.outline.boundingBox
        let shown = run.asksShown.map { outline.union($0.frame) } ?? outline
        let width = AsksLayout.reach + 24
        let cut = CGRect(
            x: onRight ? window.width - width : 0, y: shown.minY - 40, width: width, height: shown.height + 80
        )
        let shot = try EdgeShot(surface, cut: cut, onRight: onRight).shoot(turned: Running.at(0.3))

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.png().write(to: folder.appending(path: "\(name).png"))
    }

    // MARK: The board

    /// Paper's: in Needs you, Help desk redesign of Northwind asking two, a choice and a yes, and a third yes where it
    /// has a `thirdAsk`; Shift schedules of Contoso asking for words; Onboarding flow of Tailspin asking a choice whose
    /// pick, first as the CLI lists it, wraps to two lines; Invoice ledger of Fabrikam stopped at a permission prompt;
    /// and two at work.
    private static func board(thirdAsk: Bool = false) -> PanelBoard {
        let ago = { (minutes: Int) in Int(now) - minutes * minute }
        let third: WatchLine.Row.Line? = thirdAsk
            ? .init("ask:sr-nw0001:k3", .ask, ask: "k3", first: "Ship the search box", since: ago(20)) : nil
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [
                    .init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Thread replies?", since: ago(4)),
                    .init("ask:sr-nw0001:k2", .ask, ask: "k2", first: "Review Tickets & Replies", since: ago(12)),
                    third,
                ].compactMap { $0 }
            ),
            WatchLine.Row(
                session: "sr-ct0002", name: "Shift schedules", projectName: "Contoso",
                lines: [.init("ask:sr-ct0002:k1", .ask, ask: "k1", first: "Empty rota words", since: ago(7))]
            ),
            WatchLine.Row(
                session: "sr-tw0006", name: "Onboarding flow", projectName: "Tailspin",
                lines: [.init("ask:sr-tw0006:k1", .ask, ask: "k1", first: "First week for new agents?", since: ago(9))]
            ),
            WatchLine.Row(
                session: "sr-fb0003", name: "Invoice ledger", projectName: "Fabrikam",
                lines: [.init("stop:w3", .permission, writer: "w3", first: .init(lead: "Allow"), since: ago(2))]
            ),
            WatchLine.Row(
                session: "sr-wg0004", name: "Mobile app", projectName: "Woodgrove",
                lines: [.init("work:sr-wg0004", .working, first: .init(lead: "Running", mono: "tests"), since: ago(3))]
            ),
            WatchLine.Row(
                session: "sr-lw0005", name: "Data import", projectName: "Litware",
                lines: [.init("work:sr-lw0005", .working, first: "Mapping the import's columns", since: ago(6))]
            ),
        ]
        let projects = [
            WatchLine.Project(name: "Northwind", sessions: [
                WatchLine.Session(id: "sr-nw0001", name: "Help desk redesign", state: .needsYou, asks: [
                    WatchLine.Ask(
                        id: "k1", wants: .choice, yes: nil, title: "Thread replies, or keep them flat?",
                        options: ["Threaded", "Flat"], recommended: "Threaded", at: ago(4)
                    ),
                    WatchLine.Ask(id: "k2", wants: .yes, yes: "Approve", title: "Review Tickets & Replies, round 1"),
                    thirdAsk ? WatchLine.Ask(id: "k3", wants: .yes, yes: "Ship", title: "Ship the search box?") : nil,
                ].compactMap { $0 }),
            ]),
            WatchLine.Project(name: "Contoso", sessions: [
                WatchLine.Session(id: "sr-ct0002", name: "Shift schedules", state: .needsYou, asks: [
                    WatchLine.Ask(id: "k1", wants: .words, yes: nil, title: "Say what an empty rota should read"),
                ]),
            ]),
            WatchLine.Project(name: "Tailspin", sessions: [
                WatchLine.Session(id: "sr-tw0006", name: "Onboarding flow", state: .needsYou, asks: [
                    WatchLine.Ask(
                        id: "k1", wants: .choice, yes: nil, title: "How should a new agent's first week run?",
                        options: [
                            Self.pairing, "Shadow the queue for a day, then take tickets", "Straight onto the queue",
                        ],
                        recommended: Self.pairing, at: ago(9)
                    ),
                ]),
            ]),
        ]
        var last = LastBoard()

        _ = last.hear(
            .line(WatchLine(at: Int(now), version: "0.2.0", rows: rows, projects: projects).text),
            at: Date(timeIntervalSince1970: now / 1000)
        )
        return PanelBoard(last)
    }
}

/// Where the stills are drawn.
private let stills = ProcessInfo.processInfo.environment["SITREP_STILLS"].map(URL.init(fileURLWithPath:))
