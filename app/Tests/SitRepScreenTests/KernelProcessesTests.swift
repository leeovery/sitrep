import Darwin
import Foundation
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct KernelProcessesTests {
    private static func numbers(_ major: Int32, _ minor: Int32) -> dev_t {
        major << 24 | minor
    }

    @Test func aTerminalsNumbersNameAPtyMajor16AsDevTtysAndItsMinorToThreePlaces() {
        #expect(device(of: Self.numbers(16, 32)) == "/dev/ttys032")
        #expect(device(of: Self.numbers(16, 7)) == "/dev/ttys007")
        #expect(device(of: Self.numbers(16, 1024)) == "/dev/ttys1024")
    }

    @Test(arguments: [numbers(3, 2), numbers(116, 32), numbers(0, 0), -1 /* NODEV, no terminal */])
    func anyOtherNumbersNameNone(terminal: dev_t) {
        #expect(device(of: terminal) == nil)
    }

    /// `KERN_PROCARGS2`'s bytes: the count, the executable's path, its padding, each argument, then the environment.
    private static func procargs(count: Int32, _ fields: [String], padding: Int = 3) -> [UInt8] {
        let (path, rest) = (fields[0], fields.dropFirst())

        return withUnsafeBytes(of: count) { Array($0) } + Array(path.utf8) + Array(repeating: 0, count: padding)
            + rest.flatMap { Array($0.utf8) + [0] }
    }

    @Test func aCommandLineIsReadAsTheExecutablesPathAndItsArgumentsLeavingOutTheEnvironment() {
        let bytes = Self.procargs(
            count: 3,
            [zmxProgram, "/opt/homebrew/bin/zmx", "attach", "litware · restore-card", "HOME=/Users/me", "TERM=xterm"]
        )

        #expect(
            parseProcArgs(bytes)
                == ProcArgs(path: zmxProgram, arguments: ["/opt/homebrew/bin/zmx", "attach", "litware · restore-card"])
        )
    }

    @Test func anEmptyArgumentIsKept() {
        #expect(parseProcArgs(Self.procargs(count: 2, ["/bin/sh", "sh", "", "HOME=/"]))?.arguments == ["sh", ""])
    }

    @Test func bytesCutShortAreNoCommandLine() {
        let whole = Self.procargs(count: 2, ["/bin/sh", "sh", "-c"])

        #expect(parseProcArgs(whole.dropLast()) == nil)
        #expect(parseProcArgs(Self.procargs(count: 3, ["/bin/sh", "sh", "-c"])) == nil)
        #expect(parseProcArgs(withUnsafeBytes(of: Int32(0)) { Array($0) } + Array("/bin/sh".utf8)) == nil)
        #expect(parseProcArgs([1, 0]) == nil)
    }

    @Test(.tags(.thisMac))
    func theKernelGivesThisProcessItsParentItsProgramExactlyAndItsCommandLineWhereWanted() throws {
        let program = try #require(Bundle.main.executableURL?.resolvingSymlinksInPath().path)
        let processes = try #require(KernelProcesses().read { $0.program == program })
        let own = try #require(processes.all[getpid()])

        #expect(own.parent == getppid())
        #expect(own.program == program)
        #expect(processes.arguments[getpid()] == CommandLine.arguments)
        #expect(processes.all[1]?.program == "/sbin/launchd")
        #expect(processes.arguments[1] == nil, "not wanted, not read")
    }

    /// A copy of a program of macOS's, signed afresh, as macOS kills a copy of its own program run from elsewhere.
    private static func copy(
        _ program: String, to copy: URL, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        for (tool, arguments) in [("/bin/cp", [program, copy.path]), ("/usr/bin/codesign", ["--force", "-s", "-", copy.path])] {
            let ran = try await runProgram(
                Program(executable: URL(fileURLWithPath: tool), arguments: arguments, environment: [:], limit: 10)
            )

            try #require(ran.status == 0, "\(tool): \(ran.stderr)", sourceLocation: sourceLocation)
        }
    }

    @Test(.tags(.thisMac))
    func aProcessWhoseProgramWasRemovedAsItRanIsTheProgramItWasStartedBy() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-screen-\(UUID().uuidString)")
        let copy = folder.appending(path: "bash")
        let running = Process()
        let output = Pipe()

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await Self.copy("/bin/bash", to: copy)
        running.executableURL = copy
        running.arguments = ["-c", "echo running; read line"]
        running.environment = [:]
        running.standardOutput = output
        running.standardInput = Pipe()
        try running.run()
        // Killed with a signal it cannot ignore, so the wait on its end is short.
        defer {
            if running.isRunning {
                kill(running.processIdentifier, SIGKILL)
            }
            running.waitUntilExit()
        }

        // Removed while macOS still loads it, it is killed; once it says it is running, it is loaded.
        _ = try await answer(within: .seconds(10), "for bash to say it is running") { said in
            output.fileHandleForReading.readabilityHandler = { handle in
                handle.readabilityHandler = nil
                said(handle.availableData)
            }
        }
        try FileManager.default.removeItem(at: copy)

        let pid = running.processIdentifier
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)

        try #require(proc_pidpath(pid, &path, UInt32(path.count)) <= 0, "proc_pidpath cannot tell it")

        let processes = try #require(KernelProcesses().read { $0.program == copy.path })

        #expect(running.isRunning)
        #expect(processes.all[pid]?.program == copy.path)
        #expect(processes.arguments[pid] == [copy.path, "-c", "echo running; read line"])
    }

    @Test(arguments: [
        ("/dev/ttys001", true), ("/dev/ttys1000", true), ("/dev/tty_a", true), ("/dev/tty", false),
        ("/dev/ttys0/x", false), ("", false), ("/tmp/ttys001", false), ("/dev/ttyé", false), ("/dev/ttys001\n", false),
        ("/dev/null", false),
    ])
    func aDeviceIsWhatCoresIsDeviceAcceptsOnlyATty(value: String, isOne: Bool) {
        #expect(isDevice(value) == isOne)
    }

    @Test func noValueIsNoDevice() {
        #expect(!isDevice(nil))
    }
}
