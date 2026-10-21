import Foundation

/// What Lee types in the sidebar's Filter field, which narrows the view chosen in place: a session stays while every
/// word typed appears, anywhere, in its name or its project's, whatever their case and accents, so typing a project's
/// name lists its sessions. A quiet project stays while its name holds every word.
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
        words.allSatisfy { word in names.contains { $0.range(of: word, options: Self.loosely) != nil } }
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

    private static func ranges(of word: String, in name: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var rest = name.startIndex ..< name.endIndex

        while let range = name.range(of: word, options: loosely, range: rest) {
            found.append(range)
            rest = range.upperBound ..< name.endIndex
        }
        return found
    }

    private static let loosely: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
}

extension Listed {
    /// The list narrowed to what the filter keeps: a project's sessions that match under it, its count still of all of
    /// them, and gone with none; the quiet projects whose names match; the sessions of the flat list that match.
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
        narrowed.quiet = quiet.filter { filter.matches($0.name) }
        narrowed.flat = flat.filter { filter.matches($0.name, $0.project) }
        return narrowed
    }
}
