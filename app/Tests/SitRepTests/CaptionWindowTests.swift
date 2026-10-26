import AppKit
@testable import SitRep
import Testing

/// The jump's caption stays on the screen, and so on every Space, from the moment it is made, as the notch's window
/// does: clear until a caption is due, drawn whole while one plays, and clear again, never ordered out, once it is
/// kept from showing, as over a full-screen app, or once it has played. It shows far off every screen, so nothing
/// shows.
@MainActor
struct CaptionWindowTests {
    private static let over = CGRect(x: -20000, y: -20000, width: 1512, height: 958)

    @Test func itIsOnTheScreenFromTheStartClearAndTakingNoClicks() {
        let caption = CaptionWindow()

        defer { caption.window.close() }
        #expect(caption.window.isVisible)
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.ignoresMouseEvents)
    }

    @Test func keptFromShowingItStaysOnTheScreenClearAndTakingNoClicks() {
        let caption = Self.showing()

        defer { caption.window.close() }
        #expect(caption.window.alphaValue == 1)
        #expect(caption.window.ignoresMouseEvents)

        caption.mayShow = false
        #expect(caption.window.isVisible)
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.ignoresMouseEvents)
    }

    @Test func playedToItsEndItStaysOnTheScreenClear() async throws {
        let caption = Self.showing()

        defer { caption.window.close() }
        for _ in 0 ..< 40 where caption.window.alphaValue != 0 {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.isVisible)
    }

    /// A caption on its way, due 90ms from now as a jump from a row answers at once.
    private static func showing() -> CaptionWindow {
        let caption = CaptionWindow()

        caption.over = over
        caption.mayShow = true
        caption.jumping(to: "SitRep")
        caption.drained(at: 0)
        caption.answered(jumped: true, at: 0)
        return caption
    }
}
