import AppKit
@testable import SitRep
import Testing

/// The notch's and the strip's window stays on the screen, and so on every Space, from the moment it is made: hidden,
/// as over a full-screen app, it is clear and takes no clicks, whatever the frame says, and its layers' time stands
/// still; shown, it is drawn whole, takes the clicks the frame says, and its layers keep the display's time.
@MainActor
struct EdgeWindowTests {
    private static let frame = CGRect(x: 0, y: 0, width: 40, height: 40)

    @Test func itIsOnTheScreenFromTheStartHiddenAndTakingNoClicks() {
        let window = EdgeWindow.onScreen(frame: Self.frame, view: NSView())

        defer { window.close() }
        #expect(window.isVisible)
        #expect(window.alphaValue == 0)
        #expect(window.ignoresMouseEvents)
    }

    @Test func shownItIsDrawnWholeAndTakesTheClicksTheFrameSays() {
        let window = EdgeWindow.onScreen(frame: Self.frame, view: NSView())

        defer { window.close() }
        window.isShown = true
        #expect(window.alphaValue == 1)
        #expect(window.ignoresMouseEvents)
        window.takesClicks = true
        #expect(!window.ignoresMouseEvents)
        window.takesClicks = false
        #expect(window.ignoresMouseEvents)
    }

    @Test func hiddenAgainItStaysOnTheScreenClearAndTakingNoClicks() {
        let window = EdgeWindow.onScreen(frame: Self.frame, view: NSView())

        defer { window.close() }
        window.isShown = true
        window.takesClicks = true
        window.isShown = false
        #expect(window.isVisible)
        #expect(window.alphaValue == 0)
        #expect(window.ignoresMouseEvents)
    }

    @Test func hiddenItTakesNoClicksWhateverTheFrameSaysUntilItShows() {
        let window = EdgeWindow.onScreen(frame: Self.frame, view: NSView())

        defer { window.close() }
        window.takesClicks = true
        #expect(window.ignoresMouseEvents)
        window.isShown = true
        #expect(!window.ignoresMouseEvents)
    }

    /// What turns in the render server, as an arc does, is on its layer's time: hidden, a second on the display's
    /// clock moves it not at all; shown, a second.
    @Test func hiddenItsLayersTimeStandsStillAndShownItRunsWithTheDisplays() throws {
        let view = NSView()
        let window = EdgeWindow.onScreen(frame: Self.frame, view: view)
        let turning = CALayer()

        defer { window.close() }
        try #require(view.layer).addSublayer(turning)
        #expect(Self.second(on: turning) == 0)
        window.isShown = true
        #expect(abs(Self.second(on: turning) - 1) < 1e-6)
        window.isShown = false
        #expect(Self.second(on: turning) == 0)
    }

    /// How long a second on the display's clock is on a layer's.
    private static func second(on layer: CALayer) -> Double {
        let now = CACurrentMediaTime()

        return layer.convertTime(now + 1, from: nil) - layer.convertTime(now, from: nil)
    }
}
