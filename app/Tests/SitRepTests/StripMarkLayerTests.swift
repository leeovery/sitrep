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

    /// A change of look eases the letters' colour over 240, as the ring's, their glyphs kept; new letters come at once.
    @Test func itsLettersEaseTheirColourOver240AndKeepTheirGlyphs() throws {
        let turn = Self.mark(.turn), away = Self.mark(.away)
        let layer = StripMarkLayer()
        layer.show(turn, at: .zero)
        let glyphs = try #require(layer.letters.mask)

        #expect(Self.eases(from: turn, to: away, "backgroundColor") { $0.letters } == [0.24])

        layer.show(away, at: .zero)
        #expect(layer.letters.mask === glyphs)
        layer.show(StripFrame.Mark(
            key: .session("a"), text: "Sw", look: .away, centre: .zero, scale: 1, alpha: 1, isLifted: false, lift: 0,
            isJumping: false, wash: 0, flash: 0
        ), at: .zero)
        #expect(layer.letters.mask !== glyphs)
    }

    /// Shown as each of these in turn.
    private static func shown(_ marks: StripFrame.Mark...) -> StripMarkLayer {
        let layer = StripMarkLayer()

        marks.forEach { layer.show($0, at: .zero) }
        return layer
    }

    /// On its own work, the dotted ring the panel, the menu and the window mark it with, round the letters in the 24pt
    /// ring's place, in working's grey, still; no arc, so it never reads as a spinner stopped.
    @Test func aMarkOnItsOwnWorkShowsTheDottedRingAndNoArc() throws {
        let layer = Self.shown(Self.mark(.onItsWork))
        let path = try #require(layer.dotted.path)

        #expect(layer.dotted.opacity == 1)
        #expect(layer.dotted.lineDashPattern == [1.6, 2.12])
        #expect(layer.dotted.strokeColor == EdgeStyle.grey)
        #expect(layer.dotted.frame.midX == 12 && layer.dotted.frame.midY == 12)
        #expect(path.boundingBox.width == 22.5 && path.boundingBox.height == 22.5)
        #expect(layer.dotted.animationKeys() == nil)
        #expect(layer.spinner.layer.opacity == 0)
        #expect(layer.ring.borderColor == nil)
    }

    @Test(arguments: [StripFrame.Mark.Look.working, .needs, .turn, .away])
    func noOtherMarkShowsTheDottedRing(look: StripFrame.Mark.Look) {
        #expect(Self.shown(Self.mark(look)).dotted.opacity == 0)
    }

    /// A click's jump turns an arc on it as on any mark, the dotted ring gone while it does, and back after.
    @Test func aMarkOnItsOwnWorkJumpingTurnsTheArcInTheRingsPlace() {
        let jumping = Self.shown(Self.mark(.onItsWork), Self.mark(.onItsWork, jumping: true))
        let after = Self.shown(Self.mark(.onItsWork, jumping: true), Self.mark(.onItsWork))

        #expect(jumping.spinner.layer.opacity == 1 && jumping.dotted.opacity == 0)
        #expect(after.spinner.layer.opacity == 0 && after.dotted.opacity == 1)
    }

    @Test func aWorkingMarkComingToItsOwnWorkStopsTurning() {
        let layer = Self.shown(Self.mark(.working), Self.mark(.onItsWork))

        #expect(layer.spinner.layer.animationKeys() == nil)
    }

    @Test func aMarkOnItsOwnWorkTurnsAsAClickOnItJumpsAndIsHeldAgainAfter() {
        let jumping = Self.shown(Self.mark(.onItsWork), Self.mark(.onItsWork, jumping: true))
        let after = Self.shown(Self.mark(.onItsWork, jumping: true), Self.mark(.onItsWork))

        #expect(jumping.spinner.layer.animationKeys() == ["spin"])
        #expect(after.spinner.layer.animationKeys() == nil)
    }

    @Test func itsFillPressesInAndLetsOutOver110() {
        let pressed = Self.eases(from: Self.mark(), to: Self.mark(jumping: true), "backgroundColor") { $0.ring }
        let letOut = Self.eases(from: Self.mark(jumping: true), to: Self.mark(), "backgroundColor") { $0.ring }

        #expect(pressed == [0.11] && letOut == [0.11])
    }
}
