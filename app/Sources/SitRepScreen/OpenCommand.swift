import Foundation
import SitRepCore

/// The open command, as Lee sets it in Settings: what a window opened for a session no window shows runs, typed into
/// his own shell there. SitRep has no built-in way to attach, so none given, nothing opens. Its placeholders,
/// `{session}`, `{socket}` and `{pane}`, are filled with the facts of the session's live window, each quoted for the
/// shell.
///
/// It is read as the shell reads it, far enough to find its placeholders and where each stands: each `{name}`, a name
/// of letters and underscores, but none after an unescaped `$` or `#`, the shell's `${…}` and tmux's `#{…}`, nor one
/// escaped, nor, inside quotes, one whose name is no placeholder's, as awk's `'{print}'`. A placeholder is filled only
/// where it stands as a word of its own, outside quotes and backticks: anywhere else the quotes SitRep puts round its
/// value would read otherwise than meant, or let the value out of them.
struct OpenCommand: Equatable {
    /// Its words as written, between its placeholders.
    enum Piece: Equatable {
        case words(String)
        case placeholder(String, Standing)
    }

    /// Where a placeholder stands: a word of its own, outside quotes; inside quotes or backticks; or joined to other
    /// words.
    enum Standing: Equatable {
        case word
        case quoted
        case joined
    }

    let pieces: [Piece]

