import CoreGraphics
@testable import SitRepPanel
import Testing

/// When the view keeps frames coming: only while something moves (`isMoving`). A pointer resting anywhere, by the
/// notch or on the still panel, moves nothing, and its next move wakes them where it can change what shows (`wakes`).
struct WantsFramesTests {
    private static let field = MeniscusFeel.lees.field

    @Test func aNotchAtRestWithThePointerAwayWantsNone() {
        var lab = Lab(needsLee: true, pointer: CGPoint(x: 600, y: 491))
        lab.settle()

        #expect(!lab.frame.isMoving)
        #expect(!lab.frame.wakes(from: lab.pointer, to: lab.pointer, field: Self.field))
        #expect(!lab.frame.wakes(from: nil, to: nil, field: Self.field))
    }

    @Test func anythingMovingWantsThem() {
        var lab = Lab(needsLee: true)
        lab.settle()

        lab.model.newAsk()
        lab.step()

        #expect(lab.frame.isMoving)
    }

    @Test(arguments: [(20.0, 0.0), (20, 200), (-30, -220)])
    func aStillPointerInTheFieldWantsNoFramesButItsMoveWakesThem(
        pastTheField by: Double, alongTheEdge along: Double
    ) {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: Self.field + by, y: lab.notchY + along)
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.frame.wakes(from: lab.pointer, to: lab.pointer, field: Self.field))
    }

    @Test(arguments: [(30.0, 0.0), (-40, 230)])
    func aMoveFurtherOutOrAlongWakesNone(pastTheField by: Double, alongTheEdge along: Double) {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: Self.field + by, y: lab.notchY + along)
        lab.settle()

        #expect(!lab.frame.wakes(from: lab.pointer, to: lab.pointer, field: Self.field))
    }

    @Test func aFlickFromTheFieldToFarWakesThemAndTheNotchLetsThePointerGo() {
        var lab = Lab(needsLee: true)
        let near = CGPoint(x: Self.field - 10, y: lab.notchY + 20), far = CGPoint(x: 900, y: lab.notchY + 20)
        var away = Lab(needsLee: true, pointer: far)

        lab.pointer = near
        let leaning = lab.settle(), rested = away.settle()
        let leant = lab.frame.outline.boundingBox

        #expect(leaning && rested)
        #expect(!lab.frame.wakes(from: far, to: far, field: Self.field))
        #expect(lab.frame.wakes(from: near, to: far, field: Self.field))

        lab.pointer = far
        let letGo = lab.settle()

        #expect(letGo)
        #expect(leant != away.frame.outline.boundingBox)
        #expect(lab.frame.outline.boundingBox.insetBy(dx: -0.01, dy: -0.01).contains(away.frame.outline.boundingBox))
        #expect(away.frame.outline.boundingBox.insetBy(dx: -0.01, dy: -0.01).contains(lab.frame.outline.boundingBox))
    }

    @Test func framesWokenAfterASleepTakeNoSpeedFromTheMoveTheySlept() {
        foundOnTheNotchAfterASleep(Lab(needsLee: true, pointer: CGPoint(x: Self.field + 20, y: 491)))
        foundOnTheNotchAfterASleep(CardLab(needsLee: true, pointer: CGPoint(x: 49 + 20, y: 491)))
    }

    /// The pointer rested by the notch until frames slept, then came onto it unseen: the first frame woken finds it
    /// there with no speed, so the notch waits on its dwell, as for a slow touch, never opening as for a flick.
    private func foundOnTheNotchAfterASleep<M: NotchModel>(
        _ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var lab = lab
        let settled = lab.settle()

        lab.now += 10_000
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step(at: lab.now)

        #expect(settled, sourceLocation: sourceLocation)
        #expect(lab.model.trailVelocity() == Vec(0, 0), sourceLocation: sourceLocation)
        #expect(lab.phase == .closed, sourceLocation: sourceLocation)
    }

    @Test func aStillPointerOnAStillPanelWantsNoFramesAndAnyMoveWakesThem() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()
        lab.move(to: CGPoint(x: 300, y: lab.notchY), speed: 0.3)
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.phase == .open)
        #expect(lab.frame.wakes(from: lab.pointer, to: CGPoint(x: 900, y: 40), field: Self.field))
    }

    @Test func thePointerThereWithThePanelInWakesNone() {
        var lab = Lab(needsLee: true, pointer: CGPoint(x: 300, y: 491))
        lab.settle()

        #expect(!lab.frame.wakes(from: lab.pointer, to: lab.pointer, field: Self.field))
    }

    @Test func theCardToo() {
        var near = CardLab(needsLee: true, pointer: CGPoint(x: 49 + 20, y: 491))
        var far = CardLab(needsLee: true, pointer: CGPoint(x: 49 + 30, y: 491))
        let nearSettled = near.settle(), farSettled = far.settle()

        #expect(nearSettled && farSettled)
        #expect(near.frame.wakes(from: near.pointer, to: near.pointer, field: near.model.field))
        #expect(!far.frame.wakes(from: far.pointer, to: far.pointer, field: far.model.field))
    }
}
