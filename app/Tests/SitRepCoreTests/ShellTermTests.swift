import Foundation
@testable import SitRepCore
import Testing

/// Bun, where this Mac has it: the CLI's own runtime.
private let bun = (
    (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        + ["\(NSHomeDirectory())/.bun/bin", "/opt/homebrew/bin"]
)
    .map { "\($0)/bun" }
    .first { FileManager.default.isExecutableFile(atPath: $0) }

/// The CLI's binding to Bun (cli/shell/index.ts) holding an undo while SIGTERM comes, run on the real Bun: what it
/// holds is undone, once, before the run exits 143; let go, SIGTERM ends the run as ever.
@Suite(.enabled(if: bun != nil))
struct ShellTermTests {
    /// The plugin's checkout, from this file's place in it.
    private static let checkout = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "../../..").standardizedFileURL

    /// Bun on a script that holds an undo writing to a file, lets it go if told, then tells itself to end twice.
    private static func run(lettingGo: Bool) async throws -> (Ran, String?) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-term-\(UUID().uuidString)")
        let script = folder.appending(path: "hold.ts"), undone = folder.appending(path: "undone")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try """
        import { appendFileSync } from 'node:fs'
        import { atTerm } from '\(checkout.appending(path: "cli/shell/index.ts").path)'

        const letGo = atTerm(async () => appendFileSync('\(undone.path)', 'undone\\n'))

        if (\(lettingGo)) {
          letGo()
        }

        process.kill(process.pid, 'SIGTERM')
        process.kill(process.pid, 'SIGTERM')
        setTimeout(() => process.exit(0), 3_000)
        """.write(to: script, atomically: true, encoding: .utf8)

        let ran = try await runProgram(Program(
            executable: URL(fileURLWithPath: try #require(bun)), arguments: [script.path],
            environment: ProcessInfo.processInfo.environment, limit: 20
        ))

        return (ran, try? String(contentsOf: undone, encoding: .utf8))
    }

    @Test func heldTheUndoRunsOnceBeforeTheRunExits143() async throws {
        let (ran, undone) = try await Self.run(lettingGo: false)

        #expect(ran.status == 143)
        #expect(undone == "undone\n")
    }

    @Test func letGoSIGTERMEndsTheRunAsEverUndoingNothing() async throws {
        let (ran, undone) = try await Self.run(lettingGo: true)

        #expect(ran.status == SIGTERM)
        #expect(undone == nil)
    }
}
