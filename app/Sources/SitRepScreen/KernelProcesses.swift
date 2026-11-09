import Darwin
import Foundation

/// The kernel's process table, in place of `ps`: one `sysctl` (`KERN_PROC_ALL`) for every process's parent and
/// terminal, `proc_pidpath` for each one's program, and a command line (`KERN_PROCARGS2`) only where asked, or where
/// `proc_pidpath` cannot tell the program. `login` runs as root, and its command line cannot be read, but its parent
/// and terminal can, which is all the seat needs.
public struct KernelProcesses: ProcessTable {
    public init() {}

    public func processes() -> [pid_t: Proc]? {
        guard let table = Self.table() else {
            return nil
        }

        return Dictionary(
            table.map { each in
                let pid = each.kp_proc.p_pid

                return (pid, Proc(parent: each.kp_eproc.e_ppid, device: device(of: each.kp_eproc.e_tdev), program: Self.program(of: pid)))
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public func arguments(of pid: pid_t) -> [String]? {
        Self.procArgs(of: pid)?.arguments
    }

    /// A process's executable's path as it was started, and its command line; nil for one not to be read, as
    /// another user's.
    private static func procArgs(of pid: pid_t) -> ProcArgs? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argumentsMax

        guard size > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)

        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return parseProcArgs(buffer.prefix(size))
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

    /// A process's program's path, exactly; else, for one whose program was replaced on disk as it ran, as an app
    /// updated under it is, which `proc_pidpath` cannot tell (ENOENT), the path it was started by; nil for one gone.
    private static func program(of pid: pid_t) -> String? {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &path, UInt32(path.count))

        guard length > 0 else {
            return procArgs(of: pid)?.path
        }

        return String(decoding: path.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
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

/// `KERN_PROCARGS2`'s bytes: the count of the arguments, the executable's path, the padding after it, then each
/// argument, each ending in a NUL, the environment after them. Nil for bytes cut short.
func parseProcArgs(_ bytes: some Collection<UInt8>) -> ProcArgs? {
    let bytes = Array(bytes)
    let countSize = MemoryLayout<Int32>.size

    guard bytes.count >= countSize else {
        return nil
    }

    let count = Int(bytes.prefix(countSize).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
    let path = bytes[countSize...].prefix { $0 != 0 }
    let fields = bytes[path.endIndex...].drop { $0 == 0 }.split(separator: 0, omittingEmptySubsequences: false)

    guard count >= 0, path.endIndex < bytes.endIndex, fields.count > count else {
        return nil
    }

    return ProcArgs(
        path: String(decoding: path, as: UTF8.self),
        arguments: fields.prefix(count).map { String(decoding: $0, as: UTF8.self) }
    )
}
