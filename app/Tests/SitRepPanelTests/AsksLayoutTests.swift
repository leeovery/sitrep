import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Where the asks panel lays out an ask, as Paper's board F has it: 12 over its top line of 28, 14 between its parts,
/// the title's lines of 22 and the age's 16 under it, answers' rows of 38 six apart, the foot's 28 and 14 under it;
/// a words ask's foot straight under its age; the page dots and the clicks each takes; what else takes a click; where
/// it stands beside its row, kept on the screen; and the row's arrow.
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

    @Test func itsFootSitsUnderTheAnswersOpenInClaudeAtTheRight() {
        let layout = AsksLayout(Self.choice, measure: Self.measure), open = layout.open

        #expect(layout.ignore.minX == 14 && layout.ignore.width == 16 + 42)
        #expect(layout.snooze.minX == layout.ignore.maxX + 2)
        #expect(open.maxX == 360 && open.height == 26 && open.midY == layout.foot.midY)
        #expect(layout.undo.maxX == 360)
    }

    @Test func eachPartTakesItsClickAndWhileAnAnswerIsHeldUndoAlone() {
        let layout = AsksLayout(Self.choice, measure: Self.measure)
        let middle = { (box: CGRect) in CGPoint(x: box.midX, y: box.midY) }
        let part = { (box: CGRect, sending: Bool) in layout.part(at: middle(box), sending: sending, page: 0, of: 1) }

        #expect(part(layout.answers[1], false) == .answer(1))
        #expect(part(layout.ignore, false) == .ignore)
        #expect(part(layout.snooze, false) == .snooze)
        #expect(part(layout.open, false) == .open)
        #expect(part(layout.answers[0], true) == nil)
        #expect(part(layout.undo, true) == .undo)
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

    @Test func theRowsArrowEnds3InFromItsRowOnItsMiddle() {
        #expect(RowArrow.box(in: CGSize(width: 344, height: 30)) == CGRect(x: 301, y: 2, width: 40, height: 26))
        // its tail, where its path ends, is behind its tip
        #expect(RowArrow.chevron(pointsLeft: false).currentPoint.x < RowArrow.chevron(pointsLeft: true).currentPoint.x)
    }
}
