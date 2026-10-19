import CoreGraphics
@testable import SitRepPanel
import Testing

/// Lee's screens: the Studio Display with the menu bar, its Dock at the bottom, and the built-in to its right.
struct ScreenEdgeTests {
    static let studio = ScreenEdge(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visible: CGRect(x: 0, y: 86, width: 2560, height: 1324)
    )
    static let builtIn = CGRect(x: 2560, y: -581, width: 1728, height: 1117)

    @Test func theStageIsTheScreensHeightWithItsVisibleFrameFromTheTopAndTheNotch042OfTheWayDown() {
        #expect(Self.studio.stage == Stage(height: 1440, visibleTop: 30, visibleBottom: 1354, notchY: 1440 * 0.42))
    }

    @Test func thePointerHeldAgainstTheLeftEdgeIsAtZero() {
        #expect(Self.studio.stagePoint(CGPoint(x: 0, y: 720)) == CGPoint(x: 0, y: 720))
    }

    @Test func theStageRunsDownFromTheScreensTop() {
        #expect(Self.studio.stagePoint(CGPoint(x: 120.5, y: 1440)) == CGPoint(x: 120.5, y: 0))
        #expect(Self.studio.stagePoint(CGPoint(x: 120.5, y: 1000)) == CGPoint(x: 120.5, y: 440))
        #expect(Self.studio.stagePoint(CGPoint(x: 120.5, y: 0)) == CGPoint(x: 120.5, y: 1440))
    }

    @Test(arguments: [CGPoint(x: 2560, y: 0), CGPoint(x: 3400, y: -300), CGPoint(x: 4287, y: 535)])
    func onTheBuiltInDisplayThePointerIsOffTheStage(_ point: CGPoint) {
        #expect(Self.builtIn.contains(point))
        #expect(Self.studio.stagePoint(point) == nil)
    }

    @Test func theStudioDisplaysRightmostColumnIsStillOnIt() {
        #expect(Self.studio.stagePoint(CGPoint(x: 2559.5, y: 400)) == CGPoint(x: 2559.5, y: 1040))
    }

    @Test func aScreenOffTheMainOneMapsFromItsOwnCorner() {
        let edge = ScreenEdge(frame: Self.builtIn, visible: Self.builtIn)

        #expect(edge.stagePoint(CGPoint(x: 2560, y: 536)) == CGPoint(x: 0, y: 0))
        #expect(edge.stagePoint(CGPoint(x: 2600, y: 0)) == CGPoint(x: 40, y: 536))
        #expect(edge.stagePoint(CGPoint(x: 100, y: 0)) == nil)
        #expect(edge.window == CGRect(x: 2560, y: -581, width: ScreenEdge.depth, height: 1117))
    }

    @Test func theWindowRunsTheScreensFullHeightAgainstItsEdge() {
        #expect(Self.studio.window == CGRect(x: 0, y: 0, width: ScreenEdge.depth, height: 1440))
    }

    @Test(arguments: [0.3, 1.5, 4])
    func theWindowHoldsEverythingTheModelDraws(leaving speed: Double) {
        var lab = Lab()
        var deepest = 0.0

        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        lab.settle()
        lab.move(to: CGPoint(x: 1200, y: lab.notchY + 40), speed: speed) { lab in
            deepest = max(deepest, lab.frame.outline.boundingBoxOfPath.maxX)
            return false
        }
        lab.wait(1500) { lab in
            deepest = max(deepest, lab.frame.outline.boundingBoxOfPath.maxX)
            return false
        }

        // a slow leave stretches the edge to Hold before it breaks; a fast one outruns it, and the edge flings out
        // after the pointer as far as its speed throws it
        let feel = MeniscusFeel.lees
        let stretch = speed < 1 ? feel.hold : min(feel.hold, Tuning.fling * feel.pull * tanh(speed / Tuning.flingV))
        #expect(deepest > Tuning.panelDepth + stretch / 2)
        #expect(deepest < ScreenEdge.depth)
    }
}
