import Foundation
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// A command SitRep types into a new window, held to plain shell syntax (Lee, 20 November 2026) as the panel's reader
/// holds it (tests/panel-command.test.ts): its placeholders found and filled, each value quoted for the shell, anything
/// but plain syntax refused in words pointing to a script, and nothing typed that is not fit to type.
@Suite(.backstop)
struct TypedCommandTests {
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"

    /// Hostile facts: a quote that would end its own, a subscript the shell would evaluate, and a backtick.
    private static let hostile: [ResumeFact: String] = [
        .claude: "x'; touch PWNED; '", .dir: "a[$(touch PWNED)]", .tty: "`touch PWNED`",
    ]

    /// The line for a window whose folder is given, the command given.
    private static func line(_ command: String, folder: String = "/Users/me/Code/litware") async throws -> String {
        let window = Board.LastWindow(writer: claude, directory: folder)

        return try await ResumeCommand(command).line(from: ResumeFacts(window: window, tty: nil), named: JumpWorld.named)
    }

    /// The command with each placeholder replaced by its hostile fact, quoted.
    private static func filledHostile(_ command: String) -> String {
        hostile.reduce(command) { line, fact in line.replacing("{\(fact.key.rawValue)}", with: shellQuoted(fact.value)) }
    }

    /// The refusal of the problem, as a line for the session throws it.
    private static func refusal(_ problem: CommandProblem<ResumeFact>) -> Unopenable {
        Unopenable(description: problem.refusal(named: JumpWorld.named))
    }

    @Test func theCommandIsTakenAsGivenLessTheSpacesAroundIt() {
        #expect(ResumeCommand(" claude --resume {claude} ") == ResumeCommand("claude --resume {claude}"))
    }

