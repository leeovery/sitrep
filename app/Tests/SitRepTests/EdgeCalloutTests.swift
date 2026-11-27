import AppKit
@testable import SitRep
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// The callout a welcome's Done leaves beside the real edge, as `Edge` wires it to the notch, over a shape of the
/// test's own: no window shows, and the pointer is the test's.
@MainActor
@Suite(.backstop)
struct EdgeCalloutTests {
    /// The notch, as the edge has it: shown or not, where it rests, and its frames' hook.
    @MainActor
    final class Shape: CalloutShape {
        var isShown = false
        var restingBand: CGRect
        var onDrawn: ((Bool) -> Void)?

        /// Whether the shape tells of its frames.
        var isHooked: Bool { onDrawn != nil }

        init(_ band: CGRect) {
            restingBand = band
        }

        /// A frame drawn, the pointer over the shape or not, as the real one tells it.
        func draw(pointedAt: Bool = false) {
            onDrawn?(pointedAt)
        }
    }

    /// The edge's callout over a notch, as `Edge` makes it, and where it was placed, in turn.
    @MainActor
    final class Made {
        let defaults = MemoryDefaults()
        let preferences: Preferences
        let notch = Shape(CGRect(x: 0, y: 434, width: 7, height: 0))
        var isRight = false
        var placed: [EdgeCallout.Beside?] = []
        private(set) var callout: EdgeCallout?

        init(_ standing: CalloutSettings.Standing = .unshown) {
            preferences = Preferences(defaults)
            preferences.callout = CalloutSettings(standing)
            callout = EdgeCallout(preferences, shape: notch, isRight: { [unowned self] in isRight }) {
                [unowned self] in placed.append($0)
            }
        }

        /// The notch shown, or hidden, as Lee chose Nothing or a full-screen app has the display.
        func show(_ isShown: Bool) {
            notch.isShown = isShown
            callout?.refresh()
        }

        var beside: EdgeCallout.Beside {
            EdgeCallout.Beside(band: notch.restingBand, isRight: isRight)
        }
    }

    @Test func onlyOnceDueDoesItStandBesideTheNotchShowing() {
        let made = Made()

        made.show(true)
        #expect(made.placed.isEmpty)
        made.preferences.callout.done(.notch)
        #expect(made.placed == [made.beside])
    }

    /// Beside the notch, on the side Lee chose; with the notch hidden, nowhere.
    @Test func itStandsBesideTheNotchOnItsSide() {
        let made = Made(.due)

        made.show(true)
        made.isRight = true
        made.show(true)
        made.show(false)
        #expect(made.placed == [
            EdgeCallout.Beside(band: made.notch.restingBand, isRight: false), made.beside, nil,
        ])
    }

    /// Done with the notch hidden, at Nothing or under a full-screen app, it waits for the notch to show, however
    /// long.
    @Test func dueWhileTheNotchIsHiddenItWaitsForItToShow() {
        let made = Made()

        made.show(false)
        made.preferences.callout.done(.notch)
        #expect(made.placed.isEmpty)
        made.show(true)
        #expect(made.placed == [made.beside])
    }

    /// The first hover over the notch takes it away for good, saved; from then on the notch tells it nothing.
    @Test func theFirstHoverTakesItAwayForGoodAndUnhooksTheNotch() {
        let made = Made(.due)

        made.show(true)
        #expect(made.notch.isHooked)
        made.notch.draw()
        #expect(made.preferences.callout.shows)
        made.notch.draw(pointedAt: true)
        #expect(made.placed == [made.beside, nil])
        #expect(Preferences(made.defaults).callout.standing == .gone)
        #expect(!made.notch.isHooked)
    }

    /// Until Done leaves it, the notch tells it of no frame; Done hooks it.
    @Test func theNotchIsHookedOnlyOnceItIsDue() {
        let made = Made()

        made.show(true)
        #expect(!made.notch.isHooked)
        made.preferences.callout.done(.notch)
        #expect(made.notch.isHooked)
        #expect(made.placed == [made.beside])
    }

    /// Gone already as SitRep starts, the notch is never hooked at all.
    @Test func goneAlreadyItHooksNothing() {
        let made = Made(.gone)

        made.show(true)
        #expect(!made.notch.isHooked)
        #expect(made.placed.isEmpty)
    }

    /// The notch's front moves as it lights and goes dark: an ask moves it with the board, which refreshes the
    /// callout as `Edge` tells it; the last ask going, in the notch's next frame, which the callout hears of. Placed
    /// again only as the band it stands beside changes.
    @Test func theNotchsFrontMovingPlacesItAgain() {
        let made = Made(.due)

        made.show(true)
        made.notch.restingBand.size.width = 15
        made.callout?.refresh()
        made.notch.draw()
        made.notch.restingBand.size.width = 7
        made.notch.draw()
        made.notch.draw()
        #expect(made.placed.map { $0?.band.width } == [7, 15, 7])
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

    /// The real notch rests from targets: its home band, level with its home, whatever its frame.
    @Test func theNotchRestsLevelWithItsHome() {
        let edge = ScreenEdge(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: .zero, edge: .right, along: 0.5
        )

        #expect(edge.homeBand(reaching: 15) == CGRect(x: 1497, y: 491, width: 15, height: 0))
    }

    /// The real notch at rest, from its home band: further out the moment an ask lights it. Its going dark waits on
    /// its next frame, which no display draws far off every screen, where its display is, so nothing shows.
    @Test func theRealNotchRestsFurtherOutLitThanDark() {
        let display = Display(
            id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
            visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
        )
        let notch = NotchController(EdgeSettings(), on: display, folding: Folding(), keys: .none) { SnoozeSettings() }
        let now = Displays.wallNow

        defer { notch.window.close() }
        notch.show(WelcomeBoard.calm(at: now))

        let dark = notch.restingBand

        notch.show(WelcomeBoard.asked(at: now, isNew: false))

        let lit = notch.restingBand

        #expect(dark.width == 7 && lit.width == 15)
        #expect(dark.minX == display.frame.minX && dark.height == 0)
    }
}
