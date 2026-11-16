import AppKit
@testable import SitRep
import SitRepCore
import SitRepTestSupport
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

    /// Core Animation's own animations, as the app plays them: its real fade ends, and the window is clear.
    @Test func onCoreAnimationItHidesAsItsFadeEnds() async {
        let caption = Self.showing(CoreAnimations())

        defer { caption.window.close() }
        #expect(caption.window.alphaValue == 1)
        await until(within: .seconds(20)) { caption.window.alphaValue == 0 }
        #expect(caption.says == nil)
    }

    @Test func playedToItsEndItStaysOnTheScreenClear() {
        let animations = SteppedAnimations()
        let caption = Self.showing(animations)

        defer { caption.window.close() }
        #expect(caption.window.alphaValue == 1)
        animations.playOut()
        #expect(caption.window.alphaValue == 0)
        #expect(caption.window.isVisible)
    }

    /// A jump from anywhere with no answer two seconds on says so, held while it runs, though a later jump stops it;
    /// at its limit, the limit's words take its place.
    @Test func aJumpWithNoAnswerSaysItIsStillJumpingUntilItsLimitSaysTheMacIsTooBusy() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.heard(.still)
        #expect(caption.says == "Still jumping…")
        #expect(caption.window.alphaValue == 1)

        caption.heard(.ended(.stopped))
        #expect(caption.says == "Still jumping…")

        caption.heard(.ended(.unanswered))
        #expect(caption.says == "Couldn't jump: the Mac is too busy.")
    }

    /// A jump stopped by a later one shows nothing of its own: no failure, no caption.
    @Test func aJumpStoppedByALaterOneShowsNothing() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.heard(.ended(.stopped))
        #expect(caption.says == nil)
        #expect(caption.window.alphaValue == 0)
    }

    /// A row's jump that jumps after saying it was still jumping: "Jumped to…" takes the pill's place, and the jump's
    /// end leaves it.
    @Test func aRowsJumpedToTakesThePlaceOfStillJumping() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.heard(.still)
        caption.answered(.jumped, at: 2000)
        caption.heard(.ended(.jumped))

        #expect(caption.says == "Jumped to Trey Research's window")
    }

    /// A row's click that opened a window, no window showing its session: "Opened a window for…", once the opening
    /// ends; the jump that found it could, answering openable, ends nothing.
    @Test func aRowsOpeningSaysItOpenedAWindow() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.heard(.ended(.openable))
        caption.answered(.opened, at: 500)
        caption.heard(.ended(.opened))

        #expect(caption.says == "Opened a window for Trey Research")
    }

    /// A window brought forward with a word for Lee, as for a Claude he suspended there: the caption says it jumped,
    /// the word left to its banner.
    @Test func aJumpWithAWordSaysItJumped() {
        let caption = Self.shown()
        let answer = JumpAnswer.jumpedSaying("Trey Research is suspended in this window: type fg to bring it back.")

        defer { caption.window.close() }
        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.answered(answer, at: 500)
        caption.heard(.ended(answer))

        #expect(caption.says == "Jumped to Trey Research's window")
    }

    /// An opening with no answer two seconds on says it is still opening, held while it runs.
    @Test func anOpeningWithNoAnswerSaysItIsStillOpening() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.heard(.stillOpening)
        #expect(caption.says == "Still opening…")
        #expect(caption.window.alphaValue == 1)
    }

    /// A click on a session a window was asked for a moment ago, none showing it yet: nothing opened, so it says the
    /// window is opening.
    @Test func aRowsClickOnAWindowAlreadyOpeningSaysItIsOpening() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.answered(.opening, at: 500)
        caption.heard(.ended(.opening))

        #expect(caption.says == "A window for Trey Research is opening")
    }

    /// An earlier jump's stop, heard after a row's click began its own, leaves that row's "Jumped to…" waiting for its
    /// own answer: a stale stop is no answer to the click under way.
    @Test func aStaleStopLeavesARowsJumpedToWaiting() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.heard(.ended(.stopped))
        caption.answered(.jumped, at: 500)

        #expect(caption.says == "Jumped to Trey Research's window")
    }

    /// A jump refused after saying it was still jumping lets the pill go, as a caption ends; its banner says why.
    @Test func aJumpRefusedLetsStillJumpingGo() {
        let animations = SteppedAnimations()
        let caption = Self.shown(animations)

        defer { caption.window.close() }
        caption.heard(.still)
        caption.heard(.ended(.refused("Wingtip is not on screen.")))
        #expect(caption.says == "Still jumping…")
        animations.playOut()
        #expect(caption.says == nil)
        #expect(caption.window.alphaValue == 0)
    }

    @Test func keptFromShowingAJumpWithNoAnswerShowsNothing() {
        let caption = Self.shown()

        defer { caption.window.close() }
        caption.mayShow = false
        caption.heard(.still)
        caption.heard(.ended(.unanswered))
        #expect(caption.says == nil)
        #expect(caption.window.alphaValue == 0)
    }

    /// Its animations played out only as the test says.
    private static func shown(_ animations: any LayerAnimations = SteppedAnimations()) -> CaptionWindow {
        let caption = CaptionWindow(animations: animations)

        caption.over = over
        caption.mayShow = true
        return caption
    }

    /// A caption on its way, due 90ms from now as a jump from a row answers at once.
    private static func showing(_ animations: any LayerAnimations = SteppedAnimations()) -> CaptionWindow {
        let caption = shown(animations)

        caption.jumping(to: "Trey Research")
        caption.drained(at: 0)
        caption.answered(.jumped, at: 0)
        return caption
    }
}

/// A layer's animations added to it, and played out, each taken off and its end told, only as the test says. One added
/// under the key of one playing takes its place, whose end is told at once, as Core Animation tells it.
@MainActor
private final class SteppedAnimations: LayerAnimations {
    private var playing: [(layer: CALayer, key: String, ended: @MainActor () -> Void)] = []

    func add(_ animation: CAAnimation, to layer: CALayer, forKey key: String, ended: @escaping @MainActor () -> Void) {
        let replaced = playing.filter { $0.layer === layer && $0.key == key }

        playing.removeAll { $0.layer === layer && $0.key == key }
        layer.add(animation, forKey: key)
        playing.append((layer, key, ended))
        replaced.forEach { $0.ended() }
    }

    /// Every animation playing played to its end.
    func playOut() {
        let played = playing

        playing = []
        for (layer, key, ended) in played {
            layer.removeAnimation(forKey: key)
            ended()
        }
    }
}
