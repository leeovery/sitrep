import Foundation
import SitRepCore

/// A command Lee sets in Settings that SitRep types as the first line of a new window, into his own shell there: the
/// resume command (`ResumeCommand`). Its placeholders, those `Placeholder` names, are filled with the facts of the
/// session's window, each quoted for the shell.
///
/// It is read as the shell reads it, far enough to find its placeholders and where each stands: each `{name}`, a name
/// of letters and underscores, but none after an unescaped `$` or `#`, the shell's `${…}` and tmux's `#{…}`, nor one
/// escaped, nor, inside quotes, one whose name is no placeholder's, as awk's `'{print}'`. A placeholder is filled only
/// outside quotes and backticks: inside them its quoted value would end them early, letting the value out. Nor is one
/// filled in arithmetic, `$((…))`, `((…))`, `$[…]`, or a subscript, `a[…]`, `${a[…]}`, where the shell evaluates even
/// a quoted value, a `$(…)` in it run. Joined to unquoted text it is filled: `id={claude}` is `id='…'`, one shell word.
struct TypedCommand<Placeholder: CommandPlaceholder>: Equatable {
    /// Its words as written, between its placeholders, and where each placeholder stands.
    enum Piece: Equatable {
        case words(String)
        case placeholder(String, Standing)
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

    /// The placeholders it names.
    var wanted: Set<Placeholder> {
        Set(named.compactMap(Placeholder.init(rawValue:)))
    }

    /// What is wrong with it as written, whatever the session: none given; a character that can't be typed; a
    /// placeholder SitRep does not know; one in arithmetic or a subscript; or one inside quotes or backticks.
    var problem: CommandProblem<Placeholder>? {
        let unknown = named.filter { Placeholder(rawValue: $0) == nil }
        let evaluated = names { $0 == .evaluated }
        let quoted = names { $0 == .quoted }

        if pieces.isEmpty {
            return .empty
        }
        if let scalar = unprintable(in: pieces.map(\.written).joined()) {
            return .unprintable(scalar)
        }
        if !unknown.isEmpty {
            return .unknown(unknown)
        }
        if !evaluated.isEmpty {
            return .evaluated(evaluated)
        }
        return quoted.isEmpty ? nil : .quoted(quoted)
    }

    /// The line to type for a session, named as the board names it: its placeholders filled with the facts given,
    /// asked for only once the command is known fit to type and to name only facts there are. Throws `Unopenable`, in
    /// plain words, where the command or a fact is not fit to type, and the facts' own failure where what they asked
    /// gave no answer.
    func line(from facts: some CommandFacts<Placeholder>, named name: String) async throws -> String {
        if let problem {
            throw Unopenable(description: problem.refusal(named: name))
        }

        let missing = named.compactMap(Placeholder.init(rawValue:)).filter { !facts.given.contains($0) }

        guard missing.isEmpty else {
            throw Unopenable(description: facts.none(of: missing, named: name))
        }

        let values = try await facts.values(wanted: wanted)

        for placeholder in Placeholder.allCases where wanted.contains(placeholder) {
            if let scalar = values[placeholder].flatMap(unprintable(in:)) {
                throw Unopenable(description: "For \(name), \(facts.words(placeholder)) has \(scalar.untypable).")
            }
        }

        return filled(values)
    }

    /// The command, each placeholder replaced by its fact quoted for the shell; one with no fact left as written.
    func filled(_ facts: [Placeholder: String]) -> String {
        pieces.map { piece in
            if case let .placeholder(name, _) = piece, let fact = Placeholder(rawValue: name).flatMap({ facts[$0] }) {
                shellQuoted(fact)
            } else {
                piece.written
            }
        }.joined()
    }

    /// The names of the placeholders standing as wanted, in order, once.
    private func names(standing wanted: (Standing) -> Bool) -> [String] {
        var seen: Set<String> = []

        return pieces.compactMap { piece in
            guard case let .placeholder(name, standing) = piece, wanted(standing), seen.insert(name).inserted else {
                return nil
            }

            return name
        }
    }

