import Darwin
import Foundation
@testable import SitRepScreen
import Testing

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
            [zmxProgram, "/opt/homebrew/bin/zmx", "attach", "kit · restore-card", "HOME=/Users/lee", "TERM=xterm"]
        )

        #expect(
            parseProcArgs(bytes)
                == ProcArgs(path: zmxProgram, arguments: ["/opt/homebrew/bin/zmx", "attach", "kit · restore-card"])
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

    @Test func theKernelGivesThisProcessItsParentItsProgramExactlyAndItsCommandLine() throws {
        let table = KernelProcesses()
        let processes = try #require(table.processes())
        let own = try #require(processes[getpid()])

        #expect(own.parent == getppid())
        #expect(own.program == Bundle.main.executableURL?.resolvingSymlinksInPath().path)
        #expect(table.arguments(of: getpid()) == CommandLine.arguments)
        #expect(processes[1]?.program == "/sbin/launchd")
    }

    @Test func aProcessGoneHasNoCommandLine() {
        #expect(KernelProcesses().arguments(of: Int32.max) == nil)
    }
}
