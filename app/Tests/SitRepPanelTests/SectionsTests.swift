import CoreGraphics
import Foundation
@testable import SitRepPanel
import Testing

/// The card's sections, as board D lays them out: Needs you, Working and Your turn, each under its eyebrow with its
/// count, an empty one left out, the hairline after Needs you, a folded one its eyebrow alone, and Your turn's rows past
/// the fold period under "N earlier".
struct SectionsTests {
    private static let hour = 3_600_000.0

    private static func session(_ id: String, _ kind: Session.Kind, project: String = "SitRep", lines: Int = 1, since: Double = 0) -> Session {
        Session(
            id: id, project: project, kind: kind,
            lines: (0 ..< lines).map { Session.Line(title: "\(id) \($0)", since: since + Double($0)) }, sub: ""
        )
    }

    /// Kit with one ask and Harness with three; one working and one on its own work; two your turns.
    private static let board = [
        session("kit", .needs), session("harness", .needs, lines: 3),
        session("doc", .working), session("boot", .onItsWork),
        session("fumi", .turn, project: "Fumi"), session("folio", .turn, project: "Folio"),
    ]

    private static func card(_ sessions: [Session] = board, folds: CardFolds = CardFolds(), earlier: Set<String> = []) -> [Item] {
        Item.card(sessions, folds: folds) { earlier.contains($0.id) }
    }

    private static func eyebrows(_ items: [Item]) -> [Eyebrow] {
        items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }

    /// Harness's two asks asleep, in Snoozed, beside its row in Needs you.
    private static let asleep = session("harness", .snoozed, lines: 2)

    /// Snoozed is the card's last section, under Your turn, 10 under it as Your turn is under Working, and folded at
    /// first to its eyebrow, which counts the asks it holds.
    @Test func snoozedIsTheLastSectionFoldedAtFirstCountingItsAsks() {
        let items = Self.card(Self.board + [Self.asleep])
        let snoozed = Self.eyebrows(items).last

        #expect(items.map(\.key).suffix(2) == ["turn:folio", "eyebrow:snoozed"])
        #expect(snoozed == Eyebrow(section: .snoozed, count: 2, isFolded: true, above: 10))
    }

    /// Unfolded, its rows are drawn whole, each a row of its own beside the session's row elsewhere.
    @Test func unfoldedSnoozedsRowsAreOtherThanTheirSessionsRowsElsewhere() {
        let items = Self.card(Self.board + [Self.asleep], folds: CardFolds(sections: []))

        #expect(items.map(\.key).suffix(2) == ["eyebrow:snoozed", "snoozed:harness"])
        #expect(items.map(\.key).contains("needs:harness"))
        #expect(items.last == .session(Self.asleep))
        #expect(Self.asleep.headline.more == "+1")
    }

