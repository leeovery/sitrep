import CoreGraphics
import Foundation
@testable import SitRepPanel
import Testing

/// The card's sections, as board J lays them out: Needs you, Your turn, Working and Snoozed, each under its eyebrow with
/// its count, an empty one left out, a folded one its eyebrow alone, every row on one line and every your-turn row
/// shown, and nothing but the room over each eyebrow between them: no hairline.
struct SectionsTests {
    private static func session(_ id: String, _ kind: Session.Kind, project: String = "SitRep", lines: Int = 1, since: Double = 0) -> Session {
        Session(
            id: id, project: project, kind: kind,
            lines: (0 ..< lines).map { Session.Line(title: "\(id) \($0)", since: since + Double($0)) }, sub: ""
        )
    }

    /// Kit with one ask and Harness with three; two your turns; one working and one on its own work.
    private static let board = [
        session("kit", .needs), session("harness", .needs, lines: 3),
        session("fumi", .turn, project: "Fumi"), session("folio", .turn, project: "Folio"),
        session("doc", .working), session("boot", .onItsWork),
    ]

    private static func card(_ sessions: [Session] = board, folds: CardFolds = CardFolds()) -> [Item] {
        Item.card(sessions, folds: folds)
    }

    private static func eyebrows(_ items: [Item]) -> [Eyebrow] {
        items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }

    /// Harness's two asks asleep, in Snoozed, beside its row in Needs you.
    private static let asleep = session("harness", .snoozed, lines: 2)

    /// Snoozed is the card's last section, under Working, and folded at first to its eyebrow, which counts the asks it
    /// holds.
    @Test func snoozedIsTheLastSectionFoldedAtFirstCountingItsAsks() {
        let items = Self.card(Self.board + [Self.asleep])
        let snoozed = Self.eyebrows(items).last

        #expect(items.map(\.key).suffix(2) == ["boot", "eyebrow:snoozed"])
        #expect(snoozed == Eyebrow(section: .snoozed, count: 2, isFolded: true, above: 14))
    }

    /// Unfolded, its rows are on one line, each a row of its own beside the session's row elsewhere.
    @Test func unfoldedSnoozedsRowsAreOtherThanTheirSessionsRowsElsewhere() {
        let items = Self.card(Self.board + [Self.asleep], folds: CardFolds(sections: []))

        #expect(items.map(\.key).suffix(2) == ["eyebrow:snoozed", "snoozed:harness"])
        #expect(items.map(\.key).contains("needs:harness"))
        #expect(items.last == .line(Self.asleep))
        #expect(Self.asleep.headline.more == "2")
    }

