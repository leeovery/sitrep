import CoreGraphics
@testable import SitRepPanel
import Testing

struct RowsTests {
    private static let minute = 60_000.0

    @Test func thePrototypesSessionsShowTheirAgesAsItDoes() {
        let ages = Item.prototype.compactMap(\.session).map { $0.ageText(at: 0) }

        #expect(ages == ["2h", "4m", "20m", "12m", "3m", "3h", "2d"])
    }

    @Test(arguments: [(0.98, "now"), (1, "1m"), (59.9, "59m"), (60, "1h"), (1439, "23h"), (1440, "1d"), (3000, "2d")] as [(Double, String)])
    func anAgeIsWholeMinutesHoursOrDays(minutes: Double, shown: String) {
        #expect(Session.ageText(minutes * Self.minute) == shown)
    }

    /// The strip's order, until it takes core's: needs you, oldest first, away ones last; your turn, newest first;
    /// working, longest running first.
    @Test func theSessionsSortInTheDesignsOrder() {
        let sessions = Item.prototype.compactMap(\.session).reversed()

        #expect(Session.sorted(Array(sessions)).map(\.id) == ["s1", "s2", "s7", "s3", "s6", "s4", "s5"])
    }

    /// Core orders the rows: the panel keeps them as given, the hairline under the needs you that lead.
    @Test func thePanelListsItsSessionsInTheOrderGiven() {
        let sessions = Item.prototype.compactMap(\.session).reversed()

        let ids = Item.list(Array(sessions)).map { $0.session?.id ?? "divider" }

        #expect(ids == ["s7", "divider", "s6", "s5", "s4", "s3", "s2", "s1"])
    }

    @Test func noHairlineWithoutBothNeedsYouAndTheRest() {
        let sessions = Item.prototype.compactMap(\.session)

        #expect(!Item.list(sessions.filter { $0.kind == .needs }).contains(.divider))
        #expect(!Item.list(sessions.filter { $0.kind != .needs }).contains(.divider))
    }

    @Test func theHeadSaysHowManyNeedLeeAndHowManySessionsThereAre() {
        #expect(Head(needYou: 3, sessions: 7) == Head(title: "3 need you", count: "7 sessions"))
        #expect(Head(needYou: 1, sessions: 1) == Head(title: "1 needs you", count: "1 session"))
        #expect(Head(needYou: 0, sessions: 4) == Head(title: "All clear", count: "4 sessions"))
    }

    @Test func thePanelsListIsLaidOutAsTheRowsAreDrawn() {
        #expect(Content(laying: Item.prototype) == Content.css)
    }

    /// The prototypes' list is 480 tall: in a panel showing 300 of it, it scrolls from its top to 180 down.
    @Test(arguments: [(0.0, 50.0, 50.0), (50, -80, 0), (100, 50, 150), (150, 40, 180), (180, 10, 180)])
    func theRowsScrollFromTheTopToWhereTheLastShowsAtTheFoot(_ offset: Double, _ delta: Double, _ scrolled: Double) {
        #expect(Content.css.height == 480)
        #expect(Content.css.scrolled(offset, by: delta, showing: 300) == scrolled)
    }

    @Test func aListThePanelHoldsWholeNeverScrolls() {
        #expect(Content.css.scrolled(0, by: 40, showing: 500) == 0)
    }

    @Test func theHeadSitsInsideTheScrollsPadding() {
        #expect(Content.css.headFrame == CGRect(x: 14, y: 18, width: 344, height: 26))
    }

    @Test func eachItemStacksUnderTheHeadAndThoseBeforeIt() {
        let content = Content.css

        #expect(content.items[2] == .divider)
        #expect(content.itemFrame(0) == CGRect(x: 14, y: 44, width: 344, height: 59))
        #expect(content.itemFrame(2) == CGRect(x: 14, y: 162, width: 344, height: 9))
        #expect(content.itemFrame(3) == CGRect(x: 14, y: 171, width: 344, height: 59))
    }

    @Test func measuredHeightsLayItOutToo() {
        let heights = [60.0, 60, 10, 60, 60, 60, 60, 60]
        let content = Content(headHeight: 30, entries: zip(Item.prototype, heights).map { Content.Entry($0, height: $1) })

        #expect(content.itemFrame(3) == CGRect(x: 14, y: 18 + 30 + 130, width: 344, height: 60))
    }

    @Test func aPointOnARowIsThatRow() {
        let content = Content.css

        #expect(content.row(at: CGPoint(x: 20, y: 50)) == 0)
        #expect(content.row(at: CGPoint(x: 350, y: 98)) == 0)
        #expect(content.row(at: CGPoint(x: 200, y: 190)) == 3)
    }

    @Test(arguments: [CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 165), CGPoint(x: 8, y: 50), CGPoint(x: 200, y: 30)])
    func theGapBelowARowTheDividerThePaddingAndTheHeadAreNoRow(_ point: CGPoint) {
        #expect(Content.css.row(at: point) == nil)
    }

    @Test func aRowFoldingAwayIsNoRowAndTakesNoClick() {
        var content = Content.css
        content.entries[0].isGoing = true

        #expect(content.row(at: CGPoint(x: 20, y: 50)) == nil)
        #expect(!content.entries[0].jumps)
        #expect(content.entries[1].jumps)
        #expect(!content.entries[2].jumps)
        #expect(!content.entries[7].jumps)
    }

    @Test func aSessionTakesTheLettersItIsGivenElseMakesItsOwn() {
        let given = Session(id: "", project: "SitRep", letters: "Si", kind: .turn, title: "", sub: "", since: 0)
        let made = Session(id: "", project: "SitRep", kind: .turn, title: "", sub: "", since: 0)

        #expect(given.letters == "Si")
        #expect(made.letters == "SR")
    }

    @Test(arguments: [(0.0, 60_000.0), (59_999, 60_000), (60_000, 120_000), (-30_000, 60_000), (5_400_000, 5_460_000)])
    func aRowsTimeMayNextReadDifferentlyAtItsNextWholeMinute(_ age: Double, changes: Double) {
        let session = Session(id: "", project: "SitRep", kind: .turn, title: "", sub: "", since: 1000)

        #expect(session.ageChanges(after: 1000 + age) == 1000 + changes)
    }

    @Test func eachItemIsKeyedBySessionTheHairlineByItself() {
        #expect(Content.css.items.map(\.key) == ["s1", "s2", "divider", "s3", "s4", "s5", "s6", "s7"])
    }
}
