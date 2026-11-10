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

    /// Its placeholders, as Settings lists them: `{socket}, {pane}, {session}`.
    public var placeholderList: String {
        placeholders.map(\.named).joined(separator: ", ")
    }
}

/// What an attach command's placeholder stands for, filled from where a window is.
public enum Placeholder: String, Sendable, Hashable, CaseIterable {
    case session, socket, pane

    /// As a command names it: `{session}`.
    public var named: String { "{\(rawValue)}" }

    /// What its value is, as a refusal names it: `the zmx session's name`.
    func value(in kind: MultiplexerKind) -> String {
        switch self {
        case .session: "the \(kind.rawValue) session's name"
        case .socket: "the \(kind.rawValue) socket's path"
        case .pane: "the \(kind.rawValue) pane's id"
        }
    }
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
        command(given, for: kind).problem(for: kind)?.warning
    }

    private static func command(_ given: String, for kind: MultiplexerKind) -> AttachCommand {
        let trimmed = given.trimmingCharacters(in: .whitespacesAndNewlines)

        return AttachCommand(trimmed.isEmpty ? Self.default(for: kind) : trimmed)
    }
}

/// An attach command as the shell reads it, far enough to find its placeholders and where each stands: each `{name}`,
/// a name of letters and underscores, but none after an unescaped `$` or `#`, the shell's `${…}` and tmux's `#{…}`, nor
/// one escaped, nor, inside quotes, one whose name is no placeholder's, as awk's `'{print}'`. A placeholder is filled
/// only where it stands as a word of its own, outside quotes: anywhere else the quotes SitRep puts round its value
/// would read otherwise than meant, or let the value out of them.
struct AttachCommand: Equatable {
    /// Its words as written, between its placeholders.
    enum Piece: Equatable {
        case words(String)
        case placeholder(String, Standing)
    }

    /// Where a placeholder stands: a word of its own, outside quotes; inside quotes; or joined to other words.
    enum Standing: Equatable {
        case word
        case quoted
        case joined
    }

    let pieces: [Piece]

    init(_ text: String) {
        pieces = Self.pieces(of: text)
    }

    /// Each placeholder it names, in order, once, as written.
    var named: [String] {
        names { _ in true }
    }

    /// The placeholders it names that SitRep fills.
    var wanted: Set<Placeholder> {
        Set(named.compactMap(Placeholder.init(rawValue:)))
    }

    /// What is wrong with it as written, for the multiplexer: a character that can't be typed; a placeholder the
    /// multiplexer cannot fill, misspelt or another's, never typed as written, as `zmx attach` makes a session of a
    /// name it does not have; or one not standing as a word of its own, outside quotes.
    func problem(for kind: MultiplexerKind) -> CommandProblem? {
        let unknown = named.filter { name in !kind.placeholders.contains { $0.rawValue == name } }
        let quoted = names { $0 == .quoted }
        let joined = names { $0 == .joined }

        if let scalar = unprintable(in: pieces.map(\.written).joined()) {
            return .unprintable(scalar)
        }
        if !unknown.isEmpty {
            return .unknown(unknown)
        }
        if !quoted.isEmpty {
            return .quoted(quoted)
        }
        return joined.isEmpty ? nil : .joined(joined)
    }

