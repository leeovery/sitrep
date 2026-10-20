import CoreGraphics
@testable import SitRepPanel
import Testing

/// How far out the black is, which the glass eases its notch's mark by: none at the notch at rest, all of it with
/// the panel out, and rising between as the panel comes, in Meniscus and the card alike.
struct OpennessTests {
    @Test func theNotchAtRestIsNotOpenAtAll() {
        #expect(Lab().frame.openness == 0)
        #expect(CardLab().frame.openness == 0)
    }

    @Test func theNotchNeedingLeeIsBarelyOpen() {
        #expect(Lab(needsLee: true).frame.openness < 0.03)
        #expect(CardLab(needsLee: true).frame.openness < 0.03)
    }

    @Test func thePanelOutIsOpenAllTheWay() {
        #expect(Self.opened(Lab()).last == 1)
        #expect(Self.opened(CardLab()).last == 1)
    }

    @Test func itRisesFromTheNotchToThePanelAsThePanelComes() {
        for rises in [Self.opened(Lab()), Self.opened(CardLab())] {
            #expect(rises.first == 0)
            #expect(rises.contains { $0 > 0.2 && $0 < 0.8 })
        }
    }

    /// The openness of each frame, from the notch at rest to the panel out and settled.
    private static func opened<Model>(_ lab: NotchLab<Model>) -> [Double] {
        var lab = lab, seen = [lab.frame.openness]

        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        while lab.phase != .open || lab.frame.isMoving, lab.now < 4000 {
            lab.step()
            seen.append(lab.frame.openness)
        }
        return seen
    }
}
