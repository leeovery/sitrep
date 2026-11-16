import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// A press on the notch carries it once it moves more than 4 points: along the edge with the pointer, and past the
/// screen's middle to the other edge.
@Suite(.backstop)
struct NotchDragTests {
    private static let width = 1512.0, height = 982.0
    private static let press = CGPoint(x: 2, y: 400)

    @Test func aPressMovedFourPointsOrLessIsNoDrag() {
        var drag = NotchDrag(at: Self.press, home: 412)

        let begins = drag.move(to: CGPoint(x: 4, y: 403), width: Self.width)

        #expect(!begins)
        #expect(!drag.isCarrying)
    }

    @Test func movedFurtherItBecomesADragOnce() {
        var drag = NotchDrag(at: Self.press, home: 412)

        let begins = drag.move(to: CGPoint(x: 2, y: 405), width: Self.width)
        let beginsAgain = drag.move(to: CGPoint(x: 2, y: 420), width: Self.width)

        #expect(begins)
        #expect(!beginsAgain)
        #expect(drag.isCarrying)
    }

    @Test func theNotchFollowsThePointerAlongTheEdgeFromWhereItWas() {
        var drag = NotchDrag(at: Self.press, home: 412)

        drag.move(to: CGPoint(x: 30, y: 250), width: Self.width)

        #expect(drag.notchY == 262)
    }

    @Test func pastTheMiddleItIsAcrossAndBackItIsNot() {
        var drag = NotchDrag(at: Self.press, home: 412)

        drag.move(to: CGPoint(x: 757, y: 400), width: Self.width)
        #expect(drag.isAcross)

        drag.move(to: CGPoint(x: 700, y: 400), width: Self.width)
        #expect(!drag.isAcross)
    }

    @Test func letGoItSavesItsPlaceAlongTheEdgeAsAShareOfTheScreen() {
        var drag = NotchDrag(at: Self.press, home: 412)
        drag.move(to: CGPoint(x: 30, y: 250), width: Self.width)

        let dropped = drag.dropped(EdgeSettings(), at: 245.5, height: Self.height)

        #expect(dropped.along == 0.25)
        #expect(dropped.edge == .left)
    }

    @Test(arguments: [(EdgeSettings.Edge.left, EdgeSettings.Edge.right), (.right, .left)])
    func letGoAcrossItGoesToTheOtherEdge(from: EdgeSettings.Edge, to: EdgeSettings.Edge) {
        var settings = EdgeSettings()
        settings.edge = from
        var drag = NotchDrag(at: Self.press, home: 412)
        drag.move(to: CGPoint(x: 1000, y: 400), width: Self.width)

        #expect(drag.dropped(settings, at: 412, height: Self.height).edge == to)
    }

    @Test func letGoItKeepsTheRestOfTheSettings() {
        var settings = EdgeSettings()
        settings.style = .card
        settings.material = .glass
        var drag = NotchDrag(at: Self.press, home: 412)
        drag.move(to: CGPoint(x: 30, y: 250), width: Self.width)

        let dropped = drag.dropped(settings, at: 262, height: Self.height).applied(to: settings)

        #expect(dropped.style == .card)
        #expect(dropped.material == .glass)
    }
}
