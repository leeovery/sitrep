import CoreGraphics
@testable import SitRepPanel
import Testing

/// Lee's screens: the Studio Display with the menu bar, its Dock at the bottom, and the built-in to its right.
struct ScreenEdgeTests {
    static let studio = ScreenEdge(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visible: CGRect(x: 0, y: 86, width: 2560, height: 1324)
    )
    static let builtIn = CGRect(x: 2560, y: -581, width: 1728, height: 1117)

    @Test func theStageIsTheScreensHeightWithItsVisibleFrameFromTheTopAndTheLip042OfTheWayDown() {
        #expect(Self.studio.stage == Stage(height: 1440, visibleTop: 30, visibleBottom: 1354, lipY: 1440 * 0.42))
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
    func theWindowHoldsEverythingTheModelDrawsAtTheLoosestSettings(leaving speed: Double) {
        var loosest = Settings()
        loosest.hold = Dial.hold.range.upperBound
        loosest.pull = Dial.pull.range.upperBound
        loosest.bounce = Dial.bounce.range.upperBound
        var lab = Lab(settings: loosest)
        var deepest = 0.0

        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.lipY), speed: 0.3)
        lab.settle()
        lab.move(to: CGPoint(x: 1200, y: lab.lipY + 40), speed: speed) { lab in
            deepest = max(deepest, lab.frame.outline.boundingBoxOfPath.maxX)
            return false
        }
        lab.wait(1500) { lab in
            deepest = max(deepest, lab.frame.outline.boundingBoxOfPath.maxX)
            return false
        }

        #expect(deepest > Tuning.panelDepth + Dial.hold.range.upperBound / 2)
        #expect(deepest < ScreenEdge.depth)
    }
}
