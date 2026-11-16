import Foundation

/// The names no test may use, Lee's real projects, sessions and folders, as `tests/real-names.txt` lists them, with
/// the hits it allows; and its rule, which its header states.
public struct RealNames: Sendable {
    /// A listed name in a file that its allows don't exempt.
    public struct Hit: Equatable, Sendable, CustomStringConvertible {
        public let path: String
        public let name: String

        public init(path: String, name: String) {
            self.path = path
            self.name = name
        }

        public var description: String { "\(path): \(name)" }
    }

    /// The list, from the repository's root.
    public static let path = "tests/real-names.txt"

    /// The folders whose files the rule reads, from the repository's root.
    public static let scanned = ["tests", "app/Tests"]

    /// What the rule doesn't read: built products, and Finder's folder settings.
    private static let unread: Set<String> = [".build", ".DS_Store"]

    public let names: [String]
    /// Each file's names its hits are allowed of, by its path from the repository's root.
    public let allowed: [String: Set<String>]
    private let patterns: [(name: String, pattern: NSRegularExpression)]

    /// The list as written: a name a line, a line starting with `#` a comment, a blank one nothing, and
    /// `allow <path> <name>` exempting every hit of the name in that one file.
    public init(_ list: String) {
        var names: [String] = []
        var allowed: [String: Set<String>] = [:]

        for line in list.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("#") || line.allSatisfy(\.isWhitespace) {
                continue
            }
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            if parts.count == 3, parts[0] == "allow" {
                allowed[parts[1], default: []].insert(parts[2])
            } else {
                names.append(line)
            }
        }
        self.names = names
        self.allowed = allowed
        patterns = names.map { name in
            let escaped = NSRegularExpression.escapedPattern(for: name)
            // Escaped text between two lookarounds always compiles.
            let pattern = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
            return (name, pattern)
        }
    }

    /// The list in this checkout.
    public static func listed() throws -> RealNames {
        try RealNames(String(contentsOf: Repository.root.appending(path: path), encoding: .utf8))
    }

    /// The names the text holds, in the list's order: each wherever it appears, case and all, with no letter or digit
    /// directly before or after it, so `-`, `_`, `.`, `/`, a space and quotes are boundaries.
    public func names(in text: String) -> [String] {
        let whole = NSRange(text.startIndex..., in: text)

        return patterns.filter { $0.pattern.firstMatch(in: text, range: whole) != nil }.map(\.name)
    }

    /// The hits in a file's text, but those its allows exempt.
    public func hits(in text: String, at path: String) -> [Hit] {
        let exempt = allowed[path] ?? []

        return names(in: text).filter { !exempt.contains($0) }.map { Hit(path: path, name: $0) }
    }

    /// The hits in every file the rule reads in the checkout at `root`, the list itself aside, each file's whole text:
    /// a binary file, `.build` and `.DS_Store` aside too.
    public func hits(under root: URL = Repository.root) throws -> [Hit] {
        try Self.files(under: root).flatMap { path, text in hits(in: text, at: path) }
    }

    /// The text of every file the rule reads, by its path from the root, in the order of their paths; a folder it
    /// reads missing throws, so a checkout laid out otherwise can't pass for a clean one.
    private static func files(under root: URL) throws -> [(path: String, text: String)] {
        var files: [(path: String, text: String)] = []

        for folder in scanned {
            let top = root.appending(path: folder).path
            guard FileManager.default.fileExists(atPath: top), let walk = FileManager.default.enumerator(atPath: top)
            else { throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: top]) }

            while let within = walk.nextObject() as? String {
                let path = "\(folder)/\(within)", file = root.appending(path: path, directoryHint: .checkFileSystem)
                let isUnread = unread.contains(file.lastPathComponent)

                if file.hasDirectoryPath {
                    if isUnread {
                        walk.skipDescendants()
                    }
                } else if !isUnread, path != Self.path, let text = text(of: try Data(contentsOf: file)) {
                    files.append((path, text))
                }
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    /// A file's text, nil for a binary file: one that holds a NUL or isn't UTF-8.
    private static func text(of data: Data) -> String? {
        data.contains(0) ? nil : String(data: data, encoding: .utf8)
    }
}
