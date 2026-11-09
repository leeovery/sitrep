import AppKit
import CoreServices
@testable import SitRepScreen
import Testing

/// SitRep's lookup sent live to apps lacking Ghostty's terms, as a Ghostty before 1.4 lacks them, to find which errors
/// such a Ghostty gives hand-built events, which osascript gave as -2753 and -2741: each must read as too old. Run with
/// `SITREP_LIVE_EVENTS=1`, and only with Lee's go: it opens Calculator and TextEdit without bringing them forward, and
/// macOS asks once whether the terminal running the tests may control each.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SITREP_LIVE_EVENTS"] == "1"), .serialized)
struct LiveEventsTests {
    @Test(arguments: [
        ("com.apple.calculator", "Gtrm", "no dictionary at all, as before Ghostty could be scripted"),
        ("com.apple.TextEdit", "Gtrm", "a dictionary without Ghostty's terminals"),
        ("com.apple.TextEdit", "docu", "a class it knows, without the terminal's tty, as Ghostty's terminals before 1.4"),
    ])
    func aLookupAnAppLacksTheTermsOfReadsAsTooOld(bundle: String, type: String, why: String) async throws {
        let pid = try await Self.opened(bundle)
        let read = await Task.detached { Self.lookup(code(type), sentTo: pid) }.value

        #expect(read.failure == .tooOld, "\(why): answered \(read.answer), \(read.failure.map(String.init(describing:)) ?? "no error")")
    }

    /// SitRep's lookup with the class given, `tty` its property, sent to the process: what it answered, in words, and
    /// what that reads as.
    private static func lookup(_ type: FourCharCode, sentTo pid: pid_t) -> (answer: String, failure: GhosttyFailure?) {
        let test = Specifier.comparison(
            Specifier.property(GhosttyEvent.Code.tty, of: Specifier.examined), DescType(kAEEquals), "/dev/ttys000"
        )
        let event = GhosttyEvent(
            eventClass: kAECoreSuite, eventID: kAEGetData, direct: Specifier.whose(type, of: Specifier.application, test)
        ).addressed(to: pid)

        let sent = GhosttyEvents.sent(event, within: GhosttyEvents.answerSeconds)
        let answer = "status \(sent.status), reply \(rendered(sent.reply.paramDescriptor(forKeyword: keyDirectObject))), "
            + "error \(rendered(sent.reply.paramDescriptor(forKeyword: keyErrorNumber)))"

        return (answer, GhosttyEvent.failure(in: sent, isLookup: true))
    }

    /// The app opened, not brought forward, once it has finished launching: its process.
    private static func opened(_ bundle: String) async throws -> pid_t {
        let url = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle))
        let configuration = NSWorkspace.OpenConfiguration()

        configuration.activates = false

        let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)

        for _ in 0..<50 where !app.isFinishedLaunching {
            try await Task.sleep(for: .milliseconds(100))
        }
        return app.processIdentifier
    }
}
