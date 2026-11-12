import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

struct TmuxTests {
    private static let socket = "/private/tmp/tmux-501/default"

    @Test func panesReadAsEachOnesWindowTheSessionsItIsInListedOnceForEachAndItsDevice() {
        let panes = parsePanes(
            [
                "%148\t@45\t$7\t/dev/ttys043",
                "%54\t@52\t$9\t/dev/ttys044",
                "%148\t@45\t$8\t/dev/ttys043",
                "%148\t@45\t$7\t/dev/ttys043",
                "%55\t@53\t$9",
                "",
            ].joined(separator: "\n")
        )

        #expect(
            panes == [
                "%148": Pane(window: "@45", sessions: ["$7", "$8"], device: "/dev/ttys043"),
                "%54": Pane(window: "@52", sessions: ["$9"], device: "/dev/ttys044"),
            ]
        )
    }

    @Test func clientsReadAsEachOnesDeviceProcessWindowAndSessionALineWithoutItsFieldsSkipped() {
        let clients = parseClients("/dev/ttys000\t503\t@45\t$7\nnot a client\n/dev/ttys041\t523\t@52\n\t604\t@52\t$9\tmore\n")

        #expect(
            clients == [
                TmuxClient(device: "/dev/ttys000", pid: 503, window: "@45", session: "$7"),
                TmuxClient(device: "", pid: 604, window: "@52", session: "$9\tmore"),
            ]
        )
    }

    @Test func aServerIsAskedForItsPanesAndClientsAndNoServerOnTheSocketIsAnAnswer() async {
        let tmux = FakeTmux([Self.socket: FakeServer(panes: [FakePane(pane: "%1", window: "@1", session: "$1")])])
        let adapter = TmuxAdapter(tmux)

        #expect(await adapter.readServer(Self.socket) == .server(TmuxServer(panes: parsePanes("%1\t@1\t$1\t"), clients: [])))
        #expect(await adapter.readServer("/private/tmp/tmux-501/gone") == .noServer)
        #expect(await TmuxAdapter(FakeTmux(silent: true)).readServer(Self.socket) == .unanswered)
        #expect(Set(tmux.runs) == [[Self.socket, "list-panes"], [Self.socket, "list-clients"], ["/private/tmp/tmux-501/gone", "list-panes"], ["/private/tmp/tmux-501/gone", "list-clients"]])
    }

    @Test func tmuxIsFoundOnLeesPathToldItsClientTakesUTF8GivenTheSocketAndTwoSecondsAndStoppedWithItsGroup() async throws {
        let folder = try Self.folderHolding("tmux")
        let ran = OSAllocatedUnfairLock(initialState: [Program]())
        let tmux = TmuxOnPath(path: "/nowhere:\(folder.path)", environment: ["HOME": "/Users/lee", "PATH": "/usr/bin"]) { program in
            ran.withLock { $0.append(program) }

            return Ran(status: 0, stdout: "", stderr: "")
        }

        #expect(try await tmux.run(on: Self.socket, ["list-clients"]) == Ran(status: 0, stdout: "", stderr: ""))
        #expect(
            ran.withLock { $0 } == [
                Program(
                    executable: folder.appending(path: "tmux"),
                    arguments: ["-u", "-S", Self.socket, "list-clients"],
                    environment: ["HOME": "/Users/lee", "PATH": "/nowhere:\(folder.path)"],
                    limit: 2,
                    stopping: .group
                ),
            ]
        )
    }

    @Test func aFolderNamedTmuxOnThePathIsPassedOverAsAShellPassesItOver() throws {
        let folder = try Self.folderHolding("tmux")
        let decoy = FileManager.default.temporaryDirectory.appending(path: "sitrep-screen-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: decoy.appending(path: "tmux"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: decoy) }

        #expect(TmuxOnPath.find("tmux", on: "\(decoy.path):\(folder.path)") == folder.appending(path: "tmux"))
        #expect(TmuxOnPath.find("tmux", on: decoy.path) == nil)
    }

    @Test func tmuxExitingNonZeroAnswersNoServerOnlyWhereItsWordsSayNoneRunsOnTheSocket() async throws {
        let folder = try Self.folderHolding("tmux")
        let noServer = [
            "no server running on \(Self.socket)\n",
            "error connecting to \(Self.socket) (No such file or directory)\n",
        ]

        for said in noServer {
            let tmux = TmuxOnPath(path: folder.path) { _ in Ran(status: 1, stdout: "", stderr: said) }

            #expect(await TmuxAdapter(tmux).readServer(Self.socket) == .noServer, "\(said)")
        }
    }

    @Test func anyOtherErrorFromTmuxLeavesTheServerUnknownInTmuxsWordsTrimmed() async throws {
        let folder = try Self.folderHolding("tmux")
        let failures = [
            "protocol version mismatch (client 8, server 7)",
            "error connecting to \(Self.socket) (Permission denied)",
            "lost server",
            "",
        ]

        for said in failures {
            let tmux = TmuxOnPath(path: folder.path) { _ in Ran(status: 1, stdout: "", stderr: " \(said)\n") }

            #expect(await TmuxAdapter(tmux).readServer(Self.socket) == .failed(said: said), "\(said)")
        }
    }

    @Test func tmuxsWordsAreItsLastLineSoAWarningAheadOfThemNeitherHidesNoServerNorIsQuoted() async throws {
        let folder = try Self.folderHolding("tmux")
        let warning = "dyld[4242]: warning: libevent was built for a newer macOS\n"
        let cases: [(String, ServerRead)] = [
            ("no server running on \(Self.socket)\n\n", .noServer),
            ("protocol version mismatch (client 8, server 7) \n", .failed(said: "protocol version mismatch (client 8, server 7)")),
        ]

        for (said, read) in cases {
            let tmux = TmuxOnPath(path: folder.path) { _ in Ran(status: 1, stdout: "", stderr: warning + said) }

            #expect(await TmuxAdapter(tmux).readServer(Self.socket) == read, "\(said)")
        }
    }

    @Test func eitherListFailingFailsTheServerThoughTheOtherAnswered() async throws {
        let folder = try Self.folderHolding("tmux")

        for failing in ["list-panes", "list-clients"] {
            let tmux = TmuxOnPath(path: folder.path) { program in
                program.arguments.contains(failing)
                    ? Ran(status: 1, stdout: "", stderr: "lost server\n")
                    : Ran(status: 0, stdout: "%1\t@1\t$1\t/dev/ttys000\n", stderr: "")
            }

            #expect(await TmuxAdapter(tmux).readServer(Self.socket) == .failed(said: "lost server"), "\(failing)")
        }
    }

    @Test func aServerTmuxFailedOnMakesItsWindowsUnknownInItsWordsNeverOffScreen() {
        let said = "protocol version mismatch (client 8, server 7)"
        let reading = TmuxReading(servers: [Self.socket: .failed(said: said)])

        #expect(reading.unanswered(inTmux(on: Self.socket)) == [.tmuxSaid(said)])
        #expect(Screen(readings: [reading], processes: nil).reach(of: [inTmux(on: Self.socket)]) == .unknown([.tmuxSaid(said)]))
        #expect(!reading.holds(inTmux(on: Self.socket), Processes([:])), "nothing to open a window onto")
    }

    /// Each told apart from the other, and from tmux's answer of no server.
    @Test func tmuxNotOnThePathOrNotAnsweringInTimeGivesNoAnswerNeverAnAnswerOfNoServer() async throws {
        let folder = try Self.folderHolding("tmux")
        let missing = TmuxOnPath(path: "/nowhere") { _ in Ran(status: 1, stdout: "", stderr: "") }
        let slow = TmuxOnPath(path: folder.path) { program in throw RunError.timedOut(program.limit) }

        await #expect(throws: TmuxUnanswered.notFound) { try await missing.run(on: Self.socket, ["list-panes"]) }
        await #expect(throws: TmuxUnanswered.unanswered(.timedOut(2))) {
            try await slow.run(on: Self.socket, ["list-panes"])
        }
    }

    /// A scratch folder holding an executable of the name.
    private static func folderHolding(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-screen-\(UUID().uuidString)")
        let file = folder.appending(path: name)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("#!/bin/sh\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)

        return folder
    }
}
