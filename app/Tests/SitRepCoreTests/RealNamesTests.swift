import Foundation
import SitRepTestSupport
import Testing

/// No test names Lee's real work, by `tests/real-names.txt`'s rule; the TypeScript kit's tests can't read files, so
/// this one keeps both suites to it, and the prototypes their recordings are made from. The rule's own tests use
/// made-up names, as this file is one it reads.
@Suite(.backstop)
struct RealNamesTests {
    private static let list = try! RealNames("""
    # A comment, then a blank line, which are nothing.

    Quokka
    Blue Lagoon\r
    sr-zz9x1q
    /Users/zed
    allow app/Tests/A.swift Quokka
    allow app/Tests/A.swift Blue Lagoon
    """)

    @Test func noFileOfEitherSuiteNamesLeesRealWorkButWhereTheListAllowsIt() throws {
        let scan = try RealNames.listed().scan()

        #expect(scan.hits.isEmpty, "\(scan.hits.map(\.description).joined(separator: "\n"))")
        #expect(scan.stale.isEmpty, "stale: \(scan.stale.map(\.description).joined(separator: "\n"))")
    }

    @Test func theListIsItsNamesTrimmedAndItsAllowsWithCommentsAndBlankLinesNothing() {
        #expect(Self.list.names == ["Quokka", "Blue Lagoon", "sr-zz9x1q", "/Users/zed"])
        #expect(Self.list.allows == [
            RealNames.Allow(path: "app/Tests/A.swift", name: "Quokka"),
            RealNames.Allow(path: "app/Tests/A.swift", name: "Blue Lagoon"),
        ])
    }

    @Test func eachLineIsReadTrimmedOfSpacesAndTabsAndAnEndingReturn() throws {
        let list = try RealNames("  Quokka \t\n\tBlue Lagoon  \n allow app/Tests/A.swift Quokka\t\r")

        #expect(list.names == ["Quokka", "Blue Lagoon"])
        #expect(list.allows == [RealNames.Allow(path: "app/Tests/A.swift", name: "Quokka")])
    }

    /// An allow is `allow`, its path and its name, each after one space; any other line opening `allow` is no name
    /// but an error, as is a list that names nothing.
    @Test(arguments: [
        "allow", "allow app/Tests/A.swift", "allow app/Tests/A.swift ", "allow  app/Tests/A.swift Quokka",
        "allow\tapp/Tests/A.swift Quokka", "allowance", "allowed app/Tests/A.swift Quokka",
    ])
    func aMalformedAllowIsAnError(line: String) {
        let read = line.trimmingCharacters(in: .whitespaces)

        #expect(throws: RealNames.Unreadable.malformed(line: 2, read)) { try RealNames("Quokka\n\(line)") }
    }

    @Test(arguments: ["", "# only a comment\n\n", "allow app/Tests/A.swift Quokka"])
    func aListThatNamesNothingIsAnError(list: String) {
        #expect(throws: RealNames.Unreadable.empty) { try RealNames(list) }
    }

    /// Only a letter or a digit joins a name to the text around it: `-`, `_`, `.`, `/`, a space and quotes don't.
    @Test(arguments: [
        "Quokka", "com.quokka.Quokka.app", "/Users/me/Code/Quokka-1a2b", "the_Quokka_key", #""Quokka""#,
        "Quokka's turn", "ask:sr-zz9x1q:k1", "Blue Lagoon · Plan", "/Users/zed/x", "file:///Users/zed",
    ])
    func aNameIsAHitBetweenAnythingButLettersAndDigits(text: String) {
        #expect(!Self.list.found(in: text).isEmpty)
    }

    @Test(arguments: [
        "Quokkas", "MyQuokka", "Quokka2", "2Quokka", "Quokkaé", "éQuokka", "Blue Lagoons", "sr-zz9x1qa", "/Users/zedd",
        "/Users/zed2",
    ])
    func aNameWithinAWordIsNoHit(text: String) {
        #expect(Self.list.found(in: text).isEmpty)
    }

    @Test(arguments: ["quokka", "QUOKKA", "blue lagoon", "Blue  Lagoon"])
    func aNameIsMatchedAsWrittenCaseAndAll(text: String) {
        #expect(Self.list.found(in: text).isEmpty)
    }

    /// Each hit says its line, and an allow, of one name or of several words, exempts that name in that file alone.
    @Test func anAllowExemptsThatNameInThatFileAloneAndEachHitSaysItsLine() {
        let text = "Quokka\nand Blue Lagoon\nthen sr-zz9x1q"

        #expect(Self.list.hits(in: text, at: "app/Tests/A.swift").map(\.description) == ["app/Tests/A.swift:3: sr-zz9x1q"])
        #expect(Self.list.hits(in: text, at: "app/Tests/B.swift").map(\.description) == [
            "app/Tests/B.swift:1: Quokka", "app/Tests/B.swift:2: Blue Lagoon", "app/Tests/B.swift:3: sr-zz9x1q",
        ])
    }

    /// Every file under `tests/`, `app/Tests/` and `prototypes/` is read whole, but the list itself, a binary file,
    /// `.build`, `node_modules`, a `recording.json` and `.DS_Store`; a file elsewhere is not.
    @Test func theRuleReadsEveryTextFileOfBothSuitesAndThePrototypesButTheListItself() throws {
        let scratch = try Self.checkout([
            "tests/a.test.ts", "tests/real-names.txt", "app/Tests/X/B.swift", "app/Tests/X/Printed/c.jsonl",
            "app/Tests/.build/d.swift", "app/Tests/X/.DS_Store", "app/Sources/E.swift", "README.md",
            "prototypes/p/g.html", "prototypes/p/node_modules/h/i.js", "prototypes/p/recording.json",
        ])
        try Data("Quokka\0".utf8).write(to: scratch.folder.appending(path: "app/Tests/X/f.png"))

        #expect(try Self.list.scan(under: scratch.folder).hits.map(\.description) == [
            "app/Tests/X/B.swift:2: Quokka", "app/Tests/X/Printed/c.jsonl:2: Quokka", "prototypes/p/g.html:2: Quokka",
            "tests/a.test.ts:2: Quokka",
        ])
    }

    /// An allow that exempts nothing is stale: its name unlisted, its file missing, or its name no longer in its file.
    @Test func anAllowThatExemptsNothingIsStale() throws {
        let scratch = try Self.checkout(["app/Tests/A.swift", "app/Tests/B.swift"])
        let list = try RealNames("""
        Quokka
        Blue Lagoon
        allow app/Tests/A.swift Quokka
        allow app/Tests/A.swift Blue Lagoon
        allow app/Tests/B.swift Wombat
        allow app/Tests/Gone.swift Quokka
        """)

        #expect(try list.scan(under: scratch.folder).stale.map(\.description) == [
            "allow app/Tests/A.swift Blue Lagoon", "allow app/Tests/B.swift Wombat", "allow app/Tests/Gone.swift Quokka",
        ])
    }

    /// No file goes unread unsaid: a folder the rule reads missing, a text file that isn't UTF-8, UTF-16 by its byte
    /// order mark though its NULs would read as binary, or a symlinked folder is an error.
    @Test func whatTheRuleCannotReadIsAnError() throws {
        let missing = try Self.checkout(["tests/a.test.ts"], suites: ["tests"])
        let latin = try Self.checkout([])
        let little = try Self.checkout([])
        let big = try Self.checkout([])
        let linked = try Self.checkout([])

        try Data([0x51, 0xE9, 0x0A]).write(to: latin.folder.appending(path: "tests/latin.txt"))
        try (Data([0xFF, 0xFE]) + "Quokka\n".data(using: .utf16LittleEndian)!)
            .write(to: little.folder.appending(path: "tests/wide.txt"))
        try (Data([0xFE, 0xFF]) + "Quokka\n".data(using: .utf16BigEndian)!).write(to: big.folder.appending(path: "tests/wide.txt"))
        try FileManager.default.createSymbolicLink(
            at: linked.folder.appending(path: "app/Tests/Elsewhere"), withDestinationURL: linked.folder.appending(path: "tests")
        )

        #expect(throws: RealNames.Unreadable.missing(folder: "app/Tests")) { try Self.list.scan(under: missing.folder) }
        #expect(throws: RealNames.Unreadable.notText(path: "tests/latin.txt")) { try Self.list.scan(under: latin.folder) }
        #expect(throws: RealNames.Unreadable.notText(path: "tests/wide.txt")) { try Self.list.scan(under: little.folder) }
        #expect(throws: RealNames.Unreadable.notText(path: "tests/wide.txt")) { try Self.list.scan(under: big.folder) }
        #expect(throws: RealNames.Unreadable.symlinkedFolder(path: "app/Tests/Elsewhere")) {
            try Self.list.scan(under: linked.folder)
        }
    }

    /// A checkout of its own, its suites' folders made, each file given naming Quokka on its second line.
    private static func checkout(_ paths: [String], suites: [String] = RealNames.scanned) throws -> Scratch {
        let scratch = Scratch()

        for suite in suites {
            try FileManager.default.createDirectory(at: scratch.folder.appending(path: suite), withIntermediateDirectories: true)
        }
        for path in paths {
            try scratch.write("a comment\n// then Quokka\n", to: scratch.folder.appending(path: path))
        }
        return scratch
    }
}
