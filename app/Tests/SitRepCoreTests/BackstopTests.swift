import Foundation
@testable import SitRepTestSupport
import Testing

/// Every suite of the app's seven test targets carries the backstop, so no test can hang the run: Swift Testing has no
/// trait for a whole target, so each suite declares it, and this reads the sources for one that does not, failing on a
/// shape it cannot read rather than passing it over.
@Suite(.backstop)
struct BackstopTests {
    /// The suites were 190 on 16 November 2026: a scan that finds far fewer has stopped reading the sources.
    private static let fewestSuites = 150

    @Test func everySuiteWithATestCarriesTheBackstop() throws {
        let tests = Repository.root.appending(path: "app/Tests")
        let targets = try FileManager.default.contentsOfDirectory(atPath: tests.path).filter { $0.hasSuffix("Tests") }
        let scans = try targets.map { try SuiteScan(target: tests.appending(path: $0)) }
        let findings = scans.flatMap(\.findings)

        #expect(targets.count == 7)
        #expect(scans.map(\.suites).reduce(0, +) >= Self.fewestSuites)
        #expect(findings.isEmpty, "\(findings.joined(separator: "\n"))")
    }

    @Test func aSuiteIsFoundByItsTestsWhereverTheyAreDeclared() {
        let scan = SuiteScan(files: [
            "A.swift": "@Suite(.backstop)\nstruct Kept {\n    @Test func a() {}\n}\nstruct Bare {\n    @Test func b() {}\n}",
            "B.swift": "@MainActor\nstruct Extended {}\nextension Extended {\n    @Test func c() {}\n}\nenum Helper {}\n"
                + "private extension [Int] {\n    var helper: Int { 0 }\n}",
            "C.swift": "@MainActor @Suite(.backstop, .tags(.thisMac)) final class OneLine {\n    @Test func d() {}\n}",
            "D.swift": "@Suite(.backstop)\nnonisolated package struct Outer {\n    struct Inner {}\n}\n"
                + "extension Outer.Inner {\n    @Test func e() {}\n}\nopen class Opened {\n    @Test func f() {}\n}",
            "E.swift": "@Suite(.backstop) struct KeptOnOneLine { @Test func g() {} }\n"
                + "struct BareOnOneLine { @Test func h() {} }\n"
                + "struct HoldingBare {\n    struct Nested { @Test func i() {} }\n}",
        ])

        #expect(scan.suites == 9)
        #expect(scan.findings == [
            "A.swift: Bare lacks the backstop",
            "B.swift: Extended lacks the backstop",
            "D.swift: Opened lacks the backstop",
            "E.swift: BareOnOneLine lacks the backstop",
            "E.swift: HoldingBare lacks the backstop",
        ])
    }

    /// The backstop is one of `@Suite`'s traits, never words within another's.
    @Test func theBackstopIsReadAsATraitOfTheSuite() {
        let scan = SuiteScan(files: [
            "A.swift": "@Suite(.disabled(\"no .backstop\"))\nstruct Disabled {\n    @Test func a() {}\n}",
            "B.swift": "@Suite(.enabled(if: Self.backstop), .serialized)\nstruct Enabled {\n    @Test func b() {}\n}",
            "C.swift": "@Suite(.serialized, .backstop)\nstruct Kept {\n    @Test func c() {}\n}",
        ])

        #expect(scan.suites == 3)
        #expect(scan.findings == ["A.swift: Disabled lacks the backstop", "B.swift: Enabled lacks the backstop"])
    }

    @Test func aShapeTheScanCannotReadFailsIt() {
        let scan = SuiteScan(files: [
            "A.swift": "@Test(.backstop) func outside() {}",
            "B.swift": "extension Elsewhere.Inner {\n    @Test func g() {}\n}",
            "C.swift": "weird struct Odd {\n    @Test func h() {}\n}",
            "D.swift": "extension [Int] {\n    @Test func i() {}\n}",
            "E.swift": "@Suite(.backstop)\nstruct Twice {\n    @Test func j() {}\n}",
            "F.swift": "private struct Twice {}",
        ])

        #expect(scan.findings == [
            "A.swift: a test outside any suite",
            "B.swift: Elsewhere.Inner holds tests, its type declared nowhere in its target",
            "C.swift: tests under a declaration it cannot read: weird struct Odd {",
            "D.swift: tests under a declaration it cannot read: extension [Int] {",
            "E.swift: Twice holds tests, its type declared again in F.swift",
        ])
    }

    /// The backstop's rule: the run is ended once no test has begun or ended for the quiet, while some are in flight;
    /// a test beginning, as one ending, moves the run on; and with none in flight, nothing is ended.
    @Test func theRunIsEndedOnceNoTestHasBegunOrEndedForTheQuietWithSomeInFlight() {
        let start = SuspendingClock.now
        let quiet = InFlight.quiet
        var flight = Flight(at: start)

        #expect(flight.stall(at: start + .seconds(900), quiet: quiet) == nil, "none in flight")

        _ = flight.begin("Hung/waits()", at: start)
        _ = flight.begin("Slow/sleeps()", at: start + .seconds(10))
        let ending = flight.begin("Quick/ends()", at: start + .seconds(20))

        #expect(flight.stall(at: start + .seconds(319), quiet: quiet) == nil, "a beginning moves the run on")

        flight.end(ending, at: start + .seconds(100))

        #expect(flight.stall(at: start + .seconds(399), quiet: quiet) == nil, "an end moves the run on")
        #expect(flight.stall(at: start + .seconds(400), quiet: quiet) == """
            The backstop ended the run: no test has begun or ended for 300 s. In flight:
              Hung/waits(), 400 s in
              Slow/sleeps(), 390 s in

            """)
        #expect(InFlight.quiet == .seconds(300))
    }
}

/// The suites of a test target read from its sources: each top-level type holding a test, among its own declarations,
/// a nested type's or an extension's, and whether its attributes give it the backstop; and every shape holding a test
/// that the read cannot follow, which it names rather than pass over.
private struct SuiteScan {
    /// What a top-level line is: a type or an extension declared, with the attributes on its own line and whether a
    /// test is declared on it too; a test outside any type; a line naming a declaration's kind that reads as none; or
    /// none of these.
    private enum Line {
        case declaration(kind: Substring, name: Substring, attributes: [Substring], holdsTest: Bool)
        case test
        case unreadable
        case other

        var holdsTest: Bool {
            switch self {
            case .test: true
            case let .declaration(_, _, _, holdsTest): holdsTest
            case .unreadable, .other: false
            }
        }
    }

    /// A type declared, with its attributes.
    private struct Declaration {
        let path: String
        let attributes: [Substring]
    }

    /// What the lines below a declaration belong to: a type by its name, or a declaration the read cannot follow.
    private enum Holder: Hashable {
        case named(Substring)
        case unreadable(Substring)
    }

    private static let kinds: Set<Substring> = ["struct", "class", "enum", "actor", "extension"]
    private static let modifiers: Set<Substring> = [
        "public", "package", "internal", "fileprivate", "private", "open", "final", "nonisolated", "indirect",
    ]

    private(set) var suites = 0
    private(set) var findings: [String] = []

    init(target: URL) throws {
        let paths = FileManager.default.enumerator(atPath: target.path)?.compactMap { $0 as? String } ?? []

        self.init(files: try Dictionary(uniqueKeysWithValues: paths.filter { $0.hasSuffix(".swift") }.map { path in
            (target.lastPathComponent + "/" + path, try String(contentsOf: target.appending(path: path), encoding: .utf8))
        }))
    }

    init(files: [String: String]) {
        var declared: [Substring: [Declaration]] = [:]
        var tested: [Holder: String] = [:]
        var found: Set<String> = []

        for (path, text) in files {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var holder: Holder?

            for (index, line) in lines.enumerated() {
                switch Self.read(line) {
                case let .declaration(kind, name, attributes, holdsTest):
                    holder = .named(name)
                    if kind != "extension" {
                        let above = lines[..<index].reversed().prefix { $0.hasPrefix("@") }

                        declared[name, default: []].append(Declaration(path: path, attributes: Array(above) + attributes))
                    }
                    if holdsTest {
                        tested[.named(name)] = path
                    }
                case .test:
                    found.insert("\(path): a test outside any suite")
                case .unreadable:
                    holder = .unreadable(line)
                case .other:
                    if let holder, Self.read(line.drop { $0.isWhitespace }).holdsTest {
                        tested[holder] = path
                    }
                }
            }
        }

        for (holder, path) in tested {
            switch holder {
            case let .unreadable(line):
                found.insert("\(path): tests under a declaration it cannot read: \(line)")
            case let .named(name):
                found.formUnion(Self.lacking(name, in: path, declared: declared))
            }
        }

        suites = tested.count
        findings = found.sorted()
    }

    /// What is wrong of the type holding tests, under its own name or a nested type's: declared nowhere in the target,
    /// declared more than once, so which holds the tests cannot be told, or declared with no backstop.
    private static func lacking(_ name: Substring, in path: String, declared: [Substring: [Declaration]]) -> [String] {
        let type = name.prefix { $0 != "." }
        let declarations = declared[type] ?? []

        guard let declaration = declarations.first else {
            return ["\(path): \(name) holds tests, its type declared nowhere in its target"]
        }
        guard declarations.count == 1 else {
            let paths = declarations.map(\.path).sorted()
            let again = paths.dropFirst().joined(separator: ", ")

            return ["\(paths[0]): \(type) holds tests, its type declared again in \(again)"]
        }

        return carriesBackstop(declaration.attributes) ? [] : ["\(declaration.path): \(type) lacks the backstop"]
    }

    /// Whether the attributes give the suite the backstop: `.backstop` one of `@Suite`'s own traits, never words within
    /// another's.
    private static func carriesBackstop(_ attributes: [Substring]) -> Bool {
        attributes.contains { $0.hasPrefix("@Suite(") && traits(of: $0).contains(".backstop") }
    }

    /// The traits `@Suite` is given: its arguments, split at the commas between them, its strings emptied first.
    private static func traits(of suite: Substring) -> [String] {
        let given = suite.dropFirst("@Suite(".count).dropLast().replacing(#/"[^"]*"/#, with: "\"\"")
        var traits = [""]
        var depth = 0

        for character in given {
            switch character {
            case "(", "[": depth += 1
            case ")", "]": depth -= 1
            case "," where depth == 0:
                traits.append("")
                continue
            default: break
            }
            traits[traits.count - 1].append(character)
        }

        return traits.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func read(_ line: Substring) -> Line {
        guard let first = line.first, !first.isWhitespace, first != "/" else {
            return .other
        }

        let (attributes, rest) = Self.attributes(opening: line)
        let words = rest.split(separator: " ")
        let declaring = words.drop { modifiers.contains($0) }

        if attributes.contains(where: { $0.hasPrefix("@Test") }) {
            return .test
        }
        if let kind = declaring.first, kinds.contains(kind), let name = declaring.dropFirst().first.map(typeName), !name.isEmpty {
            let holdsTest = rest[name.endIndex...].contains("@Test")

            return .declaration(kind: kind, name: name, attributes: attributes, holdsTest: holdsTest)
        }

        return words.contains(where: kinds.contains) ? .unreadable : .other
    }

    /// The attributes the line opens with, each with its arguments, and the rest of the line.
    private static func attributes(opening line: Substring) -> (attributes: [Substring], rest: Substring) {
        var attributes: [Substring] = []
        var rest = line

        while rest.first == "@" {
            var end = rest.dropFirst().firstIndex { !isNamePart($0) } ?? rest.endIndex

            if end < rest.endIndex, rest[end] == "(" {
                end = closing(rest[end...]) ?? rest.endIndex
            }
            attributes.append(rest[..<end])
            rest = rest[end...].drop { $0 == " " }
        }

        return (attributes, rest)
    }

    /// Just past the bracket closing the one the text opens with.
    private static func closing(_ text: Substring) -> Substring.Index? {
        var depth = 0

        for index in text.indices {
            switch text[index] {
            case "(": depth += 1
            case ")": depth -= 1
            default: break
            }

            if depth == 0 {
                return text.index(after: index)
            }
        }

        return nil
    }

    private static func typeName(_ word: Substring) -> Substring {
        word.prefix(while: isNamePart)
    }

    private static func isNamePart(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "."
    }
}
