import QuartzCore
@testable import SitRep
@testable import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// A mark in black, eased as the prototype's `.mk` eases it: its arc in over 60ms as a click's jump starts, so a quick
/// answer still shows it, and out over the mark's 240, as it does in over 240 for a mark turning working; and its fill
/// pressed in and let out over 110.
@MainActor
@Suite(.backstop)
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
    /// ring's place, in working's grey, still; no arc, so it never reads as a spinner stopped. Its dashes the card's
    /// grown: eight going round evenly, a gap of 1.6 showing between their round caps.
    @Test func aMarkOnItsOwnWorkShowsTheDottedRingAndNoArc() throws {
        let layer = Self.shown(Self.mark(.onItsWork))
        let path = try #require(layer.dotted.path)
        let dash = try #require(layer.dotted.lineDashPattern?.map(\.doubleValue))
        let round = 2 * Double.pi * 11.25, gap = dash.last.map { $0 - Double(layer.dotted.lineWidth) } ?? 0

        #expect(layer.dotted.opacity == 1)
        #expect(dash.count == 2)
        #expect(abs(8 * dash.reduce(0, +) - round) < 0.001)
        #expect(abs(gap - 1.6) < 0.001)
        #expect(layer.dotted.strokeColor == EdgeStyle.grey)
        #expect(layer.dotted.frame.midX == 12 && layer.dotted.frame.midY == 12)
        #expect(path.boundingBox.width == 22.5 && path.boundingBox.height == 22.5)
        #expect(layer.dotted.animationKeys() == nil)
        #expect(layer.spinner.layer.opacity == 0)
        #expect(layer.ring.borderColor == nil)
    }

    /// Read round it, its eight dashes show, a gap between each, on the black and on glass alike.
    @Test func itsDottedRingReadsAsEightDashesOnTheBlack() throws {
        let layer = StripMarkLayer()

        layer.show(Self.mark(.onItsWork), at: CGPoint(x: 12, y: 12))
        #expect(try Self.dashes(Drawn(layer.layer)) == 8)
    }

    @available(macOS 26, *)
    @Test func itsDottedRingReadsAsEightDashesOnGlass() throws {
        let side = StripFrame.Mark.size

        #expect(try Self.dashes(Drawn(GlassMark(mark: Self.mark(.onItsWork)), size: CGSize(width: side, height: side)))
            == 8)
        #expect(try Self.dashes(Drawn(GlassMark(mark: Self.mark(.turn)), size: CGSize(width: side, height: side))) == 1)
    }

    /// The runs of ink met going once round a mark's ring, 11.25 from its centre: a ring whole is one.
    private static func dashes(_ drawn: Drawn) throws -> Int {
        let centre = StripFrame.Mark.size / 2, radius = (StripFrame.Mark.size - 1.5) / 2
        let round = (0 ..< 720).map { step in
            let angle = Double(step) * .pi / 360

            return drawn.pixel(at: CGPoint(x: centre + radius * cos(angle), y: centre + radius * sin(angle)))?
                .lightness ?? 0
        }
        let lit = try #require(round.max()) / 2
        let inked = round.map { $0 > lit }
        let starts = inked.indices.filter { inked[$0] && !inked[($0 + inked.count - 1) % inked.count] }

        return inked.allSatisfy(\.self) ? 1 : starts.count
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

    /// Every arc turning at a period turns in step with every other, on every surface, however long after them it
    /// starts: its turn starts where the clock is in that period.
    @Test(arguments: [1.0, 1.2, 0.9])
    func everyArcTurnsInStepByTheClock(period: Double) throws {
        let first = Arc(), later = Arc()
        let now = 86_400.25, after = 7.3

        first.turn(every: period, at: now)
        later.turn(every: period, at: now + after)
        #expect(try Self.offset(of: first) == Arc.phase(every: period, at: now))

        let gap = try Self.offset(of: later) - Self.offset(of: first) - after

        #expect(abs(gap - (gap / period).rounded() * period) < 1e-9)
    }

    /// Unless told the time, an arc reads the display's clock, in seconds, as `MenuTurn` does: its turn starts where
    /// that clock was in its period as it started, between the moments before and after.
    @Test(arguments: [1.0, 1.2, 0.9])
    func anArcTurnsByTheDisplaysClock(period: Double) throws {
        let arc = Arc()
        let before = CACurrentMediaTime()

        arc.turn(every: period)

        let after = CACurrentMediaTime()
        let since = try Self.offset(of: arc) - Arc.phase(every: period, at: before)

        #expect((since + period).truncatingRemainder(dividingBy: period) <= after - before + 1e-9)
    }

    /// Where in its turn an arc's turn starts.
    private static func offset(of arc: Arc) throws -> Double {
        let key = try #require(arc.layer.animationKeys()?.first)

        return try #require(arc.layer.animation(forKey: key)?.timeOffset)
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

    /// In Snoozed (14 November 2026), an ask's ring and a turn's dimmed as a Snoozed row's dot is, the letters faint;
    /// Snoozed's count on the track, its letters fainter than Working's count's.
    @Test func aSnoozedMarkIsDimmedAsItsSnoozedRow() {
        #expect(StripMarkLayer.ringColour(.snoozed) == EdgeStyle.asleep(EdgeStyle.orange))
        #expect(StripMarkLayer.ringColour(.snoozedTurn) == EdgeStyle.asleep(EdgeStyle.blue))
        #expect(StripMarkLayer.ringColour(.snoozedCount) == EdgeStyle.track)
        for look in [StripFrame.Mark.Look.snoozed, .snoozedTurn, .snoozedCount] {
            #expect(StripMarkLayer.letterColour(look) == EdgeStyle.ink3)
        }
        #expect(StripMarkLayer.letterColour(.count) == EdgeStyle.ink2)
    }

    @Test func itsFillPressesInAndLetsOutOver110() {
        let pressed = Self.eases(from: Self.mark(), to: Self.mark(jumping: true), "backgroundColor") { $0.ring }
        let letOut = Self.eases(from: Self.mark(jumping: true), to: Self.mark(), "backgroundColor") { $0.ring }

        #expect(pressed == [0.11] && letOut == [0.11])
    }
}
