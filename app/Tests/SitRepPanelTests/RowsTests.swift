import CoreGraphics
@testable import SitRepPanel
import Testing

struct RowsTests {
    private static let minute = 60_000.0

    /// Tailspin's three asks, an hour apart, the newest first, as core has them.
    private static let tailspin = Session(
        id: "sr-4t2kq8", project: "Tailspin", name: "Finish the Tailspin migration", kind: .needs,
        lines: [
            Session.Line(title: "Which branch?", more: "+1", since: 120 * minute),
            Session.Line(title: "Choose the release notes' grouping", since: 60 * minute),
            Session.Line(title: "Approve the first fix batch", since: 0),
        ],
        sub: "Tailspin"
    )

    /// A row needing Lee says its session, on every surface: its name, its newest line's time, and "3" for its three
    /// lines waiting; none of its lines' words.
    @Test func aRowNeedingLeeShowsItsSessionsNameThenHowManyWait() {
        #expect(Self.tailspin.title == "Finish the Tailspin migration")
        #expect(Self.tailspin.code == nil && Self.tailspin.subject == nil)
        #expect(Self.tailspin.since == 120 * Self.minute)
        #expect(Self.tailspin.ageText(at: 180 * Self.minute) == "1h")
        #expect(Self.tailspin.more == "3")
    }

    /// One line waiting shows no count: a permission prompt's command and a question's own "+2", whose words the row
    /// does not show, show nowhere on it.
    @Test func aRowNeedingLeeOfOneLineShowsItsNameAlone() {
        let question = Session(
            id: "q", project: "Litware", name: "The bootstrap", kind: .needs, title: "Which edge?", more: "+2", sub: "",
            since: 0
        )
        let prompt = Session(
            id: "p", project: "Litware", name: "The bootstrap", kind: .needs, title: "Allow Bash ", code: "gh pr create",
            sub: "", since: 0
        )

        #expect(question.title == "The bootstrap" && question.more == nil)
        #expect(prompt.title == "The bootstrap" && prompt.code == nil)
    }

    /// Any other row says its one line, as it did.
    @Test func anyOtherRowShowsItsOneLine() {
        let working = Session(
            id: "w", project: "Litware", name: "The bootstrap", kind: .working, title: "Editing ", code: "app/Litware.swift",
            sub: "Litware · The bootstrap", since: 0
        )

        #expect(working.headline == working.lines[0])
        #expect(working.title == "Editing " && working.code == "app/Litware.swift" && working.more == nil)
    }

    /// Only its time shows: the row may next read differently as its newest line's ticks, not its others'.
    @Test func aRowsWordsMayNextReadDifferentlyAsItsTimeTicks() {
        var staggered = Self.tailspin

        staggered.lines[0].since = 0
        staggered.lines[1].since = 30_000
        #expect(staggered.changes(after: 40_000) == 60_000)
        #expect(staggered.changes(after: 70_000) == 120_000)
    }

    /// A row of three lines is one row of one line's height, 49 and the 4 under it, the pointer anywhere on it over
    /// the one row.
    @Test func aRowOfSeveralLinesIsOneRowOfOneLinesHeight() {
        let content = Content(laying: [.session(Self.tailspin), .divider])
        let row = content.itemFrame(0)

        #expect(row.height == 53)
        #expect(content.height == 18 + 26 + 53 + 9 + 14)
        #expect([1.0, 25, 48].allSatisfy { content.item(at: CGPoint(x: row.midX, y: row.minY + $0)) == 0 })
        #expect(content.item(at: CGPoint(x: row.midX, y: row.minY + 51)) == nil)
    }

    @Test func thePrototypesSessionsShowTheirAgesAsItDoes() {
        let ages = Item.prototype.compactMap(\.session).map { $0.ageText(at: 0) }

        #expect(ages == ["2h", "4m", "20m", "12m", "3m", "3h", "2d"])
    }

    @Test(arguments: [(0.98, "now"), (1, "1m"), (59.9, "59m"), (60, "1h"), (1439, "23h"), (1440, "1d"), (3000, "2d")] as [(Double, String)])
    func anAgeIsWholeMinutesHoursOrDays(minutes: Double, shown: String) {
        #expect(Session.ageText(minutes * Self.minute) == shown)
    }

