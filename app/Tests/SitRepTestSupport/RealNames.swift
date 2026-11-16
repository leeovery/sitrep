import Foundation

/// The names no test may use, Lee's real projects, sessions and folders, as `tests/real-names.txt` lists them, with
/// the hits it allows; and its rule, which its header states.
public struct RealNames: Sendable {
    /// A listed name on a line of a file that its allows don't exempt.
    public struct Hit: Equatable, Sendable, CustomStringConvertible {
        public let path: String
        public let line: Int
        public let name: String

        public init(path: String, line: Int, name: String) {
            self.path = path
            self.line = line
            self.name = name
        }

        public var description: String { "\(path):\(line): \(name)" }
    }

    /// An `allow` line: every hit of its name in its one file exempt.
    public struct Allow: Hashable, Sendable, CustomStringConvertible {
        public let path: String
        public let name: String

        public init(path: String, name: String) {
            self.path = path
            self.name = name
        }

        public var description: String { "allow \(path) \(name)" }
    }

    /// What keeps the rule from being applied: a list it can't read, or a file it can't.
    public enum Unreadable: Error, Equatable, CustomStringConvertible {
        case empty
        case malformed(line: Int, String)
        case missing(folder: String)
        case notText(path: String)
        case symlinkedFolder(path: String)

        public var description: String {
            switch self {
            case .empty: "the list names nothing"
            case let .malformed(line, text): "line \(line) of the list is a malformed allow: \(text)"
            case let .missing(folder): "\(folder) is missing"
            case let .notText(path): "\(path) is neither UTF-8 nor binary"
            case let .symlinkedFolder(path): "\(path) is a symlinked folder, which the rule doesn't follow"
            }
        }
    }

    /// The checkout's hits, and the allows that no longer exempt one: of a name not listed, of a file that doesn't
    /// exist, or of a name the file no longer holds.
    public struct Scan: Sendable {
        public let hits: [Hit]
        public let stale: [Allow]
    }

    /// The list, from the repository's root.
    public static let path = "tests/real-names.txt"

    /// The folders whose files the rule reads, from the repository's root: both suites, and the prototypes their
    /// recordings are made from.
    public static let scanned = ["tests", "app/Tests", "prototypes"]

    /// What the rule doesn't read, by its name: built products, installed packages, the strip recorder's recording,
    /// which git ignores and its fixtures are made from, and Finder's folder settings.
    private static let unread: Set<String> = [".build", "node_modules", "recording.json", ".DS_Store"]

    private static let allowPrefix = "allow "

    /// The byte order marks that open UTF-16 text, little-endian, then big.
    private static let utf16Marks: [[UInt8]] = [[0xFF, 0xFE], [0xFE, 0xFF]]

    public let names: [String]
    public let allows: Set<Allow>
    private let patterns: [(name: String, pattern: NSRegularExpression)]

    /// The list as written: a name a line, a line starting with `#` a comment, a blank one nothing, and
    /// `allow <path> <name>`, single spaces, its name the rest of the line, exempting every hit of the name in that
    /// one file. Every line opening `allow` is read as one, so `allowance`, or `allow` and a tab, is malformed. Each
    /// line is read trimmed.
    public init(_ list: String) throws {
        var names: [String] = []
        var allows: Set<Allow> = []

        for (index, raw) in list.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            if line.hasPrefix("allow") {
                allows.insert(try Self.allow(line, at: index + 1))
            } else {
                names.append(line)
            }
        }
        guard !names.isEmpty else { throw Unreadable.empty }

        self.names = names
        self.allows = allows
        patterns = names.map { name in
            let escaped = NSRegularExpression.escapedPattern(for: name)
            // Escaped text between two lookarounds always compiles.
            let pattern = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
            return (name, pattern)
        }
    }

    /// The allow a line opening `allow` must be: a path and a name after `allow `, single-spaced.
    private static func allow(_ line: String, at number: Int) throws -> Allow {
        let parts = line.hasPrefix(allowPrefix)
            ? line.dropFirst(allowPrefix.count).split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            : []
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw Unreadable.malformed(line: number, line)
        }

        return Allow(path: String(parts[0]), name: String(parts[1]))
    }

    /// The list in this checkout.
    public static func listed() throws -> RealNames {
        try RealNames(String(contentsOf: Repository.root.appending(path: path), encoding: .utf8))
    }

    /// The names the text holds, in the list's order: each wherever it appears, case and all, with no letter or digit
    /// directly before or after it, so `-`, `_`, `.`, `/`, a space and quotes are boundaries.
    public func found(in text: String) -> [String] {
        let whole = NSRange(text.startIndex..., in: text)

        return patterns.filter { $0.pattern.firstMatch(in: text, range: whole) != nil }.map(\.name)
    }

    /// The hits in a file's text, line by line, but those its allows exempt.
    public func hits(in text: String, at path: String) -> [Hit] {
        let named = found(in: text).filter { !allows.contains(Allow(path: path, name: $0)) }
        guard !named.isEmpty else { return [] }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        return lines.enumerated().flatMap { index, line in
            found(in: String(line)).filter(named.contains).map { Hit(path: path, line: index + 1, name: $0) }
        }
    }

    /// The hits in every file the rule reads in the checkout at `root`, the list itself aside, each file's whole text,
    /// and the allows that exempt none.
    public func scan(under root: URL = Repository.root) throws -> Scan {
        let files = try Self.files(under: root)
        let texts = Dictionary(files, uniquingKeysWith: { first, _ in first })
        let stale = allows.filter { allow in
            !names.contains(allow.name) || !(texts[allow.path].map { found(in: $0).contains(allow.name) } ?? false)
        }

        return Scan(
            hits: files.flatMap { path, text in hits(in: text, at: path) },
            stale: stale.sorted { ($0.path, $0.name) < ($1.path, $1.name) }
        )
    }

    /// The text of every file the rule reads, by its path from the root, in the order of their paths. A folder it reads
    /// missing, a text file that isn't UTF-8 or a symlinked folder throws, so no file goes unread unsaid.
    private static func files(under root: URL) throws -> [(String, String)] {
        var files: [(String, String)] = []

        for folder in scanned {
            let top = root.appending(path: folder).path
            guard FileManager.default.fileExists(atPath: top), let walk = FileManager.default.enumerator(atPath: top)
            else { throw Unreadable.missing(folder: folder) }

            while let within = walk.nextObject() as? String {
                let path = "\(folder)/\(within)", file = root.appending(path: path)
                let isUnread = unread.contains(file.lastPathComponent)
                var isFolder: ObjCBool = false

                FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder)
                if isFolder.boolValue, (try? FileManager.default.destinationOfSymbolicLink(atPath: file.path)) != nil {
                    throw Unreadable.symlinkedFolder(path: path)
                }
                if isFolder.boolValue {
                    if isUnread {
                        walk.skipDescendants()
                    }
                } else if !isUnread, path != Self.path, let text = try text(of: Data(contentsOf: file), at: path) {
                    files.append((path, text))
                }
            }
        }
        return files.sorted { $0.0 < $1.0 }
    }

    /// A file's text, nil for a binary file, one that holds a NUL; a file of neither throws. UTF-16 text, which holds
    /// NULs too, is told by its byte order mark, and throws; without one it reads as binary.
    private static func text(of data: Data, at path: String) throws -> String? {
        guard !utf16Marks.contains(where: { data.starts(with: $0) }) else { throw Unreadable.notText(path: path) }
        guard !data.contains(0) else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { throw Unreadable.notText(path: path) }

        return text
    }
}
