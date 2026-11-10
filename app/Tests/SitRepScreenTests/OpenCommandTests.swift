import SitRepCore
@testable import SitRepScreen
import Testing

/// The open command, as Lee sets it in Settings: none by default, its placeholders filled with the facts of the
/// session's live window, each quoted for the shell, and nothing typed that is not fit to type (stage 7, C).
struct OpenCommandTests {
    private static let kit = "kit · restore-card"

    /// The line for a window, the command given, in the multiplexer given.
    private static func line(_ command: String, _ where: Where, in multiplexer: any Multiplexer) async throws -> String {
        try await OpenCommand(command).line(for: `where`, in: multiplexer, named: named)
    }

    /// SitRep has no built-in way to attach: no command, or only spaces, opens nothing, and says where to set one.
    @Test(arguments: ["", "  ", "\n"])
    func noCommandIsRefusedSayingToSetOneInSettings(given: String) async {
        let tmux = FakeTmux()

        #expect(OpenCommand(given).problem == .empty)
        await #expect(throws: Unopenable(description: "No terminal window shows \(named). To open one for it, set an open command in Settings.")) {
            try await Self.line(given, inTmux(), in: TmuxAdapter(tmux))
        }
        #expect(tmux.runs.isEmpty)
    }

    @Test func theCommandIsTakenAsGivenLessTheSpacesAroundIt() {
        #expect(OpenCommand(" portal open -s {session} ") == OpenCommand("portal open -s {session}"))
    }

    @Test(arguments: [
        ("%148", "%148"),
        ("/private/tmp/tmux-501/default", "/private/tmp/tmux-501/default"),
        ("sitrep-iFpz7T", "sitrep-iFpz7T"),
        (kit, "'kit · restore-card'"),
        ("lee's work", #"'lee'\''s work'"#),
        ("$HOME;rm", "'$HOME;rm'"),
        ("=zmx", "'=zmx'"),
        ("~/tmux", "'~/tmux'"),
        ("", "''"),
    ])
    func eachValueIsQuotedForTheShellWhereItMustBeAndLeftAsTypedWhereNot(value: String, quoted: String) {
        #expect(shellQuoted(value) == quoted)
    }

    @Test func eachPlaceholderIsFilledQuotedEveryTimeItIsNamed() {
        let command = OpenCommand("portal open -s {session} # {session}")

        #expect(command.filled([.session: Self.kit]) == "portal open -s 'kit · restore-card' # 'kit · restore-card'")
    }

    /// zmx's `{session}` is the window's `$ZMX_SESSION`, and zmx is asked nothing: SitRep runs no zmx.
    @Test func zmxsSessionIsTheWindowsZmxSession() async throws {
        #expect(try await Self.line("portal open -s {session}", inZmx(Self.kit), in: ZmxAdapter()) == "portal open -s 'kit · restore-card'")
    }

    /// tmux's socket and pane are the heartbeat's: tmux is asked nothing for them.
    @Test func tmuxsSocketAndPaneAreTheHeartbeatsAskingTmuxNothing() async throws {
        let tmux = FakeTmux()
        let line = try await Self.line("tmux -S {socket} attach -t {pane}", inTmux(), in: TmuxAdapter(tmux))

        #expect(line == "tmux -S /private/tmp/tmux-501/default attach -t %148")
        #expect(tmux.runs.isEmpty)
    }

    /// A tmux session can be renamed: its name is asked of tmux at the click, by the pane, which never changes, and only
    /// where the command names it.
    @Test func tmuxsSessionIsTheNameOfTheSessionHoldingThePaneAskedOfTmuxAtTheClick() async throws {
        let panes = [FakePane(pane: "%148", window: claudes, session: "$45")]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, names: ["$45": "work · renamed"])])
        let line = try await Self.line("tmux -S {socket} attach -t {session}", inTmux(), in: TmuxAdapter(tmux))

        #expect(line == "tmux -S /private/tmp/tmux-501/default attach -t 'work · renamed'")
        #expect(tmux.words == [["display-message", "-p", "-t", "%148", "#{session_name}"]])
    }

    /// tmux not found is told apart from tmux not answering in time, and from its error.
    @Test(arguments: [
        (FakeTmux(missing: true), "tmux is not on your login shell's PATH, so SitRep cannot ask which session holds Claude's pane."),
        (FakeTmux(silent: true), "tmux, asked which session holds Claude's pane, did not answer within 2 seconds."),
        (FakeTmux([socket: FakeServer()]), #"tmux, asked which session holds Claude's pane, said "can't find pane: %148"."#),
        (FakeTmux(), #"tmux, asked which session holds Claude's pane, said "no server running on /private/tmp/tmux-501/default"."#),
    ])
    func tmuxNotNamingTheSessionIsRefusedInPlainWords(tmux: FakeTmux, words: String) async {
        await #expect(throws: TmuxFailure(description: words)) {
            try await Self.line("tmux attach -t {session}", inTmux(), in: TmuxAdapter(tmux))
        }
    }

    /// A placeholder the session has no fact for, or one SitRep does not know, is refused before anything is asked.
    @Test(arguments: [
        ("portal open -s {pane}", inZmx("kit"), "\(named) runs in zmx, which gives no {pane}. A zmx session gives {session}."),
        ("zmx attach {socket} {pane}", inZmx("kit"), "\(named) runs in zmx, which gives no {socket} or {pane}. A zmx session gives {session}."),
        ("tmux attach -t {window}", inTmux(), "The open command in Settings has {window}, which SitRep doesn't know. It knows {session}, {socket} and {pane}."),
        ("zmx attach {sesion} {Session}", inZmx("kit"), "The open command in Settings has {sesion} and {Session}, which SitRep doesn't know. It knows {session}, {socket} and {pane}."),
    ])
    func aPlaceholderWithNoFactOrUnknownIsRefusedNamingIt(command: String, where: Where, words: String) async {
        let tmux = FakeTmux()
        let multiplexer: any Multiplexer = `where`.tmux == nil ? ZmxAdapter() : TmuxAdapter(tmux)

        await #expect(throws: Unopenable(description: words)) {
            try await Self.line(command, `where`, in: multiplexer)
        }
        #expect(tmux.runs.isEmpty)
    }

    /// `{a,b}` is the shell's own braces, and `{ x; }` its group: neither is a placeholder.
    @Test func shellBracesAreNoPlaceholderAndAreLeftAsWritten() {
        let command = OpenCommand("{ zmx attach {session}; } && echo {a,b}")

        #expect(command.named == ["session"])
        #expect(command.filled([.session: "kit"]) == "{ zmx attach kit; } && echo {a,b}")
    }

    /// The shell's `${…}`, tmux's `#{…}` and a brace escaped are never placeholders, so never refused nor filled.
    @Test(arguments: [
        "echo ${HOME} && zmx attach {session}",
        "tmux display -p '#{session_name}'; zmx attach {session}",
        "tmux display -p x#{pane}; zmx attach {session}",
        #"echo \{session} && zmx attach {session}"#,
        "echo ${session} && zmx attach {session}",
    ])
    func aBraceAfterADollarAHashOrABackslashIsNoPlaceholder(command: String) {
        let parsed = OpenCommand(command)

        #expect(parsed.named == ["session"])
        #expect(parsed.problem == nil)
        #expect(parsed.filled([.session: "a b"]) == command.replacing("zmx attach {session}", with: "zmx attach 'a b'"))
    }

    /// Quotes of its own around a placeholder would put SitRep's inside them: in double quotes the name gains literal
    /// quotes; in single quotes it splits into words, and a `;` in it runs what follows.
    @Test(arguments: [
        #"zmx attach "{session}""#, "zmx attach '{session}'", "zmx attach $'{session}'", #"zmx attach "x{session}y""#,
    ])
    func aPlaceholderInsideQuotesIsRefused(command: String) {
        #expect(OpenCommand(command).problem == .quoted(["session"]))
    }

    /// An escaped `$`, or `$$`, the shell's process id, opens no `$'…'`: the quote after it is a plain one, so a
    /// placeholder after it is inside quotes, and refused. Read as `$'…'`, the placeholder would be filled, and its
    /// value, quoted, would run as a command (found in review, 10 November 2026).
    @Test(arguments: [#"zmx attach \$'\'X'{session}'"#, #"zmx attach $$'\'X'{session}'"#])
    func aDollarEscapedOrDoubledOpensNoAnsiQuoteSoAPlaceholderAfterItIsRefused(command: String) async {
        await #expect(throws: Unopenable(description: CommandProblem.quoted(["session"]).refusal(named: named))) {
            try await Self.line(command, inZmx("a; touch pwned; "), in: ZmxAdapter())
        }
    }

    @Test(arguments: [
        #"echo "it's" && zmx attach {session}"#, #"echo 'say "hi"' && zmx attach {session}"#,
        #"echo "a\"b" && zmx attach {session}"#, #"echo $'it\'s' && zmx attach {session}"#,
    ])
    func quotesClosedBeforeThePlaceholderLeaveItUnquoted(command: String) {
        #expect(OpenCommand(command).problem == nil)
    }

    /// A placeholder must stand as a word of its own: joined to other words, the quotes SitRep puts round its value
    /// would read otherwise than meant.
    @Test(arguments: ["zmx attach x{session}", "zmx attach {session};", "zmx attach --name={session}"])
    func aPlaceholderJoinedToOtherWordsIsRefused(command: String) {
        #expect(OpenCommand(command).problem == .joined(["session"]))
    }

    /// The terminal and the line editor act on a control byte before any quoting: ^U erases what was typed, ^C
    /// abandons the line, ESC starts an editor sequence, and a newline or a tab runs or completes it.
    @Test(arguments: [
        ("\u{15}", "U+0015"), ("\u{03}", "U+0003"), ("\u{7F}", "U+007F"), ("\u{1B}", "U+001B"), ("\n", "U+000A"),
        ("\t", "U+0009"), ("\u{85}", "U+0085"), ("\u{202E}", "U+202E"),
    ])
    func aValueHoldingAControlOrOtherCharacterThatPrintsNothingIsRefused(character: String, code: String) async {
        let session = "x\(character)touch pwned; echo '"

        await #expect(throws: Unopenable(description: "For \(named), the zmx session's name has a character that can't be typed (\(code)).")) {
            try await Self.line("zmx attach {session}", inZmx(session), in: ZmxAdapter())
        }
    }

    @Test(arguments: ["zmx attach\t{session}", "zmx attach {session}\u{15}", "zmx\u{1B}attach {session}"])
    func aCommandHoldingAControlIsRefused(command: String) {
        guard case .unprintable = OpenCommand(command).problem else {
            Issue.record("\(command.debugDescription) was not refused")
            return
        }
    }

    @Test(arguments: [
        (CommandProblem.unprintable("\u{15}"), "The open command in Settings has a character that can't be typed (U+0015)."),
        (.quoted(["session"]), "The open command in Settings puts {session} in quotes. Remove them: SitRep quotes each value itself."),
        (.joined(["session", "pane"]), "The open command in Settings joins {session} and {pane} to other text. Put a space before and after each placeholder."),
    ])
    func eachProblemIsRefusedInPlainWords(problem: CommandProblem, words: String) {
        #expect(problem.refusal(named: named) == words)
    }

    @Test func aValueOfSpacesAndOtherPrintingCharactersIsTyped() async throws {
        #expect(try await Self.line("zmx attach {session}", inZmx(Self.kit), in: ZmxAdapter()) == "zmx attach 'kit · restore-card'")
    }
}
