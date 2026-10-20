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