    @Test func eachSectionFollowsItsEyebrowInTheSectionsOrder() {
        #expect(Self.card().map(\.key) == [
            "eyebrow:needsYou", "needs:kit", "needs:harness", "divider",
            "eyebrow:working", "doc", "boot",
            "eyebrow:yourTurn", "turn:fumi", "turn:folio",
        ])
    }

    /// Needs you counts its waiting lines, the asks and stops, Kit's one and Harness's three; Working and Your turn
    /// count their rows, on its own work among Working's.
    @Test func needsYouCountsItsLinesAndTheOthersTheirRows() {
        #expect(Self.eyebrows(Self.card()).map(\.count) == [4, 2, 2])
    }

    @Test func anEmptySectionIsLeftOutWithItsEyebrow() {
        let noneWorking = Self.board.filter { $0.section != .working }

        #expect(Self.eyebrows(Self.card(noneWorking)).map(\.section) == [.needsYou, .yourTurn])
        #expect(Self.card([]).isEmpty)
    }

    /// The hairline after Needs you, where another section follows, folded or not; none with Needs you alone, nor
    /// without it.
    @Test func theHairlineFollowsNeedsYouFoldedOrNot() {
        let folded = Self.card(folds: CardFolds(sections: [.needsYou]))

        #expect(folded.map(\.key).prefix(3) == ["eyebrow:needsYou", "divider", "eyebrow:working"])
        #expect(!Self.card(Self.board.filter { $0.section == .needsYou }).contains(.divider))
        #expect(!Self.card(Self.board.filter { $0.section != .needsYou }).contains(.divider))
    }

    /// The first eyebrow 4 under the card's top, the one after the hairline straight on, Your turn's 10 under Working.
    @Test func anEyebrowSitsUnderWhatIsAboveIt() {
        let eyebrows = Self.eyebrows(Self.card())

        #expect(eyebrows.map(\.above) == [4, 0, 10])
        #expect(eyebrows.map { Item.eyebrow($0).height } == [32, 28, 38])
        #expect(Self.eyebrows(Self.card(Self.board.filter { $0.section != .needsYou })).map(\.above) == [4, 10])
    }

    /// Folded, a section is its eyebrow alone, its count still told.
    @Test func aFoldedSectionIsItsEyebrowAlone() {
        let items = Self.card(folds: CardFolds(sections: [.working]))
        let working = Self.eyebrows(items)[1]

        #expect(working.isFolded && working.count == 2)
        #expect(!items.contains { $0.session?.section == .working })
    }

    /// A your-turn row on the card is one line, 30 tall with no gap; a row of Needs you or Working is drawn whole.
    @Test func yourTurnsRowsAreOneLine30Tall() {
        let items = Self.card()

        #expect(items.filter { if case .turn = $0 { true } else { false } }.map(\.height) == [30, 30])
        #expect(Item.session(Self.board[0]).height == 59)
        #expect(Item.turn(Self.board[4]).margins == (0, 0))
    }

    // MARK: N earlier

    private static let turns = [
        session("a", .turn, project: "Terrace"), session("b", .turn, project: "Fumi"),
        session("c", .turn, project: "Terrace"), session("d", .turn, project: "Fabric"),
    ]

    @Test func noEarlierLineWhileNoSessionIsPastThePeriod() {
        #expect(!Self.card(Self.turns).contains { $0.key == "earlier" })
    }

    /// Past the period, the sessions fold into one line at Your turn's end: its count, and their projects, each once,
    /// in the rows' order. Your turn's count still counts them.
    @Test func theSessionsPastThePeriodFoldIntoNEarlier() throws {
        let items = Self.card(Self.turns, earlier: ["b", "c", "d"])
        let line = try #require(items.last)

        #expect(items.map(\.key) == ["eyebrow:yourTurn", "turn:a", "earlier"])
        #expect(line == .earlier(Earlier([Self.turns[1], Self.turns[2], Self.turns[3]], isOpen: false)))
        guard case let .earlier(earlier) = line else {
            return
        }
        #expect(earlier.title == "3 earlier")
        #expect(earlier.projects == ["Fumi", "Terrace", "Fabric"])
        #expect(Self.eyebrows(items)[0].count == 4)
        #expect(line.height == 36 && line.margins == (2, 0))
    }

    /// Open, the earlier sessions show under it as ordinary your-turn rows, the line staying as their eyebrow.
    @Test func openTheEarlierSessionsShowUnderIt() {
        let items = Self.card(Self.turns, folds: CardFolds(isEarlierOpen: true), earlier: ["c", "d"])

        #expect(items.map(\.key) == ["eyebrow:yourTurn", "turn:a", "turn:b", "earlier", "turn:c", "turn:d"])
    }

    /// A row's key says its section, so one moving from Working to Your turn folds away from one and in at the other.
    @Test func aRowsKeyChangesWithItsSection() {
        var ended = Self.board[2]
        ended.kind = .turn

        #expect(Set([Item.session(Self.board[2]).key, Item.turn(ended).key, "needs:doc"]).count == 3)
    }

    @Test func aSectionFoldsAndUnfolds() {
        var folds = CardFolds(sections: [])

        folds.toggle(.working)
        #expect(folds.sections == [.working])
        folds.toggle(.working)
        #expect(folds.sections.isEmpty)
    }

    /// Snoozed starts folded, to its eyebrow and its count; the rest open.
    @Test func atFirstOnlySnoozedIsFolded() {
        #expect(CardFolds().sections == [.snoozed])
    }

    // MARK: The content

    /// With no head, the first eyebrow's box from board D's 12, under 4, so the first row stands at 44, where it stood
    /// under the head.
    @Test func withNoHeadTheFirstRowStandsWhereItStoodUnderTheHead() {
        let card = Content(laying: Self.card(), headed: false)
        let headed = Content(laying: Item.prototype)

        #expect(card.itemFrame(0) == CGRect(x: 14, y: 12, width: 344, height: 32))
        #expect(card.itemFrame(1).minY == headed.itemFrame(0).minY)
    }

    /// A click on an eyebrow or "N earlier" is on it, where it is drawn: never in the room over it.
    @Test func anEyebrowAndNEarlierTakeAClickWhereTheyAreDrawn() {
        let items = Self.card(Self.turns, earlier: ["d"])
        let content = Content(laying: items, headed: false)
        let eyebrow = content.itemFrame(0), earlier = content.itemFrame(4)

        #expect(content.item(at: CGPoint(x: 100, y: eyebrow.minY + 2)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: eyebrow.minY + 6)) == 0)
        #expect(content.item(at: CGPoint(x: 100, y: earlier.minY + 1)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: earlier.minY + 3)) == 4)
        #expect(content.item(at: CGPoint(x: 100, y: content.itemFrame(1).midY)) == 1)
    }
}

