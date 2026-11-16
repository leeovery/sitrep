import Foundation
import SitRepTestSupport
import Testing

/// Every suite of the app's seven test targets carries the backstop, so no test can hang the run: Swift Testing has no
/// trait for a whole target, so each suite declares it, and this reads the sources for one that does not.
@Suite(.backstop)
struct BackstopTests {
    @Test func everySuiteWithATestCarriesTheBackstop() throws {
        let tests = Repository.root.appending(path: "app/Tests")
        let targets = try FileManager.default.contentsOfDirectory(atPath: tests.path).filter { $0.hasSuffix("Tests") }
        let lacking = try targets.flatMap { try Self.suitesLackingTheBackstop(in: tests.appending(path: $0)) }

        #expect(targets.count == 7)
        #expect(lacking.isEmpty, "\(lacking.joined(separator: "\n"))")
    }

    @Test func aSuiteIsFoundByItsTestsWhereverTheyAreDeclared() {
        let files = [
            "A.swift": "@Suite(.backstop)\nstruct Kept {\n    @Test func a() {}\n}\nstruct Bare {\n    @Test func b() {}\n}",
            "B.swift": "@MainActor\nstruct Extended {}\nextension Extended {\n    @Test func c() {}\n}\nenum Helper {}",
        ]

        #expect(Self.suitesLackingTheBackstop(in: files) == ["A.swift: Bare", "B.swift: Extended"])
    }

    /// Each top-level type of the target holding a test, among its own declarations or an extension's, whose
    /// attributes name no backstop.
    private static func suitesLackingTheBackstop(in target: URL) throws -> [String] {
        let paths = FileManager.default.enumerator(atPath: target.path)?.compactMap { $0 as? String } ?? []
        let files = try Dictionary(uniqueKeysWithValues: paths.filter { $0.hasSuffix(".swift") }.map { path in
            (target.lastPathComponent + "/" + path, try String(contentsOf: target.appending(path: path), encoding: .utf8))
        })

        return suitesLackingTheBackstop(in: files)
    }

    private static func suitesLackingTheBackstop(in files: [String: String]) -> [String] {
        var declared: [String: (path: String, attributes: [Substring])] = [:]
        var tested: Set<String> = []

        for (path, text) in files {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let starts = lines.indices.filter { declaration(lines[$0]) != nil }

            for (index, start) in starts.enumerated() {
                guard let (kind, name) = declaration(lines[start]) else {
                    continue
                }

                let end = index + 1 < starts.count ? starts[index + 1] : lines.endIndex

                if kind != "extension" {
                    declared[name] = (path, lines[..<start].reversed().prefix { $0.hasPrefix("@") })
                }
                if lines[(start + 1) ..< end].contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("@Test") }) {
                    tested.insert(name)
                }
            }
        }

        return tested.compactMap { name in
            guard let (path, attributes) = declared[name], !attributes.contains(where: { $0.contains(".backstop") }) else {
                return nil
            }

            return "\(path): \(name)"
        }.sorted()
    }

    /// A top-level declaration's kind and name, a type or an extension of one, at the start of its line.
    private static func declaration(_ line: Substring) -> (kind: String, name: String)? {
        guard line.first?.isLetter == true else {
            return nil
        }

        let words = line.split(separator: " ").drop { ["public", "private", "fileprivate", "internal", "final"].contains($0) }

        guard let kind = words.first, ["struct", "class", "enum", "actor", "extension"].contains(kind),
              let name = words.dropFirst().first?.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." })
        else {
            return nil
        }

        return (String(kind), String(name))
    }
}
