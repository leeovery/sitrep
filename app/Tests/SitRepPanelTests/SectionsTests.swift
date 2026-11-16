import CoreGraphics
import Foundation
@testable import SitRepPanel
import Testing

/// The card's sections, as board J lays them out: Needs you, its asks then its turns (13 November 2026), Working and
/// Snoozed, each under its eyebrow with its count, an empty one left out, a folded one its eyebrow alone, every row on
/// one line and every your-turn row shown, and nothing but the room over each eyebrow between them: no hairline.
struct SectionsTests {
    private static func session(
        _ id: String, _ kind: Session.Kind, project: String = "Trey Research", lines: Int = 1, since: Double = 0,
        away: Bool = false
    ) -> Session {
        Session(
            id: id, project: project, kind: kind, away: away,
            lines: (0 ..< lines).map { Session.Line(title: "\(id) \($0)", since: since + Double($0)) }, sub: ""
        )
    }

    /// Litware with one ask and Tailspin with three; two your turns; one working and one on its own work.
    private static let board = [
        session("litware", .needs), session("tailspin", .needs, lines: 3),
        session("wingtip", .turn, project: "Wingtip"), session("alpine", .turn, project: "Alpine"),
        session("doc", .working), session("boot", .onItsWork),
    ]

    private static func card(_ sessions: [Session] = board, folds: CardFolds = CardFolds()) -> [Item] {
        Item.card(sessions, folds: folds)
    }

    private static func eyebrows(_ items: [Item]) -> [Eyebrow] {
        items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }

    /// Tailspin's two asks asleep, in Snoozed, beside its row in Needs you.
    private static let asleep = session("tailspin", .snoozed, lines: 2)

    /// Snoozed is the card's last section, under Working, and folded at first to its eyebrow, which counts the asks it
    /// holds.
    @Test func snoozedIsTheLastSectionFoldedAtFirstCountingItsAsks() {
        let items = Self.card(Self.board + [Self.asleep])
        let snoozed = Self.eyebrows(items).last

        #expect(items.map(\.key).suffix(2) == ["boot", "eyebrow:snoozed"])
        #expect(snoozed == Eyebrow(section: .snoozed, counts: [Eyebrow.Count(2)], isFolded: true, above: 14))
    }

    /// Unfolded, its rows are on one line, each a row of its own beside the session's row elsewhere.
    @Test func unfoldedSnoozedsRowsAreOtherThanTheirSessionsRowsElsewhere() {
        let items = Self.card(Self.board + [Self.asleep], folds: CardFolds(sections: []))

        #expect(items.map(\.key).suffix(2) == ["eyebrow:snoozed", "snoozed:tailspin"])
        #expect(items.map(\.key).contains("needs:tailspin"))
        #expect(items.last == .line(Self.asleep))
        #expect(Self.asleep.headline.more == "2")
    }

