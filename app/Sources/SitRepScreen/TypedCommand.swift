import Foundation
import SitRepCore

/// A command Lee sets in Settings that SitRep types as the first line of a new window, into his own shell there: the
/// resume command (`ResumeCommand`). Its placeholders, those `Placeholder` names, are filled with the facts of the
/// session's window, each quoted for the shell.
///
/// It is held to plain shell syntax, which sh, bash, zsh, dash and ksh all read alike, and anything else is refused, in
/// words pointing to a script (Lee, 20 November 2026): a reader refusing each place a shell reads a value again could
/// never be finished, as three reviews each found more. Plain syntax is:
/// - words of ASCII letters, digits and `_ . / : @ % + , = -`; a `~` starting one, or right after its first `=` or a
///   `:` past that, as in `PATH=~/bin:~/go/bin`, though never right before a placeholder, as zsh and ksh read `~'…'`
///   as a user's home; `\` and the character after it;
/// - spaces and tabs between them; `|`, `||`, `&&` and `;`;
/// - redirections, `<`, `>` and `>>`, each to a word, and `>&` or `<&` to a single digit, which nothing may join, as
///   `2>&1`;
/// - `[` and `]` as words of their own, as `[ -n "$s" ]`;
/// - `'…'`, holding anything;
/// - `"…"`, holding what prints but a backtick and `!`, and `\` only before `"` or `$`;
/// - a parameter, in double quotes or out: `$name`, `${name}`, `$?`, `$$`, or `$1` to `$9`, one outside braces only
///   where every shell ends it: at a blank, an operator, a redirection, a `)`, a double quote, one of
///   `/ - = , + @ % \ $`, or the command's end, and in double quotes at a `'` too;
/// - `$(…)`, outside quotes, holding plain syntax, however deep.
///
/// `$!` is none: an interactive bash or zsh, as SitRep types into, reads a `!` after it as history, and `&` alone,
/// which gives `$!` its meaning, is refused. Nor is `$#`, always 0 here: zsh reads its `#` as asking the length of what
/// follows, so in `$#$(…)` zsh reads the length of `$$` and a glob qualifier where the others read a `$(…)`.
///
/// A placeholder is filled outside every quote, at the top level or in a `$(…)`, joined to a word or not:
/// `id={claude}` is `id='…'`, one word. Inside quotes it is refused, as its quoted value would end them early. Another
/// name in braces outside quotes is refused as one SitRep doesn't know; inside quotes it is text, as awk's `'{print}'`.
///
/// What takes code, a name or a number from its argument passes as words, and a command Lee writes that passes a
/// placeholder to one takes that risk: a builtin such as `eval`, `trap`, `let`, `read`, `declare`, `typeset`, `local`,
/// `export`, `printf -v`, `test`'s numeric comparisons, `shift`, `exit`, `return` or `ulimit`; an assignment to a
/// variable the shell evaluates, as `PS1`, `PS4`, `PROMPT_COMMAND`, `ENV` and `BASH_ENV`, or an integer one such as
/// `RANDOM`, `SECONDS` or `OPTIND`; or a program running an argument as code, as `sh -c`.
///
/// With zsh's GLOB_SUBST set, an unquoted parameter or `$(…)` holding a value can run code, as `x={dir}; echo $x`
/// does: a command for such a shell puts them in double quotes. SitRep types the line into an interactive shell, which
/// reads `.zshrc`; the panel's login shell, `-l -c`, reads none.
///
/// A value starting with a dash is refused, as a program would read it as an option.
///
/// The panel's reader (`cli/panel/command.ts`) is the same machine, branch for branch.
struct TypedCommand<Placeholder: CommandPlaceholder>: Equatable {
    /// Its words as written, between its placeholders, and where each placeholder stands.
    enum Piece: Equatable {
        case words(String)
        case placeholder(String, Standing)
    }

    /// The command as given, less the spaces around it.
    let text: String
    /// Its pieces, as far as its reading went.
    let pieces: [Piece]
    /// Where its reading stopped, at a part SitRep can't check or at its end with a part left open; none where it read
    /// to its end.
    private let stop: CommandProblem<Placeholder>?

