import Foundation

/// What the CLI wrote to stderr as it ended, in a line, as fits a menu item
/// or a banner: what ended it. That is the last line that says anything,
/// its `sitrep: ` dropped where it is the CLI's own: the CLI's own line when
/// it ended on its own error, else the error's own line when it crashed
/// (`error: Cannot find module …`, `TypeError: …`), even after a line of
/// its own. Never Bun's version trailer, a stack frame, the source Bun
/// quotes above an error, or a blank line.
struct Said {
    private static let prefix = "sitrep: "

    let reason: String?

    init(_ stderr: String) {
        reason = stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !Self.isNoise($0) }
            .map { $0.hasPrefix(Self.prefix) ? String($0.dropFirst(Self.prefix.count)) : $0 }
    }

    /// `Bun v1.4.2 (macOS arm64)`, `at f (/path:2:13)`, `2 |   throw …`, `^`.
    private static func isNoise(_ line: String) -> Bool {
        line.isEmpty
            || line.hasPrefix("at ")
            || line.contains(/^Bun v\d/)
            || line.contains(/^\d+ \|/)
            || line.allSatisfy { $0 == "^" }
    }
}
