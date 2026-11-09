import Darwin
import Foundation
import SitRepCore
@testable import SitRepScreen
import Testing

/// The kernel's table beside the CLI's reading of `ps`, live and read-only, on this Mac: run with `SITREP_PARITY=1`.
/// The CLI's own code reads `ps` (through Bun), then the kernel is read at once; a process present in both must have
/// the same parent and device, and the same app where the CLI's reading finds one; and each zmx session a client on a
/// tty names must show at the same places.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SITREP_PARITY"] == "1"))
struct ParityTests {
    private struct Read: Decodable {
        /// Each process as the CLI read it: its id, its parent's, its device and its app's name.
        let processes: [[Value]]
        /// Each zmx session's places, its device and its app's name.
        let zmx: [String: [[String?]]]
    }

    private enum Value: Decodable, Equatable {
        case number(Int32)
        case text(String?)

        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()

            self = try (try? value.decode(Int32.self)).map(Value.number) ?? .text(value.decode(String?.self))
        }

        var number: Int32? { if case let .number(number) = self { number } else { nil } }
        var text: String? { if case let .text(text) = self { text } else { nil } }
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// The CLI's reading of one `ps` snapshot, with a UTF-8 character type, as the CLI runs it.
    private static func cliRead() async throws -> Read {
        let script = """
        import { appOfCommand } from '\(root.path)/cli/apps'
        import { parseProcesses, PS } from '\(root.path)/cli/processes'
        import { ZMX } from '\(root.path)/cli/zmx'

        const ran = Bun.spawnSync(PS, { env: { ...process.env, LC_CTYPE: 'UTF-8' } })
        const processes = parseProcesses(ran.stdout.toString())
        const reading = await ZMX.read(undefined as never, [])
        const sessions = new Set([...processes.values()].flatMap(each => {
          const [, session] = /(?:^|\\/)zmx attach (.+)$/.exec(each.args) ?? []
          return each.device === undefined || session === undefined ? [] : [session]
        }))

        console.log(JSON.stringify({
          processes: [...processes].map(([pid, each]) => [pid, each.parent, each.device ?? null, appOfCommand(each.args)?.name ?? null]),
          zmx: Object.fromEntries([...sessions].map(session => [
            session,
            reading.places({ zmx: { session } }, processes).map(place => [place.device ?? null, place.app.name]),
          ])),
        }))
        """
        let file = FileManager.default.temporaryDirectory.appending(path: "sitrep-parity-\(UUID().uuidString).ts")
        let path = ProcessInfo.processInfo.environment["PATH", default: ""] + ":/opt/homebrew/bin:\(NSHomeDirectory())/.bun/bin"
        let bun = try #require(TmuxOnPath.find("bun", on: path))

        try script.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let ran = try await runProgram(
            Program(executable: bun, arguments: ["run", file.path], environment: ProcessInfo.processInfo.environment, limit: 30)
        )

        try #require(ran.status == 0, "\(ran.stderr)")

        return try JSONDecoder().decode(Read.self, from: Data(ran.stdout.utf8))
    }

    @Test func theKernelsTableAgreesWithTheCLIsReadingOfPs() async throws {
        let cli = try await Self.cliRead()
        let kernel = try #require(KernelProcesses().processes())
        var compared = 0
        var apps = 0
        var foundBeyond: [String] = []

        for row in cli.processes {
            guard let pid = row[0].number, let process = kernel[pid] else {
                continue
            }

            let app = process.program.flatMap(TerminalApp.init(path:))?.name

            compared += 1
            #expect(process.parent == row[1].number, "\(pid)'s parent")
            #expect(process.device == row[2].text, "\(pid)'s device")

            if let cliApp = row[3].text {
                apps += 1
                #expect(app == cliApp, "\(pid)'s app, its program \(process.program ?? "unread")")
            } else if let app {
                foundBeyond.append("\(pid) \(app): \(process.program ?? "")")
            }
        }

        print("Parity: \(compared) processes in both of \(cli.processes.count) in ps and \(kernel.count) in the kernel's table, \(apps) in an app by the CLI's reading")
        print("Parity: apps found where the CLI's reading finds none: \(foundBeyond.count)\n\(foundBeyond.joined(separator: "\n"))")
        #expect(compared > cli.processes.count / 2)
    }

    @Test func eachZmxSessionShowsAtTheSamePlacesAsTheCLIsReading() async throws {
        let cli = try await Self.cliRead()
        let sessions = cli.zmx.keys.sorted()
        let windows = sessions.map { Where(terminal: "ghostty", zmx: Where.Zmx(session: $0)) }
        let screen = await ScreenReader(tmux: TmuxOnPath(path: { "" })).read(windows)

        for (session, window) in zip(sessions, windows) {
            #expect(seen(screen.places(showing: [window])).map { Array($0.prefix(2)) } == cli.zmx[session], "\(session)")
        }

        print("Parity: \(sessions.count) zmx sessions with a client on a tty: \(sessions.joined(separator: ", "))")
        print("Parity: \(cli.zmx.values.map(\.count).reduce(0, +)) places, \(screen.places(showing: windows).count) of them each device once")
    }
}