    /// The command as given, less the spaces around it.
    init(_ text: String) {
        pieces = Self.pieces(of: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Each placeholder it names, in order, once, as written.
    var named: [String] {
        names { _ in true }
    }

    /// The facts it names.
    var wanted: Set<Fact> {
        Set(named.compactMap(Fact.init(rawValue:)))
    }

    /// What is wrong with it as written, whatever the session: none given; a character that can't be typed; a
    /// placeholder SitRep does not know; or one not standing as a word of its own, outside quotes.
    var problem: CommandProblem? {
        let unknown = named.filter { Fact(rawValue: $0) == nil }
        let quoted = names { $0 == .quoted }
        let joined = names { $0 == .joined }

        if pieces.isEmpty {
            return .empty
        }
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

    /// The line to type for a window in the multiplexer, named as the board names its session: its placeholders
    /// filled with the facts the multiplexer gives, asked of it only once the command is known fit to type and to name
    /// only facts it has. Throws `Unopenable`, in plain words, where the command or a fact is not fit to type, and the
    /// multiplexer's own failure where what it was asked gave no answer.
    func line(for where: Board.Window.Where, in multiplexer: any Multiplexer, named name: String) async throws
        -> String
    {
        let kind = multiplexer.kind

        if let problem {
            throw Unopenable(description: problem.refusal(named: name))
        }

        let missing = named.filter { !kind.facts.map(\.rawValue).contains($0) }

        guard missing.isEmpty else {
            throw Unopenable(description: CommandProblem.noFact(missing, kind).refusal(named: name))
        }

        let facts = try await multiplexer.facts(of: `where`, wanted: wanted)

        for fact in Fact.allCases where wanted.contains(fact) {
            if let scalar = facts[fact].flatMap(unprintable(in:)) {
                throw Unopenable(description: "For \(name), \(fact.words(in: kind)) has \(scalar.untypable).")
            }
        }

        return filled(facts)
    }

    /// The command, each placeholder replaced by its fact quoted for the shell; one with no fact left as written.
    func filled(_ facts: [Fact: String]) -> String {
        pieces.map { piece in
            if case let .placeholder(name, _) = piece, let fact = Fact(rawValue: name).flatMap({ facts[$0] }) {
                shellQuoted(fact)
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

extension OpenCommand.Piece {
    /// As it was written.
    var written: String {
        switch self {
        case let .words(words): words
        case let .placeholder(name, _): "{\(name)}"
        }
    }
}

/// Where the shell is in a command it reads, a character at a time: inside which quotes, or backticks, if any, as one
/// may hold another, backticks in double quotes; whether the next character is escaped; whether the one before is an
/// unescaped `$` that opens an expansion, `$'…'` or `${…}`, never the second of `$$`, the shell's own process id, nor one
/// escaped, `\$`, a `$` as written; whether it was an unescaped `#`; and whether a word starts here.
private struct ShellReading {
    enum Quote {
        /// `'…'`, where nothing is escaped.
        case single
        /// `$'…'`, ANSI-C quoting, where a backslash escapes.
        case ansi
        /// `"…"`, where a backslash escapes.
        case double
        /// `` `…` ``, a command substitution, which the shell scans for its closing backtick before any quoting inside
        /// it, so a value quoted there could end it early; a backslash escapes.
        case backtick
    }

    private var quotes: [Quote] = []

    private var isEscaped = false
    private var isAfterDollar = false
    private var isAfterHash = false
    private var isAtWordStart = true

    private var quote: Quote? {
        quotes.last
    }

    /// Whether a `{` here may open a placeholder: not escaped, and not after an unescaped `$` or `#`.
    var mayStartPlaceholder: Bool {
        !isEscaped && !isAfterDollar && !isAfterHash
    }

    /// Where a placeholder of the name, opening here and followed by the character given, stands; nil where it is
    /// none, a name in quotes that is no placeholder's being only words.
    func standing(of name: String, before next: Character?) -> OpenCommand.Standing? {
        guard quote == nil else {
            return Fact(rawValue: name) == nil ? nil : .quoted
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
            close(at: character, "'")
        case .ansi:
            isEscaped = character == "\\"
            close(at: character, "'")
        case .backtick:
            isEscaped = character == "\\"
            close(at: character, "`")
        case .double:
            isEscaped = character == "\\"
            isAfterDollar = character == "$" && !wasAfterDollar
            isAfterHash = character == "#"
            close(at: character, "\"")
            open(character == "`" ? .backtick : nil)
        case nil:
            isEscaped = character == "\\"
            isAfterDollar = character == "$" && !wasAfterDollar
            isAfterHash = character == "#"
            isAtWordStart = character == " " || character == "\t"
            open(Self.opening(character, afterDollar: wasAfterDollar))
        }
    }

    /// The quotes a character opens outside any: `$'`, `'`, `"` or a backtick.
    private static func opening(_ character: Character, afterDollar: Bool) -> Quote? {
        switch character {
        case "'": afterDollar ? .ansi : .single
        case "\"": .double
        case "`": .backtick
        default: nil
        }
    }

    private mutating func open(_ opened: Quote?) {
        if let opened {
            quotes.append(opened)
        }
    }

    private mutating func close(at character: Character, _ closing: Character) {
        if character == closing {
            quotes.removeLast()
        }
    }
}

/// What is wrong with the open command, as written or for the session it opens a window for.
enum CommandProblem: Equatable {
    /// None given.
    case empty
    /// A character no line typed into a shell may hold: a control, as ^U, which the terminal and the line editor act
    /// on before any quoting, or another that prints nothing.
    case unprintable(Unicode.Scalar)
    /// Placeholders SitRep does not know, by their names.
    case unknown([String])
    /// Placeholders inside quotes or backticks, by their names.
    case quoted([String])
    /// Placeholders joined to other words, by their names.
    case joined([String])
    /// Placeholders the session's multiplexer has no fact for, by their names.
    case noFact([String], MultiplexerKind)

    /// Why no window opens, in plain words, for the session named.
    func refusal(named name: String) -> String {
        let command = "The open command in Settings"

        return switch self {
        case .empty:
            "No terminal window shows \(name). To open one for it, set an open command in Settings."
        case let .unprintable(scalar):
            "\(command) has \(scalar.untypable)."
        case let .unknown(names):
            "\(command) has \(Self.braced(names)), which SitRep doesn't know. It knows {session}, {socket} and {pane}."
        case let .quoted(names):
            "\(command) puts \(Self.braced(names)) in quotes or backticks. Remove them: SitRep quotes each value "
                + "itself."
        case let .joined(names):
            "\(command) joins \(Self.braced(names)) to other text. Put a space before and after each placeholder."
        case let .noFact(names, kind):
            "\(name) runs in \(kind.rawValue), which gives no \(Self.braced(names, "or")). A \(kind.rawValue) session "
                + "gives \(Self.braced(kind.facts.map(\.rawValue)))."
        }
    }

    private static func braced(_ names: [String], _ conjunction: String = "and") -> String {
        inWords(names.map { "{\($0)}" }, conjunction)
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
    /// As a refusal names it, one that can't be typed: the common ones by name, `a tab`; the rest by their code point,
    /// `a character that can't be typed (U+0015)`.
    var untypable: String {
        switch value {
        case 0x09: "a tab, which can't be typed"
        case 0x0A, 0x0D, 0x85, 0x2028, 0x2029: "a line break, which can't be typed"
        case 0x1B: "an escape, which can't be typed"
        default: "a character that can't be typed (\(String(format: "U+%04X", value)))"
        }
    }
}

/// A value as a POSIX shell, or zsh, reads it back whole: always in single quotes, each of its own closed, escaped and
/// opened again, never bare, as a bare word can be a zsh global alias, and a zmx session's name holds a space or `·`.
func shellQuoted(_ value: String) -> String {
    "'" + value.replacing("'", with: #"'\''"#) + "'"
}

/// Why no window opens for a session, in plain words.
struct Unopenable: Error, Equatable, CustomStringConvertible {
    let description: String
}
