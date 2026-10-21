import Foundation

/// What Lee types in the sidebar's Filter field, which narrows the view chosen in place: a session stays while every
/// word typed appears, anywhere, in its name or its project's, whatever their case and accents, so typing a project's
/// name lists its sessions. A quiet project stays while its name holds every word, or one of its sessions matches.
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

/// How bright a name's words are, of the window's three greys: its own, with nothing typed; while the filter narrows
/// the list, the rest of it no brighter than soft, and the words typed one step brighter than that.
public enum Tone: Sendable, Equatable {
    case text, soft, faint

    /// The words of the name that the filter does not light.
    public var rest: Tone {
        self == .text ? .soft : self
    }

    /// The words the filter lights.
    public var lit: Tone {
        rest == .faint ? .soft : .text
    }
}

extension Listed {
    /// The list narrowed to what the filter keeps: a project's sessions that match under it, its count still of all of
    /// them, and gone with none; the quiet projects whose names or sessions match; the sessions of the flat list that
    /// match.
    public func narrowed(by filter: Filter) -> Listed {
        guard !filter.isEmpty else {
            return self
        }

        var narrowed = self

        narrowed.projects = projects.compactMap { project in
            var project = project

            project.sessions = project.sessions.filter { filter.matches($0.name, $0.project) }
            return project.sessions.isEmpty ? nil : project
        }
        narrowed.quiet = quiet.filter { project in
            filter.matches(project.name) || project.sessions.contains { filter.matches($0, project.name) }
        }
        narrowed.flat = flat.filter { filter.matches($0.name, $0.project) }
        return narrowed
    }
}
