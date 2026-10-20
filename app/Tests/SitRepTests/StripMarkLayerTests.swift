import QuartzCore
@testable import SitRep
@testable import SitRepPanel
import Testing

/// A mark in black, eased as the prototype's `.mk` eases it: its arc in over 60ms as a click's jump starts, so a quick
/// answer still shows it, and out over the mark's 240, as it does in over 240 for a mark turning working; and its fill
/// pressed in and let out over 110.
@MainActor
struct StripMarkLayerTests {
    private static func mark(_ look: StripFrame.Mark.Look = .turn, jumping: Bool = false) -> StripFrame.Mark {
        StripFrame.Mark(
            key: .session("a"), text: "SR", look: look, centre: .zero, scale: 1, alpha: 1, isLifted: false, lift: 0,
            isJumping: jumping, wash: 0, flash: 0
        )
    }

    /// The transactions a layer's property changes in, as its action is looked up: how long each eases over.
    private final class Eases: NSObject, CALayerDelegate {
        let key: String
        var eases: [Double] = []

        init(_ key: String) {
            self.key = key
        }

        func action(for layer: CALayer, forKey event: String) -> (any CAAction)? {
            if event == key, !CATransaction.disableActions() {
                eases.append(CATransaction.animationDuration())
            }
            return nil
        }
    }

    /// How a part of the mark eases as it goes from one look to the next, its layer and property as named.
    private static func eases(
        from: StripFrame.Mark, to: StripFrame.Mark, _ key: String, of part: (StripMarkLayer) -> CALayer
    ) -> [Double] {
        let layer = StripMarkLayer(), eases = Eases(key)

        layer.show(from, at: .zero)
        part(layer).delegate = eases
        layer.show(to, at: .zero)

        return eases.eases
    }

    @Test func aJumpsArcFadesInOver60ms() {
        #expect(Self.eases(from: Self.mark(), to: Self.mark(jumping: true), "opacity") { $0.spinner.layer } == [0.06])
    }

    @Test func andOutOverTheMarks240() {
        #expect(Self.eases(from: Self.mark(jumping: true), to: Self.mark(), "opacity") { $0.spinner.layer } == [0.24])
    }

    @Test func aMarkTurningWorkingFadesItsArcInOver240() {
        #expect(Self.eases(from: Self.mark(), to: Self.mark(.working), "opacity") { $0.spinner.layer } == [0.24])
    }

    @Test func itsFillPressesInAndLetsOutOver110() {
        let pressed = Self.eases(from: Self.mark(), to: Self.mark(jumping: true), "backgroundColor") { $0.ring }
        let letOut = Self.eases(from: Self.mark(jumping: true), to: Self.mark(), "backgroundColor") { $0.ring }

        #expect(pressed == [0.11] && letOut == [0.11])
    }
}
