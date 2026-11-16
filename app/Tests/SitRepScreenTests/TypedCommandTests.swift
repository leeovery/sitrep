import SitRepCore
@testable import SitRepScreen
import Testing

/// A command SitRep types into a new window, read as the shell reads it (stage 7, C, as stage 8's rethink left it): its
/// placeholders found and filled, each value quoted for the shell, and nothing typed that is not fit to type.
struct TypedCommandTests {
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"

    /// The line for a window whose folder is given, the command given.
    private static func line(_ command: String, folder: String = "/Users/lee/Code/kit") async throws -> String {
        let window = Board.LastWindow(writer: claude, directory: folder)

        return try await ResumeCommand(command).line(from: ResumeFacts(window: window, tty: nil), named: JumpWorld.named)
    }

    @Test func theCommandIsTakenAsGivenLessTheSpacesAroundIt() {
        #expect(ResumeCommand(" claude --resume {claude} ") == ResumeCommand("claude --resume {claude}"))
    }

    /// Never bare, even where no character is special, as a bare word can be a zsh global alias.
    @Test(arguments: [
        ("%148", "'%148'"),
        ("/private/tmp/tmux-501/default", "'/private/tmp/tmux-501/default'"),
        ("sitrep-iFpz7T", "'sitrep-iFpz7T'"),
        ("kit · restore-card", "'kit · restore-card'"),
        ("lee's work", #"'lee'\''s work'"#),
        ("$HOME;rm", "'$HOME;rm'"),
        ("=zmx", "'=zmx'"),
        ("~/tmux", "'~/tmux'"),
        ("", "''"),
    ])
    func eachValueIsAlwaysInSingleQuotesItsOwnEscaped(value: String, quoted: String) {
        #expect(shellQuoted(value) == quoted)
    }

    @Test func eachPlaceholderIsFilledQuotedEveryTimeItIsNamed() {
        let command = ResumeCommand("cd {dir} # {dir}")

        #expect(command.filled([.dir: "kit · card"]) == "cd 'kit · card' # 'kit · card'")
    }

    /// `{a,b}` is the shell's own braces, and `{ x; }` its group: neither is a placeholder.
    @Test func shellBracesAreNoPlaceholderAndAreLeftAsWritten() {
        let command = ResumeCommand("{ cd {dir}; } && echo {a,b}")

        #expect(command.named == ["dir"])
        #expect(command.filled([.dir: "kit"]) == "{ cd 'kit'; } && echo {a,b}")
    }

    /// The shell's `${…}`, tmux's `#{…}` and a brace escaped are never placeholders, so never refused nor filled.
    @Test(arguments: [
        "echo ${HOME} && cd {dir}",
        "tmux display -p '#{session_name}'; cd {dir}",
        "tmux display -p x#{pane}; cd {dir}",
        #"echo \{dir} && cd {dir}"#,
        "echo ${dir} && cd {dir}",
    ])
    func aBraceAfterADollarAHashOrABackslashIsNoPlaceholder(command: String) {
        let parsed = ResumeCommand(command)

        #expect(parsed.named == ["dir"])
        #expect(parsed.problem == nil)
        #expect(parsed.filled([.dir: "a b"]) == command.replacing("cd {dir}", with: "cd 'a b'"))
    }

    /// Joined to unquoted text, a placeholder's quoted value is one shell word with it: allowed and filled (stage 8's
    /// rethink, 13 November 2026).
    @Test(arguments: [
        ("claude --resume={claude}", "claude --resume='\(claude)'"),
        ("awk -v id={claude}", "awk -v id='\(claude)'"),
        ("cd x{dir}y;", "cd x'/Users/lee/Code/kit'y;"),
        ("cd {dir}/sub", "cd '/Users/lee/Code/kit'/sub"),
        (#"echo "a"{claude}"#, #"echo "a"'\#(claude)'"#),
    ])
    func aPlaceholderJoinedToUnquotedTextIsFilled(command: String, line: String) async throws {
        #expect(ResumeCommand(command).problem == nil)
        #expect(try await Self.line(command) == line)
    }

    /// Quotes of its own around a placeholder would put SitRep's inside them: in double quotes the value gains literal
    /// quotes; in single quotes it splits into words, and a `;` in it runs what follows.
    @Test(arguments: [#"cd "{dir}""#, "cd '{dir}'", "cd $'{dir}'", #"cd "x{dir}y""#, "awk -v id='{claude}'"])
    func aPlaceholderInsideQuotesIsRefused(command: String) {
        #expect(ResumeCommand(command).problem == .quoted(ResumeCommand(command).named))
    }

    /// An escaped `$`, or `$$`, the shell's process id, opens no `$'…'`: the quote after it is a plain one, so a
    /// placeholder after it is inside quotes, and refused. Read as `$'…'`, the placeholder would be filled, and its
    /// value, quoted, would run as a command (found in review, 10 November 2026).
    @Test(arguments: [#"cd \$'\'X'{dir}'"#, #"cd $$'\'X'{dir}'"#])
    func aDollarEscapedOrDoubledOpensNoAnsiQuoteSoAPlaceholderAfterItIsRefused(command: String) async {
        await #expect(throws: Unopenable(description: CommandProblem<ResumeFact>.quoted(["dir"]).refusal(named: JumpWorld.named))) {
            try await Self.line(command, folder: "a; touch pwned; ")
        }
    }

    /// Bash scans `` `…` `` for its closing backtick before any quoting inside it, so a backtick in a value quoted
    /// there ends it, and what follows runs: a placeholder in backticks is refused, as in quotes (proven in bash, in
    /// review, 10 November 2026).
    @Test(arguments: ["cd `echo {dir} `", #"cd "`echo {dir} `""#, "x `a` `{dir}`"])
    func aPlaceholderInBackticksIsRefused(command: String) async {
        await #expect(throws: Unopenable(description: CommandProblem<ResumeFact>.quoted(["dir"]).refusal(named: JumpWorld.named))) {
            try await Self.line(command, folder: "kit · card`;touch PWNED;")
        }
    }

    /// Arithmetic, and a subscript, which the shell evaluates as arithmetic, run a `$(…)` even inside a quoted value:
    /// `$(( '/x$(cmd)' ))` runs `cmd` in zsh, bash and sh. A placeholder there is refused, saying why.
    @Test(arguments: [
        "echo $(( {dir} ))", "(( x = {dir} ))", "echo $(( 1 + ({dir}) ))", "echo $[ {dir} ]", "echo ${a[{dir}]}",
        "a[{dir}]=1", "echo $a[{dir}]", #"echo "$(( {dir} ))""#,
    ])
    func aPlaceholderInArithmeticOrASubscriptIsRefused(command: String) async {
        await #expect(throws: Unopenable(description: CommandProblem<ResumeFact>.evaluated(["dir"]).refusal(named: JumpWorld.named))) {
            try await Self.line(command, folder: "/x$(touch pwned)")
        }
    }

    /// Arithmetic and subscripts closed before a placeholder, a test's brackets, `$(…)`, and the shell's own `${…}`
    /// leave it filled; the design's examples stand as written.
    @Test(arguments: [
        "echo $(( 1 + (2) )) && cd {dir}", "echo ${a[1]} && cd {dir}", "[ -d {dir} ] && cd {dir}",
        "[[ -d {dir} ]] && cd {dir}", "cd $(echo x) {dir}", "cd ${x:-{dir}}",
        #"s=$(portal hook list | awk -F'\t' -v id={claude} 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && portal open -s "$s" || portal open -p {dir} -- claude --resume {claude}"#,
        "t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d={tty} '$1==d {print $2; exit}'); [ -n \"$t\" ] && tmux attach -t \"$t\" || tmux new -c {dir} claude --resume {claude}",
    ])
    func aPlaceholderOutsideArithmeticAndSubscriptsIsFilled(command: String) {
        #expect(ResumeCommand(command).problem == nil)
    }

    @Test func backticksClosedBeforeThePlaceholderLeaveItUnquoted() {
        #expect(ResumeCommand("cd `pwd` && cd {dir}").problem == nil)
    }

    @Test(arguments: [
        #"echo "it's" && cd {dir}"#, #"echo 'say "hi"' && cd {dir}"#, #"echo "a\"b" && cd {dir}"#,
        #"echo $'it\'s' && cd {dir}"#,
    ])
    func quotesClosedBeforeThePlaceholderLeaveItUnquoted(command: String) {
        #expect(ResumeCommand(command).problem == nil)
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
    ])
    func aValueHoldingAControlOrOtherCharacterThatPrintsNothingIsRefused(character: String, words: String) async {
        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the folder its Claude ran in has \(words).")) {
            try await Self.line("cd {dir}", folder: "x\(character)touch pwned; echo '")
        }
    }

    @Test(arguments: ["cd\t{dir}", "cd {dir}\u{15}", "cd\u{1B}x {dir}"])
    func aCommandHoldingAControlIsRefused(command: String) {
        guard case .unprintable = ResumeCommand(command).problem else {
            Issue.record("\(command.debugDescription) was not refused")
            return
        }
    }

    @Test(arguments: [
        (CommandProblem<ResumeFact>.unprintable("\u{15}"), "The resume command in Settings has a character that can't be typed (U+0015)."),
        (.unprintable("\t"), "The resume command in Settings has a tab, which can't be typed."),
        (.quoted(["dir"]), "The resume command in Settings puts {dir} in quotes or backticks. Remove them: SitRep quotes each value itself."),
        (.evaluated(["dir"]), "The resume command in Settings puts {dir} in arithmetic or a subscript, where the shell runs what is in a value even quoted. Move it out."),
        (.unknown(["session"]), "The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
        (.empty, "The resume command in Settings is empty. To carry \(JumpWorld.named) on, set one, or restore the default."),
    ])
    func eachProblemIsRefusedInPlainWords(problem: CommandProblem<ResumeFact>, words: String) {
        #expect(problem.refusal(named: JumpWorld.named) == words)
    }
}
