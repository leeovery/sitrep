import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// How far out the black is, which the glass eases its notch's mark by: none at the notch at rest, all of it with
/// the panel out, and rising between as the panel comes, in Meniscus and the card alike.
@Suite(.backstop)
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

    /// Meniscus's front springs short of the panel's depth and back once it is open: open is open all the same.
    @Test func everyOpenFrameIsOpenAllTheWay() {
        for open in [Self.openFrames(Lab()), Self.openFrames(CardLab())] {
            #expect(!open.isEmpty)
            #expect(open.allSatisfy { $0.openness == 1 })
        }
    }

    /// The frames of the panel open, the pointer held on the notch for three seconds.
    private static func openFrames<Model>(_ lab: NotchLab<Model>) -> [Frame] {
        var lab = lab, open: [Frame] = []

        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        while lab.now < 4000 {
            lab.step()
            if lab.phase == .open {
                open.append(lab.frame)
            }
        }
        return open
    }

    @Test func itRisesFromTheNotchToThePanelAsThePanelComes() {
        for rises in [Self.opened(Lab()), Self.opened(CardLab())] {
            #expect(rises.first == 0)
            #expect(rises.contains { $0 > 0.2 && $0 < 0.8 })
        }
    }

    @Test func itFallsBackToTheNotchAsThePanelGoes() {
        for falls in [Self.closed(Lab()), Self.closed(CardLab())] {
            #expect(falls.first == 1)
            #expect(falls.last == 0)
            #expect(falls.contains { $0 > 0.2 && $0 < 0.8 })
            #expect(zip(falls, falls.dropFirst()).allSatisfy { $0 - $1 < Self.step && $1 <= $0 + 0.1 })
        }
    }

    /// The most a frame may change it by, the same cap the mark's ease keeps: the card goes in about six frames,
    /// under a quarter of the way in each.
    private static let step = 0.3

    /// The openness of each frame, from the panel out and settled, the pointer leaving it, to the notch at rest.
    private static func closed<Model>(_ lab: NotchLab<Model>) -> [Double] {
        var lab = lab

        lab.openByTouch()
        lab.settle()

        var seen = [lab.frame.openness]

        lab.pointer = CGPoint(x: 700, y: lab.notchY)
        while lab.phase != .closed || lab.frame.isMoving, lab.now < 8000 {
            lab.step()
            seen.append(lab.frame.openness)
        }
        return seen
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
