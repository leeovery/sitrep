@testable import SitRepCore
import SitRepLines
import Testing

/// `sitrep screen --json`, as the real CLI printed it, read as which sessions show on screen.
struct ScreenReadingTests {
    @Test func eachSessionAWindowHoldsSaysWhetherAJumpCouldReachIt() throws {
        let reading = try ScreenReading.read(Lines.screen)

        #expect(reading.onScreen(of: "sr-0nscrn") == .on)
        #expect(reading.onScreen(of: "sr-n0pane") == .off)
        #expect(reading.onScreen(of: "sr-n0srvr") == .off)
        #expect(reading.unanswered.isEmpty)
    }

    /// The app showing each session, as the CLI says it since it began to; none from one before, as `Lines.screen`.
    @Test func eachSessionOnScreenNamesTheAppShowingIt() throws {
        let reading = try ScreenReading.read(
            #"{"v": 1, "sessions": [{"id": "sr-0nscrn", "is": "on", "app": "Ghostty"}, {"id": "sr-n0pane", "is": "off", "app": null}], "unanswered": []}"#
        )

        #expect(reading.app(of: "sr-0nscrn") == "Ghostty")
        #expect(reading.app(of: "sr-n0pane") == nil)
        #expect(try ScreenReading.read(Lines.screen).app(of: "sr-0nscrn") == nil)
    }

    @Test func aSessionNotListedHasNoAnswerNotUnknown() throws {
        #expect(try ScreenReading.read(Lines.screen).onScreen(of: "sr-awayyy") == nil)
    }

    @Test func whereTmuxGaveNoAnswerItsSessionsAreUnknownAndItIsNamed() throws {
        let reading = try ScreenReading.read(Lines.screenUnanswered)

        #expect(reading.sessions.map(\.is) == [.unknown, .unknown, .unknown])
        #expect(reading.unanswered == ["tmux"])
    }

    @Test func anotherVersionIsNamedAsSuchWhateverItsShape() {
        #expect(throws: Unread.version(given: 2, read: 1)) { try ScreenReading.read(#"{"v": 2, "shown": {}}"#) }
    }

    @Test(arguments: [
        "", "not json", #"{"sessions": [], "unanswered": []}"#, #"{"v": 1, "sessions": []}"#,
        #"{"v": 1, "sessions": [{"id": "sr-0nscrn", "is": "maybe"}], "unanswered": []}"#,
    ])
    func outputThatIsNotAReadingIsUnread(json: String) {
        #expect(throws: Unread.shape) { try ScreenReading.read(json) }
    }
}
