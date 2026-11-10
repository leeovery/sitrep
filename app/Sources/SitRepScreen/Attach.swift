import Foundation
import SitRepCore

/// A multiplexer, as its attach command is keyed in Settings.
public enum MultiplexerKind: String, Sendable, Hashable, CaseIterable {
    case tmux, zmx

    /// The placeholders its attach command can name: a zmx session's name; a tmux server's socket, a pane's id and the
    /// name of the tmux session holding the pane.
    public var placeholders: [Placeholder] {
        switch self {
        case .zmx: [.session]
        case .tmux: [.socket, .pane, .session]
        }
    }

    /// Its placeholders in words, as Settings and a refusal list them: `{socket}, {pane} or {session}`.
    public var placeholdersInWords: String {
        inWords(placeholders.map(\.named), "or")
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

        return Self.command(given, for: kind)
    }

    public static func `default`(for kind: MultiplexerKind) -> String {
        switch kind {
        case .zmx: zmxDefault
        case .tmux: tmuxDefault
        }
    }

    /// What is wrong with a command as Lee types it, for Settings to say under its field as he types: nil for nothing,
    /// and for one left empty, which is SitRep's own.
    public static func warning(about given: String, for kind: MultiplexerKind) -> String? {
        command(given, for: kind).problem(for: kind)?.warning(for: kind)
    }

    private static func command(_ given: String, for kind: MultiplexerKind) -> AttachCommand {
        let trimmed = given.trimmingCharacters(in: .whitespacesAndNewlines)

        return AttachCommand(trimmed.isEmpty ? Self.default(for: kind) : trimmed)
    }
}

/// An attach command as the shell reads it, far enough to find its placeholders: each `{name}`, a name of letters and
/// underscores, but none after `$` or `#`, the shell's `${…}` and tmux's `#{…}`, nor one escaped; and whether each sits
/// inside quotes.
struct AttachCommand: Equatable {
    /// Its words as written, between its placeholders.
    enum Piece: Equatable {
        case words(String)
        case placeholder(String, isQuoted: Bool)
    }

    let pieces: [Piece]

    init(_ text: String) {
        pieces = Self.pieces(of: text)
    }

    /// Each placeholder it names, in order, once, as written.
    var named: [String] {
        var seen: Set<String> = []

        return pieces.compactMap { piece in
            if case let .placeholder(name, _) = piece, seen.insert(name).inserted { name } else { nil }
        }
    }

    /// The placeholders it names that SitRep fills.
    var wanted: Set<Placeholder> {
        Set(named.compactMap(Placeholder.init(rawValue:)))
    }

    /// What is wrong with it as written, for the multiplexer: a character that cannot be typed; a placeholder the
    /// multiplexer cannot fill, misspelt or another's, never typed as written, as `zmx attach` makes a session of a
    /// name it does not have; or one inside quotes, which would put the quotes SitRep adds inside its own.
    func problem(for kind: MultiplexerKind) -> CommandProblem? {
        let unknown = named.filter { name in !kind.placeholders.contains { $0.rawValue == name } }
        let quoted = pieces.compactMap { piece in
            if case let .placeholder(name, true) = piece { name } else { nil }
        }

        if let scalar = unprintable(in: pieces.map(\.written).joined()) {
            return .unprintable(scalar)
        }
        if !unknown.isEmpty {
            return .unknown(unknown)
        }
        return quoted.isEmpty ? nil : .quoted(quoted)
    }

    /// The line that attaches to the window, filled with what the multiplexer it runs in gives for it, each value it
    /// names printable, once the multiplexer confirms the session is there: refused, in plain words, where the command
    /// or a value is not fit to type, before the multiplexer is asked anything with a value that is not.
    func line(attaching where: Board.Window.Where, in multiplexer: any Multiplexer) async throws -> String {
        if let problem = problem(for: multiplexer.kind) {
            throw Unattachable(description: problem.refusal(for: multiplexer.kind))
        }

        let values = try await multiplexer.attachValues(`where`, wanted: wanted)
        let named = Placeholder.allCases.filter(wanted.contains)

        for placeholder in named {
            if let scalar = values[placeholder].flatMap(unprintable(in:)) {
                throw Unattachable(
                    description: "its \(placeholder.named) holds a character that cannot be typed safely (\(scalar.code))."
                )
            }
        }

        try await multiplexer.confirm(`where`)
        return filled(values)
    }

    /// The command, each placeholder replaced by its value quoted for the shell; one with no value left as written.
    func filled(_ values: [Placeholder: String]) -> String {
        pieces.map { piece in
            if case let .placeholder(name, _) = piece, let value = Placeholder(rawValue: name).flatMap({ values[$0] }) {
                shellQuoted(value)
            } else {
                piece.written
            }
        }.joined()
    }