    /// Core orders the rows: the panel keeps them as given, the hairline under what waits on Lee that leads them, the
    /// needs you and your turn.
    @Test func thePanelListsItsSessionsInTheOrderGiven() {
        let sessions = Item.prototype.compactMap(\.session).reversed()

        let ids = Item.list(Array(sessions)).map { $0.session?.id ?? "divider" }

        #expect(ids == ["s7", "s6", "divider", "s5", "s4", "s3", "s2", "s1"])
    }

    @Test func noHairlineWithoutBothWhatWaitsOnLeeAndTheRest() {
        let sessions = Item.prototype.compactMap(\.session)

        #expect(!Item.list(sessions.filter { $0.kind != .working }).contains(.divider))
        #expect(!Item.list(sessions.filter { $0.kind == .working }).contains(.divider))
    }

    @Test func theHeadSaysHowManyNeedLeeAndHowManySessionsThereAre() {
        #expect(Head(needYou: 3, sessions: 7) == Head(title: "3 need you", count: "7 sessions"))
        #expect(Head(needYou: 1, sessions: 1) == Head(title: "1 needs you", count: "1 session"))
        #expect(Head(needYou: 0, sessions: 4) == Head(title: "All clear", count: "4 sessions"))
    }

    /// As the prototypes' CSS, but for each row 6 shorter, since Lee found them too spaced on 26 October 2026: 7 over
    /// its two lines and 8 under them, not 10 and 11.
    @Test func thePanelsListIsLaidOutAsTheRowsAreDrawn() {
        var drawn = Content.css

        drawn.entries = drawn.entries.map { $0.item.session == nil ? $0 : Content.Entry($0.item, height: $0.height - 6) }
        #expect(Content(laying: Item.prototype) == drawn)
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

        #expect(content.item(at: CGPoint(x: 20, y: 50)) == 0)
        #expect(content.item(at: CGPoint(x: 350, y: 98)) == 0)
        #expect(content.item(at: CGPoint(x: 200, y: 190)) == 3)
    }

    @Test(arguments: [CGPoint(x: 200, y: 100), CGPoint(x: 200, y: 165), CGPoint(x: 8, y: 50), CGPoint(x: 200, y: 30)])
    func theGapBelowARowTheDividerThePaddingAndTheHeadAreNoRow(_ point: CGPoint) {
        #expect(Content.css.item(at: point) == nil)
    }

    @Test func aRowFoldingAwayIsNoRowAndTakesNoClick() {
        var content = Content.css
        content.entries[0].isGoing = true

        #expect(content.item(at: CGPoint(x: 20, y: 50)) == nil)
        #expect(!content.entries[0].jumps)
        #expect(content.entries[1].jumps)
        #expect(!content.entries[2].jumps)
        #expect(content.entries[7].jumps, "an away row's carries its session on")
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
        let wake = Session(id: "", project: "Litware", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)
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
        let wake = Session(id: "", project: "Litware", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)

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
        let wake = Session(id: "", project: "Litware", kind: .onItsWork, title: "Wakes ", until: Self.wake, sub: "", since: 0)

        #expect(wake.countdownRoom(after: now) == room)
    }

    /// Three days on from 0, ms.
    private static let wake = 3 * 86_400_000.0

    @Test func aRowWithNoWakeLeavesNoRoomForACountdown() {
        #expect(Session(id: "", project: "Litware", kind: .onItsWork, title: "Waiting on ", subject: "3 agents", sub: "", since: 0)
            .countdownRoom(after: 0).isEmpty)
    }

    /// Alone, as a count's rows show no time: a minute before the wake, then as it comes due, then never.
    @Test(arguments: [(0.0, 40_000.0), (970_000, 1_000_000), (1_000_000, nil), (2_000_000, nil)] as [(Double, Double?)])
    func aWakesCountdownAloneNextReadsDifferentlyUntilItIsDue(_ now: Double, changes: Double?) {
        let wake = Session(id: "", project: "Litware", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)

        #expect(wake.countdownChanges(after: now) == changes)
    }

    @Test func eachItemIsKeyedBySessionTheHairlineByItself() {
        #expect(Content.css.items.map(\.key) == ["needs:s1", "needs:s2", "divider", "turn:s3", "s4", "s5", "turn:s6", "needs:s7"])
    }
}
