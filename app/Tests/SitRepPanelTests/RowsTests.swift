import CoreGraphics
@testable import SitRepPanel
import Testing

struct RowsTests {
    private static let minute = 60_000.0

    @Test func theSampleSessionsShowTheirAgesAsThePrototypeDoes() {
        let ages = Item.samples.compactMap(\.session).map(\.ageText)

        #expect(ages == ["2h", "4m", "20m", "12m", "3m", "3h", "2d"])
    }

    @Test(arguments: [(0.98, "now"), (1, "1m"), (59.9, "59m"), (60, "1h"), (1439, "23h"), (1440, "1d"), (3000, "2d")] as [(Double, String)])
    func anAgeIsWholeMinutesHoursOrDays(minutes: Double, shown: String) {
        let session = Session(id: "s", kind: .quiet, title: "", code: nil, sub: "", age: minutes * Self.minute)

        #expect(session.ageText == shown)
    }

    @Test func theHeadCountsWhatNeedsLeeAndEverySession() {
        let head = Head(Item.samples)

        #expect(head.title == "2 need you")
        #expect(head.count == "7 sessions")
    }

    @Test func oneNeedingLeeNeedsHimAndNoneIsAllClear() {
        let sessions = Item.samples.compactMap(\.session)
        let one = sessions.filter { $0.kind != .needs || $0.id == "s1" }.map(Item.session)
        let none = sessions.filter { $0.kind != .needs }.map(Item.session)

        #expect(Head(one).title == "1 needs you")
        #expect(Head(none).title == "All clear")
        #expect(Head(none).count == "5 sessions")
    }

    @Test func theHeadSitsInsideTheScrollsPadding() {
        #expect(Content.css.headFrame == CGRect(x: 14, y: 18, width: 344, height: 26))
    }

    @Test func eachItemStacksUnderTheHeadAndThoseBeforeIt() {
        let content = Content.css

        #expect(Item.samples[2] == .divider)
        #expect(content.itemFrame(0) == CGRect(x: 14, y: 44, width: 344, height: 59))
        #expect(content.itemFrame(2) == CGRect(x: 14, y: 162, width: 344, height: 9))
        #expect(content.itemFrame(3) == CGRect(x: 14, y: 171, width: 344, height: 59))
    }

    @Test func measuredHeightsLayItOutToo() {
        let content = Content(headHeight: 30, itemHeights: [60, 60, 10, 60, 60, 60, 60, 60])

        #expect(content.itemFrame(3) == CGRect(x: 14, y: 18 + 30 + 130, width: 344, height: 60))
    }

    @Test func aPointOnARowIsThatRow() {
        let content = Content.css

        #expect(content.row(at: CGPoint(x: 20, y: 50), of: Item.samples) == 0)
        #expect(content.row(at: CGPoint(x: 350, y: 98), of: Item.samples) == 0)
        #expect(content.row(at: CGPoint(x: 200, y: 190), of: Item.samples) == 3)
    }

    @Test(arguments: [CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 165), CGPoint(x: 8, y: 50), CGPoint(x: 200, y: 30)])
    func theGapBelowARowTheDividerThePaddingAndTheHeadAreNoRow(_ point: CGPoint) {
        #expect(Content.css.row(at: point, of: Item.samples) == nil)
    }
}