    private static func pieces(of text: String) -> [Piece] {
        var pieces: [Piece] = []
        var words = ""
        var reading = ShellReading()
        var rest = Substring(text)

        while let character = rest.first {
            if reading.mayStartPlaceholder, character == "{", let (name, after) = placeholder(at: rest) {
                pieces.append(.words(words))
                pieces.append(.placeholder(name, isQuoted: reading.quote != nil))
                words = ""
                rest = after
                reading.read("}")
                continue
            }

            reading.read(character)
            words.append(character)
            rest = rest.dropFirst()
        }

        pieces.append(.words(words))
        return pieces.filter { $0 != .words("") }
    }

    /// `{name}` at the start of the text: its name, and what follows it.
    private static func placeholder(at text: Substring) -> (String, Substring)? {
        let name = text.dropFirst().prefix { $0 == "_" || ($0.isASCII && $0.isLetter) }
        let after = text.dropFirst(1 + name.count)

        guard !name.isEmpty, after.first == "}" else {
            return nil
        }

        return (String(name), after.dropFirst())
    }
}

extension AttachCommand.Piece {
    /// As it was written.
    var written: String {
        switch self {
        case let .words(words): words
        case let .placeholder(name, _): "{\(name)}"
        }
    }
}

/// Where the shell is in a command it reads, a character at a time: inside which quotes, if any; whether the next
/// character is escaped; and the character before.
private struct ShellReading {
    enum Quote {
        /// `'…'`, where nothing is escaped.
        case single
        /// `$'…'`, ANSI-C quoting, where a backslash escapes.
        case ansi
        /// `"…"`, where a backslash escapes.
        case double
    }

    private(set) var quote: Quote?
    private var isEscaped = false
    private var previous: Character?

    /// Whether a `{` here may open a placeholder: not escaped, and not after `$` or `#`.
    var mayStartPlaceholder: Bool {
        !isEscaped && previous != "$" && previous != "#"
    }

    mutating func read(_ character: Character) {
        defer { previous = character }

        if isEscaped {
            isEscaped = false
            return
        }

        switch quote {
        case .single:
            quote = character == "'" ? nil : .single
        case .ansi, .double:
            isEscaped = character == "\\"
            if character == (quote == .ansi ? "'" : "\"") {
                quote = nil
            }
        case nil:
            isEscaped = character == "\\"
            quote = character == "'" ? (previous == "$" ? .ansi : .single) : character == "\"" ? .double : nil
        }
    }
}

/// What is wrong with an attach command as written.
enum CommandProblem: Equatable {
    /// A character no line typed into a shell may hold: a control, as ^U, which the terminal and the line editor act
    /// on before any quoting, or another that prints nothing.
    case unprintable(Unicode.Scalar)
    /// Placeholders the multiplexer cannot fill, by their names.
    case unknown([String])
    /// Placeholders inside quotes, by their names.
    case quoted([String])

    /// What it is, finishing a sentence about the command.
    private func what(for kind: MultiplexerKind) -> String {
        switch self {
        case let .unprintable(scalar):
            "holds a character that cannot be typed safely (\(scalar.code))"
        case let .unknown(names):
            "names \(braced(names)), which SitRep cannot fill for \(kind.rawValue): use \(kind.placeholdersInWords)"
        case let .quoted(names):
            "puts \(braced(names)) in quotes: SitRep quotes each value itself"
        }
    }

    /// Under the command's field in Settings.
    func warning(for kind: MultiplexerKind) -> String {
        let what = what(for: kind)

        return what.prefix(1).uppercased() + what.dropFirst() + "."
    }

    /// Ending a refusal's sentence, at the click.
    func refusal(for kind: MultiplexerKind) -> String {
        "the \(kind.rawValue) attach command in Settings \(what(for: kind))."
    }

    private func braced(_ names: [String]) -> String {
        inWords(names.map { "{\($0)}" })
    }
}

/// The first character in the text that is not fit to type into a shell: a control (C0, DEL, C1), a format character,
/// a line or paragraph separator, or one unassigned; none for text that only prints.
func unprintable(in text: String) -> Unicode.Scalar? {
    text.unicodeScalars.first { scalar in
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .unassigned: true
        default: false
        }
    }
}

extension Unicode.Scalar {
    /// As Unicode names it: `U+0015`.
    var code: String {
        String(format: "U+%04X", value)
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
}

/// The multiplexer has no session of the window's name: one gone since the window last beat, which an attach would
/// make anew, empty.
struct SessionGone: Error {}
