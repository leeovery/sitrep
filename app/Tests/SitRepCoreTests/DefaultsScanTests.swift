import Foundation
import SitRepTestSupport
import Testing

/// No test reaches this Mac's real preferences, or its real board folder. Every one gives what it makes
/// `MemoryDefaults`, as tests that made a suite of their own once left 171 domains behind; and every one gives a
/// `SnoozeFile` or a `HereFile` a folder of its own, as the app's own write the board folder SitRep shows. No type falls
/// back to either, so a test reaches one only by naming it; this reads the app's test sources, across their lines, for
/// a way it might: the standard domain, `.standard` however it is reached, a `UserDefaults` made, or another name given
/// the type; and the live `SnoozeFile` or `HereFile`, or one found from this Mac's own environment or home. It allows only
/// `MemoryDefaultsTests`' one check that its suite stays empty, by that line.
@Suite(.backstop)
struct DefaultsScanTests {
    /// The test sources were 187 on 17 November 2026: a scan that reads far fewer has stopped reading them.
    private static let fewestFiles = 150

    /// Every way in to the preferences, as a pattern across lines: `.standard`, a `UserDefaults` made, or the type
    /// given another name.
    private static var preferences: Regex<Substring> {
        // Simple word boundaries, here and for the board folder: Unicode's run on across a `.` between letters, so
        // `.standard.bool(forKey:)` would pass unseen.
        #/\.\s*standard\b|\bUserDefaults\s*(?:\.\s*init\s*)?\(|\btypealias\s+\w+\s*=\s*UserDefaults\b/#
            .wordBoundaryKind(.simple)
    }

    /// Every way in to the board folder, as a pattern across lines: `SnoozeFile.live` or `HereFile.live`, or `.live`
    /// given for one, or a file found from this Mac's environment or its home.
    private static var boardFolder: Regex<Substring> {
        #/
            \b(?:Snooze|Here)File \s* \. \s* live\b
            | \b(?:snooze|here)File \s* : \s* \. \s* live\b
            | \benvironment \s* : \s* ProcessInfo \s* \. \s* processInfo \s* \. \s* environment\b
            | \bhomeDirectory (?:ForCurrentUser)\b
        /#
            .wordBoundaryKind(.simple)
    }

    /// The one use allowed, by its file and its line, spelt in parts so this file holds none.
    private static let allowed = [
        "SitRepCoreTests/MemoryDefaultsTests.swift":
            "let domain = try #require(UserDefaults" + "(suiteName: defaults.suite))",
    ]

    @Test func noTestReachesThisMacsPreferencesOrItsBoardFolder() throws {
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
            "SitRepTests/F.swift": "let h = UserDefaults." + "standard.bool(forKey: \"k\")",
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
            "SitRepTests/F.swift:1 reaches this Mac's preferences",
        ])
    }

    /// The live file, `.live` given for one, and a file found from this Mac's environment or home are each found,
    /// across lines too; a file of a test's own folder, an environment of its own, or the live board's name in a
    /// comment, is not.
    @Test func aWayToTheBoardFolderIsFoundWhereverItIsPlanted() {
        let files = [
            "SitRepMenuTests/A.swift": "let a = SnoozeFile\n    ." + "live\nlet b = SnoozeFile(url: folder)",
            "SitRepTests/B.swift": "let c = Preferences(defaults, snoozeFile: ." + "live)\n// SnoozeFile." + "live",
            "SitRepTests/C.swift": "let d = SnoozeFile(\n    environment: ProcessInfo.processInfo" + ".environment, home: home\n)",
            "SitRepTests/D.swift": "let e = SnoozeFile(environment: [:], home: FileManager.default.homeDirectory"
                + "ForCurrentUser)\nlet f = SnoozeFile(environment: [\"HOME\": \"/x\"], home: home)",
            "SitRepTests/E.swift": "let g = SnoozeFile." + "live.url",
            "SitRepScreenTests/F.swift": "let h = HereFile\n    ." + "live\nlet i = HereFile(url: folder)",
            "SitRepTests/G.swift": "let j = Works(hereFile: ." + "live)\n// HereFile." + "live",
        ]

        #expect(Self.findings(files) == [
            "SitRepMenuTests/A.swift:1 reaches this Mac's board folder",
            "SitRepScreenTests/F.swift:1 reaches this Mac's board folder",
            "SitRepTests/B.swift:1 reaches this Mac's board folder",
            "SitRepTests/C.swift:2 reaches this Mac's board folder",
            "SitRepTests/D.swift:1 reaches this Mac's board folder",
            "SitRepTests/E.swift:1 reaches this Mac's board folder",
            "SitRepTests/G.swift:1 reaches this Mac's board folder",
        ])
    }

    /// Each use of a way in, by the line it starts on and what it reaches, but the allowed line of its file.
    private static func findings(_ files: [String: String]) -> [String] {
        files.sorted { $0.key < $1.key }.flatMap { path, text in
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let code = lines.map(uncommented).joined(separator: "\n")
            let lineOf = { (match: Regex<Substring>.Match) in code[..<match.range.lowerBound].count { $0 == "\n" } }
            let reached = [(preferences, "preferences"), (boardFolder, "board folder")].flatMap { ways, what in
                Set(code.matches(of: ways).map(lineOf)).sorted()
                    .filter { lines[$0].trimmingCharacters(in: .whitespaces) != allowed[path] }
                    .map { ($0, what) }
            }

            return reached.sorted { $0.0 < $1.0 }.map { "\(path):\($0.0 + 1) reaches this Mac's \($0.1)" }
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
