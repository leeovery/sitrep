import Foundation
import SitRepCore

/// A program of Lee's, as tmux and zmx are, found once on the PATH given, so one is made for each click with Lee's PATH
/// as it then stands: one installed or removed since shows at the next. Each run has 2 seconds, and is ended with its
/// process group at its limit, as the CLI's tmux was. None found, every run gives no answer.
struct ProgramOnPath: Sendable {
    static let limit: TimeInterval = 2

    private let executable: URL?
    private let environment: [String: String]
    private let runner: Runner

    init(_ name: String, path: String, environment: [String: String], run: @escaping Runner) {
        executable = Self.find(name, on: path)
        self.environment = environment.merging(["PATH": path]) { _, given in given }
        runner = run
    }

    /// How it ran, given the words; nil where it could not start or did not answer in its time.
    func run(_ arguments: [String]) async -> Ran? {
        guard let executable else {
            return nil
        }

        return try? await runner(
            Program(
                executable: executable, arguments: arguments, environment: environment, limit: Self.limit,
                stopping: .group
            )
        )
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
