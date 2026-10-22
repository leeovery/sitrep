import QuartzCore
@testable import SitRep
import SitRepEdge
@testable import SitRepPanel
import Testing

/// A count's rows in its tab, under the pointer: the row there lifts and comes down as the pointer leaves it, and the
/// one a click jumps from presses in.
@MainActor
struct StripWordsLayerTests {
    private static let box = CGRect(x: 0, y: 0, width: 220, height: 100)

    private static func scene() -> StripScene {
        let stage = StripStage(width: 1512, height: 982, menu: 37)
        let input = StripInput(time: 0, pointer: nil, stage: stage)
        let measure = StripMeasure(row: { _ in 200 }, rows: { _ in 200 }, idle: { 200 })
        let strip = Strip(length: .full, maxLength: .full, along: 0.42, sessions: [], measure: measure, input)

        return StripScene(
            frame: strip.frame(input), hoverRow: nil, note: StripNote(), now: 0, mirror: .identity, menu: 37,
            reducesMotion: false
        )
    }

    private static func row(_ id: String) -> Session {
        Session(id: id, project: "SitRep", kind: .turn, title: "Your turn", sub: "SitRep · Build", since: 0)
    }

    private static func words(pressing pressed: String? = nil) -> StripFrame.Words {
        StripFrame.Words(
            id: 1, key: .more, content: .rows([row("a"), row("b")]), frame: box, scroll: 0, alpha: 1, dy: 0,
            isPressed: false, pressedRow: pressed
        )
    }

    private static func wake(in minutes: Double) -> Session {
        Session(id: "k", project: "Kit", kind: .onItsWork, title: "Wakes ", until: minutes * 60_000, sub: "", since: 0)
    }

    /// A wake an hour and a minute off reads "in 1h", and widens to "in 59m" two minutes on: its tab, a session's or a
    /// count's, is as wide from the first, so the countdown is never cut short.
    @Test func aTabLeavesRoomForAWakesCountdownToWiden() {
        let wake = Self.wake(in: 61)

        #expect(wake.subject(at: 0) == "in 1h")
        #expect(wake.subject(at: 120_000) == "in 59m")
        #expect(StripWordsLayer.rowWidth(wake, at: 0) == StripWordsLayer.rowWidth(wake, at: 120_000))
        #expect(StripWordsLayer.countRowWidth(wake, at: 0) == StripWordsLayer.countRowWidth(wake, at: 120_000))
        #expect(StripWordsLayer.rowWidth(wake, at: 0) > StripWordsLayer.rowWidth(Self.wake(in: 2), at: 0))
    }

    /// A session with three lines waiting is one tab, as one row of a count's: its oldest line, then "+2" for the two
    /// after it, set as a question of one line sets its "+2".
    @Test func aSessionOfSeveralLinesSaysItsOldestThenHowManyMore() {
        let oldest = Session.Line(title: "Approve the first fix batch", since: 0)
        let three = Session(
            id: "h", project: "Harness", kind: .needs,
            lines: [oldest, Session.Line(title: "Choose", since: 1), Session.Line(title: "Paste", since: 2)],
            sub: "Harness"
        )
        let asked = Session(
            id: "h", project: "Harness", kind: .needs, title: oldest.title, more: "+2",
            sub: "Harness", since: 0
        )
        let alone = Session(
            id: "h", project: "Harness", kind: .needs, title: oldest.title,
            sub: "Harness", since: 0
        )

        #expect(StripWordsLayer.rowWidth(three, at: 0) == StripWordsLayer.rowWidth(asked, at: 0))
        #expect(StripWordsLayer.countRowWidth(three, at: 0) == StripWordsLayer.countRowWidth(asked, at: 0))
        #expect(StripWordsLayer.countRowWidth(three, at: 0) > StripWordsLayer.countRowWidth(alone, at: 0))
    }

    /// The room left is each unit's widest reading, "in 59m", so every reading of two figures must set as wide as it:
    /// "in 11m" too, its figures tabular.
    @Test func aCountdownsFiguresAreTabular() {
        let wake = Self.wake(in: 59)

        #expect(StripWordsLayer.rowWidth(wake, at: 48 * 60_000) == StripWordsLayer.rowWidth(wake, at: 0))
        #expect(StripWordsLayer.countRowWidth(wake, at: 48 * 60_000) == StripWordsLayer.countRowWidth(wake, at: 0))
    }

    @Test func aRowLiftedComesDownAsThePointerMovesToAnother() {
        let layer = StripWordsLayer(Self.words(), in: Self.box, Self.scene())

        layer.show(Self.words(), in: Self.box, hover: "a", now: 0)
        #expect(layer.rows["a"]?.backgroundColor == EdgeStyle.hover)

        layer.show(Self.words(), in: Self.box, hover: "b", now: 0)
        #expect(layer.rows["a"]?.backgroundColor == nil)
        #expect(layer.rows["b"]?.backgroundColor == EdgeStyle.hover)

        layer.show(Self.words(), in: Self.box, hover: nil, now: 0)
        #expect(layer.rows["b"]?.backgroundColor == nil)
    }

    /// The row lifted under the pointer, clicked, presses in: the same row, lit again as pressed.
    @Test func aLiftedRowClickedPressesIn() {
        let layer = StripWordsLayer(Self.words(), in: Self.box, Self.scene())

        layer.show(Self.words(), in: Self.box, hover: "a", now: 0)
        layer.show(Self.words(pressing: "a"), in: Self.box, hover: "a", now: 0)

        #expect(layer.rows["a"]?.backgroundColor == EdgeStyle.press)
        let pressedIn = CATransform3DMakeScale(0.985, 0.985, 1)
        #expect(layer.rows["a"].map { CATransform3DEqualToTransform($0.transform, pressedIn) } == true)
    }
}
