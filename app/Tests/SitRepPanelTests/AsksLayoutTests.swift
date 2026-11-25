import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Where the asks panel lays out an ask, as Paper's board F has it: 12 over its top line of 28, 14 between its parts,
/// the title's lines of 22 and the age's 16 under it, answers' rows of 38 six apart, the foot's 28 and 14 under it;
/// what takes a click; where it stands beside its row, kept on the screen; and the row's arrow.
@Suite(.backstop)
struct AsksLayoutTests {
    private static let measure = AsksMeasure(titleLines: { _ in 1 }, footWidth: { Double($0.count) * 7 })
    private static let choice = PanelAsk(id: "k1", title: "Thread replies?", answers: ["Threaded", "Flat"], since: 0)
    private static let words = PanelAsk(id: "k2", title: "Say what an empty rota should read", since: 0)
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

    @Test func aWordsAskHasOneRowAnsweringInClaudeAndNoOpenInClaude() {
        let layout = AsksLayout(Self.words, measure: Self.measure)

        #expect(layout.answers.count == 1 && layout.open == nil)
        let row = layout.answers[0]

        #expect(layout.part(at: CGPoint(x: row.midX, y: row.midY), sending: false) == .inClaude)
    }

    @Test func itsFootSitsUnderTheAnswersOpenInClaudeAtTheRight() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure), open = try #require(layout.open)

        #expect(layout.ignore.minX == 14 && layout.ignore.width == 16 + 42)
        #expect(layout.snooze.minX == layout.ignore.maxX + 2)
        #expect(open.maxX == 360 && open.height == 26 && open.midY == layout.foot.midY)
        #expect(layout.undo.maxX == 360)
    }

    @Test func eachPartTakesItsClickAndWhileAnAnswerIsHeldUndoAlone() throws {
        let layout = AsksLayout(Self.choice, measure: Self.measure), open = try #require(layout.open)
        let middle = { (box: CGRect) in CGPoint(x: box.midX, y: box.midY) }

        #expect(layout.part(at: middle(layout.answers[1]), sending: false) == .answer(1))
        #expect(layout.part(at: middle(layout.ignore), sending: false) == .ignore)
        #expect(layout.part(at: middle(layout.snooze), sending: false) == .snooze)
        #expect(layout.part(at: middle(open), sending: false) == .open)
        #expect(layout.part(at: middle(layout.answers[0]), sending: true) == nil)
        #expect(layout.part(at: middle(layout.undo), sending: true) == .undo)
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
