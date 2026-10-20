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
        #expect(!lab.frame.wakes(pointer: lab.pointer, field: Self.field))
        #expect(!lab.frame.wakes(pointer: nil, field: Self.field))
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
        #expect(lab.frame.wakes(pointer: lab.pointer, field: Self.field))
    }

    @Test(arguments: [(30.0, 0.0), (-40, 230)])
    func aMoveFurtherOutOrAlongWakesNone(pastTheField by: Double, alongTheEdge along: Double) {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: Self.field + by, y: lab.notchY + along)
        lab.settle()

        #expect(!lab.frame.wakes(pointer: lab.pointer, field: Self.field))
    }

    @Test func aStillPointerOnAStillPanelWantsNoFramesAndAnyMoveWakesThem() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()
        lab.move(to: CGPoint(x: 300, y: lab.notchY), speed: 0.3)
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.phase == .open)
        #expect(lab.frame.wakes(pointer: CGPoint(x: 900, y: 40), field: Self.field))
    }

    @Test func thePointerThereWithThePanelInWakesNone() {
        var lab = Lab(needsLee: true, pointer: CGPoint(x: 300, y: 491))
        lab.settle()

        #expect(!lab.frame.wakes(pointer: lab.pointer, field: Self.field))
    }

    @Test func theCardToo() {
        var near = CardLab(needsLee: true, pointer: CGPoint(x: 49 + 20, y: 491))
        var far = CardLab(needsLee: true, pointer: CGPoint(x: 49 + 30, y: 491))
        let nearSettled = near.settle(), farSettled = far.settle()

        #expect(nearSettled && farSettled)
        #expect(near.frame.wakes(pointer: near.pointer, field: near.model.field))
        #expect(!far.frame.wakes(pointer: far.pointer, field: far.model.field))
    }
}
