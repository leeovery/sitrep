import CoreGraphics
@testable import SitRepPanel
import Testing

/// When the view keeps frames coming: while anything moves, while the pointer is by the lip, or over the open panel.
struct WantsFramesTests {
    private static let field = Settings().field

    @Test func aLipAtRestWithThePointerAwayWantsNone() {
        var lab = Lab(needsLee: true, pointer: CGPoint(x: 600, y: 491))
        lab.settle()

        #expect(!lab.frame.wantsFrames(pointer: lab.pointer, field: Self.field))
        #expect(!lab.frame.wantsFrames(pointer: nil, field: Self.field))
    }

    @Test func anythingMovingWantsThem() {
        var lab = Lab(needsLee: true)
        lab.settle()

        lab.model.newAsk()
        lab.step()

        #expect(lab.frame.isMoving)
        #expect(lab.frame.wantsFrames(pointer: nil, field: Self.field))
    }

    @Test(arguments: [(20.0, 0.0), (20, 200), (-30, -220)])
    func thePointerResting(pastTheField by: Double, alongTheEdge along: Double) {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: Self.field + by, y: lab.lipY + along)
        lab.settle()

        #expect(!lab.frame.isMoving)
        #expect(lab.frame.wantsFrames(pointer: lab.pointer, field: Self.field))
    }

    @Test(arguments: [(30.0, 0.0), (-40, 230)])
    func thePointerRestingFurtherOutOrAlongWantsNone(pastTheField by: Double, alongTheEdge along: Double) {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: Self.field + by, y: lab.lipY + along)
        lab.settle()

        #expect(!lab.frame.wantsFrames(pointer: lab.pointer, field: Self.field))
    }

    @Test func thePointerRestingOverTheOpenPanelWantsThem() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()
        lab.move(to: CGPoint(x: 300, y: lab.lipY), speed: 0.3)
        lab.settle()

        #expect(lab.phase == .open)
        #expect(!lab.frame.isMoving)
        #expect(lab.frame.wantsFrames(pointer: lab.pointer, field: Self.field))
    }

    @Test func thePointerThereWithThePanelInWantsNone() {
        var lab = Lab(needsLee: true, pointer: CGPoint(x: 300, y: 491))
        lab.settle()

        #expect(!lab.frame.wantsFrames(pointer: lab.pointer, field: Self.field))
    }
}
