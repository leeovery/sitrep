import Foundation
import SitRepCore

/// A multiplexer, as its attach command is keyed in Settings.
public enum MultiplexerKind: String, Sendable, Hashable {
    case tmux, zmx

    /// The placeholders its attach command can name: a zmx session's name; a tmux server's socket, a pane's id and the
    /// name of the tmux session holding the pane.
    public var placeholders: [Placeholder] {
        switch self {
        case .zmx: [.session]
        case .tmux: [.socket, .pane, .session]
        }
    }

    /// Its placeholders in words, as Settings and a refusal list them: `{socket}, {pane} and {session}`.
    public var placeholdersInWords: String {
        inWords(placeholders.map(\.named))
    }
}

/// What an attach command's placeholder stands for, filled from where a window is.
public enum Placeholder: String, Sendable, Hashable, CaseIterable {
    case session, socket, pane

    /// As a command names it: `{session}`.
    public var named: String { "{\(rawValue)}" }
}

/// The commands that attach a new terminal window to a session no window shows, one for each multiplexer, as Lee sets
/// them in Settings: SitRep knows no Portal, only the command it is given. One left empty, or only spaces, is the
/// default, so a default changed later reaches a Mac that never set its own.
public struct AttachCommands: Sendable, Equatable {
    public static let zmxDefault = "zmx attach {session}"
    /// `{socket}` reaches a tmux server off its default socket; a pane's id is fixed for its life, Claude's, where a tmux
    /// session can be renamed.
    public static let tmuxDefault = "tmux -S {socket} attach -t {pane}"

    public var zmx: String
    public var tmux: String

    public init(zmx: String = "", tmux: String = "") {
        self.zmx = zmx
        self.tmux = tmux
    }

    /// The command for the multiplexer, as given, else its default.
    func command(for kind: MultiplexerKind) -> AttachCommand {
        let given = switch kind {
        case .zmx: zmx
        case .tmux: tmux
        }
        let trimmed = given.trimmingCharacters(in: .whitespacesAndNewlines)

        return AttachCommand(trimmed.isEmpty ? Self.default(for: kind) : trimmed)
    }

    public static func `default`(for kind: MultiplexerKind) -> String {
        switch kind {
        case .zmx: zmxDefault
        case .tmux: tmuxDefault
        }
    }
}

/// An attach command: its words, each `{name}` in them a placeholder.
struct AttachCommand: Equatable {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    /// `{` and a name of letters and underscores, then `}`: shell braces holding a comma or a space are no
    /// placeholder.
    private static var placeholder: Regex<(Substring, Substring)> {
        /\{([A-Za-z_]+)\}/
    }

    /// Each placeholder it names, in order, once, as written.
    var named: [String] {
        var seen: Set<String> = []

        return text.matches(of: Self.placeholder).map { String($0.output.1) }.filter { seen.insert($0).inserted }
    }

    /// The placeholders it names that SitRep fills.
    var wanted: Set<Placeholder> {
        Set(named.compactMap(Placeholder.init(rawValue:)))
    }

    /// The line that attaches to the window, filled with what the multiplexer it runs in gives for it: refused where
    /// the command names a placeholder the multiplexer cannot fill, a misspelt one or another multiplexer's, rather
    /// than typed as written, as `zmx attach` makes a session of a name it does not have.
    func line(attaching where: Board.Window.Where, in multiplexer: any Multiplexer) async throws -> String {
        let unknown = named.filter { name in !multiplexer.kind.placeholders.contains { $0.rawValue == name } }

        guard unknown.isEmpty else {
            throw Unattachable.unknown(unknown, in: multiplexer.kind)
        }

        return try await filled(multiplexer.attachValues(`where`, wanted: wanted))
    }

    /// The command, each placeholder replaced by its value quoted for the shell; one with no value left as written.
    func filled(_ values: [Placeholder: String]) -> String {
        text.replacing(Self.placeholder) { match in
            Placeholder(rawValue: String(match.output.1)).flatMap { values[$0] }.map(shellQuoted)
                ?? String(match.output.0)
        }
    }
}

/// A value as a POSIX shell, or zsh, reads it back whole: as it is where every character is one no shell treats
/// specially, so a tmux socket and pane read as typed; else in single quotes, each of its own closed, escaped and
/// opened again, as a zmx session's name holding a space or `·` needs. `=` is quoted, as zsh expands a word it starts.
func shellQuoted(_ value: String) -> String {
    let plain = !value.isEmpty && value.unicodeScalars.allSatisfy { scalar in
        scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "%+,-./:@_".unicodeScalars.contains(scalar))
    }

    return plain ? value : "'" + value.replacing("'", with: #"'\''"#) + "'"
}

/// Why a window could not be attached to, in plain words, finishing a sentence that says SitRep cannot open one.
struct Unattachable: Error, Equatable, CustomStringConvertible {
    let description: String

    /// A command naming placeholders its multiplexer does not give.
    static func unknown(_ names: [String], in kind: MultiplexerKind) -> Unattachable {
        let braced = names.map { "{\($0)}" }

        return Unattachable(description: "the \(kind.rawValue) attach command in Settings names \(inWords(braced)), "
            + "which SitRep cannot fill for \(kind.rawValue): it fills \(kind.placeholdersInWords)."
        )
    }
}
