import Darwin
import Foundation

/// The kernel's process table, in place of `ps`: one `sysctl` (`KERN_PROC_ALL`) for every process's parent and
/// terminal, `proc_pidpath` for each one's program, and a command line (`KERN_PROCARGS2`), once at most, only where
/// wanted, or where `proc_pidpath` cannot tell the program. `login` runs as root, and its command line cannot be read,
/// but its parent and terminal can, which is all the seat needs. The same read gives, apart, the SSH client address
/// in the environment of each process asked for, and nothing else of the environment (`parseSSHAddress`).
public struct KernelProcesses: ProcessTable {
    public init() {}

    public func read(arguments wanted: (Proc) -> Bool) -> Processes? {
        guard let table = Self.table() else {
            return nil
        }

        let reader = Reader()
        var all: [pid_t: Proc] = [:]
        var arguments: [pid_t: [String]] = [:]

        for each in table where all[each.kp_proc.p_pid] == nil {
            let pid = each.kp_proc.p_pid
            let path = reader.program(of: pid)
            let started = path == nil ? reader.procArgs(of: pid) : nil
            let process = Proc(
                parent: each.kp_eproc.e_ppid, device: device(of: each.kp_eproc.e_tdev), program: path ?? started?.path,
                isStopped: Int32(each.kp_proc.p_stat) == SSTOP
            )

            if wanted(process), let read = path == nil ? started : reader.procArgs(of: pid) {
                arguments[pid] = read.arguments
            }

            all[pid] = process
        }

        return Processes(all, arguments: arguments)
    }

    /// Each process's SSH client address, read through `KERN_PROCARGS2` into one buffer for every process asked of.
    public func sshAddressReader() -> (pid_t) -> String? {
        Reader().sshAddress(of:)
    }

    /// Every process, as one `sysctl` gives them: asked how much room it needs, then given some over, as processes
    /// start between the two; asked again the few times that is not enough.
    private static func table() -> [kinfo_proc]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        let stride = MemoryLayout<kinfo_proc>.stride

        for _ in 0..<3 {
            var size = 0

            guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
                return nil
            }

            var table = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 64)

            size = table.count * stride

            if sysctl(&mib, UInt32(mib.count), &table, &size, nil, 0) == 0 {
                return Array(table.prefix(size / stride))
            }

            guard errno == ENOMEM else {
                return nil
            }
        }

        return nil
    }

}

/// What reads each process's program and command line for one look at the table, into buffers made once for it: a
/// command line may take `KERN_ARGMAX`, a mebibyte, which is left unfilled, as only what the kernel writes is read.
private final class Reader {
    private var path = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
    private var procArgs = [UInt8](unsafeUninitializedCapacity: Reader.argumentsMax) { _, count in
        count = Reader.argumentsMax
    }

    /// A process's program's path, exactly; nil for one gone, or whose program was replaced on disk as it ran, as an
    /// app updated under it is, which `proc_pidpath` cannot tell (ENOENT).
    func program(of pid: pid_t) -> String? {
        let length = path.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }

        return length > 0 ? String(decoding: path.prefix(Int(length)), as: UTF8.self) : nil
    }

    /// A process's executable's path as it was started, and its command line; nil for one not to be read, as another
    /// user's.
    func procArgs(of pid: pid_t) -> ProcArgs? {
        procArgsBytes(of: pid).flatMap(parseProcArgs)
    }

    /// A process's SSH client address, from its environment; nil for one not to be read, or holding none.
    func sshAddress(of pid: pid_t) -> String? {
        procArgsBytes(of: pid).flatMap(parseSSHAddress)
    }

    private func procArgsBytes(of pid: pid_t) -> ArraySlice<UInt8>? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = procArgs.count
        let read = procArgs.withUnsafeMutableBytes { sysctl(&mib, UInt32(mib.count), $0.baseAddress, &size, nil, 0) }

        return size > 0 && read == 0 ? procArgs.prefix(size) : nil
    }

    /// The most a command line and its environment may take, `KERN_ARGMAX`.
    private static let argumentsMax: Int = {
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        var max: Int32 = 0
        var size = MemoryLayout<Int32>.size

        return sysctl(&mib, UInt32(mib.count), &max, &size, nil, 0) == 0 ? Int(max) : 0
    }()
}

/// The device a terminal's numbers name, `/dev/ttys032` for major 16, a pty, minor 32, as `ps` gives it `16/32`; nil
/// for any device but a pty, and for none (`NODEV`, all ones, so major 255).
func device(of terminal: dev_t) -> String? {
    let major = (UInt32(bitPattern: terminal) >> 24) & 0xFF
    let minor = UInt32(bitPattern: terminal) & 0xFF_FFFF

    return major == 16 ? String(format: "/dev/ttys%03u", minor) : nil
}

