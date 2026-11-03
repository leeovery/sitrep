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

    /// A box on the stage back on the screen, the way back from `stagePoint`: down from the screen's top, in from its
    /// edge, mirrored on the right.
    @Test func aBoxOnTheStageIsBackOnTheScreen() {
        let screen = CGRect(x: 2560, y: -581, width: 1728, height: 1117)
        let box = CGRect(x: 2, y: 400, width: 7, height: 60)
        let left = ScreenEdge(frame: screen, visible: .zero, edge: .left).screenRect(box)
        let right = ScreenEdge(frame: screen, visible: .zero, edge: .right).screenRect(box)

        #expect(left == CGRect(x: 2562, y: 536 - 460, width: 7, height: 60))
        #expect(right == CGRect(x: 4288 - 9, y: 536 - 460, width: 7, height: 60))
        #expect(ScreenEdge(frame: screen, visible: .zero).stagePoint(CGPoint(x: left.minX, y: left.maxY))
            == CGPoint(x: 2, y: 400))
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

    @Test func theNotchsHomeIsWhereTheSettingsPutItAlongTheEdge() {
        var settings = EdgeSettings()
        settings.edge = .right
        settings.along = 0.75

        let edge = ScreenEdge(Display(id: "studio", frame: Self.studio.frame, visible: Self.studio.visible), settings)

        #expect(edge.stage.notchY == 1080)
        #expect(edge.edge == .right)
        #expect(edge.moved(along: 0.25).stage.notchY == 360)
    }

    private static let right = ScreenEdge(frame: studio.frame, visible: studio.visible, edge: .right)

    @Test func onTheRightTheStageRunsInFromTheScreensRightSide() {
        #expect(Self.right.stagePoint(CGPoint(x: 2559.5, y: 1000)) == CGPoint(x: 0.5, y: 440))
        #expect(Self.right.stagePoint(CGPoint(x: 2160, y: 1000)) == CGPoint(x: 400, y: 440))
        #expect(Self.right.stage == Self.studio.stage)
    }

    @Test func onTheRightTheWindowIsAgainstTheRightSide() {
        #expect(Self.right.window == CGRect(x: 2560 - ScreenEdge.depth, y: 0, width: ScreenEdge.depth, height: 1440))
    }

    @Test func onTheLeftTheStageIsTheWindowsOwnAndOnTheRightItIsMirroredAcrossIt() {
        let point = CGPoint(x: 30, y: 500)

        #expect(point.applying(Self.studio.mirror) == point)
        #expect(point.applying(Self.right.mirror) == CGPoint(x: ScreenEdge.depth - 30, y: 500))
    }

    /// The point a pointer at the screen's right side, 30 in from it, is drawn at in the window: on the screen, where
    /// it is.
    @Test func throughTheMirrorAStagePointIsDrawnUnderThePointer() {
        let screenPoint = CGPoint(x: 2530, y: 900)
        let stage = Self.right.stagePoint(screenPoint)!

        let drawn = stage.applying(Self.right.mirror)

        #expect(Self.right.window.minX + drawn.x == screenPoint.x)
    }

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func aPointOnTheContentReadsLeftToRightOnEitherEdge(_ side: EdgeSettings.Edge) {
        let edge = ScreenEdge(frame: Self.studio.frame, visible: Self.studio.visible, edge: side)
        var lab = Lab(needsLee: true)
        lab.openByTouch()
        let panel = lab.frame.panel!
        // 20 in from the content's left as drawn: on the left edge, from the edge; on the right, from the front
        let stageX = side == .left ? panel.frame.minX + 20 : panel.frame.maxX - 20

        let point = panel.contentPoint(CGPoint(x: stageX, y: panel.frame.minY + 50), mirror: edge.mirror, scroll: 30)

        #expect(point == CGPoint(x: 20, y: 80))
    }

    @Test func theDisplayChosenIsTheOneOfThatIdWhileItIsConnectedElseTheMain() {
        let main = Display(id: "studio", frame: Self.studio.frame, visible: Self.studio.visible)
        let builtIn = Display(id: "built-in", frame: Self.builtIn, visible: Self.builtIn)

        #expect(Display.chosen("built-in", among: [main, builtIn]) == builtIn)
        #expect(Display.chosen(nil, among: [main, builtIn]) == main)
        #expect(Display.chosen("gone", among: [main, builtIn]) == main)
        #expect(Display.chosen(nil, among: []) == nil)
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
