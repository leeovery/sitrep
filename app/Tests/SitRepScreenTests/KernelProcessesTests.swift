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

    /// `KERN_PROCARGS2`'s bytes as the kernel lays them out: the count; the executable's path, its NULs running to the
    /// next multiple of 8 counted from its start; each argument; then the environment.
    private static func procargs(count: Int32, _ fields: [String]) -> [UInt8] {
        let (path, rest) = (Array(fields[0].utf8), fields.dropFirst())
        let padded = (path.count + 8) / 8 * 8

        return withUnsafeBytes(of: count) { Array($0) } + path + Array(repeating: 0, count: padded - path.count)
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

    /// An empty argument is kept, the first among them: the path's padding is skipped by its length, so it never takes
    /// an empty first argument with it, a path of 7 bytes, with no padding but its NUL, among them.
    @Test(arguments: ["/bin/sh", "/bin/sleep", "/usr/bin/yes"])
    func anEmptyArgumentIsKeptTheFirstAmongThem(path: String) {
        #expect(parseProcArgs(Self.procargs(count: 2, [path, "sh", "", "HOME=/"]))?.arguments == ["sh", ""])
        #expect(parseProcArgs(Self.procargs(count: 2, [path, "", "30", "HOME=/"]))?.arguments == ["", "30"])
    }

    @Test func bytesCutShortAreNoCommandLine() {
        let whole = Self.procargs(count: 2, ["/bin/sh", "sh", "-c"])

        #expect(parseProcArgs(whole.dropLast()) == nil)
        #expect(parseProcArgs(Self.procargs(count: 0, ["/bin/zsh"]).prefix(13)) == nil, "cut inside the padding")
        #expect(parseProcArgs(Self.procargs(count: 3, ["/bin/sh", "sh", "-c"])) == nil)
        #expect(parseProcArgs(withUnsafeBytes(of: Int32(0)) { Array($0) } + Array("/bin/sh".utf8)) == nil)
        #expect(parseProcArgs([1, 0]) == nil)
    }

    /// A login's environment as sshd leaves it, tokens among it, with `SSH_CONNECTION` given.
    private static func login(_ connection: String...) -> [UInt8] {
        procargs(
            count: 2,
            ["/bin/zsh", "-zsh", "-l", "HOME=/Users/me", "GITHUB_TOKEN=ghp_notARealToken0001"]
                + connection.map { "SSH_CONNECTION=\($0)" } + ["SSH_AUTH_SOCK=/tmp/agent.1", "TERM=xterm-ghostty"]
        )
    }

    /// The client's address, the first field of `SSH_CONNECTION`, alone: IPv4, IPv6, and IPv6 with its zone.
    @Test(arguments: [
        ("192.0.2.7 50122 192.0.2.1 22", "192.0.2.7"),
        ("2001:db8::7 50122 2001:db8::1 22", "2001:db8::7"),
        ("fe80::7%en0 50122 fe80::1%en0 22", "fe80::7%en0"),
    ])
    func anSSHAddressIsTheFirstFieldOfSSHConnection(connection: String, address: String) {
        #expect(parseSSHAddress(Self.login(connection)) == address)
    }

    /// Nothing but an address is ever given from the environment: none where `SSH_CONNECTION` is not set, is empty, or
    /// starts with anything but an IP address, a token set in its place among them, or one longer than any address;
    /// never a variable whose name only starts the same, nor an argument that looks like one, nor what follows the
    /// environment's end, nor a value cut short, though what is left of it looks like an address.
    @Test func nothingButAnAddressIsGivenFromTheEnvironment() {
        let afterTheEnd = Self.procargs(count: 1, ["/bin/zsh", "-zsh", "HOME=/Users/me", "", "SSH_CONNECTION=192.0.2.7 1 2 3"])
        let whole = Self.login("192.0.2.123 50122 192.0.2.1 22")
        let cut = whole[..<(whole.firstRange(of: Array("=192.0.2.12".utf8))?.upperBound ?? whole.endIndex)]
        let tooLong = "fe80::7%" + String(repeating: "e", count: 60)

        #expect(parseSSHAddress(Self.login()) == nil)
        for connection in [
            "", "ghp_notARealToken0001 1 2 3", "GITHUB_TOKEN=ghp_notARealToken0001", "192.0.2.7x 1 2 3", "fe80::7% 1",
            "fe80::7%e-0 1", tooLong + " 1",
        ] {
            #expect(parseSSHAddress(Self.login(connection)) == nil, "\(connection)")
        }
        #expect(parseSSHAddress(cut) == nil, "cut inside its value")
        #expect(parseSSHAddress(Self.procargs(count: 1, ["/bin/zsh", "-zsh", "SSH_CONNECTION_X=192.0.2.7 1 2 3"])) == nil)
        #expect(parseSSHAddress(Self.procargs(count: 2, ["/bin/zsh", "-zsh", "SSH_CONNECTION=192.0.2.7 1 2 3", "A=b"])) == nil)
        #expect(parseSSHAddress(afterTheEnd) == nil)
        #expect(parseSSHAddress(Self.login("192.0.2.7 1 2 3", "198.51.100.4 1 2 3")) == "192.0.2.7", "the first, as getenv")
        #expect(parseSSHAddress(Self.login("192.0.2.7 1 2 3").dropLast(40)) == "192.0.2.7")
        #expect(parseSSHAddress([1, 0]) == nil)
    }

    /// The kernel gives a process's SSH client address from its own environment, and none for one whose environment
    /// holds none; nor for macOS's own program, whose environment it hides from other processes, as it hides a login
    /// shell's (`Viewing`).
    @Test(.tags(.thisMac))
    func theKernelGivesAProcessesSSHAddressFromItsEnvironmentUnlessItIsMacOSsOwnProgram() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-screen-\(UUID().uuidString)")
        let copy = folder.appending(path: "sleep")
        let connection = ["SSH_CONNECTION": "192.0.2.7 50122 192.0.2.1 22"]
        var started: [Process] = []

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Killed with a signal it cannot ignore, so the wait on its end is short.
        defer {
            for each in started {
                kill(each.processIdentifier, SIGKILL)
                each.waitUntilExit()
            }
            try? FileManager.default.removeItem(at: folder)
        }
        try await Self.copy("/bin/sleep", to: copy)
        for (program, environment) in [(copy, connection), (copy, ["SITREP_TEST": "x"]), (URL(filePath: "/bin/sleep"), connection)] {
            let sleeping = Process()

            sleeping.executableURL = program
            sleeping.arguments = ["30"]
            sleeping.environment = environment
            try sleeping.run()
            started.append(sleeping)
        }

        let address = KernelProcesses().sshAddressReader()

        #expect(started.map { address($0.processIdentifier) } == ["192.0.2.7", nil, nil])
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