/// A process's executable's path as it was started, and its command line, its program first.
struct ProcArgs: Equatable {
    let path: String
    let arguments: [String]
}

/// `KERN_PROCARGS2`'s bytes: the count of the arguments, the executable's path, the NULs padding it to a pointer's
/// alignment, then each argument, each ending in a NUL, the environment after them. Nil for bytes cut short.
func parseProcArgs(_ bytes: some Collection<UInt8>) -> ProcArgs? {
    ProcArgsFields(bytes).map { fields in
        ProcArgs(
            path: String(decoding: fields.path, as: UTF8.self),
            arguments: fields.arguments.map { String(decoding: $0, as: UTF8.self) }
        )
    }
}

/// The address of the SSH client that reached a process, from `KERN_PROCARGS2`'s bytes: the first field of
/// `SSH_CONNECTION`, sshd's `<client> <port> <server> <port>`; nil where none is set, or its first field is no IP
/// address. Environments hold tokens, so it is the one variable ever read there: each is matched by its bytes, and only
/// an address they are checked to be is made text.
func parseSSHAddress(_ bytes: some Collection<UInt8>) -> String? {
    guard let connection = ProcArgsFields(bytes)?.environment.first(where: { $0.starts(with: sshConnection) }) else {
        return nil
    }

    let address = connection.dropFirst(sshConnection.count).prefix { $0 != UInt8(ascii: " ") }

    return isAddress(address) ? String(decoding: address, as: UTF8.self) : nil
}

private let sshConnection = Array("SSH_CONNECTION=".utf8)

/// The longest address taken: an IPv6 address's text and its zone's name (`fe80::1%en0`).
private let addressMax = Int(INET6_ADDRSTRLEN) + Int(IF_NAMESIZE)

/// Whether the bytes are an IPv4 or IPv6 address, a zone of letters and digits after `%` allowed (`fe80::1%en0`).
private func isAddress(_ bytes: ArraySlice<UInt8>) -> Bool {
    guard bytes.count <= addressMax else {
        return false
    }

    let parts = bytes.split(separator: UInt8(ascii: "%"), maxSplits: 1, omittingEmptySubsequences: false)
    let address = Array(parts[0]) + [0]
    var read = in6_addr()
    let isIP = address.withUnsafeBufferPointer { address in
        address.withMemoryRebound(to: CChar.self) { text in
            inet_pton(AF_INET, text.baseAddress, &read) == 1 || inet_pton(AF_INET6, text.baseAddress, &read) == 1
        }
    }

    return isIP && parts.dropFirst().allSatisfy { zone in !zone.isEmpty && zone.allSatisfy(isLetterOrDigit) }
}

private func isLetterOrDigit(_ byte: UInt8) -> Bool {
    switch byte {
    case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"):
        true
    default:
        false
    }
}

/// `KERN_PROCARGS2`'s bytes in their parts: the executable's path, then the fields after its padding, each ending in a
/// NUL, the arguments first, as many as the count says. The environment, which can run to kilobytes, is split only as
/// it is walked.
///
/// The padding runs from the path's NUL to a pointer's alignment, counted from the path's start, where the arguments
/// start: so it is skipped by its length, never by its NULs, which would take an empty first argument with them (live,
/// 20 November 2026: every one of 988 processes, and `exec` given an empty first argument).
private struct ProcArgsFields {
    let path: ArraySlice<UInt8>
    private(set) var arguments: [ArraySlice<UInt8>] = []
    /// The bytes after the arguments.
    private var rest: ArraySlice<UInt8>

    /// Nil for bytes cut short.
    init?(_ bytes: some Collection<UInt8>) {
        let bytes = Array(bytes)
        let countSize = MemoryLayout<Int32>.size

        guard bytes.count >= countSize else {
            return nil
        }

        let count = Int(bytes.prefix(countSize).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        let alignment = MemoryLayout<UnsafeRawPointer>.alignment

        path = bytes[countSize...].prefix { $0 != 0 }

        let start = countSize + (path.count + alignment) / alignment * alignment

        guard count >= 0, start <= bytes.endIndex else {
            return nil
        }

        rest = bytes[start...]

        while arguments.count < count {
            guard let field = Self.field(of: &rest) else {
                return nil
            }

            arguments.append(field)
        }
    }

    /// The environment's variables, up to the first empty field, which ends them.
    var environment: some Sequence<ArraySlice<UInt8>> {
        sequence(state: rest) { rest in Self.field(of: &rest).flatMap { $0.isEmpty ? nil : $0 } }
    }

    /// The field the bytes start with, up to its NUL, which it takes from them; nil where no NUL ends one.
    private static func field(of bytes: inout ArraySlice<UInt8>) -> ArraySlice<UInt8>? {
        guard let end = bytes.firstIndex(of: 0) else {
            return nil
        }

        defer { bytes = bytes[(end + 1)...] }
        return bytes[..<end]
    }
}
