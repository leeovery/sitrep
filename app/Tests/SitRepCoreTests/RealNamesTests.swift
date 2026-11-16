import Foundation
import SitRepTestSupport
import Testing

/// No test names Lee's real work, by `tests/real-names.txt`'s rule; the TypeScript kit's tests can't read files, so
/// this one keeps both suites to it. The rule's own tests use made-up names, as this file is one it reads.
struct RealNamesTests {
    private static let list = RealNames("""
    # A comment, then a blank line, which are nothing.

    Quokka
    Blue Lagoon
    sr-zz9x1q
    allow app/Tests/A.swift Quokka
    """)

    @Test func noFileOfEitherSuiteNamesLeesRealWorkButWhereTheListAllowsIt() throws {
        let hits = try RealNames.listed().hits()

        #expect(hits.isEmpty, "\(hits.map(\.description).joined(separator: "\n"))")
    }

    @Test func theListIsItsNamesAndItsAllowsWithCommentsAndBlankLinesNothing() {
        #expect(Self.list.names == ["Quokka", "Blue Lagoon", "sr-zz9x1q"])
        #expect(Self.list.allowed == ["app/Tests/A.swift": ["Quokka"]])
    }

    /// Only a letter or a digit joins a name to the text around it: `-`, `_`, `.`, `/`, a space and quotes don't.
    @Test(arguments: [
        "Quokka", "com.quokka.Quokka.app", "/Users/me/Code/Quokka-1a2b", "the_Quokka_key", #""Quokka""#,
        "Quokka's turn", "ask:sr-zz9x1q:k1", "Blue Lagoon · Plan",
    ])
    func aNameIsAHitBetweenAnythingButLettersAndDigits(text: String) {
        #expect(!Self.list.names(in: text).isEmpty)
    }

    @Test(arguments: ["Quokkas", "MyQuokka", "Quokka2", "2Quokka", "Quokkaé", "éQuokka", "Blue Lagoons", "sr-zz9x1qa"])
    func aNameWithinAWordIsNoHit(text: String) {
        #expect(Self.list.names(in: text).isEmpty)
    }

    @Test(arguments: ["quokka", "QUOKKA", "blue lagoon", "Blue  Lagoon"])
    func aNameIsMatchedAsWrittenCaseAndAll(text: String) {
        #expect(Self.list.names(in: text).isEmpty)
    }

    @Test func anAllowExemptsThatNameInThatFileAlone() {
        let text = "Quokka and Blue Lagoon"

        #expect(Self.list.hits(in: text, at: "app/Tests/A.swift").map(\.name) == ["Blue Lagoon"])
        #expect(Self.list.hits(in: text, at: "app/Tests/B.swift").map(\.name) == ["Quokka", "Blue Lagoon"])
    }

    /// Every file under `tests/` and `app/Tests/` is read whole, but the list itself, a binary file, `.build` and
    /// `.DS_Store`; a file elsewhere is not.
    @Test func theRuleReadsEveryTextFileOfBothSuitesButTheListItself() throws {
        let scratch = Scratch()
        let named = "a comment\n// then Quokka\n"

        for path in [
            "tests/a.test.ts", "tests/real-names.txt", "app/Tests/X/B.swift", "app/Tests/X/Printed/c.jsonl",
            "app/Tests/.build/d.swift", "app/Tests/X/.DS_Store", "app/Sources/E.swift", "README.md",
        ] {
            try scratch.write(named, to: scratch.folder.appending(path: path))
        }
        try Data("Quokka\0".utf8).write(to: scratch.folder.appending(path: "app/Tests/X/f.png"))

        #expect(try Self.list.hits(under: scratch.folder).map(\.description) == [
            "app/Tests/X/B.swift: Quokka", "app/Tests/X/Printed/c.jsonl: Quokka", "tests/a.test.ts: Quokka",
        ])
    }

    /// A checkout without a folder the rule reads is no clean one: its missing folder is no folder of clean files.
    @Test func aCheckoutMissingASuitesFolderIsAnError() throws {
        let scratch = Scratch()

        try scratch.write("Quokka", to: scratch.folder.appending(path: "tests/a.test.ts"))

        #expect(throws: CocoaError.self) { try Self.list.hits(under: scratch.folder) }
    }
}
