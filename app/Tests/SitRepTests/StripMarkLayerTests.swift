import QuartzCore
@testable import SitRep
@testable import SitRepPanel
import Testing

/// A mark's arc in black, as the prototype's `.mk .arc` fades it: in over 60ms as a click's jump starts, so a quick
/// answer still shows it, and out over the mark's 240 as it ends.
@MainActor
struct StripMarkLayerTests {
    private static func mark(jumping: Bool) -> StripFrame.Mark {
        StripFrame.Mark(
            key: .session("a"), text: "SR", look: .turn, centre: .zero, scale: 1, alpha: 1, isLifted: false, lift: 0,
            isJumping: jumping, wash: 0, flash: 0
        )
    }

    /// The transaction a layer's opacity changes in, as its action is looked up: how long it eases over.
    private final class Fades: NSObject, CALayerDelegate {
        var opacity: [Double] = []

        func action(for layer: CALayer, forKey event: String) -> (any CAAction)? {
            if event == "opacity", !CATransaction.disableActions() {
                opacity.append(CATransaction.animationDuration())
            }
            return nil
        }
    }

    /// How long the arc eases over as the mark goes from not jumping to this.
    private static func arcFade(to jumping: Bool) -> [Double] {
        let layer = StripMarkLayer(), fades = Fades()

        layer.show(mark(jumping: !jumping), at: .zero)
        layer.spinner.layer.delegate = fades
        layer.show(mark(jumping: jumping), at: .zero)

        return fades.opacity
    }

    @Test func aJumpsArcFadesInOver60ms() {
        #expect(Self.arcFade(to: true) == [0.06])
    }

    @Test func andOutOverTheMarks240() {
        #expect(Self.arcFade(to: false) == [0.24])
    }
}
