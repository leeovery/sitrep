import Foundation
import SitRepCore

/// A program of Lee's, as tmux and zmx are, run with the environment given, his login shell's, so it sees what a
/// command typed into his shell sees: zmx the folder its sessions are in, `ZMX_DIR`, which only his startup files may
/// set. It is found once on that environment's PATH, so one is made for each click with the environment as it then
/// stands. Each run has 2 seconds, and is ended with its process group at its limit, as the CLI's tmux was.
struct ProgramOnPath: Sendable {
    static let limit: TimeInterval = 2

    private let name: String
    private let executable: URL?
    private let environment: [String: String]
    private let runner: Runner

    init(_ name: String, environment: [String: String], run: @escaping Runner) {
        self.name = name
        executable = Self.find(name, on: environment["PATH"] ?? "")
        self.environment = environment
        runner = run
    }

    /// How it ran, given the words; throws `ProgramUnanswered` where it is not on the PATH, could not start, or did not
    /// answer in its time.
    func run(_ arguments: [String]) async throws -> Ran {
        guard let executable else {
            throw ProgramUnanswered.notFound(name)
        }

        do {
            return try await runner(
                Program(
                    executable: executable, arguments: arguments, environment: environment, limit: Self.limit,
                    stopping: .group
                )
            )
        } catch {
            throw ProgramUnanswered.unanswered(name, why: String(describing: error))
        }
    }

    /// The first executable file of the name in the PATH's folders, as a shell finds it: never a folder.
    static func find(_ name: String, on path: String) -> URL? {
        path.split(separator: ":").lazy
            .map { URL(fileURLWithPath: String($0)).appending(path: name) }
            .first { file in
                var isFolder: ObjCBool = false

                return FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue
                    && FileManager.default.isExecutableFile(atPath: file.path)
            }
    }
}

/// Why a program of Lee's gave no answer: not on his PATH, by its name; or not answering, as one that could not start
/// or outran its time, in `RunError`'s words.
public enum ProgramUnanswered: Error, Equatable {
    case notFound(String)
    case unanswered(String, why: String)

    /// In plain words, after what it was asked, as `zmx, asked which sessions it has,`.
    func words(asked: String) -> String {
        switch self {
        case let .notFound(name):
            "\(name) is not on your login shell's PATH."
        case let .unanswered(_, why):
            "\(asked) \(why)."
        }
    }
}
