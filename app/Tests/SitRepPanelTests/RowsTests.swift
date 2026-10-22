import CoreGraphics
@testable import SitRepPanel
import Testing

struct RowsTests {
    private static let minute = 60_000.0

    /// Harness's three asks, an hour apart, the oldest first.
    private static let harness = Session(
        id: "sr-4g01a7", project: "Harness", kind: .needs,
        lines: [
            Session.Line(title: "Approve the first fix batch", since: 0),
            Session.Line(title: "Choose the release notes' grouping", since: 60 * minute),
            Session.Line(title: "Which branch?", more: "+1", since: 120 * minute),
        ],
        sub: "Harness · Finish the Harness modernisation"
    )

    /// Where there is room for one line, as on the strip and in the menu: the oldest, its time, and "+2" for the two
    /// after it, in place of a question's own count; a session of one line shows its question's "+2" as it is.
    @Test func withRoomForOneLineASessionShowsItsOldestThenHowManyMore() {
        let question = Session(id: "q", project: "Kit", kind: .needs, title: "Which edge?", more: "+2", sub: "", since: 0)

        #expect(Self.harness.title == "Approve the first fix batch")
        #expect(Self.harness.since == 0)
        #expect(Self.harness.ageText(at: 180 * Self.minute) == "3h")
        #expect(Self.harness.moreOnOneLine == "+2")
        #expect(question.moreOnOneLine == "+2")
        #expect(Session(id: "t", project: "Kit", kind: .turn, title: "Done", sub: "", since: 0).moreOnOneLine == nil)
    }

    /// Each line's time ticks on its own minute: the row may next read differently at the soonest of them.
    @Test func aRowsWordsMayNextReadDifferentlyAtItsSoonestLinesChange() {
        var staggered = Self.harness

        staggered.lines[1].since = 30_000
        #expect(staggered.changes(after: 40_000) == 60_000)
        #expect(staggered.changes(after: 70_000) == 90_000)
    }

    /// A row of three lines: 99 and the 4 under it, the content's height with it, and the pointer anywhere on any of
    /// its lines over the one row.
    @Test func aRowOfSeveralLinesIsOneRowAsTallAsThem() {
        let content = Content(laying: [.session(Self.harness), .divider])
        let row = content.itemFrame(0)

        #expect(row.height == 103)
        #expect(content.height == 18 + 26 + 103 + 9 + 14)
        #expect([10.0, 40, 72, 95].allSatisfy { content.row(at: CGPoint(x: row.midX, y: row.minY + $0)) == 0 })
        #expect(content.row(at: CGPoint(x: row.midX, y: row.minY + 100)) == nil)
    }

    @Test func thePrototypesSessionsShowTheirAgesAsItDoes() {
        let ages = Item.prototype.compactMap(\.session).map { $0.ageText(at: 0) }

        #expect(ages == ["2h", "4m", "20m", "12m", "3m", "3h", "2d"])
    }

    @Test(arguments: [(0.98, "now"), (1, "1m"), (59.9, "59m"), (60, "1h"), (1439, "23h"), (1440, "1d"), (3000, "2d")] as [(Double, String)])
    func anAgeIsWholeMinutesHoursOrDays(minutes: Double, shown: String) {
        #expect(Session.ageText(minutes * Self.minute) == shown)
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

        #expect(session.lines[0].ageChanges(after: 1000 + age) == 1000 + changes)
    }

    /// A wake's countdown, from its time left: up to the whole minute, then as the time lane counts, and "now" once due.
    @Test(arguments: [
        (720_000.0, "in 12m"), (690_000, "in 12m"), (660_001, "in 12m"), (660_000, "in 11m"), (30_000, "in 1m"),
        (1, "in 1m"), (0, "now"), (-5_000, "now"), (5_400_000, "in 1h"), (90_000_000, "in 1d"),
    ])
    func aWakesCountdownReadsUpToTheWholeMinute(_ left: Double, reads: String) {
        #expect(Session.untilText(left) == reads)
    }

