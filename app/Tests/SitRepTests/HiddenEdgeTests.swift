import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch and the strip, hidden as over a full-screen app and shown again, never leave the screen: their windows
/// stay ordered in throughout, and so on every Space. The display is far off every screen, so nothing shows.
@MainActor
@Suite(.backstop)
struct HiddenEdgeTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
    )

    @Test func theNotchStaysOnTheScreenHiddenAndShown() {
        let notch = NotchController(EdgeSettings(), on: Self.display, folding: Folding())

        defer { notch.window.close() }
        #expect(notch.window.isVisible)
        notch.isShown = true
        #expect(notch.window.isVisible)
        notch.isShown = false
        #expect(notch.window.isVisible)
    }

    @Test func theStripStaysOnTheScreenHiddenAndShown() {
        let strip = StripController(EdgeSettings(), on: Self.display, folding: Folding())

        defer { strip.window.close() }
        #expect(strip.window.isVisible)
        strip.isShown = true
        #expect(strip.window.isVisible)
        strip.isShown = false
        #expect(strip.window.isVisible)
    }
}
