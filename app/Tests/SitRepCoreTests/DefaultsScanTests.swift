import Foundation
import SitRepTestSupport
import Testing

/// No test reaches this Mac's real preferences: every one gives what it makes `MemoryDefaults`, as tests that made a
/// suite of their own once left 171 domains behind. No type's defaults fall back to the standard domain, so a test
/// reaches it only by naming it; this reads the app's test sources, across their lines, for a way it might: the
/// standard domain, `.standard` however it is reached, a `UserDefaults` made, or another name given the type. It
/// allows only `MemoryDefaultsTests`' one check that its suite stays empty, by that line.
@Suite(.backstop)
struct DefaultsScanTests {
    /// The test sources were 187 on 17 November 2026: a scan that reads far fewer has stopped reading them.
    private static let fewestFiles = 150

    /// Every way in, as a pattern across lines: `.standard`, a `UserDefaults` made, or the type given another name.
    private static var ways: Regex<Substring> {
        #/\.\s*standard\b|\bUserDefaults\s*(?:\.\s*init\s*)?\(|\btypealias\s+\w+\s*=\s*UserDefaults\b/#
    }

    /// The one use allowed, by its file and its line, spelt in parts so this file holds none.
    private static let allowed = [
        "SitRepCoreTests/MemoryDefaultsTests.swift":
            "let domain = try #require(UserDefaults" + "(suiteName: defaults.suite))",
    ]

    @Test func noTestReachesThisMacsPreferences() throws {
        let tests = Repository.root.appending(path: "app/Tests")
        let paths = FileManager.default.enumerator(atPath: tests.path)?.compactMap { $0 as? String } ?? []
        let files = try Dictionary(uniqueKeysWithValues: paths.filter { $0.hasSuffix(".swift") }.map { path in
            (path, try String(contentsOf: tests.appending(path: path), encoding: .utf8))
        })
        let findings = Self.findings(files)

        #expect(files.count >= Self.fewestFiles)
        #expect(findings.isEmpty, "\(findings.joined(separator: "\n"))")
    }

    /// Each way in planted is found, named by the line it starts on, though it runs across lines or comes as an
    /// argument; the allowed line passes, but not the same words elsewhere; a comment naming one is no use.
    @Test func aWayInIsFoundWhereverItIsPlanted() {
        let made = "UserDefaults" + "(suiteName: \"x\")"
        let files = [
            "SitRepTests/A.swift": "let a = UserDefaults\n    ." + "standard\nlet kept = MemoryDefaults()",
            "SitRepTests/B.swift": "// " + made + "\nlet b = Preferences(." + "standard)",
            "SitRepTests/C.swift": "let c = UserDefaults" + "()\nlet d = UserDefaults\n    .init" + "(suiteName: nil)",
            "SitRepTests/D.swift": "typealias" + " Plain = UserDefaults\nlet e = Plain()",
            "SitRepEdgeTests/E.swift": "let f = " + made,
            "SitRepCoreTests/MemoryDefaultsTests.swift": "\n" + Self.allowed.values.first! + "\nlet g = " + made,
        ]

        #expect(Self.findings(files) == [
            "SitRepCoreTests/MemoryDefaultsTests.swift:3 reaches this Mac's preferences",
            "SitRepEdgeTests/E.swift:1 reaches this Mac's preferences",
            "SitRepTests/A.swift:2 reaches this Mac's preferences",
            "SitRepTests/B.swift:2 reaches this Mac's preferences",
            "SitRepTests/C.swift:1 reaches this Mac's preferences",
            "SitRepTests/C.swift:2 reaches this Mac's preferences",
            "SitRepTests/D.swift:1 reaches this Mac's preferences",
        ])
    }

    /// Each use of a way in, by the line it starts on, but the allowed line of its file.
    private static func findings(_ files: [String: String]) -> [String] {
        files.sorted { $0.key < $1.key }.flatMap { path, text in
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let code = lines.map(uncommented).joined(separator: "\n")
            let starts = code.matches(of: ways).map(\.range.lowerBound)
            let numbers = Set(starts.map { code[..<$0].count { $0 == "\n" } })

            return numbers.sorted()
                .filter { lines[$0].trimmingCharacters(in: .whitespaces) != allowed[path] }
                .map { "\(path):\($0 + 1) reaches this Mac's preferences" }
        }
    }

    /// A line less any comment it ends with.
    private static func uncommented(_ line: Substring) -> String {
        guard let comment = line.range(of: "//") else {
            return String(line)
        }

        return String(line[..<comment.lowerBound])
    }
}
