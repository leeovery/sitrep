import AppKit
@testable import SitRep
import Testing

/// The jump's caption stays on the screen, and so on every Space, from the moment it is made, as the notch's window
/// does: clear until a caption is due, drawn whole while one plays, and clear again, never ordered out, once it is
/// kept from showing, as over a full-screen app.
@MainActor
struct CaptionWindowTests {
    @Test func itIsOnTheScreenFromTheStartClearAndTakingNoClicks() {
        let caption = CaptionWindow()

        defer { caption.window.close() }
        #expect(caption.window.isVisible)
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.ignoresMouseEvents)
    }

    @Test func keptFromShowingItStaysOnTheScreenClearAndTakingNoClicks() {
        let caption = CaptionWindow()

        defer { caption.window.close() }
        caption.over = CGRect(x: 0, y: 0, width: 1512, height: 958)
        caption.mayShow = true
        caption.jumping(to: "SitRep")
        caption.drained(at: 0)
        caption.answered(jumped: true, at: 0)
        #expect(caption.window.alphaValue == 1)
        #expect(caption.window.ignoresMouseEvents)

        caption.mayShow = false
        #expect(caption.window.isVisible)
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.ignoresMouseEvents)
    }
}
