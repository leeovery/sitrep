import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepLines
@testable import SitRepPanel
import Testing

/// The card's sections as the notch runs them: a click on an eyebrow folds its section at once and is kept, an
/// arrival unfolds Needs you, "N earlier" opens in place and is folded each time the card comes out, the rows past the
/// fold period fold into it as the wall clock passes it, and the head shows only with nothing to list or a stale
/// board.
@MainActor
struct CardSectionsRunTests {
    /// A wall clock the test moves, ms.
    final class Wall {
        var now = 1_792_445_574_706.0
    }

    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
    )
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491)
    private static let away = CGPoint(x: 900, y: 491)
    private static let minute = 60_000

    private static func at(_ time: Double, _ pointer: CGPoint? = nil, period: FoldPeriod = .hour) -> NotchRun.Moment {
        var setting = setting
        setting.period = period
        return NotchRun.Moment(time: time, pointer: pointer, setting: setting)
    }

    private static func ask(_ id: String) -> String {
        row("ask:\(id)", "ask", session: id, lead: "Ask \(id)", second: "SitRep · \(id)", since: 1_792_445_000_000)
    }

    private static func working(_ id: String) -> String {
        row("work:\(id)", "working", session: id, lead: "Running the tests", second: "DocMan · \(id)", since: 1_792_445_000_000)
    }

    /// A your turn whose turn ended this many minutes before the wall clock's start.
    private static func turn(_ id: String, ago minutes: Int) -> String {
        turn(id, since: 1_792_445_574_706 - minutes * minute)
    }

    /// A your turn whose turn ended at this time on the wall clock, ms.
    private static func turn(_ id: String, since: Int) -> String {
        row("turn:\(id)", "yourTurn", session: id, lead: "Your turn", second: "SitRep · \(id)", since: since)
    }

    private static func board(_ rows: [String], new: [String] = []) -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: rows.count, new: new, rows: rows)), at: Date())
        return PanelBoard(last)
    }

    private static func frames(_ run: NotchRun, for ms: Double, _ pointer: CGPoint?, period: FoldPeriod = .hour, until done: () -> Bool = { false }) {
        let end = run.time + ms

        while run.time + frameMS <= end + 1e-9, !done() {
            run.step(at(run.time + frameMS, pointer, period: period))
        }
    }

    /// A run over this board, its folds kept in `kept`, the wall clock `wall` in London's calendar, its panel opened
    /// by the pointer held on the notch.
    private static func opened(
        _ rows: [String], kept: SavedSettings<CardSettings>? = nil, wall: Wall = Wall(), period: FoldPeriod = .hour
    ) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, kept: kept, wall: { wall.now }, calendar: london)

        _ = run.show(board(rows), at(run.time, period: period))
        frames(run, for: 3000, onTheNotch, period: period) { run.phase == .open }
        return run
    }

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// Folds kept in defaults of their own, these sections folded.
    private static func kept(_ sections: Set<BoardSection> = []) -> SavedSettings<CardSettings> {
        let kept = SavedSettings<CardSettings>(MemoryDefaults())

        kept.save(CardSettings(folded: sections))
        return kept
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    /// A press in the middle of the item drawn under this key.
    private static func press(_ key: String, in run: NotchRun, mayJump: Bool = true) throws -> NotchRun.Press? {
        let panel = try #require(run.frame.panel)
        let index = try #require(run.list.content.entries.firstIndex { $0.item.key == key })
        let item = run.list.content.itemFrame(index), drawn = run.list.content.entries[index].item.box(width: item.width)
        let point = CGPoint(x: panel.frame.minX + item.midX, y: panel.frame.minY + item.minY + drawn.midY - run.scroll)

        return run.press(at(run.time, point), mayJump: mayJump)
    }

    private static let mixed = [ask("sr-a"), ask("sr-b"), turn("sr-t", ago: 5), working("sr-w")]

    @Test func aClickOnAnEyebrowFoldsItsSectionToTheEyebrowAloneAtOnce() throws {
        let run = Self.opened(Self.mixed)

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections == [.working, .snoozed])
        #expect(Self.keys(run) == ["eyebrow:needsYou", "needs:sr-a", "needs:sr-b", "eyebrow:yourTurn", "turn:sr-t", "divider", "eyebrow:working"])
        #expect(!run.isFolding(at: run.time))
        #expect(run.list.content.entries.allSatisfy { $0.height == $0.item.height && $0.alpha == 1 })
        #expect(run.list.content.items.contains(.eyebrow(Eyebrow(section: .working, count: 1, isFolded: true, above: 0))))

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections == [.snoozed])
        #expect(Self.keys(run).contains("sr-w"))
        #expect(!run.isFolding(at: run.time))
    }

    /// Needs you folded, the hairline still follows Your turn; Your turn folded, it follows its eyebrow.
    @Test func theHairlineStaysAfterYourTurnFoldedOrNot() throws {
        let run = Self.opened(Self.mixed)

        _ = try Self.press("eyebrow:needsYou", in: run)
        #expect(Self.keys(run).prefix(5) == ["eyebrow:needsYou", "eyebrow:yourTurn", "turn:sr-t", "divider", "eyebrow:working"])

        _ = try Self.press("eyebrow:yourTurn", in: run)
        #expect(Self.keys(run).prefix(4) == ["eyebrow:needsYou", "eyebrow:yourTurn", "divider", "eyebrow:working"])
    }

    /// Folds Lee left are where the run starts: its eyebrow alone, pointing right.
    @Test func theFoldsSavedAreRestored() {
        let run = Self.opened(Self.mixed, kept: Self.kept([.yourTurn]))

        #expect(Self.keys(run).suffix(4) == ["eyebrow:yourTurn", "divider", "eyebrow:working", "sr-w"])
        #expect(run.list.content.items.contains(.eyebrow(Eyebrow(section: .yourTurn, count: 1, isFolded: true, above: 10))))
    }

    /// A click on an eyebrow keeps the fold, and a click again keeps it unfolded.
    @Test func aClickOnAnEyebrowIsKept() throws {
        let kept = Self.kept()
        let run = Self.opened(Self.mixed, kept: kept)

        _ = try Self.press("eyebrow:working", in: run)
        #expect(kept.read().folded == [.working])

        _ = try Self.press("eyebrow:working", in: run)
        #expect(kept.read().folded.isEmpty)
    }

    /// While a jump runs no row jumps, but an eyebrow still folds.
    @Test func anEyebrowFoldsWhileAJumpRuns() throws {
        let run = Self.opened(Self.mixed)

        #expect(try Self.press("eyebrow:yourTurn", in: run, mayJump: false) == .fold)
        #expect(run.folded.sections == [.yourTurn, .snoozed])
    }

    /// A row holding a new line unfolds Needs you, its rows there at once, and the unfold is kept; the row arriving
    /// folds in, as one arriving does; a board with nothing new leaves it folded.
    @Test func anArrivalUnfoldsNeedsYouAndIsKept() throws {
        let kept = Self.kept([.needsYou])
        let run = Self.opened(Self.mixed, kept: kept)

        _ = run.show(Self.board(Self.mixed), Self.at(run.time))
        #expect(run.folded.sections == [.needsYou])

        _ = run.show(Self.board([Self.ask("sr-c")] + Self.mixed, new: ["ask:sr-c"]), Self.at(run.time))

        let entries = run.list.content.entries
        let arriving = try #require(entries.first { $0.item.key == "needs:sr-c" })
        let there = entries.filter { ["needs:sr-a", "needs:sr-b"].contains($0.item.key) }

        #expect(run.folded.sections.isEmpty)
        #expect(kept.read().folded.isEmpty)
        #expect(Self.keys(run).prefix(4) == ["eyebrow:needsYou", "needs:sr-c", "needs:sr-a", "needs:sr-b"])
        #expect(there.count == 2 && there.allSatisfy { $0.height == $0.item.height })
        #expect(arriving.height < arriving.item.height)
    }

    /// A new working row on the board that unfolds Needs you folds in as any arriving row does.
    @Test func aRowArrivingAsNeedsYouUnfoldsFoldsIn() throws {
        let run = Self.opened(Self.mixed, kept: Self.kept([.needsYou]))

        _ = run.show(Self.board([Self.ask("sr-c")] + Self.mixed + [Self.working("sr-x")], new: ["ask:sr-c"]), Self.at(run.time))

        let arriving = try #require(run.list.content.entries.first { $0.item.key == "sr-x" })

        #expect(arriving.height < arriving.item.height)
        #expect(run.isFolding(at: run.time))
    }

    /// A row folding away, its ask answered, finishes folding as Lee folds another section, and as a row folds into
    /// "N earlier": only what the fold changes changes at once.
    @Test func aRowFoldingAwayKeepsFoldingAsAnotherSectionFoldsOrARowRefolds() throws {
        let wall = Wall()
        let run = Self.opened([Self.ask("sr-a"), Self.ask("sr-b"), Self.turn("sr-t", ago: 59), Self.working("sr-w")], wall: wall)

        _ = run.show(Self.board([Self.ask("sr-a"), Self.turn("sr-t", ago: 59), Self.working("sr-w")]), Self.at(run.time))
        Self.frames(run, for: 50, Self.onTheNotch)
        _ = try Self.press("eyebrow:working", in: run)

        let going = try #require(run.list.content.entries.first { $0.item.key == "needs:sr-b" })
        #expect(going.isGoing && going.height > 0 && going.height < going.item.height)

        wall.now += Double(Self.minute)
        Self.frames(run, for: Self.frameMS, Self.onTheNotch)

        let still = try #require(run.list.content.entries.first { $0.item.key == "needs:sr-b" })
        #expect(Self.keys(run).suffix(4) == ["eyebrow:yourTurn", "earlier", "divider", "eyebrow:working"])
        #expect(still.isGoing && still.height > 0)
    }

    // MARK: N earlier

    private static let turns = [turn("sr-new", ago: 5), turn("sr-old", ago: 90), turn("sr-older", ago: 300)]

    @Test func aClickOnNEarlierOpensItInPlaceAndAgainFoldsIt() throws {
        let run = Self.opened(Self.turns)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "earlier"])
        #expect(try Self.press("earlier", in: run) == .fold)
        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "earlier", "turn:sr-old", "turn:sr-older"])
        #expect(!run.isFolding(at: run.time))

        _ = try Self.press("earlier", in: run)
        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "earlier"])
    }

    /// Open is never kept: the card comes out with "N earlier" folded again, as what it holds is stale.
    @Test func nEarlierIsFoldedAgainEachTimeTheCardComesOut() throws {
        let run = Self.opened(Self.turns)

        _ = try Self.press("earlier", in: run)
        run.clickElsewhere(Self.at(run.time))
        Self.frames(run, for: 5000, Self.away) { run.phase == .closed }
        Self.frames(run, for: 3000, Self.onTheNotch) { run.phase == .open }

        #expect(run.phase == .open)
        #expect(!run.folded.isEarlierOpen)
        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "earlier"])
    }

    /// The next redraw is due as the first shown row passes the period; past it, the row folds in, at once.
    @Test func aRowFoldsIntoNEarlierAsItPassesThePeriod() {
        let wall = Wall()
        let run = Self.opened([Self.turn("sr-a", ago: 50), Self.turn("sr-b", ago: 20)], wall: wall)
        let due = wall.now + 10 * Double(Self.minute)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-a", "turn:sr-b"])
        #expect(run.nextAgeChange(after: wall.now).map { $0 <= due } == true)
        #expect(run.nextAgeChange(after: due - 1) == due)

        wall.now = due
        Self.frames(run, for: Self.frameMS, Self.onTheNotch)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-b", "earlier"])
        #expect(!run.isFolding(at: run.time))
    }

    /// The period changing refolds the card at once: never shows no "N earlier".
    @Test func aNewPeriodRefoldsTheCardAtOnce() {
        let run = Self.opened(Self.turns)

        Self.frames(run, for: Self.frameMS, Self.onTheNotch, period: .never)
        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "turn:sr-old", "turn:sr-older"])

        Self.frames(run, for: Self.frameMS, Self.onTheNotch, period: .fourHours)
        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-new", "turn:sr-old", "earlier"])
    }

    /// Open, "N earlier" closes as the line goes: its one row's session starts a turn, and a row passing the period
    /// later in the same opening brings it back folded.
    @Test func nEarlierClosesAsTheLineGoes() throws {
        let wall = Wall()
        let run = Self.opened([Self.turn("sr-new", ago: 50), Self.turn("sr-old", ago: 90)], wall: wall)

        _ = try Self.press("earlier", in: run)
        _ = run.show(Self.board([Self.turn("sr-new", ago: 50), Self.working("sr-old")]), Self.at(run.time))

        #expect(!run.folded.isEarlierOpen)
        #expect(!Self.shown(run).contains("earlier"))

        wall.now += 10 * Double(Self.minute)
        Self.frames(run, for: Self.frameMS, Self.onTheNotch)

        #expect(Self.shown(run).prefix(4) == ["eyebrow:yourTurn", "earlier", "divider", "eyebrow:working"])
        #expect(!run.folded.isEarlierOpen)
    }

    /// The keys of the items staying, not folding away.
    private static func shown(_ run: NotchRun) -> [String] {
        run.list.content.entries.filter { !$0.isGoing }.map(\.item.key)
    }

    /// Open, a row passing the period moves under "N earlier" at once, its count with it.
    @Test func aRowPassingThePeriodWhileNEarlierIsOpenMovesUnderIt() throws {
        let wall = Wall()
        let run = Self.opened([Self.turn("sr-new", ago: 50), Self.turn("sr-old", ago: 90)], wall: wall)

        _ = try Self.press("earlier", in: run)
        wall.now += 10 * Double(Self.minute)
        Self.frames(run, for: Self.frameMS, Self.onTheNotch)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "earlier", "turn:sr-new", "turn:sr-old"])
        #expect(run.folded.isEarlierOpen)
        #expect(run.list.content.entries.allSatisfy { $0.height == $0.item.height })
        #expect(!run.isFolding(at: run.time))
    }

    /// Today, through the run: a turn ended at 23:59:30 in London stays out until midnight, the next redraw due then,
    /// before the row's time next ticks, and folds in as the clock passes it.
    @Test func todayFoldsATurnAtLocalMidnight() {
        let wall = Wall(), midnight = 1_792_710_000_000 // 23 October 2026, 00:00 BST

        wall.now = Double(midnight) - 10_000
        let run = Self.opened([Self.turn("sr-late", since: midnight - 30_000)], wall: wall, period: .today)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-late"])
        #expect(run.nextAgeChange(after: wall.now) == Double(midnight))

        wall.now = Double(midnight)
        Self.frames(run, for: Self.frameMS, Self.onTheNotch, period: .today)

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "earlier"])
    }

    // MARK: Held places

    /// A row whose turn ends while the card is out leaves its place in Working, folding away there, and folds in at
    /// its place in Your turn.
    @Test func aRowMovingFromWorkingToYourTurnFoldsOutAndIn() throws {
        let run = Self.opened([Self.turn("sr-t", ago: 5), Self.working("sr-w"), Self.working("sr-x")])

        _ = run.show(Self.board([Self.turn("sr-w", ago: 0), Self.turn("sr-t", ago: 5), Self.working("sr-x")]), Self.at(run.time))
        Self.frames(run, for: 100, Self.onTheNotch)

        let entries = run.list.content.entries
        let going = try #require(entries.first { $0.item.key == "sr-w" })
        let coming = try #require(entries.firstIndex { $0.item.key == "turn:sr-w" })
        let yourTurn = try #require(entries.firstIndex { $0.item.key == "eyebrow:yourTurn" })

        #expect(going.isGoing)
        #expect(coming > yourTurn)
        #expect(run.isFolding(at: run.time))
    }

    // MARK: The head

    @Test func theHeadGoesWhileTheCardListsRows() {
        let run = Self.opened(Self.mixed)

        #expect(run.list.head == nil)
        #expect(run.list.content.headHeight == 0)
    }

    /// The empty card keeps its "All clear", and a stale board says when it was last known current.
    @Test func theHeadShowsWithNothingToListOrABoardGoneStale() {
        let empty = Self.opened([])
        var last = LastBoard()

        #expect(empty.list.head?.title == "All clear")
        _ = last.hear(.line(line(needYou: 1, sessions: 1, new: [], rows: [Self.ask("sr-a")])), at: Date())
        _ = last.hear(.exited(.status(1), stderr: ""), at: Date())
        _ = empty.show(PanelBoard(last), Self.at(empty.time))

        #expect(empty.list.head?.count.hasPrefix("as of") == true)
    }
}