    /// Each section under its eyebrow in the sections' order, and nothing between them: no hairline.
    @Test func eachSectionFollowsItsEyebrowWithNoHairline() {
        #expect(Self.card().map(\.key) == [
            "eyebrow:needsYou", "needs:kit", "needs:harness",
            "eyebrow:yourTurn", "turn:fumi", "turn:folio",
            "eyebrow:working", "doc", "boot",
        ])
    }

    /// No hairline, whichever sections show and whichever are folded.
    @Test func noHairlineWhateverShowsOrFolds() {
        let boards = [
            Self.board, Self.board + [Self.asleep], Self.board.filter { $0.section != .yourTurn },
            Self.board.filter { $0.section != .needsYou }, Self.board.filter(\.section.waitsOnLee),
        ]
        let folds = [CardFolds(), CardFolds(sections: []), CardFolds(sections: [.needsYou, .yourTurn])]

        for board in boards {
            for folded in folds {
                #expect(!Self.card(board, folds: folded).contains(.divider))
            }
        }
    }

    /// Needs you counts its waiting lines, the asks and stops, Kit's one and Harness's three; Your turn and Working
    /// count their rows, on its own work among Working's.
    @Test func needsYouCountsItsLinesAndTheOthersTheirRows() {
        #expect(Self.eyebrows(Self.card()).map(\.count) == [4, 2, 2])
    }

    @Test func anEmptySectionIsLeftOutWithItsEyebrow() {
        let noneWorking = Self.board.filter { $0.section != .working }

        #expect(Self.eyebrows(Self.card(noneWorking)).map(\.section) == [.needsYou, .yourTurn])
        #expect(Self.card([]).isEmpty)
    }

    /// The first eyebrow 4 under the card's top; every one after it 14 under the row above it, or the eyebrow above it
    /// where that section is folded, whichever sections they are.
    @Test func everyEyebrowAfterTheFirstSits14UnderWhatIsAboveIt() {
        let eyebrows = Self.eyebrows(Self.card(Self.board + [Self.asleep]))
        let folded = Self.eyebrows(Self.card(folds: CardFolds(sections: [.needsYou, .yourTurn])))
        let noTurns = Self.eyebrows(Self.card(Self.board.filter { $0.section != .yourTurn }))

        #expect(eyebrows.map(\.above) == [4, 14, 14, 14])
        #expect(eyebrows.map { Item.eyebrow($0).height } == [32, 42, 42, 42])
        #expect(folded.map(\.above) == [4, 14, 14])
        #expect(noTurns.map(\.above) == [4, 14])
        #expect(Self.eyebrows(Self.card(Self.board.filter { $0.section == .working })).map(\.above) == [4])
    }

    /// Folded, a section is its eyebrow alone, its count still told.
    @Test func aFoldedSectionIsItsEyebrowAlone() throws {
        let items = Self.card(folds: CardFolds(sections: [.working]))
        let working = try #require(Self.eyebrows(items).first { $0.section == .working })

        #expect(working.isFolded && working.count == 2)
        #expect(!items.contains { $0.session?.section == .working })
    }

    /// One shape: every row on one line, 30 tall with no gap, in every section.
    @Test func everyRowIsOnOneLine() {
        let items = Self.card(Self.board + [Self.asleep], folds: CardFolds(sections: []))
        let rows = items.filter { $0.session != nil }

        #expect(rows.allSatisfy { if case .line = $0 { true } else { false } })
        #expect(rows.compactMap(\.session?.id) == ["kit", "harness", "fumi", "folio", "doc", "boot", "harness"])
        #expect(rows.allSatisfy { $0.height == 30 && $0.margins == (0, 0) })
    }

    /// Your turn shows every row, however long ago its turn ended: no "N earlier".
    @Test func yourTurnShowsEveryRow() {
        let turns = (0 ..< 8).map { Self.session("t\($0)", .turn, since: Double($0) * -86_400_000) }
        let items = Self.card(turns)

        #expect(items.map(\.key) == ["eyebrow:yourTurn"] + turns.map { "turn:\($0.id)" })
        #expect(Self.eyebrows(items)[0].count == 8)
    }

    /// A row's key says its section, whatever its shape, so one moving from Working to Your turn folds away from one
    /// and in at the other.
    @Test func aRowsKeyChangesWithItsSection() {
        var ended = Self.board[4]
        ended.kind = .turn

        #expect(Item.line(Self.board[4]).key == "doc" && Item.session(Self.board[4]).key == "doc")
        #expect(Item.line(ended).key == "turn:doc")
        #expect(Set([Item.line(Self.board[4]).key, Item.line(ended).key, "needs:doc"]).count == 3)
    }

    // MARK: The menu's list

    /// The menu keeps its separator, a menu's own idiom: under what waits on Lee, Needs you and Your turn; with no Your
    /// turn, under Needs you; with neither, or nothing after them, none.
    @Test func theMenusHairlineFollowsWhatWaitsOnLee() {
        let keys = { (sessions: [Session]) in Item.list(sessions).map(\.key) }
        let noTurns = Self.board.filter { $0.section != .yourTurn }

        #expect(keys(Self.board) == ["needs:kit", "needs:harness", "turn:fumi", "turn:folio", "divider", "doc", "boot"])
        #expect(keys(noTurns) == ["needs:kit", "needs:harness", "divider", "doc", "boot"])
        #expect(!Item.list(Self.board.filter { $0.section == .working }).contains(.divider))
        #expect(!Item.list(Self.board.filter(\.section.waitsOnLee)).contains(.divider))
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
        let first = content.itemFrame(0), turn = content.itemFrame(3)

        #expect(content.item(at: CGPoint(x: 100, y: first.minY + 2)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: first.minY + 6)) == 0)
        #expect(content.item(at: CGPoint(x: 100, y: turn.minY + 13)) == nil)
        #expect(content.item(at: CGPoint(x: 100, y: turn.minY + 15)) == 3)
        #expect(content.item(at: CGPoint(x: 100, y: content.itemFrame(1).midY)) == 1)
    }
}
