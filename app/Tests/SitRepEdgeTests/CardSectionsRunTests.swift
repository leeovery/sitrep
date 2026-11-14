import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepLines
@testable import SitRepPanel
import Testing

/// The card's sections as the notch runs them: a click on an eyebrow folds its section at once and is kept, an
/// arrival unfolds Needs you, every your-turn row stays however old, no hairline comes as sections fold, and the head
/// shows only with nothing to list or a stale board.
@MainActor
struct CardSectionsRunTests {
    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false, isChosen: true
    )
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491)
    private static let away = CGPoint(x: 900, y: 491)
    private static let minute = 60_000

    private static func at(_ time: Double, _ pointer: CGPoint? = nil) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: pointer, setting: setting)
    }

    private static func ask(_ id: String) -> String {
        row("ask:\(id)", "ask", session: id, lead: "Ask \(id)", second: "SitRep · \(id)", since: 1_792_445_000_000)
    }

    private static func working(_ id: String) -> String {
        row("work:\(id)", "working", session: id, lead: "Running the tests", second: "DocMan · \(id)", since: 1_792_445_000_000)
    }

    /// A your turn whose turn ended this many minutes before 1_792_445_574_706, ms on the wall clock.
    private static func turn(_ id: String, ago minutes: Int) -> String {
        row(
            "turn:\(id)", "yourTurn", session: id, lead: "Your turn", second: "SitRep · \(id)",
            since: 1_792_445_574_706 - minutes * minute
        )
    }

    private static func board(_ rows: [String], new: [String] = []) -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: rows.count, new: new, rows: rows)), at: Date())
        return PanelBoard(last)
    }

    private static func frames(_ run: NotchRun, for ms: Double, _ pointer: CGPoint?, until done: () -> Bool = { false }) {
        let end = run.time + ms

        while run.time + frameMS <= end + 1e-9, !done() {
            run.step(at(run.time + frameMS, pointer))
        }
    }

    /// A run over this board, its folds kept in `kept`, in London's calendar, its panel opened by the pointer held on
    /// the notch.
    private static func opened(_ rows: [String], kept: SavedSettings<CardSettings>? = nil) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folding: Folding(kept: kept), calendar: london)

        _ = run.show(board(rows), at(run.time))
        frames(run, for: 3000, onTheNotch) { run.phase == .open }
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
    private static func press(_ key: String, in run: NotchRun) throws -> NotchRun.Press? {
        let panel = try #require(run.frame.panel)
        let index = try #require(run.list.content.entries.firstIndex { $0.item.key == key })
        let item = run.list.content.itemFrame(index), drawn = run.list.content.entries[index].item.box(width: item.width)
        let point = CGPoint(x: panel.frame.minX + item.midX, y: panel.frame.minY + item.minY + drawn.midY - run.scroll)

        return run.press(at(run.time, point))
    }

    private static let mixed = [ask("sr-a"), ask("sr-b"), turn("sr-t", ago: 5), working("sr-w")]

    @Test func aClickOnAnEyebrowFoldsItsSectionToTheEyebrowAloneAtOnce() throws {
        let run = Self.opened(Self.mixed)

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections == [.working, .snoozed])
        #expect(Self.keys(run) == ["eyebrow:needsYou", "needs:sr-a", "needs:sr-b", "turn:sr-t", "eyebrow:working"])
        #expect(!run.isFolding(at: run.time))
        #expect(run.list.content.entries.allSatisfy { $0.height == $0.item.height && $0.alpha == 1 })
        #expect(run.list.content.items.contains(.eyebrow(Eyebrow(section: .working, counts: [Eyebrow.Count(1)], isFolded: true, above: 14))))

        #expect(try Self.press("eyebrow:working", in: run) == .fold)
        #expect(run.folded.sections == [.snoozed])
        #expect(Self.keys(run).contains("sr-w"))
        #expect(!run.isFolding(at: run.time))
    }

    /// Folded or not, no section brings a hairline: each eyebrow follows what is above it.
    @Test func noHairlineAsSectionsFold() throws {
        let run = Self.opened(Self.mixed)

        _ = try Self.press("eyebrow:needsYou", in: run)
        #expect(Self.keys(run) == ["eyebrow:needsYou", "eyebrow:working", "sr-w"])

        _ = try Self.press("eyebrow:working", in: run)
        #expect(Self.keys(run) == ["eyebrow:needsYou", "eyebrow:working"])
        #expect(!run.list.content.items.contains(.divider))
    }

    /// Folds Lee left are where the run starts: its eyebrow alone, pointing right, counting its asks and its stopped.
    @Test func theFoldsSavedAreRestored() {
        let run = Self.opened(Self.mixed, kept: Self.kept([.needsYou]))
        let counts = [Eyebrow.Count(2, need: .ask), Eyebrow.Count(1, need: .turn)]

        #expect(Self.keys(run) == ["eyebrow:needsYou", "eyebrow:working", "sr-w"])
        #expect(run.list.content.items.contains(.eyebrow(Eyebrow(
            section: .needsYou, counts: counts, isFolded: true, above: Eyebrow.first
        ))))
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

    /// A row folding away, its ask answered, finishes folding as Lee folds another section: only what the fold changes
    /// changes at once.
    @Test func aRowFoldingAwayKeepsFoldingAsAnotherSectionFolds() throws {
        let run = Self.opened([Self.ask("sr-a"), Self.ask("sr-b"), Self.turn("sr-t", ago: 59), Self.working("sr-w")])

        _ = run.show(Self.board([Self.ask("sr-a"), Self.turn("sr-t", ago: 59), Self.working("sr-w")]), Self.at(run.time))
        Self.frames(run, for: 50, Self.onTheNotch)
        _ = try Self.press("eyebrow:working", in: run)

        let going = try #require(run.list.content.entries.first { $0.item.key == "needs:sr-b" })
        #expect(going.isGoing && going.height > 0 && going.height < going.item.height)
        #expect(Self.keys(run).suffix(3) == ["needs:sr-b", "turn:sr-t", "eyebrow:working"])
    }

    /// Needs you shows every turn, however long ago it ended, each on one line, and keeps showing them as the panel
    /// stays out: no "N earlier".
    @Test func needsYouShowsEveryTurnHoweverOld() {
        let run = Self.opened([Self.turn("sr-new", ago: 5), Self.turn("sr-old", ago: 90), Self.turn("sr-older", ago: 3000)])
        let shown = ["eyebrow:needsYou", "turn:sr-new", "turn:sr-old", "turn:sr-older"]

        #expect(Self.keys(run) == shown)
        Self.frames(run, for: 2000, Self.onTheNotch)
        #expect(Self.keys(run) == shown)
        #expect(run.list.content.items.dropFirst().allSatisfy { if case .line = $0 { true } else { false } })
    }

    // MARK: Held places

    /// A row whose turn ends while the card is out leaves its place in Working, folding away there, and folds in at
    /// its place among Needs you's turns.
    @Test func aRowMovingFromWorkingToLeesTurnFoldsOutAndIn() throws {
        let run = Self.opened([Self.turn("sr-t", ago: 5), Self.working("sr-w"), Self.working("sr-x")])

        _ = run.show(Self.board([Self.turn("sr-w", ago: 0), Self.turn("sr-t", ago: 5), Self.working("sr-x")]), Self.at(run.time))
        Self.frames(run, for: 100, Self.onTheNotch)

        let entries = run.list.content.entries
        let going = try #require(entries.first { $0.item.key == "sr-w" })
        let coming = try #require(entries.firstIndex { $0.item.key == "turn:sr-w" })
        let needsYou = try #require(entries.firstIndex { $0.item.key == "eyebrow:needsYou" })
        let working = try #require(entries.firstIndex { $0.item.key == "eyebrow:working" })

        #expect(going.isGoing)
        #expect(coming > needsYou && coming < working)
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