    /// The command as given, less the spaces around it, read a scalar at a time: a quote with a combining mark after it
    /// is one character to Swift, but still a quote to the shell, which reads bytes.
    init(_ text: String) {
        var reading = Reading(text.trimmingCharacters(in: .whitespacesAndNewlines))

        self.text = reading.text
        (pieces, stop) = reading.read()
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
    /// placeholder SitRep does not know; one inside quotes; or a part that is not plain shell syntax, or one left open.
    var problem: CommandProblem<Placeholder>? {
        let unknown = named.filter { Placeholder(rawValue: $0) == nil }
        let quoted = names { $0 == .quoted }

        if text.isEmpty {
            return .empty
        }
        if let scalar = unprintable(in: text) {
            return .unprintable(scalar)
        }
        if !unknown.isEmpty {
            return .unknown(unknown)
        }
        return quoted.isEmpty ? stop : .quoted(quoted)
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

        if let problem = valueProblem(in: values, words: facts.words, named: name) {
            throw Unopenable(description: problem)
        }

        return filled(values)
    }

    /// What is wrong with the values it names, in plain words: one holding a character that can't be typed; or one
    /// starting with a dash, which a program would read as an option, as `claude --resume {claude}` would read an id of
    /// `--settings=…`. Each the first by the placeholders' order.
    private func valueProblem(
        in values: [Placeholder: String], words: (Placeholder) -> String, named name: String
    ) -> String? {
        let named = Placeholder.allCases.filter(wanted.contains).map { ($0, values[$0] ?? "") }

        for (placeholder, value) in named {
            if let scalar = unprintable(in: value) {
                return "For \(name), \(words(placeholder)) has \(scalar.untypable)."
            }
        }

        return named.first { $0.1.hasPrefix("-") }.map { placeholder, _ in
            "For \(name), \(words(placeholder)) starts with a dash, which a program would read as an option."
        }
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

/// Where a placeholder stands in a command: outside every quote, or inside quotes.
enum Standing: Equatable {
    case bare, quoted
}

extension TypedCommand {
    /// Where a reading stands outside quotes: at a word's start; inside a word; after a redirection, its word to come;
    /// or after one to a descriptor, `2>&1`, which nothing may join.
    private enum Spot {
        case start, word, target, apart
    }

    /// The command read by plain shell syntax a scalar at a time, as far as it holds to it: inside which quotes, if any;
    /// how many `$(…)` deep; where outside quotes; where the word's first `=` stands, and each outer word's while in a
    /// `$(…)`; and the redirection read last, as a refusal of what follows it names it.
    private struct Reading {
        let text: String
        private let scalars: [Unicode.Scalar]
        private var pieces: [Piece] = []
        private var words = String.UnicodeScalarView()
        private var at = 0
        private var depth = 0
        private var spot = Spot.start
        private var quote: Unicode.Scalar?
        private var equalsAt: Int?
        private var outerEquals: [Int?] = []
        private var redirection = ""
        private var stop: CommandProblem<Placeholder>?

        init(_ text: String) {
            self.text = text
            scalars = Array(text.unicodeScalars)
        }

        /// Its pieces, as far as the reading went, and where it stopped, if it did.
        mutating func read() -> ([Piece], CommandProblem<Placeholder>?) {
            while at < scalars.count, stop == nil {
                let scalar = scalars[at]

                switch quote {
                case "'": inSingle(scalar)
                case "\"": inDouble(scalar)
                default: inCommand(scalar)
                }
            }

            pieces.append(.words(String(words)))
            return (pieces.filter { $0 != .words("") }, stop ?? stopAtEnd)
        }

        /// The scalar `offset` on from where the reading is, as written; empty past the end.
        private func ahead(_ offset: Int) -> String {
            scalars.at(at + offset).map { "\($0)" } ?? ""
        }

        private mutating func take(_ count: Int) {
            words.append(contentsOf: scalars[at ..< min(at + count, scalars.count)])
            at += count
        }

        /// Into a word: a new one, its `=` yet to come, where the reading stood outside one.
        private mutating func inWord() {
            if spot != .word {
                equalsAt = nil
                spot = .word
            }
        }

        private mutating func word(_ count: Int) {
            inWord()
            take(count)
        }

        /// A plain scalar, the word's first `=` kept, as a `~` may follow it.
        private mutating func plain(_ scalar: Unicode.Scalar) {
            word(1)

            if scalar == "=", equalsAt == nil {
                equalsAt = at - 1
            }
        }

        private mutating func operate(_ count: Int) {
            take(count)
            spot = .start
        }

        private mutating func refuse(_ part: String) {
            stop = .unchecked(part)
        }

        private mutating func placeholder(_ name: String, _ standing: Standing, end: Int) {
            pieces.append(.words(String(words)))
            pieces.append(.placeholder(name, standing))
            words = String.UnicodeScalarView()
            at = end
        }

        /// A `{` outside quotes: a placeholder, known or not, joined to the word it is in; or a brace of the shell's,
        /// refused.
        private mutating func brace() {
            guard let (name, end) = placeholderAt(scalars, at) else {
                return refuse("{")
            }

            inWord()
            placeholder(name, .bare, end: end)
        }

        /// A `~` outside quotes: starting a word, or right after its first `=` or a `:` past that; never right before a
        /// placeholder, which zsh and ksh read through its quotes as a user's name.
        private mutating func tilde() {
            let isAssigned = spot == .word && equalsAt.map { $0 == at - 1 || ahead(-1) == ":" } == true
            let found = ahead(1) == "{" ? placeholderAt(scalars, at + 1) : nil

            if spot != .start, spot != .target, !isAssigned {
                return refuse("~")
            }

            if let (name, _) = found { refuse("~{\(name)}") } else { word(1) }
        }

        /// A `{` in quotes: a placeholder, refused as quoted; any other name, text.
        private mutating func quotedBrace() {
            if let (name, end) = placeholderAt(scalars, at), Placeholder(rawValue: name) != nil {
                placeholder(name, .quoted, end: end)
            } else {
                take(1)
            }
        }

        /// A `$`: a parameter; outside quotes, a `$(…)` opening; nothing else.
        private mutating func dollar() {
            guard ahead(1) == "(" else {
                if let length = parameterLength(scalars, at, isQuoted: quote == "\"") {
                    return word(length)
                }
                return refuse(dollarPart(scalars, at))
            }
            if ahead(2) == "(" || quote == "\"" {
                return refuse(ahead(2) == "(" ? "$((" : "$(")
            }

            inWord()
            outerEquals.append(equalsAt)
            take(2)
            depth += 1
            spot = .start
        }

        /// A `)` closing a `$(…)`, which leaves the word it is in open.
        private mutating func close() {
            take(1)
            depth -= 1
            equalsAt = outerEquals.popLast() ?? nil
            spot = .word
        }

        /// `<`, `>` or `>>`, its word to come; or `>&` or `<&` and a digit; never `<<`, `<(` nor `>(`.
        private mutating func redirect(_ scalar: Unicode.Scalar) {
            let next = ahead(1)

            if next == "(" || (scalar == "<" && next == "<") {
                return refuse("\(scalar)\(next)")
            }
            if next == "&" {
                redirection = "\(scalar)&\(ahead(2))"

                guard scalars.at(at + 2)?.isDigit == true else {
                    return refuse(scalars.at(at + 2)?.isBlank == true ? "\(scalar)&" : redirection)
                }

                take(3)
                spot = .apart
                return
            }

            redirection = scalar == ">" && next == ">" ? ">>" : "\(scalar)"
            take(redirection.unicodeScalars.count)
            spot = .target
        }

        /// A scalar outside quotes, as plain syntax reads it where the reading stands.
        private mutating func inCommand(_ scalar: Unicode.Scalar) {
            if scalar.isBlank {
                spot = spot == .target ? .target : .start
                return take(1)
            }
            if (spot == .target && !scalar.isWordPart && !scalar.startsWord) || (spot == .apart && !scalar.isBreak) {
                return refuse(redirection + "\(scalar)")
            }

            switch scalar {
            case "{":
                brace()
            case "~":
                tilde()
            case "\\":
                if ahead(1).isEmpty { refuse("\\") } else { word(2) }
            case "$":
                dollar()
            case "'", "\"":
                quote = scalar
                word(1)
            case ")":
                if depth > 0 { close() } else { refuse(")") }
            case "|", ";":
                operate(scalar == "|" && ahead(1) == "|" ? 2 : 1)
            case "&":
                if ahead(1) == "&" { operate(2) } else { refuse("&") }
            case "<", ">":
                redirect(scalar)
            case "[", "]":
                if spot == .start, scalars.at(at + 1)?.isBreak ?? true { word(1) } else { refuse("\(scalar)") }
            default:
                if scalar.isWordPart { plain(scalar) } else { refuse("\(scalar)") }
            }
        }

        /// A scalar in double quotes: their end, `\"` or `\$`, a parameter, or what prints but a backtick and `!`.
        private mutating func inDouble(_ scalar: Unicode.Scalar) {
            switch scalar {
            case "\"":
                quote = nil
                take(1)
            case "\\":
                if ahead(1) == "\"" || ahead(1) == "$" { take(2) } else { refuse("\\" + ahead(1)) }
            case "$":
                dollar()
            case "{":
                quotedBrace()
            default:
                if scalar.isUnquotable { refuse("\(scalar)") } else { take(1) }
            }
        }

        /// A scalar in single quotes: their end, or anything.
        private mutating func inSingle(_ scalar: Unicode.Scalar) {
            if scalar == "'" {
                quote = nil
                return take(1)
            }

            if scalar == "{" { quotedBrace() } else { take(1) }
        }

        /// What is left open at the command's end: a quote, a `$(…)`, or a redirection's word.
        private var stopAtEnd: CommandProblem<Placeholder>? {
            if quote != nil || depth > 0 {
                return .unclosed(quote.map { "\($0)" } ?? "$(")
            }

            return spot == .target ? .unchecked(redirection) : nil
        }
    }
}

/// `{name}` at `at` among the scalars: its name and where what follows it starts; none where none is there.
private func placeholderAt(_ scalars: [Unicode.Scalar], _ at: Int) -> (String, Int)? {
    var end = at + 1

    while scalars.at(end)?.isPlaceholderPart == true {
        end += 1
    }

    guard end > at + 1, scalars.at(end) == "}" else {
        return nil
    }

    return (written(scalars, from: at + 1, to: end), end + 1)
}

/// How many scalars the parameter `$` starts at `at` takes, in double quotes or not, `$name`, `${name}`, `$?`, `$$` or
/// `$1` to `$9`, one outside braces only where what follows ends it, in double quotes a `'` too, as in `"$USER's"`;
/// none where it starts none.
private func parameterLength(_ scalars: [Unicode.Scalar], _ at: Int, isQuoted: Bool) -> Int? {
    let next = scalars.at(at + 1)
    let isBraced = next == "{"
    var end = at + (isBraced ? 2 : 1)

    if next?.isSpecialParameter == true {
        end += 1
    } else if scalars.at(end)?.isNameStart == true {
        while scalars.at(end)?.isNamePart == true {
            end += 1
        }
    } else {
        return nil
    }

    if isBraced {
        return scalars.at(end) == "}" ? end + 1 - at : nil
    }

    let isEnded = scalars.at(end).map { $0.endsParameter || (isQuoted && $0 == "'") } ?? true

    return isEnded ? end - at : nil
}

/// A `$` at `at` that starts no parameter, as a refusal names it: what it starts, to the scalar that ends it, as `${x:`,
/// `$x:`, `$$'` or `$'`; `$` alone before a blank or the command's end.
private func dollarPart(_ scalars: [Unicode.Scalar], _ at: Int) -> String {
    let next = scalars.at(at + 1)
    var end = at + (next == "{" ? 2 : 1)

    guard let next, !next.isBlank else {
        return "$"
    }

    if next.isSpecialParameter {
        end += 1
    } else if next == "{" || next.isNameStart {
        while scalars.at(end)?.isNamePart == true {
            end += 1
        }
    }

    return written(scalars, from: at, to: end + 1)
}

/// The scalars from `start` up to `end`, as text, none past the last.
private func written(_ scalars: [Unicode.Scalar], from start: Int, to end: Int) -> String {
    String(String.UnicodeScalarView(scalars[start ..< min(end, scalars.count)]))
}

private extension [Unicode.Scalar] {
    /// The scalar at the index; none past the end.
    func at(_ index: Int) -> Unicode.Scalar? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Unicode.Scalar {
    /// A plain character of a word: an ASCII letter or digit, or one of `_ . / : @ % + , = -`.
    var isWordPart: Bool {
        isNamePart || "./:@%+,=-".unicodeScalars.contains(self)
    }

    /// What may start a word but its plain characters: a placeholder's brace, `~`, `\`, `$` and the quotes.
    var startsWord: Bool {
        "{~\\$'\"".unicodeScalars.contains(self)
    }

    /// A character of a shell name: an ASCII letter or digit, or `_`.
    var isNamePart: Bool {
        self == "_" || (isASCII && CharacterSet.alphanumerics.contains(self))
    }

    /// A shell name's first character: an ASCII letter, or `_`.
    var isNameStart: Bool {
        isNamePart && !isDigit
    }

    /// A character of a placeholder's name: an ASCII letter, or `_`.
    var isPlaceholderPart: Bool {
        isNameStart
    }

    /// What `$` may name but a name: `$?`, `$$` and `$1` to `$9`. Never `$#`, as zsh reads `$#` as the length of what
    /// follows, `$#$` of `$$`.
    var isSpecialParameter: Bool {
        self == "?" || self == "$" || ("1" ... "9").contains(self)
    }

    var isDigit: Bool {
        ("0" ... "9").contains(self)
    }

    /// What may follow a parameter outside braces, where every shell ends it: a break, a double quote, or one of
    /// `/ - = , + @ % \ $`; or the command's end, read as none. Others read on: zsh's `$x:F:…:` evaluates the `…` as
    /// arithmetic, `$x[…]` is zsh's subscript, and zsh reads `$12` as `${12}` and `$$'…'` as `$$` and `$'…'`; ksh reads
    /// `$x.y` as one name, and bash and ksh take a letter past ASCII into one. All but `$'…'` hold in double quotes too.
    var endsParameter: Bool {
        isBreak || "\"/-=,+@%\\$".unicodeScalars.contains(self)
    }

    var isBlank: Bool {
        self == " " || self == "\t"
    }

    /// What may follow a part nothing may join, `2>&1`, `[` or `]`: a blank, an operator, a redirection or a `$(…)`'s
    /// end; or the command's, read as none.
    var isBreak: Bool {
        isBlank || "|&;<>)".unicodeScalars.contains(self)
    }

    /// What double quotes may not hold, though it prints: a backtick, and `!`, which an interactive bash or zsh reads as
    /// history.
    var isUnquotable: Bool {
        self == "`" || self == "!"
    }
}

/// A placeholder of a command SitRep types, by its name, and the command, as Settings names it.
protocol CommandPlaceholder: RawRepresentable<String>, CaseIterable, Hashable, Sendable {
    /// The command, as Settings names it: `resume command`.
    static var command: String { get }
    /// A command passing the placeholders to a script, as a refusal of a part SitRep can't check suggests:
    /// `~/bin/resume {claude} {dir}`.
    static var scripted: String { get }
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
    /// Placeholders inside quotes, by their names.
    case quoted([String])
    /// A part that is not plain shell syntax, as found: `(`, `${x:`.
    case unchecked(String)
    /// A quote or a `$(…)` left open at the command's end, by how it opens.
    case unclosed(String)

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
            "\(command) puts \(braced(names)) in quotes. Remove them: SitRep quotes each value itself."
        case let .unchecked(part):
            "\(command) uses \(named(part: part)), which SitRep can't check. Put that part in a script and pass it "
                + "\(braced(Placeholder.allCases.map(\.rawValue), "or")), as in \(Placeholder.scripted)."
        case let .unclosed(part):
            "\(command) opens \(named(part: part)) but never closes it."
        }
    }
}

/// A part of a command as a refusal names it: one holding a backtick by its name, the rest as written, in backticks.
private func named(part: String) -> String {
    part.contains("`") ? "a backtick" : "`\(part)`"
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
/// Its quotes are found by scalar, as the shell finds them: one with a combining mark after it is one character to
/// Swift, and would be passed over by character.
func shellQuoted(_ value: String) -> String {
    var quoted = String.UnicodeScalarView()

    for scalar in value.unicodeScalars {
        if scalar == "'" {
            quoted.append(contentsOf: #"'\''"#.unicodeScalars)
        } else {
            quoted.append(scalar)
        }
    }

    return "'" + String(quoted) + "'"
}

/// Why no window opens for a session, in plain words.
struct Unopenable: Error, Equatable, CustomStringConvertible {
    let description: String
}
