import CoreGraphics
@testable import SitRepPanel
import Testing

/// The notch's time runs on while nothing shows it, as over a full-screen app: shown again, it is where it would have
/// got to, at rest, with nothing left to play late.
struct RunOnTests {
    private static func input(_ time: Double, needsLee: Bool = true) -> Input {
        Input(time: time, pointer: nil, needsLee: needsLee, stage: screen, content: .css)
    }

    @Test func aNewAskWhileHiddenHasSwelledAndSettledByTheTimeItShows() {
        swellsWhileHidden(Meniscus(Self.input(0, needsLee: false)))
        swellsWhileHidden(Card(Self.input(0, needsLee: false)))
    }

    @Test func aDrainWhileHiddenIsHomeByTheTimeItShows() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()
        lab.model.clickElsewhere()

        let frame = lab.model.runOn(from: lab.now, to: lab.now + 60_000) { Self.input($0) }

        #expect(lab.phase == .closed)
        #expect(!frame.isMoving)
    }

    @Test func itRunsOnNoFurtherThanItNeedsTo() {
        let notch = Meniscus(Self.input(0))
        var frames = 0

        _ = notch.runOn(from: 0, to: 3_600_000) { time in
            frames += 1
            return Self.input(time)
        }

        #expect(frames == 1)
    }

    private func swellsWhileHidden(_ notch: some Notch) {
        notch.newAsk()

        let frame = notch.runOn(from: 0, to: 600_000) { Self.input($0) }

        #expect(!frame.isMoving)
        #expect(abs(frame.light.level - 1) < 1e-3)
        #expect(abs(frame.outline.boundingBox.maxX - NotchShape.needs.w) < 0.01)
        #expect(!notch.frame(Self.input(600_000 + 1000 / 60)).isMoving)
    }
}