    @Test func aRowWaitingOnAWakeSaysItsCountdownElseItsSubject() {
        let wake = Session(id: "", project: "Kit", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)
        let agents = Session(id: "", project: "SitRep", kind: .onItsWork, title: "Waiting on ", subject: "3 agents", sub: "", since: 0)

        #expect(wake.subject(at: 1_000_000 - 690_000) == "in 12m")
        #expect(wake.subject(at: 1_000_000) == "now")
        #expect(agents.subject(at: 0) == "3 agents")
    }

    /// Its words may next read differently at the sooner of its time's next whole minute and its countdown's next,
    /// which passes a whole minute before the wake, then comes due, then reads so for good.
    @Test(arguments: [
        (0.0, 40_000.0), (40_000, 60_000), (60_000, 100_000), (970_000, 1_000_000), (1_000_000, 1_020_000),
    ])
    func aRowWaitingOnAWakeMayNextReadDifferentlyAsItsCountdownOrItsTimeTicks(_ now: Double, changes: Double) {
        let wake = Session(id: "", project: "Kit", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)

        #expect(wake.changes(after: now) == changes)
    }

    @Test func aRowWaitingOnNoWakeMayNextReadDifferentlyAsItsTimeTicks() {
        let agents = Session(id: "", project: "SitRep", kind: .onItsWork, title: "Waiting on ", subject: "3", sub: "", since: 0)

        #expect(agents.changes(after: 40_000) == agents.lines[0].ageChanges(after: 40_000))
        #expect(agents.countdownChanges(after: 40_000) == nil)
    }

    /// Its reading now, then the widest of each smaller unit to come, as days give way to hours and hours to minutes.
    @Test(arguments: [
        (0.0, ["in 3d", "in 23h", "in 59m"]), (86_400_000, ["in 2d", "in 23h", "in 59m"]),
        (Self.wake - 86_400_000, ["in 1d", "in 23h", "in 59m"]), (Self.wake - 86_340_000, ["in 23h", "in 59m"]),
        (Self.wake - 3_600_000, ["in 1h", "in 59m"]), (Self.wake - 3_540_001, ["in 1h", "in 59m"]),
        (Self.wake - 3_540_000, ["in 59m"]), (Self.wake - 1, ["in 1m"]), (Self.wake, ["now"]),
    ] as [(Double, [String])])
    func aRowLeavesRoomForTheWidestItsWakesCountdownMayYetRead(_ now: Double, room: [String]) {
        let wake = Session(id: "", project: "Kit", kind: .onItsWork, title: "Wakes ", until: Self.wake, sub: "", since: 0)

        #expect(wake.countdownRoom(after: now) == room)
    }

    /// Three days on from 0, ms.
    private static let wake = 3 * 86_400_000.0

    @Test func aRowWithNoWakeLeavesNoRoomForACountdown() {
        #expect(Session(id: "", project: "Kit", kind: .onItsWork, title: "Waiting on ", subject: "3 agents", sub: "", since: 0)
            .countdownRoom(after: 0).isEmpty)
    }

    /// Alone, as a count's rows show no time: a minute before the wake, then as it comes due, then never.
    @Test(arguments: [(0.0, 40_000.0), (970_000, 1_000_000), (1_000_000, nil), (2_000_000, nil)] as [(Double, Double?)])
    func aWakesCountdownAloneNextReadsDifferentlyUntilItIsDue(_ now: Double, changes: Double?) {
        let wake = Session(id: "", project: "Kit", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)

        #expect(wake.countdownChanges(after: now) == changes)
    }

    @Test func eachItemIsKeyedBySessionTheHairlineByItself() {
        #expect(Content.css.items.map(\.key) == ["s1", "s2", "divider", "s3", "s4", "s5", "s6", "s7"])
    }
}
