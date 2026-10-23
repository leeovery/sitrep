import Foundation

/// What Lee types in the sidebar's Filter field, which narrows the list in place: a session stays while every
/// word typed appears, anywhere, in its name, its project's or its lines' words, whatever their case and accents, so
/// typing a project's name lists its sessions; a project stays in Projects while its name holds every word.
public struct Filter: Equatable, Sendable {
    /// A piece of a name, lit where a word typed appears in it, soft elsewhere.
    public struct Run: Equatable, Sendable {
        public let text: String
        public let isLit: Bool
    }

    public let text: String
    private let words: [String]

    public init(_ text: String = "") {
        self.text = text
        words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Nothing typed but spaces: the whole board.
    public var isEmpty: Bool { words.isEmpty }

    /// Every word appears in one of these names.
    func matches(_ names: String...) -> Bool {
        matches(names)
    }

    func matches(_ names: [String]) -> Bool {
        words.allSatisfy { word in names.contains { !Self.ranges(of: word, in: $0).isEmpty } }
    }

    /// A name in runs, each word typed lit wherever it appears, the rest soft.
    public func runs(of name: String) -> [Run] {
        var runs: [Run] = []
        var from = name.startIndex

        for lit in litRanges(in: name) {
            if from < lit.lowerBound {
                runs.append(Run(text: String(name[from ..< lit.lowerBound]), isLit: false))
            }
            runs.append(Run(text: String(name[lit]), isLit: true))
            from = lit.upperBound
        }
        if from < name.endIndex {
            runs.append(Run(text: String(name[from...]), isLit: false))
        }
        return runs
    }

    /// Where each word appears in the name, those that touch or overlap joined, in order.
    private func litRanges(in name: String) -> [Range<String.Index>] {
        let found = words.flatMap { word in Self.ranges(of: word, in: name) }.sorted { $0.lowerBound < $1.lowerBound }

        return found.reduce(into: []) { joined, range in
            if let last = joined.last, range.lowerBound <= last.upperBound {
                joined[joined.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            } else {
                joined.append(range)
            }
        }
    }

    /// Where the word appears in the name. Foundation finds a word whose folding changes its length at a range that is
    /// not it: "ß" at the "St" of "Strasse", or of "Stop the build", which holds no "ss" at all. So a range whose
    /// letters do not fold to the word's is no place of it, for the match as for the letters lit.
    private static func ranges(of word: String, in name: String) -> [Range<String.Index>] {
        let folded = fold(word)
        var found: [Range<String.Index>] = []
        var rest = name.startIndex ..< name.endIndex

        while let range = name.range(of: word, options: loosely, range: rest) {
            if fold(String(name[range])) == folded {
                found.append(range)
            }
            rest = range.upperBound ..< name.endIndex
        }
        return found
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: loosely, locale: nil)
    }

    private static let loosely: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
}

/// How bright a name's words are, of the sidebar's greys, brightest first: its own, with nothing typed; while the
/// filter narrows the list, the rest of it no brighter than soft, and the words typed one step brighter than that.
/// Quiet, a Snoozed row's name, sits between the text and soft, and lights as the text does.
public enum Tone: Sendable, Equatable {
    case text, quiet, soft, dim, faint

    /// The words of the name that the filter does not light.
    public var rest: Tone {
        self == .text || self == .quiet ? .soft : self
    }

    /// The words the filter lights.
    public var lit: Tone {
        rest == .soft ? .text : .soft
    }
}

extension Listed {
    /// The list narrowed to what the filter keeps: the sessions that match, by their names, their projects' and their
    /// lines' words, each in its section; the projects whose names match.
    public func narrowed(by filter: Filter) -> Listed {
        guard !filter.isEmpty else {
            return self
        }

        var narrowed = self

        narrowed.rows = rows.filter { filter.matches([$0.name, $0.project] + $0.lines.map(\.words)) }
        narrowed.projects = projects.filter { filter.matches($0.name) }
        return narrowed
    }
}