    /// The line that attaches to the window, filled with what the multiplexer it runs in gives for it, each value it
    /// names printable, once the multiplexer confirms the session is there: refused, in plain words, where the command
    /// or a value is not fit to type, before the multiplexer is asked anything with a value that is not.
    func line(attaching where: Board.Window.Where, in multiplexer: any Multiplexer) async throws -> String {
        let kind = multiplexer.kind

        if let problem = problem(for: kind) {
            throw Unattachable(description: problem.refusal(for: kind))
        }

        let values = try await multiplexer.attachValues(`where`, wanted: wanted)

        for placeholder in Placeholder.allCases.filter(wanted.contains) {
            if let scalar = values[placeholder].flatMap(unprintable(in:)) {
                throw Unattachable(
                    description: "\(placeholder.value(in: kind)) contains a character that can't be typed (\(scalar.code))."
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

    /// The names of the placeholders standing as given, in order, once.
    private func names(standing: (Standing) -> Bool) -> [String] {
        var seen: Set<String> = []

        return pieces.compactMap { piece in
            if case let .placeholder(name, stands) = piece, standing(stands), seen.insert(name).inserted { name } else { nil }
        }
    }

    private static func pieces(of text: String) -> [Piece] {
        var pieces: [Piece] = []
        var words = ""
        var reading = ShellReading()
        var rest = Substring(text)

        while let character = rest.first {
            if reading.mayStartPlaceholder, character == "{", let (name, after) = placeholder(at: rest),
               let standing = reading.standing(of: name, before: after.first)
            {
                pieces.append(.words(words))
                pieces.append(.placeholder(name, standing))
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
/// character is escaped; whether the one before is an unescaped `$` that opens an expansion, `$'…'` or `${…}`, never
/// the second of `$$`, the shell's own process id; whether it was an unescaped `#`; and whether a word starts here.
private struct ShellReading {
    enum Quote {
        /// `'…'`, where nothing is escaped.
        case single
        /// `$'…'`, ANSI-C quoting, where a backslash escapes.
        case ansi
        /// `"…"`, where a backslash escapes.
        case double
    }

    private var quote: Quote?
    private var isEscaped = false
    private var isAfterDollar = false
    private var isAfterHash = false
    private var isAtWordStart = true

    /// Whether a `{` here may open a placeholder: not escaped, and not after an unescaped `$` or `#`.
    var mayStartPlaceholder: Bool {
        !isEscaped && !isAfterDollar && !isAfterHash
    }

    /// Where a placeholder of the name, opening here and followed by the character given, stands; nil where it is
    /// none, a name in quotes that is no placeholder's being only words.
    func standing(of name: String, before next: Character?) -> AttachCommand.Standing? {
        guard quote == nil else {
            return Placeholder(rawValue: name) == nil ? nil : .quoted
        }

        return isAtWordStart && (next == nil || next == " " || next == "\t") ? .word : .joined
    }

    mutating func read(_ character: Character) {
        let wasAfterDollar = isAfterDollar
        let isEscapedHere = isEscaped

        isEscaped = false
        isAfterDollar = false
        isAfterHash = false
        isAtWordStart = false

        guard !isEscapedHere else {
            return
        }

        switch quote {
        case .single:
            quote = character == "'" ? nil : .single
        case .ansi:
            isEscaped = character == "\\"
            quote = character == "'" ? nil : .ansi
        case .double:
            isEscaped = character == "\\"
            isAfterDollar = character == "$" && !wasAfterDollar
            isAfterHash = character == "#"
            quote = character == "\"" ? nil : .double
        case nil:
            isEscaped = character == "\\"
            isAfterDollar = character == "$" && !wasAfterDollar
            isAfterHash = character == "#"
            isAtWordStart = character == " " || character == "\t"
            quote = character == "'" ? (wasAfterDollar ? .ansi : .single) : character == "\"" ? .double : nil
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
    /// Placeholders joined to other words, by their names.
    case joined([String])

    /// Under the command's field in Settings, as Lee types.
    var warning: String {
        switch self {
        case let .unprintable(scalar):
            "Contains a character that can't be typed (\(scalar.code))."
        case let .unknown(names):
            "Unknown \(Self.placeholders(names))."
        case let .quoted(names):
            "Remove the quotes around \(Self.braced(names)). Values are quoted automatically."
        case let .joined(names):
            "Put a space before and after \(Self.braced(names))."
        }
    }

    /// Ending a refusal's sentence, at the click.
    func refusal(for kind: MultiplexerKind) -> String {
        let command = "the \(kind.rawValue) command in Settings"

        return switch self {
        case let .unprintable(scalar):
            "\(command) contains a character that can't be typed (\(scalar.code))."
        case let .unknown(names):
            "\(command) has an unknown \(Self.placeholders(names, listed: ", "))."
        case let .quoted(names):
            "\(command) puts \(Self.braced(names)) in quotes, and values are quoted automatically."
        case let .joined(names):
            "\(command) joins \(Self.braced(names)) to other text, and a placeholder needs a space before and after it."
        }
    }

    /// `placeholder {a}`, or `placeholders {a} and {b}`, set off as given.
    private static func placeholders(_ names: [String], listed: String = " ") -> String {
        (names.count == 1 ? "placeholder" : "placeholders") + listed + braced(names)
    }

    private static func braced(_ names: [String]) -> String {
        inWords(names.map { "{\($0)}" })
    }
}

/// The first character in the text that is not fit to type into a shell: a control (C0, DEL, C1), a format character,
/// a line or paragraph separator, or one unassigned; none for text that only prints. A Swift string holds no lone
/// surrogate, so none is looked for.
func unprintable(in text: String) -> Unicode.Scalar? {
    text.unicodeScalars.first { scalar in
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator, .unassigned: true
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
