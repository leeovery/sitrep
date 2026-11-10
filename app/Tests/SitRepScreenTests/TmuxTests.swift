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

        #expect(await tmux.run(on: Self.socket, ["list-clients"]) == Ran(status: 0, stdout: "", stderr: ""))
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

        #expect(ProgramOnPath.find("tmux", on: "\(decoy.path):\(folder.path)") == folder.appending(path: "tmux"))
        #expect(ProgramOnPath.find("tmux", on: decoy.path) == nil)
    }

    @Test func tmuxNotOnThePathOrNotAnsweringInTimeGivesNoAnswerNeverAnAnswerOfNoServer() async throws {
        let folder = try Self.folderHolding("tmux")
        let missing = TmuxOnPath(path: "/nowhere") { _ in Ran(status: 1, stdout: "", stderr: "") }
        let slow = TmuxOnPath(path: folder.path) { program in throw RunError.timedOut(program.limit) }

        #expect(await missing.run(on: Self.socket, ["list-panes"]) == nil)
        #expect(await slow.run(on: Self.socket, ["list-panes"]) == nil)
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
