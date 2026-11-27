import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Where the asks panel lays out an ask, as Paper's boards F and H3 have it: 12 over its top line of 28, 14 between
/// its parts, the title's lines of 22 and the age's 16 under it, answers' rows six apart, each 38 or as tall as its
/// two lines of 18 with 9 above and below, their words 12 from the left and 40 from the right, the keycap's room, and
/// the keycap there, the held answer's check in it, the foot's 28 and 14 under it; a words ask's foot straight under
/// its age;
/// Snooze ▾ only while Snooze offers a time; the page dots, following a slide, and the clicks each takes; what else
/// takes a click; where it stands beside its row, kept on the screen, at the height a slide gives it; and the row's
/// arrow.
@Suite(.backstop)
struct AsksLayoutTests {
    private static let measure = AsksMeasure(titleLines: { _ in 1 }, footWidth: { Double($0.count) * 7 })
    private static let choice = PanelAsk(
        id: "k1", title: "Thread replies?", wants: .choice, answers: ["Threaded", "Flat"], since: 0
    )
    private static let words = PanelAsk(id: "k2", title: "Say what an empty rota should read", wants: .words, since: 0)
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)

    @Test func aChoiceOfTwoOnOneLineIs248Tall() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)

        #expect(layout.height == 12 + 28 + 14 + (22 + 4 + 16) + 14 + (38 + 6 + 38) + 14 + 28 + 14)
        #expect(layout.answers.map(\.minY) == [110, 154])
        #expect(layout.answers.allSatisfy { $0.minX == 12 && $0.width == 348 && $0.height == 38 })
        #expect(layout.title == CGRect(x: 22, y: 54, width: 328, height: 22))
    }

    /// A row of two lines is 9 + 2 × 18 + 9 = 54 tall, the rows under it and the foot moved down by the 16 it grows; an
    /// answer measured past two lines takes two. The measure is told which answer is Claude's pick, as its tag wraps
    /// with its words.
    @Test func anAnswerRowGrowsToTheTwoLinesItsWordsWrapTo() {
        let pick = PanelAsk(
            id: "k1", title: "Thread replies?", wants: .choice, answers: ["Threaded", "Flat", "Off"],
            recommended: "Threaded", since: 0
        )
        let lines = AsksMeasure(
            titleLines: { _ in 1 }, answerLines: { answer, isPick in isPick ? 2 : answer == "Off" ? 7 : 1 },
            footWidth: { Double($0.count) * 7 }
        )
        let layout = AsksLayout(pick, measure: lines)
        let oneLine = AsksLayout(pick, measure: Self.measure)

        #expect(layout.answerLines == [2, 1, 2])
        #expect(layout.answers.map(\.height) == [54, 38, 54])
        #expect(layout.answers.map(\.minY) == [110, 170, 214])
        #expect(layout.foot.minY == layout.answers[2].maxY + 14)
        #expect(layout.height == oneLine.height + 32)
    }

    /// Its lines on the row's middle, 12 in from its left and 40 from its right, keycap or none, so its words wrap
    /// alike as keycaps come and go.
    @Test func anAnswersLinesSitOnItsRowsMiddleLeavingItsKeycapRoom() {
        let row = CGSize(width: 348, height: 54)

        #expect(AsksLayout.answerWidth == 296)
        #expect(AsksLayout.answerBoxes(in: row, lines: 2) == [
            CGRect(x: 12, y: 9, width: 296, height: 18), CGRect(x: 12, y: 27, width: 296, height: 18),
        ])
        #expect(AsksLayout.answerBoxes(in: CGSize(width: 348, height: 38), lines: 1) == [
            CGRect(x: 12, y: 10, width: 296, height: 18),
        ])
    }

    /// The keycap 20 across, 12 in from the row's right, centred on its first line, clear of the words' 40; the held
    /// answer's check 11 across, centred in the keycap's room.
    @Test func theKeycapEndsTheRowOnItsFirstLineAndTheCheckTakesItsRoom() {
        let one = CGSize(width: 348, height: 38), two = CGSize(width: 348, height: 54)
        let firstLine = AsksLayout.answerBoxes(in: two, lines: 2)[0]

        #expect(AsksLayout.keycap(in: one, lines: 1) == CGRect(x: 316, y: 9, width: 20, height: 20))
        #expect(AsksLayout.keycap(in: two, lines: 2) == CGRect(x: 316, y: 8, width: 20, height: 20))
        #expect(AsksLayout.keycap(in: two, lines: 2).midY == firstLine.midY)
        #expect(AsksLayout.keycap(in: one, lines: 1).minX >= 12 + AsksLayout.answerWidth)
        #expect(AsksLayout.check(in: one, lines: 1) == CGRect(x: 320.5, y: 13.5, width: 11, height: 11))
        #expect(AsksLayout.check(in: two, lines: 2) == CGRect(x: 320.5, y: 12.5, width: 11, height: 11))
    }

    /// Lee switched every Snooze time off, or each has passed for today: no Snooze ▾, and nothing takes a click where
    /// it stood; Ignore and Open in Claude stand as they were.
    @Test func withNoSnoozeTimeOfferedItsFootHasNoSnooze() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure, offersSnooze: false)
        let offered = AsksLayout(Self.choice, measure: Self.measure)
        let snooze = try #require(offered.snooze)

        #expect(layout.snooze == nil)
        #expect(layout.part(at: CGPoint(x: snooze.midX, y: snooze.midY), sending: false, page: 0, of: 1) == nil)
        #expect(layout.ignore == offered.ignore && layout.open == offered.open && layout.height == offered.height)
    }

    @Test func aTitleTakesTheLinesItWrapsToAtMostThree() {
        let three = AsksLayout(Self.choice, measure: AsksMeasure(titleLines: { _ in 5 }, footWidth: { _ in 30 }))

        #expect(three.titleLines == 3 && three.title.height == 66)
        #expect(three.height == AsksLayout(Self.choice, measure: Self.measure).height + 44)
    }

    /// No row answering in Claude: its foot, Open in Claude at its right, 14 under its age.
    @Test func aWordsAskHasNoRowsItsFootUnderItsAge() {
        let layout = AsksLayout(Self.words, measure: Self.measure)

        #expect(layout.answers.isEmpty)
        #expect(layout.foot.minY == layout.age.maxY + 14)
        #expect(layout.open.maxX == 360 && layout.open.midY == layout.foot.midY)
        #expect(layout.height == 12 + 28 + 14 + (22 + 4 + 16) + 14 + 28 + 14)
        let open = CGPoint(x: layout.open.midX, y: layout.open.midY)

        #expect(layout.part(at: open, sending: false, page: 0, of: 1) == .open)
    }

    @Test func itsFootSitsUnderTheAnswersOpenInClaudeAtTheRight() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure), open = layout.open

        #expect(layout.ignore.minX == 14 && layout.ignore.width == 16 + 42)
        #expect(try #require(layout.snooze).minX == layout.ignore.maxX + 2)
        #expect(open.maxX == 360 && open.height == 26 && open.midY == layout.foot.midY)
        #expect(layout.undo.maxX == 360)
    }

    @Test func eachPartTakesItsClickAndWhileAnAnswerIsHeldUndoAlone() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure)
        let middle = { (box: CGRect) in CGPoint(x: box.midX, y: box.midY) }
        let part = { (box: CGRect, sending: Bool) in layout.part(at: middle(box), sending: sending, page: 0, of: 1) }

        #expect(part(layout.answers[1], false) == .answer(1))
        #expect(part(layout.ignore, false) == .ignore)
        #expect(part(try #require(layout.snooze), false) == .snooze)
        #expect(part(layout.open, false) == .open)
        #expect(part(layout.answers[0], true) == nil)
        #expect(part(layout.undo, true) == .undo)
    }

    /// Where a key presses each part, the dots where a slide has brought them; none for a part it lacks.
    @Test func eachPartHasTheBoxAKeyPresses() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure)
        let none = AsksLayout(Self.choice, measure: Self.measure, offersSnooze: false)

        #expect(layout.box(of: .answer(1), progress: 0, of: 2) == layout.answers[1])
        #expect(layout.box(of: .answer(2), progress: 0, of: 2) == nil)
        #expect(layout.box(of: .ignore, progress: 0, of: 2) == layout.ignore)
        #expect(layout.box(of: .snooze, progress: 0, of: 2) == layout.snooze)
        #expect(none.box(of: .snooze, progress: 0, of: 2) == nil)
        #expect(layout.box(of: .open, progress: 0, of: 2) == layout.open)
        #expect(layout.box(of: .undo, progress: 0, of: 2) == layout.undo)
        #expect(layout.box(of: .page(1), progress: 0.5, of: 2) == layout.dots(at: 0.5, of: 2)[1])
        #expect(layout.box(of: .page(2), progress: 0, of: 2) == nil)
        #expect(layout.box(of: .page(-1), progress: 0, of: 2) == nil)
        #expect(layout.box(of: .page(0), progress: 0, of: 1) == nil)
    }

    /// At the top line's right, the current one 14 wide and orange, the others 5, 4 apart, ending where its words do;
    /// none for one ask.
    @Test func thePageDotsEndTheTopLineTheCurrentOneWide() {
        let layout = AsksLayout(Self.choice, measure: Self.measure), top = layout.top

        #expect(layout.dots(page: 0, of: 1).isEmpty)
        #expect(layout.dots(page: 1, of: 3).map(\.minX) == [top.maxX - 32, top.maxX - 23, top.maxX - 5])
        #expect(layout.dots(page: 1, of: 3).map(\.width) == [5, 14, 5])
        #expect(layout.dots(page: 1, of: 3).allSatisfy { $0.midY == top.midY && $0.height == 5 })
    }

    /// As the asks slide, the dots follow: each as wide as it is near the slide's progress, the wide one passing to
    /// the next, their run as long throughout, so the words before it never move.
    @Test func theDotsFollowASlide() {
        let layout = AsksLayout(Self.choice, measure: Self.measure), top = layout.top
        let quarter = layout.dots(at: 1.25, of: 3)

        // 5 and 9 of the 14's extra for three quarters of it, and for a quarter
        #expect(quarter.map(\.width) == [5, 11.75, 7.25])
        #expect(quarter.first?.minX == top.maxX - 32)
        #expect(quarter.last?.maxX == top.maxX)
        #expect(layout.dots(at: 2, of: 3) == layout.dots(page: 2, of: 3))
        #expect(AsksLayout.nearness(of: 0, to: 1.25) == 0 && AsksLayout.nearness(of: 2, to: 1.75) == 0.75)
    }

    /// Each dot takes the clicks nearest it, across the dots and 6 past either end, down the top line's whole 28: a
    /// click between two goes to the nearer, and one past the reach, or on the name, to none. Held or not.
    @Test(arguments: [false, true])
    func eachDotTakesTheClicksNearestIt(sending: Bool) {
        let layout = AsksLayout(Self.choice, measure: Self.measure), dots = layout.dots(page: 0, of: 3)
        let part = { (x: Double, y: Double) in layout.part(at: CGPoint(x: x, y: y), sending: sending, page: 0, of: 3) }

        #expect(part(dots[0].minX - 5.5, 13) == .page(0))
        #expect(part(dots[0].midX, 39) == .page(0))
        #expect(part(dots[0].maxX + 1.5, 26) == .page(0))
        #expect(part(dots[1].minX - 1.5, 26) == .page(1))
        #expect(part(dots[2].midX, 26) == .page(2))
        #expect(part(dots[2].maxX + 5.5, 26) == .page(2))
        #expect(part(dots[0].minX - 6.5, 26) == nil)
        #expect(part(dots[2].maxX + 6.5, 26) == nil)
        #expect(part(dots[1].midX, 41) == nil)
    }

    /// Where the asks lie right to left, on the right edge, so do their dots, the first nearest the notch: the same
    /// run at the top line's right, each dot in its mirror's place, the wide one passing leftward as a slide goes on.
    @Test func pointingLeftTheDotsLieRightToLeft() {
        let layout = AsksLayout(Self.choice, measure: Self.measure), top = layout.top
        let first = layout.dots(page: 0, of: 3, pointsLeft: true)
        let quarter = layout.dots(at: 1.25, of: 3, pointsLeft: true)

        #expect(first.map(\.maxX) == [top.maxX, top.maxX - 18, top.maxX - 27])
        #expect(first.map(\.width) == [14, 5, 5])
        #expect(quarter.map(\.width) == [5, 11.75, 7.25])
        #expect(quarter.last?.minX == top.maxX - 32 && quarter.first?.maxX == top.maxX)
        #expect(layout.box(of: .page(2), progress: 0, of: 3, pointsLeft: true) == first[2])
    }

    /// Each dot takes the clicks nearest where it is drawn: lying right to left, the dot at the run's left end is the
    /// last ask's, at its right end the first's, and 6 past either end are theirs.
    @Test func pointingLeftEachDotTakesTheClicksNearestWhereItIsDrawn() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)
        let dots = layout.dots(page: 0, of: 3, pointsLeft: true)
        let part = { (x: Double) in
            layout.part(at: CGPoint(x: x, y: 26), sending: false, page: 0, of: 3, pointsLeft: true)
        }

        #expect(part(dots[2].minX - 5.5) == .page(2))
        #expect(part(dots[1].midX) == .page(1))
        #expect(part(dots[0].maxX + 5.5) == .page(0))
        #expect(part(dots[2].minX - 6.5) == nil && part(dots[0].maxX + 6.5) == nil)
    }

    /// Overlapping the list's front by 8, its top 12 over its row's, and moved just enough to keep 8 inside the
    /// screen's visible frame, as a submenu.
    @Test func itStandsLevelWithItsRowKeptOnTheScreen() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)

        let beside = layout.frame(besideRowAt: 300, front: 400, on: Self.stage)

        #expect(beside == CGRect(x: 392, y: 288, width: 372, height: 248))
        let lowest = CGFloat(Self.stage.visibleBottom - AsksLayout.spare)
        let highest = CGFloat(Self.stage.visibleTop + AsksLayout.spare)

        #expect(layout.frame(besideRowAt: 900, front: 372, on: Self.stage).maxY == lowest)
        #expect(layout.frame(besideRowAt: 20, front: 372, on: Self.stage).minY == highest)
    }

    /// As tall as a slide between two asks has come, it stands where it would, kept on the screen at that height.
    @Test func slidingItStandsAtTheHeightTheSlideGivesIt() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)
        let lowest = CGFloat(Self.stage.visibleBottom - AsksLayout.spare)

        #expect(
            layout.frame(besideRowAt: 300, front: 400, on: Self.stage, height: 200)
                == CGRect(x: 392, y: 288, width: 372, height: 200)
        )
        #expect(layout.frame(besideRowAt: 900, front: 372, on: Self.stage, height: 200).maxY == lowest)
    }

    @Test func theRowsArrowEnds3InFromItsRowOnItsMiddle() {
        #expect(RowArrow.box(in: CGSize(width: 344, height: 30)) == CGRect(x: 301, y: 2, width: 40, height: 26))
        // its tail, where its path ends, is behind its tip
        #expect(RowArrow.chevron(pointsLeft: false).currentPoint.x < RowArrow.chevron(pointsLeft: true).currentPoint.x)
    }

    /// On the right edge, pointing left, the arrow is at the row's left end, 26 by 26 on its dot's middle.
    @Test func onTheRightEdgeTheRowsArrowIsOnItsDot() {
        #expect(RowArrow.box(in: CGSize(width: 344, height: 30), pointsLeft: true) == CGRect(x: 3, y: 2, width: 26, height: 26))
        #expect(RowArrow.chevron(pointsLeft: true, in: CGSize(width: 26, height: 26)).boundingBox.midX == 13)
    }

    /// Beside a row, kept within the span given: the screen's visible frame, above the Dock.
    @Test func itKeepsWithinTheSpanItIsGiven() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)

        #expect(layout.frame(besideRowAt: 20, front: 300, within: 37 ... 982).minY == CGFloat(37 + AsksLayout.spare))
        #expect(layout.frame(besideRowAt: 960, front: 300, within: 37 ... 982).maxY == CGFloat(982 - AsksLayout.spare))
        #expect(layout.frame(besideRowAt: 300, front: 300, within: 37 ... 982).minX == 292)
    }
}
