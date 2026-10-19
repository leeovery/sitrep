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

    /// Needs you, oldest first, away ones last; your turn, newest first; working, longest running first; the hairline
    /// under needs you.
    @Test func thePanelListsItsSessionsInTheDesignsOrder() {
        let sessions = Item.prototype.compactMap(\.session).reversed()

        let ids = Item.list(Array(sessions)).map { $0.session?.id ?? "divider" }

        #expect(ids == ["s1", "s2", "s7", "divider", "s3", "s6", "s4", "s5"])
    }

    @Test func noHairlineWithoutBothNeedsYouAndTheRest() {
        let sessions = Item.prototype.compactMap(\.session)

        #expect(!Item.list(sessions.filter { $0.kind == .needs }).contains(.divider))
        #expect(!Item.list(sessions.filter { $0.kind != .needs }).contains(.divider))
    }

    @Test func theHeadCountsWhatNeedsLeeAwayOrNotAndEverySession() {
        let head = Head(Item.prototype)

        #expect(head.title == "3 need you")
        #expect(head.count == "7 sessions")
    }

    @Test func oneNeedingLeeNeedsHimAndNoneIsAllClear() {
        let sessions = Item.prototype.compactMap(\.session)
        let one = sessions.filter { $0.kind != .needs || $0.id == "s1" }.map(Item.session)
        let none = sessions.filter { $0.kind != .needs }.map(Item.session)

        #expect(Head(one).title == "1 needs you")
        #expect(Head(none).title == "All clear")
        #expect(Head(none).count == "4 sessions")
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
}