    /// Each section under its eyebrow in the sections' order, your turns in Needs you under its asks, with no section
    /// of their own, and nothing between them: no hairline.
    @Test func eachSectionFollowsItsEyebrowWithNoHairline() {
        #expect(Self.card().map(\.key) == [
            "eyebrow:needsYou", "needs:litware", "needs:tailspin", "turn:wingtip", "turn:alpine",
            "eyebrow:working", "doc", "boot",
        ])
    }

    /// Needs you's asks first, then its turns, each those this Mac shows before the away ones, in core's order, newest
    /// first; so a session held where this Mac doesn't show it, which core has among those it shows, leads the away
    /// ones. The rest after them, in core's order.
    @Test func needsYouHoldsItsAsksThenItsTurnsEachHereBeforeAway() {
        let rows = [
            Self.session("newTurn", .turn, since: 8), Self.session("heldTurn", .turn, since: 7, away: true),
            Self.session("oldTurn", .turn, since: 1),
            Self.session("newAsk", .needs, since: 6), Self.session("heldAsk", .needs, since: 5, away: true),
            Self.session("oldAsk", .needs, since: 4), Self.session("awayAsk", .needs, since: 9, away: true),
            Self.session("doc", .working, since: 2), Self.session("boot", .onItsWork, since: 3),
        ]

        #expect(rows.inPanelOrder().map(\.id) == [
            "newAsk", "oldAsk", "heldAsk", "awayAsk", "newTurn", "oldTurn", "heldTurn", "doc", "boot",
        ])
    }

    /// No hairline, whichever sections show and whichever are folded.
    @Test func noHairlineWhateverShowsOrFolds() {
        let boards = [
            Self.board, Self.board + [Self.asleep], Self.board.filter { $0.kind != .turn },
            Self.board.filter { $0.section != .needsYou }, Self.board.filter { $0.section == .needsYou },
        ]
        let folds = [CardFolds(), CardFolds(sections: []), CardFolds(sections: [.needsYou, .working])]

        for board in boards {
            for folded in folds {
                #expect(!Self.card(board, folds: folded).contains(.divider))
            }
        }
    }

    /// Needs you counts what waits on Lee in two, the asks first, each only above zero: its asks, the lines of
    /// Litware's one and Tailspin's three, and its stopped, the two sessions at his turn; with neither, there is no
    /// Needs you and no eyebrow for it. Working counts its rows whole, on its own work among them.
    @Test func needsYouCountsItsAsksAndItsStoppedApartEachAboveZero() {
        let asks = Self.board.filter { $0.kind == .needs }, stopped = Self.board.filter { $0.kind == .turn }
        let working = Self.board.filter { $0.section == .working }
        let counts = { (board: [Session]) in Self.eyebrows(Self.card(board)).first { $0.section == .needsYou }?.counts }

        #expect(counts(asks) == [Eyebrow.Count(4, need: .ask)])
        #expect(counts(stopped) == [Eyebrow.Count(2, need: .turn)])
        #expect(Self.eyebrows(Self.card()).map(\.counts) == [
            [Eyebrow.Count(4, need: .ask), Eyebrow.Count(2, need: .turn)], [Eyebrow.Count(2)],
        ])
        #expect(counts(working) == nil)
    }

    @Test func anEmptySectionIsLeftOutWithItsEyebrow() {
        let noneWorking = Self.board.filter { $0.section != .working }

        #expect(Self.eyebrows(Self.card(noneWorking)).map(\.section) == [.needsYou])
        #expect(Self.card([]).isEmpty)
    }

    /// The first eyebrow 4 under the card's top; every one after it 14 under the row above it, or the eyebrow above it
    /// where that section is folded, whichever sections they are.
    @Test func everyEyebrowAfterTheFirstSits14UnderWhatIsAboveIt() {
        let eyebrows = Self.eyebrows(Self.card(Self.board + [Self.asleep]))
        let folded = Self.eyebrows(Self.card(folds: CardFolds(sections: [.needsYou, .working])))
        let noTurns = Self.eyebrows(Self.card(Self.board.filter { $0.kind != .turn }))

        #expect(eyebrows.map(\.above) == [4, 14, 14])
        #expect(eyebrows.map { Item.eyebrow($0).height } == [32, 42, 42])
        #expect(folded.map(\.above) == [4, 14])
        #expect(noTurns.map(\.above) == [4, 14])
        #expect(Self.eyebrows(Self.card(Self.board.filter { $0.section == .working })).map(\.above) == [4])
    }

    /// Folded, a section is its eyebrow alone, its count still told.
    @Test func aFoldedSectionIsItsEyebrowAlone() throws {
        let items = Self.card(folds: CardFolds(sections: [.working]))
        let working = try #require(Self.eyebrows(items).first { $0.section == .working })

        #expect(working.isFolded && working.counts == [Eyebrow.Count(2)])
        #expect(!items.contains { $0.session?.section == .working })
    }

    /// One shape: every row on one line, 30 tall with no gap, in every section.
    @Test func everyRowIsOnOneLine() {
        let items = Self.card(Self.board + [Self.asleep], folds: CardFolds(sections: []))
        let rows = items.filter { $0.session != nil }

        #expect(rows.allSatisfy { if case .line = $0 { true } else { false } })
        #expect(rows.compactMap(\.session?.id) == ["litware", "tailspin", "wingtip", "alpine", "doc", "boot", "tailspin"])
        #expect(rows.allSatisfy { $0.height == 30 && $0.margins == (0, 0) })
    }

    /// Needs you shows every turn, however long ago it ended: no "N earlier".
    @Test func needsYouShowsEveryTurn() {
        let turns = (0 ..< 8).map { Self.session("t\($0)", .turn, since: Double($0) * -86_400_000) }
        let items = Self.card(turns)

        #expect(items.map(\.key) == ["eyebrow:needsYou"] + turns.map { "turn:\($0.id)" })
        #expect(Self.eyebrows(items)[0].counts == [Eyebrow.Count(8, need: .turn)])
    }

    /// A row's key says its section, whatever its shape, and in Needs you whether it is an ask's or a turn's, so one
    /// moving from Working to Lee's turn, or from his turn to an ask, folds away from one place and in at the other.
    @Test func aRowsKeyChangesWithItsSectionAndItsNeed() {
        var ended = Self.board[4], asked = Self.board[4]
        ended.kind = .turn
        asked.kind = .needs

        #expect(Item.line(Self.board[4]).key == "doc" && Item.session(Self.board[4]).key == "doc")
        #expect(Item.line(ended).key == "turn:doc" && Item.line(asked).key == "needs:doc")
        #expect(ended.section == asked.section)
    }

    // MARK: The menu's list

    /// The menu keeps its separator, a menu's own idiom: under Needs you, its asks and its turns; with none in it, or
    /// nothing after it, none.
    @Test func theMenusHairlineFollowsNeedsYou() {
        let keys = { (sessions: [Session]) in Item.list(sessions).map(\.key) }
        let noTurns = Self.board.filter { $0.kind != .turn }

        #expect(keys(Self.board) == ["needs:litware", "needs:tailspin", "turn:wingtip", "turn:alpine", "divider", "doc", "boot"])
        #expect(keys(noTurns) == ["needs:litware", "needs:tailspin", "divider", "doc", "boot"])
        #expect(!Item.list(Self.board.filter { $0.section == .working }).contains(.divider))
        #expect(!Item.list(Self.board.filter { $0.section == .needsYou }).contains(.divider))
        #expect(Item.list(Self.board).allSatisfy { if case .line = $0 { false } else { true } })
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

    /// A click on an eyebrow is on it, where it is drawn: never in the room over it.
    @Test func anEyebrowTakesAClickWhereItIsDrawn() {
        let content = Content(laying: Self.card(), headed: false)
        let first = content.itemFrame(0), working = content.itemFrame(5)

        #expect(content.item(at: CGPoint(x: 100, y: first.minY + 2)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: first.minY + 6)) == 0)
        #expect(content.item(at: CGPoint(x: 100, y: working.minY + 13)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: working.minY + 15)) == 5)
        #expect(content.item(at: CGPoint(x: 100, y: content.itemFrame(1).midY)) == 1)
    }
}
