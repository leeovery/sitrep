import AppKit
@testable import SitRep
import SitRepLines
import SitRepMenu
import SitRepPanel
import Testing

/// The callout a welcome's Done leaves beside the real edge, as `Edge` wires it to the notch and the strip, over shapes
/// of the test's own: no window shows, and the pointer is the test's.
@MainActor
struct EdgeCalloutTests {
    /// The notch or the strip, as the edge has it: shown or not, where it rests, and its hover hook.
    @MainActor
    final class Shape: CalloutShape {
        var isShown = false
        var restingBand: CGRect
        var onPointedAt: () -> Void = {}

        init(_ band: CGRect) {
            restingBand = band
        }
    }

    /// The edge's callout over a notch and a strip, as `Edge` makes it, and where it was placed, in turn.
    @MainActor
    final class Made {
        let defaults = MemoryDefaults()
        let preferences: Preferences
        let notch = Shape(CGRect(x: 0, y: 434, width: 7, height: 0))
        let strip = Shape(CGRect(x: 0, y: 434, width: 36, height: 0))
        var isRight = false
        var placed: [EdgeCallout.Beside?] = []
        private(set) var callout: EdgeCallout?

        init(_ standing: CalloutSettings.Standing = .unshown) {
            preferences = Preferences(defaults)
            preferences.callout = CalloutSettings(standing)
            callout = EdgeCallout(preferences, shapes: [notch, strip], isRight: { [unowned self] in isRight }) {
                [unowned self] in placed.append($0)
            }
        }

        /// The edge showing this shape, or neither, as Lee chose it, at Nothing or under a full-screen app.
        func show(_ shape: Shape?) {
            notch.isShown = shape === notch
            strip.isShown = shape === strip
            callout?.refresh()
        }

        func beside(_ shape: Shape) -> EdgeCallout.Beside {
            EdgeCallout.Beside(band: shape.restingBand, isRight: isRight)
        }
    }

    @Test func onlyOnceDueDoesItStandBesideTheShapeShowing() {
        let made = Made()

        made.show(made.notch)
        #expect(made.placed.isEmpty)
        made.preferences.callout.done()
        #expect(made.placed == [made.beside(made.notch)])
    }

    /// Beside the strip as the notch would be, on the side Lee chose; neither showing, nowhere.
    @Test func itStandsBesideWhicheverShowsOnItsSide() {
        let made = Made(.due)

        made.show(made.strip)
        made.isRight = true
        made.show(made.notch)
        made.show(nil)
        #expect(made.placed == [
            EdgeCallout.Beside(band: made.strip.restingBand, isRight: false), made.beside(made.notch), nil,
        ])
    }

    /// Done with neither showing, at Nothing or under a full-screen app, it waits for one to show, however long.
    @Test func dueWhileNeitherShowsItWaitsForOneToShow() {
        let made = Made()

        made.show(nil)
        made.preferences.callout.done()
        #expect(made.placed.isEmpty)
        made.show(made.strip)
        #expect(made.placed == [made.beside(made.strip)])
    }

    /// The first hover over either shape takes it away for good, saved; from then on the shapes tell it nothing.
    @Test func theFirstHoverTakesItAwayForGoodAndUnhooksTheShapes() {
        let made = Made(.due)

        made.show(made.strip)
        made.strip.onPointedAt()
        #expect(made.placed == [made.beside(made.strip), nil])
        #expect(Preferences(made.defaults).callout.standing == .gone)
        made.preferences.callout = CalloutSettings(.due)
        made.notch.onPointedAt()
        made.strip.onPointedAt()
        #expect(made.preferences.callout.shows)
    }

    /// A hover while it isn't due changes nothing: it still shows once Done leaves it.
    @Test func aHoverBeforeDoneChangesNothing() {
        let made = Made()

        made.show(made.notch)
        made.notch.onPointedAt()
        #expect(made.preferences.callout.standing == .unshown)
        made.preferences.callout.done()
        #expect(made.placed == [made.beside(made.notch)])
    }

    /// Gone already as SitRep starts, the shapes are never hooked at all.
    @Test func goneAlreadyItHooksNothing() {
        let made = Made(.gone)

        made.preferences.callout = CalloutSettings(.due)
        made.show(made.notch)
        made.notch.onPointedAt()
        #expect(made.preferences.callout.shows)
    }

    /// Its near side 14 past the shape's front, room for its shadow round it, its middle level with the notch's home.
    @Test func itStandsFourteenPastTheShapesFront() {
        let size = CGSize(width: 260, height: 90), room = CalloutWindow.room
        let left = CalloutWindow.frame(
            .init(band: CGRect(x: 0, y: 430, width: 7, height: 0), isRight: false), size: size
        )
        let right = CalloutWindow.frame(
            .init(band: CGRect(x: 1476, y: 430, width: 36, height: 0), isRight: true), size: size
        )

        #expect(left.minX + room == 7 + 14 && left.midY == 430 && left.size == size)
        #expect(right.maxX - room == 1476 - 14 && right.midY == 430)
    }

    /// The real shapes rest from targets: the notch's home band and the strip's resting width, whatever its frame.
    @Test func theShapesRestLevelWithTheNotchsHome() {
        let edge = ScreenEdge(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: .zero, edge: .right, along: 0.5
        )

        #expect(edge.homeBand(reaching: Strip.restingWidth) == CGRect(x: 1476, y: 491, width: 36, height: 0))
    }
}