    /// Never bare, even where no character is special, as a bare word can be a zsh global alias; and each quote escaped,
    /// one with a combining mark after it among them, which is one character to Swift but still a quote to the shell.
    /// Matched by character, `x'\u{301}; touch pwned; '\u{301}` was typed unescaped, its `;` run (found in review, 19
    /// November 2026), so the line is held to its scalars.
    @Test(arguments: [
        ("%12", "'%12'"),
        ("/private/tmp/tmux-501/default", "'/private/tmp/tmux-501/default'"),
        ("proseware-Qm4tZ8", "'proseware-Qm4tZ8'"),
        ("litware · restore-card", "'litware · restore-card'"),
        ("team's work", #"'team'\''s work'"#),
        ("$HOME;rm", "'$HOME;rm'"),
        ("=zmx", "'=zmx'"),
        ("~/tmux", "'~/tmux'"),
        ("", "''"),
        ("x'\u{301}; touch pwned; '\u{301}", "'x'\\''\u{301}; touch pwned; '\\''\u{301}'"),
    ] as [(String, String)])
    func eachValueIsAlwaysInSingleQuotesItsOwnEscaped(value: String, quoted: String) {
        #expect(Array(shellQuoted(value).unicodeScalars) == Array(quoted.unicodeScalars))
    }

    @Test func eachPlaceholderIsFilledQuotedEveryTimeItIsNamed() {
        let command = ResumeCommand("cd {dir} && ls {dir}")

        #expect(command.filled([.dir: "litware · card"]) == "cd 'litware · card' && ls 'litware · card'")
    }

    /// The default, a script given the placeholders, and Lee's one-liner through his session tool, as DESIGN records it,
    /// the tool renamed `seat`: each passes, filled and quoted.
    @Test func theDefaultAScriptAndTheSessionToolsOneLinerFillAsWritten() async throws {
        let seat = #"s=$(seat hook list | awk -F'\t' -v id={claude} 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && seat open -s "$s" || seat open -p {dir} -- claude --resume {claude}"#

        #expect(try await Self.line(OpenSettings.defaultResumeCommand) == "cd '/Users/me/Code/litware' && claude --resume '\(Self.claude)'")
        #expect(try await Self.line("~/bin/resume {claude} {dir}") == "~/bin/resume '\(Self.claude)' '/Users/me/Code/litware'")
        #expect(try await Self.line(seat) == #"s=$(seat hook list | awk -F'\t' -v id='\#(Self.claude)' 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && seat open -s "$s" || seat open -p '/Users/me/Code/litware' -- claude --resume '\#(Self.claude)'"#)
    }

    static let plain: [String] = [
        "a {dir} | b {claude} || c && d; e;f|g {tty}",
        "claude --resume {claude} 2>&1 >>~/log <&0 >{tty} < {dir} 1>&2",
        "[ -d {dir} ] && cd {dir}",
        #"echo "$HOME" "${x}" "$?$$$1" "a\"b\$c" $x ${x}{dir} $_x9"#,
        "PATH=${PATH}:/opt/bin {dir} ${x}:{tty}",
        ##"echo \( \` \$x \  \{ \# {dir}"##,
        "s=$(a $(b {claude}) {dir}); t=$( ); u=$()",
        "~/bin/x {dir} ~ ~/y >~/z",
        #"echo 'a $(b) `c` {print} #!* \' {dir}"#,
        #"echo "it's (a) {x} ~ * ? # ; & | < > [ ] }" {dir}"#,
        #"claude --resume={claude} -v id={claude} x{dir}y {dir}/sub "a"{claude} {dir}:{tty}"#,
        #"echo "resuming $USER's session" "$1'" "${x}'" {dir}"#,
        "PATH=~/bin:$PATH claude --resume {claude}",
        "x=a:~/b:~/c --flag=~/d a_1=~/e {dir}",
        "x=$(echo {dir}):~/b {claude}",
    ]

    /// Plain shell syntax passes, each placeholder filled wherever it stands outside quotes, however deep in `$(…)`.
    @Test(arguments: plain)
    func plainShellSyntaxPassesEachPlaceholderFilled(command: String) {
        #expect(ResumeCommand(command).problem == nil)
        #expect(ResumeCommand(command).filled(Self.hostile) == Self.filledHostile(command))
    }

    /// `${dir}` and `$dir` are the shell's parameters, never placeholders.
    @Test func dollarDirIsTheShellsParameterNeverAPlaceholder() {
        let command = ResumeCommand(#"echo ${dir} "$dir" {dir}"#)

        #expect(command.named == ["dir"])
        #expect(command.filled([.dir: "a b"]) == #"echo ${dir} "$dir" 'a b'"#)
    }

    /// Quotes of its own around a placeholder would put SitRep's inside them: in double quotes the value gains literal
    /// quotes; in single quotes it splits into words, and a `;` in it runs what follows. So in a `$(…)`, and after a
    /// quote with a combining mark after it, which is one character to Swift but still a quote to the shell.
    @Test(arguments: [#"cd "{dir}""#, "cd '{dir}'", #"cd "x{dir}y""#, "cd $(echo '{dir}')", "cd '\u{301}{dir}'"])
    func aPlaceholderInsideQuotesIsRefused(command: String) async {
        await #expect(throws: Self.refusal(.quoted(["dir"]))) {
            try await Self.line(command, folder: "x; touch pwned; echo ")
        }
    }

    @Test func eachPlaceholderInsideQuotesIsNamedOnce() {
        #expect(ResumeCommand(#"cd "{dir}" "{claude}" "{dir}""#).problem == .quoted(["dir", "claude"]))
    }

    /// A name in braces inside quotes that is no placeholder's is text, as awk's `'{print}'` and tmux's `'#{pane}'`.
    @Test(arguments: ["awk '{print $1}' {dir}", #"echo "{x}" {dir}"#, "tmux display -p '#{session_name}' {dir}"])
    func aNameInBracesInsideQuotesThatIsNoPlaceholdersIsText(command: String) {
        #expect(ResumeCommand(command).problem == nil)
        #expect(ResumeCommand(command).filled(Self.hostile) == Self.filledHostile(command))
    }

    static let parts: [(String, String)] = [
        ("echo `pwd` {dir}", "`"),
        ("( cd {dir} )", "("),
        ("cd {dir} )", ")"),
        ("{ cd {dir}; }", "{"),
        ("echo {a,b} {dir}", "{"),
        (#"echo \{dir} && cd {dir}"#, "}"),
        ("! cd {dir}", "!"),
        ("ls * {dir}", "*"),
        ("ls a? {dir}", "?"),
        ("ls a[1] {dir}", "["),
        ("[[ -d {dir} ]]", "["),
        ("echo x] {dir}", "]"),
        ("cd {dir} # note", "#"),
        ("claude & {dir}", "&"),
        ("cat <<x {dir}", "<<"),
        ("diff <(a) {dir}", "<("),
        ("tee >(a) {dir}", ">("),
        ("echo $((1)) {dir}", "$(("),
        ("echo $[1] {dir}", "$["),
        ("echo ${x:-y} {dir}", "${x:"),
        ("echo ${ x; } {dir}", "${ "),
        ("echo ${{dir}}", "${{"),
        ("echo ${1} {dir}", "${1}"),
        ("echo $'x' {dir}", "$'"),
        ("echo $! {dir}", "$!"),
        ("echo $@ {dir}", "$@"),
        ("echo $0 {dir}", "$0"),
        ("echo $# {dir}", "$#"),
        ("echo $#$( [ {dir} ] )", "$#"),
        ("echo $x:F:{dir}:h", "$x:"),
        ("echo $?:h {dir}", "$?:"),
        ("echo $1:t {dir}", "$1:"),
        (#"echo "$x:h" {dir}"#, "$x:"),
        ("echo $10:F:{dir}:h", "$10"),
        ("echo $x.log {dir}", "$x."),
        ("echo $x{dir}", "$x{"),
        ("echo $x'a' {dir}", "$x'"),
        (#"echo "$xé" {dir}"#, "$xé"),
        ("echo $ {dir}", "$"),
        ("echo $${dir}", "$${"),
        (#"echo $$'\'x' {dir}"#, "$$'"),
        (#"echo "$(pwd)" {dir}"#, "$("),
        (#"echo "$((1))" {dir}"#, "$(("),
        (#"echo "a\\b" {dir}"#, #"\\"#),
        (#"echo "!" {dir}"#, "!"),
        (#"echo "$x[1]" {dir}"#, "$x["),
        (#"echo "$x.y" {dir}"#, "$x."),
        (#"echo "`pwd`" {dir}"#, "`"),
        ("echo x >&{dir}", ">&{"),
        ("echo x >&- {dir}", ">&-"),
        ("echo x >& 1 {dir}", ">&"),
        ("echo x 2>&12 {dir}", ">&12"),
        ("echo x 2>&1{dir}", ">&1{"),
        ("echo x >|{dir}", ">|"),
        ("echo x <>{dir}", "<>"),
        ("cd a~b {dir}", "~"),
        ("echo a:~/b {dir}", "~"),
        ("x=a=~/b {dir}", "~"),
        ("x=1 $(echo a):~/b {dir}", "~"),
        ("cd ~{dir}", "~{dir}"),
        ("x=~{dir}", "~{dir}"),
        ("x=a:~{claude}", "~{claude}"),
        ("echo ~{x}", "~{x}"),
        ("cd ~/café {dir}", "é"),
        ("cd {dir} >", ">"),
        (#"cd {dir} \"#, #"\"#),
    ]

    /// Each part but plain shell syntax is refused, named as found.
    @Test(arguments: parts)
    func eachPartButPlainSyntaxIsRefusedNamedAsFound(command: String, part: String) {
        #expect(ResumeCommand(command).problem == .unchecked(part))
    }

    /// A quote or a `$(…)` left open is refused, naming the innermost.
    @Test(arguments: [
        (#"cd {dir} "x"#, #"""#), ("cd {dir} 'x", "'"), ("cd $(echo {dir}", "$("), (#"cd $(echo "x"#, #"""#),
    ] as [(String, String)])
    func aQuoteOrASubstitutionLeftOpenIsRefused(command: String, part: String) {
        #expect(ResumeCommand(command).problem == .unclosed(part))
    }

    /// A placeholder SitRep doesn't know is refused before one in quotes, and one in quotes before a part it can't check.
    @Test func anUnknownPlaceholderComesFirstThenOneInQuotesThenAPart() {
        #expect(ResumeCommand(#"echo {session} "{dir}" `x`"#).problem == .unknown(["session"]))
        #expect(ResumeCommand(#"echo "{dir}" `x`"#).problem == .quoted(["dir"]))
    }

    /// Every hole the reviews of 19 November 2026 and the fuzz of the 20th found, and every case probed beside one, as
    /// the panel's tests list them, so both readers are held to the same: none passes.
    @Test func everyHoleTheReviewsFoundIsRefused() throws {
        let list = try String(contentsOf: Repository.root.appending(path: "tests/refused-commands.ts"), encoding: .utf8)
        let opening = try #require(list.range(of: "= ["))
        let commands = try JSONDecoder().decode([String].self, from: Data(list[list.index(before: opening.upperBound)...].utf8))

        #expect(commands.count > 250)
        #expect(commands.filter { ResumeCommand($0).problem == nil } == [])
    }

    /// The commands of tests/reader-cases.ts, made by the panel's reader, each with the line or the refusal it gave.
    private struct ReaderCases: Decodable {
        struct Facts: Decodable {
            let claude: String
            let dir: String
            let tty: String
            let isHeld: Bool
        }

        struct Row: Decodable, Equatable {
            let command: String
            var line: String?
            var refusal: String?
        }

        let name: String
        let facts: Facts
        let rows: [Row]
    }

    /// Each command of the cases the panel's tests hold its reader to gets what the panel gave it when the file was
    /// made: the same line, or the same refusal.
    @Test func eachCommandOfTheReaderCasesGetsWhatThePanelGaveIt() async throws {
        let file = try String(contentsOf: Repository.root.appending(path: "tests/reader-cases.ts"), encoding: .utf8)
        let opening = try #require(file.range(of: "= {\n"))
        let object = file[file.index(opening.lowerBound, offsetBy: 2)...]
        let cases = try JSONDecoder().decode(ReaderCases.self, from: Data(object.utf8))
        let window = Board.LastWindow(writer: cases.facts.claude, directory: cases.facts.dir)
        let facts = ResumeFacts(window: window, tty: cases.facts.tty, isHeld: cases.facts.isHeld)
        var differing: [ReaderCases.Row] = []

        for row in cases.rows {
            var given = ReaderCases.Row(command: row.command)

            do {
                given.line = try await ResumeCommand(row.command).line(from: facts, named: cases.name)
            } catch let refusal as Unopenable {
                given.refusal = refusal.description
            }

            if given != row {
                differing.append(given)
            }
        }

        #expect(cases.rows.count == 2000)
        #expect(differing == [])
    }

    static let evaluating: [String] = [
        "eval {dir}", "trap {dir} EXIT", "let {dir}", "read {dir}", "declare -i n={dir}", "local {dir}",
        "printf -v {dir} x", "[ {dir} -eq 1 ]", "shift {dir}", "exit {dir}", "ulimit {dir}", "PS4={dir}; set -x",
        "BASH_ENV={dir} bash x", "PROMPT_COMMAND={dir}", "RANDOM={dir}", "OPTIND={dir}",
    ]

    /// What takes code, a name or a number from its argument passes as words, a builtin or a variable the shell
    /// evaluates: a command passing a placeholder to one takes that risk.
    @Test(arguments: evaluating)
    func whatTakesCodeFromItsArgumentPassesAsWords(command: String) {
        #expect(ResumeCommand(command).problem == nil)
        #expect(ResumeCommand(command).filled(Self.hostile) == Self.filledHostile(command))
    }

    /// A value starting with a dash would be read as an option, as an id of `--settings=…` by
    /// `claude --resume {claude}`: refused, naming the fact, each value that can't be typed first, and a dash inside a
    /// word passes.
    @Test func aValueStartingWithADashIsRefusedNamingTheFact() async throws {
        let line = { (command: String, writer: String, folder: String, tty: String) in
            try await ResumeCommand(command).line(
                from: ResumeFacts(window: Board.LastWindow(writer: writer, directory: folder), tty: tty),
                named: JumpWorld.named
            )
        }
        let dashed = "which a program would read as an option."

        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the Claude Code session's id starts with a dash, \(dashed)")) {
            try await line("claude --resume {claude}", "--settings=x", "/a", "")
        }
        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the folder its Claude ran in starts with a dash, \(dashed)")) {
            try await line("attach {tty} {dir}", Self.claude, "-x", "-t")
        }
        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the terminal its Claude runs on has a character that can't be typed (U+0015).")) {
            try await line("attach {tty} {claude}", "-x", "/a", "\u{15}")
        }
        #expect(try await line("claude --resume {claude} x{dir}", Self.claude, "a-b", "") == "claude --resume '\(Self.claude)' x'a-b'")
    }

    /// The terminal and the line editor act on a control byte before any quoting: ^U erases what was typed, ^C
    /// abandons the line, ESC starts an editor sequence, and a newline or a tab runs or completes it. The common ones by
    /// name, the rest by their code point.
    @Test(arguments: [
        ("\u{15}", "a character that can't be typed (U+0015)"), ("\u{03}", "a character that can't be typed (U+0003)"),
        ("\u{7F}", "a character that can't be typed (U+007F)"), ("\u{1B}", "an escape, which can't be typed"),
        ("\n", "a line break, which can't be typed"), ("\r", "a line break, which can't be typed"),
        ("\u{2028}", "a line break, which can't be typed"), ("\t", "a tab, which can't be typed"),
        ("\u{85}", "a line break, which can't be typed"), ("\u{202E}", "a character that can't be typed (U+202E)"),
    ] as [(String, String)])
    func aValueHoldingAControlOrOtherCharacterThatPrintsNothingIsRefused(character: String, words: String) async {
        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the folder its Claude ran in has \(words).")) {
            try await Self.line("cd {dir}", folder: "x\(character)touch pwned; echo '")
        }
    }

    /// A control is refused before anything else, a placeholder in quotes or a part past plain syntax among them.
    @Test(arguments: ["cd\t{dir}", "cd {dir}\u{15}", "cd\u{1B}x {dir}", "cd\t\"{session}\" `x`"])
    func aCommandHoldingAControlIsRefused(command: String) {
        guard case .unprintable = ResumeCommand(command).problem else {
            Issue.record("\(command.debugDescription) was not refused")
            return
        }
    }

    @Test(arguments: [
        (CommandProblem<ResumeFact>.unprintable("\u{15}"), "The resume command in Settings has a character that can't be typed (U+0015)."),
        (.unprintable("\t"), "The resume command in Settings has a tab, which can't be typed."),
        (.quoted(["dir"]), "The resume command in Settings puts {dir} in quotes. Remove them: SitRep quotes each value itself."),
        (.unchecked("("), "The resume command in Settings uses `(`, which SitRep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}."),
        (.unchecked("`"), "The resume command in Settings uses a backtick, which SitRep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}."),
        (.unchecked(#"\`"#), "The resume command in Settings uses a backtick, which SitRep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}."),
        (.unclosed(#"""#), #"The resume command in Settings opens `"` but never closes it."#),
        (.unclosed("$("), "The resume command in Settings opens `$(` but never closes it."),
        (.unknown(["session"]), "The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
        (.empty, "The resume command in Settings is empty. To carry \(JumpWorld.named) on, set one, or restore the default."),
    ] as [(CommandProblem<ResumeFact>, String)])
    func eachProblemIsRefusedInPlainWords(problem: CommandProblem<ResumeFact>, words: String) {
        #expect(problem.refusal(named: JumpWorld.named) == words)
    }

    /// A combining mark is one character with what it follows to Swift, but the shell reads bytes: the command is read
    /// a scalar at a time, so a mark outside quotes is a character past plain syntax, and one inside them is text.
    @Test func aCombiningMarkIsReadAsItsOwnScalar() async throws {
        #expect(ResumeCommand("cd {dir}\u{301}").problem == .unchecked("\u{301}"))
        #expect(
            Array(try await Self.line("cd {dir}'\u{301}'").unicodeScalars)
                == Array("cd '/Users/me/Code/litware''\u{301}'".unicodeScalars)
        )
    }
}
