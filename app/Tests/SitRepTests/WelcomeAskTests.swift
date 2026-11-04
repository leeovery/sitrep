import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// Step 2, An ask, from Claude to you: one loop on the stage, on SitRep's own notch, and nothing pressed or sent.
/// Frames run on a clock of the test's own, never awaiting between them, so no frame on the display's clock comes
/// between them.
@MainActor
struct WelcomeAskTests {
    typealias Made = WelcomeWindowTests.Made

    /// The welcome at step 2, the stage told it, its window in front.
    private static func atAsk() async -> Made {
        let made = Made()

        made.at(.ask)
        _ = await made.settled()
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
        return made
    }

    /// The stage stepped a 60th at a time from this time until its loop is this far in: the time it got to.
    @discardableResult
    private static func play(_ stage: StageEdge, from start: Double, until loopTime: Double) -> Double {
        var time = start

        while stage.loopTime < loopTime {
            time += 1000 / 60
            stage.step(at: time)
        }
        return time
    }

    @Test func itPlaysItsOwnLoopWithThePanelRoomyAsStepOnes() async throws {
        let made = await Self.atAsk()

        #expect(made.welcome.step == .ask)
        #expect(try made.stage.play == .answer)
        #expect(try made.stage.scale == StageEdge.loopScale)
    }

    /// The panel pours on the ask's row, which the click presses in; the jump landing drains it, as the real one's
    /// does.
    @Test func theClickPressesTheRowAndThePanelDrainsAsTheJumpLands() async throws {
        let made = await Self.atAsk()
        let stage = try made.stage, loop = WelcomeLoop.ask
        var time = Self.play(stage, from: Displays.now, until: try #require(loop.clicks) - 100)

        #expect(stage.isOut && stage.row != nil && !stage.isPressing)
        time = Self.play(stage, from: time, until: try #require(loop.clicks) + 20)
        #expect(stage.isPressing)
        Self.play(stage, from: time, until: loop.leave + 600)
        #expect(!stage.isPressing && !stage.isOut)
    }

    /// The ask's row not found at the click, as the notch was made anew just before it, nothing is pressed: a press off
    /// the row would start a drag nothing lets go.
    @Test func withNoRowFoundTheClickPressesNothing() async throws {
        let made = await Self.atAsk()
        let stage = try made.stage, loop = WelcomeLoop.ask
        var time = Self.play(stage, from: Displays.now, until: try #require(loop.clicks) - 40)

        made.preferences.edit { $0.show = .strip }
        time = Self.play(stage, from: time, until: try #require(loop.clicks) - 20)
        made.preferences.edit { $0.show = .notch }
        Self.play(stage, from: time, until: try #require(loop.clicks) + 20)
        #expect(stage.row == nil && !stage.isPressing)
    }

    /// The scene told the desktop and the words in step with the loop: lit, opened, then answered in the session,
    /// the session's window forward and the answer in it; the ask gone, so the light is out.
    @Test func theWordsAndTheDesktopFollowTheLoop() async throws {
        let made = await Self.atAsk()
        let stage = try made.stage, loop = WelcomeLoop.ask
        let beats = try [loop.lands, loop.approach, #require(loop.clicks), #require(loop.answers), #require(loop.resolves)]
        var time = Displays.now, told: [WelcomeLoop.Scene] = []

        for beat in beats {
            time = Self.play(stage, from: time, until: beat + 20)
            told.append(stage.told)
        }
        #expect(told.map(\.moment) == [.lands, .opens, .answers, .answers, nil])
        #expect(told.map(\.isInSession) == [false, false, false, true, true])
        #expect(told.map(\.isAnswered) == [false, false, false, true, true])
        await Task.yield()
        #expect(stage.scene.now == told.last)
    }

    /// Answered, the ask leaves the board: the light goes out, and nothing on the notch moves of itself.
    @Test func theAnswerTakesTheAskAwaySoTheLightGoesOut() async throws {
        let made = await Self.atAsk()
        let stage = try made.stage, loop = WelcomeLoop.ask
        let time = Self.play(stage, from: Displays.now, until: loop.lands + 2_000)

        #expect(stage.lastPace == .light || stage.lastPace == .moving)
        Self.play(stage, from: time, until: try #require(loop.resolves) + 2_000)
        #expect(stage.lastPace == .still)
    }

    /// Nothing from step 2 reaches the real edge, the board, the CLI or macOS, and it plays no sound, however long it
    /// loops.
    @Test func itSendsNothingAnywhereAndPlaysNothing() async throws {
        let made = await Self.atAsk()

        try Self.play(made.stage, from: Displays.now, until: 2 * WelcomeLoop.ask.length)
        made.welcome.goOn()
        #expect(made.mac.played.isEmpty && made.mac.stops == 0)
        #expect(made.mac.jumps.isEmpty && made.mac.tests == 0 && made.mac.copies.isEmpty)
        #expect(made.mac.opened.isEmpty && made.mac.asksForNotices == 0 && made.mac.allows.isEmpty)
        #expect(made.mac.registers == 0 && made.mac.opensGhostty == 0)
        #expect(!made.preferences.callout.shows)
    }
}