    private static func pieces(of text: String) -> [Piece] {
        var pieces: [Piece] = []
        var words = ""
        var reading = ShellReading()
        var rest = Substring(text)

        while let character = rest.first {
            if reading.mayStartPlaceholder, character == "{", let (name, after) = placeholder(at: rest),
               let standing = reading.standing(isPlaceholder: Placeholder(rawValue: name) != nil)
            {
                pieces.append(.words(words))
                pieces.append(.placeholder(name, standing))
                words = ""
                rest = after
                reading.readPlaceholder()
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

extension TypedCommand.Piece {
    /// As it was written.
    var written: String {
        switch self {
        case let .words(words): words
        case let .placeholder(name, _): "{\(name)}"
        }
    }
}

/// Where a placeholder stands in a command: bare; inside quotes or backticks; or where the shell evaluates it, in
/// arithmetic or a subscript.
enum Standing: Equatable {
    case bare, quoted, evaluated
}

/// Where the shell is in a command it reads, a character at a time: inside which quotes, backticks, arithmetic,
/// subscripts or `${…}`, if any, as one may hold another; whether the next character is escaped; whether the one before
/// is an unescaped `$` that opens an expansion, `$'…'`, `${…}`, `$[…]` or `$((…))`, never the second of `$$`, the
/// shell's own process id, nor one escaped, `\$`, a `$` as written; whether it was an unescaped `#`, or `(`, and
/// whether it ended a name, as a subscript's `[` follows one.
private struct ShellReading {
    enum Context: Equatable {
        /// `'…'`, where nothing is escaped.
        case single
        /// `$'…'`, ANSI-C quoting, where a backslash escapes.
        case ansi
        /// `"…"`, where a backslash escapes.
        case double
        /// `` `…` ``, a command substitution, which the shell scans for its closing backtick before any quoting inside
        /// it, so a value quoted there could end it early; a backslash escapes.
        case backtick
        /// `$((…))` or `((…))`, open by as many parentheses as are unclosed.
        case arithmetic(open: Int)
        /// `$[…]`, or a subscript, `a[…]` or `${a[…]}`, which the shell evaluates as arithmetic, open by as many
        /// brackets as are unclosed.
        case subscripted(open: Int)
        /// `${…}`, open by as many braces as are unclosed.
        case expansion(open: Int)

        var isQuote: Bool {
            [.single, .ansi, .double, .backtick].contains(self)
        }

        var isEvaluated: Bool {
            switch self {
            case .arithmetic, .subscripted: true
            default: false
            }
        }

        var isExpansion: Bool {
            if case .expansion = self { true } else { false }
        }

        /// What it nests by, and how many are open; none for quotes.
        var nesting: (opens: Character, closes: Character, open: Int)? {
            switch self {
            case let .arithmetic(open): ("(", ")", open)
            case let .subscripted(open): ("[", "]", open)
            case let .expansion(open): ("{", "}", open)
            default: nil
            }
        }

        /// The same, open by as many as given.
        func opened(_ open: Int) -> Context {
            switch self {
            case .arithmetic: .arithmetic(open: open)
            case .subscripted: .subscripted(open: open)
            case .expansion: .expansion(open: open)
            default: self
            }
        }
    }

    /// The `(` read last: none, a plain one, or `$(`'s.
    private enum Paren {
        case none, plain, dollar
    }

    private var contexts: [Context] = []

    private var isEscaped = false
    private var isAfterDollar = false
    private var isAfterHash = false
    private var isAfterName = false
    private var paren = Paren.none

    /// Whether a `{` here may open a placeholder: not escaped, and not after an unescaped `$` or `#`.
    var mayStartPlaceholder: Bool {
        !isEscaped && !isAfterDollar && !isAfterHash
    }

    /// Where a name opening here, a placeholder's or not, stands; nil where it is no placeholder's and in quotes, a
    /// name in quotes that is no placeholder's being only words.
    func standing(isPlaceholder: Bool) -> Standing? {
        if contexts.contains(where: \.isEvaluated) {
            return .evaluated
        }
        guard contexts.contains(where: \.isQuote) else {
            return .bare
        }

        return isPlaceholder ? .quoted : nil
    }

    /// A placeholder read whole: what follows it follows no `$`, `#`, `(` or name.
    mutating func readPlaceholder() {
        forgetBefore()
    }

    private mutating func forgetBefore() {
        isAfterDollar = false
        isAfterHash = false
        isAfterName = false
        paren = .none
    }

    mutating func read(_ character: Character) {
        let wasAfterDollar = isAfterDollar, wasAfterName = isAfterName, wasParen = paren
        let isEscapedHere = isEscaped

        isEscaped = false
        forgetBefore()

        guard !isEscapedHere else {
            return
        }

        switch contexts.last {
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
            if character == "\"" {
                contexts.removeLast()
            } else if character == "`" {
                contexts.append(.backtick)
            } else {
                expand(character, afterDollar: wasAfterDollar, afterName: wasAfterName, paren: wasParen)
            }
        case nil, .arithmetic, .subscripted, .expansion:
            isEscaped = character == "\\"
            guard !closes(character) else {
                return
            }

            if let quote = Self.opening(character, afterDollar: wasAfterDollar) {
                contexts.append(quote)
            } else {
                expand(character, afterDollar: wasAfterDollar, afterName: wasAfterName, paren: wasParen)
            }
        }
    }

    /// A character outside quotes, or in double quotes: the expansions and evaluations it opens, and what it leaves the
    /// next to follow. `((` opens arithmetic only outside quotes, where it is a command.
    private mutating func expand(_ character: Character, afterDollar: Bool, afterName: Bool, paren: Paren) {
        isAfterDollar = character == "$" && !afterDollar
        isAfterHash = character == "#"
        isAfterName = character == "_" || (character.isASCII && (character.isLetter || character.isNumber))

        switch character {
        case "(" where paren == .dollar || (paren == .plain && contexts.last != .double):
            contexts.append(.arithmetic(open: 2))
        case "(":
            self.paren = afterDollar ? .dollar : .plain
        case "[" where afterDollar || afterName || contexts.last?.isExpansion == true:
            contexts.append(.subscripted(open: 1))
        case "{" where afterDollar:
            contexts.append(.expansion(open: 1))
        default:
            break
        }
    }

    /// Whether the character closes, or nests deeper in, the arithmetic, subscript or `${…}` it is in: true where it
    /// was only that.
    private mutating func closes(_ character: Character) -> Bool {
        guard let last = contexts.last, let nesting = last.nesting else {
            return false
        }

        let open = character == nesting.opens ? nesting.open + 1 : character == nesting.closes ? nesting.open - 1 : nil

        guard let open else {
            return false
        }

        contexts.removeLast()
        if open > 0 {
            contexts.append(last.opened(open))
        }
        return true
    }

    /// The quotes a character opens outside any: `$'`, `'`, `"` or a backtick.
    private static func opening(_ character: Character, afterDollar: Bool) -> Context? {
        switch character {
        case "'": afterDollar ? .ansi : .single
        case "\"": .double
        case "`": .backtick
        default: nil
        }
    }

    private mutating func close(at character: Character, _ closing: Character) {
        if character == closing {
            contexts.removeLast()
        }
    }
}

/// A placeholder of a command SitRep types, by its name, and the command, as Settings names it.
protocol CommandPlaceholder: RawRepresentable<String>, CaseIterable, Hashable, Sendable {
    /// The command, as Settings names it: `resume command`.
    static var command: String { get }
    /// Why no window opens, where none is given, for the session named.
    static func unset(named name: String) -> String
}

/// The facts a session's window gives a command's placeholders: those it has, why it has none for the rest, in plain
/// words, and what each is, in words; and their values, asked for once the command is known fit to type.
protocol CommandFacts<Placeholder> {
    associatedtype Placeholder: CommandPlaceholder

    var given: Set<Placeholder> { get }
    /// Why the command, naming these, opens no window for the session named.
    func none(of missing: [Placeholder], named name: String) -> String
    /// What a fact is, as a refusal of one that can't be typed names it: `the folder its Claude ran in`.
    func words(_ placeholder: Placeholder) -> String
    /// The facts wanted, each it has; throws, in plain words, where what it asked gave no answer.
    func values(wanted: Set<Placeholder>) async throws -> [Placeholder: String]
}

/// What is wrong with a command as written, whatever the session it opens a window for.
enum CommandProblem<Placeholder: CommandPlaceholder>: Equatable {
    /// None given.
    case empty
    /// A character no line typed into a shell may hold: a control, as ^U, which the terminal and the line editor act
    /// on before any quoting, or another that prints nothing.
    case unprintable(Unicode.Scalar)
    /// Placeholders SitRep does not know, by their names.
    case unknown([String])
    /// Placeholders inside quotes or backticks, by their names.
    case quoted([String])
    /// Placeholders in arithmetic or a subscript, by their names.
    case evaluated([String])

    /// Why no window opens, in plain words, for the session named.
    func refusal(named name: String) -> String {
        let command = "The \(Placeholder.command) in Settings"

        return switch self {
        case .empty:
            Placeholder.unset(named: name)
        case let .unprintable(scalar):
            "\(command) has \(scalar.untypable)."
        case let .unknown(names):
            "\(command) has \(braced(names)), which SitRep doesn't know. It knows "
                + "\(braced(Placeholder.allCases.map(\.rawValue)))."
        case let .quoted(names):
            "\(command) puts \(braced(names)) in quotes or backticks. Remove them: SitRep quotes each value itself."
        case let .evaluated(names):
            "\(command) puts \(braced(names)) in arithmetic or a subscript, where the shell runs what is in a value "
                + "even quoted. Move it out."
        }
    }
}

/// Placeholders by their names, as a refusal names them: `{claude} and {dir}`.
func braced(_ names: [String], _ conjunction: String = "and") -> String {
    inWords(names.map { "{\($0)}" }, conjunction)
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
/// opened again, never bare, as a bare word can be a zsh global alias, and a folder's name may hold a space or `'`.
func shellQuoted(_ value: String) -> String {
    "'" + value.replacing("'", with: #"'\''"#) + "'"
}

/// Why no window opens for a session, in plain words.
struct Unopenable: Error, Equatable, CustomStringConvertible {
    let description: String
}
