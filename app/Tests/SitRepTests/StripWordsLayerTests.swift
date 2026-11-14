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

    private static func row(_ id: String) -> Session {
        Session(id: id, project: "SitRep", kind: .turn, title: "Your turn", sub: "SitRep · Build", since: 0)
    }

    private static func words(pressing pressed: String? = nil) -> StripFrame.Words {
        StripFrame.Words(
            id: 1, key: .count(.working), content: .rows([row("a"), row("b")]), frame: box, scroll: 0, alpha: 1, dy: 0,
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

    /// A session with three lines waiting is one tab, as one row of a count's: its name, then "3" for its three lines
    /// waiting, set as a row's count is; one line waiting, a question with its own "+2" among them, its name
    /// alone.
    @Test func aSessionOfSeveralLinesSaysItsNameThenHowManyWait() {
        let name = "Finish the Harness modernisation"
        let three = Session(
            id: "h", project: "Harness", name: name, kind: .needs,
            lines: ["Approve the first fix batch", "Choose", "Paste"].enumerated().map {
                Session.Line(title: $1, since: Double($0))
            },
            sub: "Harness"
        )
        let counted = Session(id: "h", project: "Harness", kind: .turn, title: name, more: "3", sub: "Harness", since: 0)
        let question = Session(
            id: "h", project: "Harness", name: name, kind: .needs, title: "Which edge?", more: "+2", sub: "Harness",
            since: 0
        )
        let alone = Session(id: "h", project: "Harness", kind: .turn, title: name, sub: "Harness", since: 0)

        #expect(StripWordsLayer.rowWidth(three, at: 0) == StripWordsLayer.rowWidth(counted, at: 0))
        #expect(StripWordsLayer.countRowWidth(three, at: 0) == StripWordsLayer.countRowWidth(counted, at: 0))
        #expect(StripWordsLayer.countRowWidth(question, at: 0) == StripWordsLayer.countRowWidth(alone, at: 0))
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
        let layer = StripWordsLayer(Self.words(), in: Self.box, StripScene.resting())

        layer.show(Self.words(), in: Self.box, hover: "a", now: 0)
        #expect(layer.rows["a"]?.backgroundColor == EdgeStyle.hover)

        layer.show(Self.words(), in: Self.box, hover: "b", now: 0)
        #expect(layer.rows["a"]?.backgroundColor == nil)
        #expect(layer.rows["b"]?.backgroundColor == EdgeStyle.hover)

        layer.show(Self.words(), in: Self.box, hover: nil, now: 0)
        #expect(layer.rows["b"]?.backgroundColor == nil)
    }

    /// Snoozed's count's rows go by their marks' keys, as the strip lights and presses them, apart from the same
    /// sessions' rows in another section.
    @Test func aSnoozedCountsRowsGoByTheirMarksKeys() {
        let asleep = ["a", "b"].map { id in
            Session(id: id, project: "Northwind", kind: .snoozed, title: "Pick", sub: "Northwind", since: 0)
        }
        let words = StripFrame.Words(
            id: 1, key: .count(.snoozed), content: .rows(asleep), frame: Self.box, scroll: 0, alpha: 1, dy: 0,
            isPressed: false, pressedRow: nil
        )
        let layer = StripWordsLayer(words, in: Self.box, StripScene.resting())

        layer.show(words, in: Self.box, hover: "snoozed:a", now: 0)

        #expect(Set(layer.rows.keys) == ["snoozed:a", "snoozed:b"])
        #expect(layer.rows["snoozed:a"]?.backgroundColor == EdgeStyle.hover)
    }

    /// The row lifted under the pointer, clicked, presses in: the same row, lit again as pressed.
    @Test func aLiftedRowClickedPressesIn() {
        let layer = StripWordsLayer(Self.words(), in: Self.box, StripScene.resting())

        layer.show(Self.words(), in: Self.box, hover: "a", now: 0)
        layer.show(Self.words(pressing: "a"), in: Self.box, hover: "a", now: 0)

        #expect(layer.rows["a"]?.backgroundColor == EdgeStyle.press)
        let pressedIn = CATransform3DMakeScale(0.985, 0.985, 1)
        #expect(layer.rows["a"].map { CATransform3DEqualToTransform($0.transform, pressedIn) } == true)
    }
}
