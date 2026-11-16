import Foundation
import SitRepTestSupport
import Testing

@Suite(.backstop, .tags(.thisMac))
struct HandshakeTests {
    /// A child that lets the pipe go without ending its line has said all it will: its line is read as it goes, never
    /// waited on to the time.
    @Test func aLineLeftUnendedIsReadAsTheChildLetsThePipeGo() async throws {
        let handshake = try Handshake()
        let child = Process()

        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = ["-c", "printf 4012 > '\(handshake.path)'"]
        try child.run()
        defer { child.terminate() }

        #expect(try await handshake.line() == "4012")
    }
}
