import Foundation

/// What the CLI wrote to stderr, as a line fits a menu item or a banner: its
/// own, which it prints as `sitrep: <words>`, its prefix dropped; else any
/// line with anything on it, such as the head of a Bun stack trace.
struct Said {
    private static let prefix = "sitrep: "

    private let own: [String]
    private let any: [String]

    init(_ stderr: String) {
        any = stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        own = any.compactMap { $0.hasPrefix(Self.prefix) ? String($0.dropFirst(Self.prefix.count)) : nil }
    }

    /// What a run that ended at once said: the first line of its own, else the first of any.
    var first: String? { own.first ?? any.first }

    /// What a run that lived a while said as it ended: the last line of its own, else the last of any.
    var last: String? { own.last ?? any.last }
}
