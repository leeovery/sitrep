import Foundation
import SitRepTestSupport
import Testing

/// No test reaches this Mac's real preferences: every one gives what it makes `MemoryDefaults`, as tests that made a
/// suite of their own once left 171 domains behind. This reads the app's test sources for a way in, the standard
/// domain, a suite by name, or a type whose defaults are the standard domain when given none, allowing only
/// `MemoryDefaults` itself and its one check that its suite stays empty.
@Suite(.backstop)
struct DefaultsScanTests {
    /// Each way into the real preferences, spelt in parts so this file holds none of them.
    private static let ways = [
        "UserDefaults" + ".standard", "UserDefaults" + "(suiteName:", "Preferences" + "()", "SavedEdgeSettings" + "()",
    ]

    /// The uses allowed, by file, each with how many.
    private static let allowed = ["SitRepCoreTests/MemoryDefaultsTests.swift": 1]

    @Test func noTestReachesThisMacsPreferences() throws {
        let tests = Repository.root.appending(path: "app/Tests")
        let paths = FileManager.default.enumerator(atPath: tests.path)?.compactMap { $0 as? String } ?? []
        let files = try Dictionary(uniqueKeysWithValues: paths.filter { $0.hasSuffix(".swift") }.map { path in
            (path, try String(contentsOf: tests.appending(path: path), encoding: .utf8))
        })

        #expect(files.count > 100)
        #expect(Self.findings(files).isEmpty, "\(Self.findings(files).joined(separator: "\n"))")
    }

    /// A way in planted anywhere is found, each named by its line; the one allowed use passes, and a second in its
    /// file does not; a comment naming one is no use, nor a longer name ending in one.
    @Test func aWayInIsFoundWhereverItIsPlanted() {
        let files = [
            "SitRepTests/A.swift": "let defaults = " + Self.ways[0] + "\nlet kept = MemoryDefaults()\n"
                + "@Test func noTestReaches" + Self.ways[2] + " {}",
            "SitRepTests/B.swift": "let suite = " + Self.ways[1] + " \"sitrep.Model\")",
            "SitRepTests/C.swift": "/// never " + Self.ways[2] + "\nlet preferences = " + Self.ways[2],
            "SitRepEdgeTests/D.swift": "let saved = " + Self.ways[3],
            "SitRepCoreTests/MemoryDefaultsTests.swift": "let domain = " + Self.ways[1] + " defaults.suite)",
        ]

        #expect(Self.findings(files) == [
            "SitRepEdgeTests/D.swift:1 reaches this Mac's preferences",
            "SitRepTests/A.swift:1 reaches this Mac's preferences",
            "SitRepTests/B.swift:1 reaches this Mac's preferences",
            "SitRepTests/C.swift:2 reaches this Mac's preferences",
        ])

        var twice = files

        twice["SitRepCoreTests/MemoryDefaultsTests.swift", default: ""] += "\nlet again = " + Self.ways[1] + " \"x\")"
        #expect(Self.findings(twice).contains("SitRepCoreTests/MemoryDefaultsTests.swift: 2 uses, 1 allowed"))
    }

    /// Each line using a way in, but in a file allowed so many, which is named only where it uses more.
    private static func findings(_ files: [String: String]) -> [String] {
        files.sorted { $0.key < $1.key }.flatMap { path, text in
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().filter { _, line in
                let code = line.drop { $0.isWhitespace }

                return !code.hasPrefix("//") && ways.contains { uses(code, $0) }
            }

            guard let allowed = allowed[path] else {
                return lines.map { "\(path):\($0.offset + 1) reaches this Mac's preferences" }
            }

            return lines.count > allowed ? ["\(path): \(lines.count) uses, \(allowed) allowed"] : []
        }
    }

    /// Whether the line uses the way in as a name of its own, not the end of a longer one: `Preferences()`, never a
    /// test named `…Preferences()`.
    private static func uses(_ code: Substring, _ way: String) -> Bool {
        code.ranges(of: way).contains { range in
            range.lowerBound == code.startIndex || !isNamePart(code[code.index(before: range.lowerBound)])
        }
    }

    private static func isNamePart(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