/// How long a your-turn row stays out: an hour, four hours, today or never, from its turn's end on the wall clock.
struct FoldPeriodTests {
    private static let hour = 3_600_000.0
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// 22 October 2026, 23:30 in London (BST, an hour ahead of UTC).
    private static let lateEvening = 1_792_708_200_000.0

    @Test(arguments: [(FoldPeriod.hour, 1.0), (.fourHours, 4)])
    func aRowFoldsThisLongAfterItsTurnEnded(period: FoldPeriod, hours: Double) {
        let since = 1_000_000.0

        #expect(period.folds(since, in: Self.london) == since + hours * Self.hour)
        #expect(!period.isPast(since, at: since + hours * Self.hour - 1, in: Self.london))
        #expect(period.isPast(since, at: since + hours * Self.hour, in: Self.london))
    }

    /// Today folds what ended before local midnight: a turn ended at 23:30 stays out until midnight, then folds.
    @Test func todayFoldsWhatEndedBeforeLocalMidnight() throws {
        let midnight = try #require(FoldPeriod.today.folds(Self.lateEvening, in: Self.london))

        #expect(midnight - Self.lateEvening == 30 * 60_000)
        #expect(!FoldPeriod.today.isPast(Self.lateEvening, at: midnight - 1, in: Self.london))
        #expect(FoldPeriod.today.isPast(Self.lateEvening, at: midnight, in: Self.london))
        // a turn ended at 00:10 the next day is today's, and stays out all that day
        #expect(!FoldPeriod.today.isPast(midnight + 600_000, at: midnight + 20 * Self.hour, in: Self.london))
    }

    @Test func todaysMidnightIsLocal() {
        var tokyo = Self.london
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        #expect(FoldPeriod.today.folds(Self.lateEvening, in: tokyo) != FoldPeriod.today.folds(Self.lateEvening, in: Self.london))
    }

    @Test func neverFoldsNothing() {
        #expect(FoldPeriod.never.folds(0, in: Self.london) == nil)
        #expect(!FoldPeriod.never.isPast(0, at: 1e15, in: Self.london))
    }
}
