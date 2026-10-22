import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
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
        row("turn:\(id)", "yourTurn", session: id, lead: "Your turn", second: "SitRep · \(id)", since: 1_792_445_574_706 - minutes * minute)
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

    /// A run over this board, the wall clock `wall`, its panel opened by the pointer held on the notch.
    private static func opened(_ rows: [String], folded: Set<BoardSection> = [], wall: Wall = Wall()) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folded: folded, wall: { wall.now })

        _ = run.show(board(rows), at(run.time))
        frames(run, for: 3000, onTheNotch) { run.phase == .open }
        return run
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    /// A press in the middle of the item drawn under this key.
    private static func press(_ key: String, in run: NotchRun) throws -> NotchRun.Press? {
        let panel = try #require(run.frame.panel)
        let index = try #require(run.list.content.entries.firstIndex { $0.item.key == key })
        let item = run.list.content.itemFrame(index), drawn = run.list.content.entries[index].item.box(width: item.width)
        let point = CGPoint(x: panel.frame.minX + item.midX, y: panel.frame.minY + item.minY + drawn.midY - run.scroll)

        return run.press(at(run.time, point), mayJump: true)
    }

    private static let mixed = [ask("sr-a"), ask("sr-b"), working("sr-w"), turn("sr-t", ago: 5)]

    @Test func aClickOnAnEyebrowFoldsItsSectionToTheEyebrowAloneAtOnce() throws {
        let run = Self.opened(Self.mixed)

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections == [.working])
        #expect(Self.keys(run) == ["eyebrow:needsYou", "needs:sr-a", "needs:sr-b", "divider", "eyebrow:working", "eyebrow:yourTurn", "turn:sr-t"])
        #expect(!run.isFolding(at: run.time))
        #expect(run.list.content.entries.allSatisfy { $0.height == $0.item.height && $0.alpha == 1 })
        #expect(run.list.content.items.contains(.eyebrow(Eyebrow(section: .working, count: 1, isFolded: true, above: 0))))

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections.isEmpty)
        #expect(Self.keys(run).contains("sr-w"))
        #expect(!run.isFolding(at: run.time))
    }

    /// Needs you folded, the hairline still follows its eyebrow.
    @Test func theHairlineStaysAfterNeedsYouFolded() throws {
        let run = Self.opened(Self.mixed)

        _ = try Self.press("eyebrow:needsYou", in: run)

        #expect(Self.keys(run).prefix(3) == ["eyebrow:needsYou", "divider", "eyebrow:working"])
    }

    /// Folds Lee left are where the run starts: its eyebrow alone, pointing right.
    @Test func theFoldsSavedAreRestored() {
        let run = Self.opened(Self.mixed, folded: [.yourTurn])

        #expect(Self.keys(run).last == "eyebrow:yourTurn")
        #expect(run.list.content.items.last == .eyebrow(Eyebrow(section: .yourTurn, count: 1, isFolded: true, above: 10)))
    }

    /// A row holding a new line unfolds Needs you, at once; a board with nothing new leaves it folded.
    @Test func anArrivalUnfoldsNeedsYou() {
        let run = Self.opened(Self.mixed, folded: [.needsYou])

        _ = run.show(Self.board(Self.mixed), Self.at(run.time))
        #expect(run.folded.sections == [.needsYou])

        _ = run.show(Self.board([Self.ask("sr-c")] + Self.mixed, new: ["ask:sr-c"]), Self.at(run.time))

        #expect(run.folded.sections.isEmpty)
        #expect(Self.keys(run).prefix(4) == ["eyebrow:needsYou", "needs:sr-c", "needs:sr-a", "needs:sr-b"])
        #expect(!run.isFolding(at: run.time))
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

    // MARK: Held places

    /// A row whose turn ends while the card is out leaves its place in Working, folding away there, and folds in at
    /// its place in Your turn.
    @Test func aRowMovingFromWorkingToYourTurnFoldsOutAndIn() throws {
        let run = Self.opened([Self.working("sr-w"), Self.working("sr-x"), Self.turn("sr-t", ago: 5)])

        _ = run.show(Self.board([Self.working("sr-x"), Self.turn("sr-w", ago: 0), Self.turn("sr-t", ago: 5)]), Self.at(run.time))
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
