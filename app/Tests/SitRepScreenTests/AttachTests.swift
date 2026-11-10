import SitRepCore
@testable import SitRepScreen
import Testing

/// The attach commands, as Lee sets them in Settings: each multiplexer's, SitRep's own where left empty, its
/// placeholders filled from the window's heartbeat, each value quoted for the shell, and nothing typed that is not fit
/// to type.
struct AttachTests {
    private static let kit = "kit · restore-card"

    @Test func sitRepsOwnAttachToTheZmxSessionAndToTheTmuxPaneOnItsSocket() {
        #expect(AttachCommands().command(for: .zmx) == AttachCommand("zmx attach {session}"))
        #expect(AttachCommands().command(for: .tmux) == AttachCommand("tmux -S {socket} attach -t {pane}"))
    }

    /// Empty, SitRep's own, so a default changed later reaches a Mac that never set one.
    @Test(arguments: ["", "  ", "\n"])
    func aCommandLeftEmptyIsSitRepsOwn(given: String) {
        let commands = AttachCommands(zmx: given, tmux: given)

        #expect(commands.command(for: .zmx) == AttachCommand(AttachCommands.zmxDefault))
        #expect(commands.command(for: .tmux) == AttachCommand(AttachCommands.tmuxDefault))
    }

    @Test func leesOwnIsTakenAsGivenLessTheSpacesAroundIt() {
        let commands = AttachCommands(zmx: " portal open -s {session} ", tmux: "tmux attach -t {session}")

        #expect(commands.command(for: .zmx) == AttachCommand("portal open -s {session}"))
        #expect(commands.command(for: .tmux) == AttachCommand("tmux attach -t {session}"))
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
        let command = AttachCommand("portal open -s {session} # {session}")

        #expect(command.filled([.session: Self.kit]) == "portal open -s 'kit · restore-card' # 'kit · restore-card'")
    }

    /// `{a,b}` is the shell's own braces, and `{ x; }` its group: neither is a placeholder.
    @Test func shellBracesAreNoPlaceholderAndAreLeftAsWritten() {
        let command = AttachCommand("{ zmx attach {session}; } && echo {a,b}")

        #expect(command.named == ["session"])
        #expect(command.filled([.session: "kit"]) == "{ zmx attach kit; } && echo {a,b}")
    }

    /// The shell's `${…}`, tmux's `#{…}` and a brace escaped are never placeholders, so never refused nor filled.
    @Test(arguments: [
        "echo ${HOME} && zmx attach {session}",
        "tmux display -p '#{session_name}'; zmx attach {session}",
        #"echo \{session} && zmx attach {session}"#,
        "echo ${session} && zmx attach {session}",
    ])
    func aBraceAfterADollarAHashOrABackslashIsNoPlaceholder(command: String) {
        let parsed = AttachCommand(command)

        #expect(parsed.named == ["session"])
        #expect(parsed.problem(for: .zmx) == nil)
        #expect(parsed.filled([.session: "a b"]) == command.replacing("zmx attach {session}", with: "zmx attach 'a b'"))
    }

    /// Quotes of its own around a placeholder would put SitRep's inside them: in double quotes the name gains literal
    /// quotes, and zmx makes a new empty session; in single quotes it splits into words, and a `;` in it runs what
    /// follows.
    @Test(arguments: [
        #"zmx attach "{session}""#, "zmx attach '{session}'", "zmx attach $'{session}'", #"zmx attach "x{session}y""#,
    ])
    func aPlaceholderInsideQuotesIsRefused(command: String) {
        #expect(AttachCommand(command).problem(for: .zmx) == .quoted(["session"]))
    }

    @Test(arguments: [
        #"echo "it's" && zmx attach {session}"#, #"echo 'say "hi"' && zmx attach {session}"#,
        #"echo "a\"b" && zmx attach {session}"#, #"echo $'it\'s' && zmx attach {session}"#,
    ])
    func quotesClosedBeforeThePlaceholderLeaveItUnquoted(command: String) {
        #expect(AttachCommand(command).problem(for: .zmx) == nil)
    }

    /// The terminal and the line editor act on a control byte before any quoting: ^U erases what was typed, ^C
    /// abandons the line, ESC starts an editor sequence, and a newline or a tab runs or completes it.
    @Test(arguments: [
        ("\u{15}", "U+0015"), ("\u{03}", "U+0003"), ("\u{7F}", "U+007F"), ("\u{1B}", "U+001B"), ("\n", "U+000A"),
        ("\t", "U+0009"), ("\u{85}", "U+0085"), ("\u{202E}", "U+202E"),
    ])
    func aValueHoldingAControlOrOtherCharacterThatPrintsNothingIsRefused(character: String, code: String) async {
        let session = "x\(character)touch pwned; echo '"

        await #expect(throws: Unattachable(description: "its {session} holds a character that cannot be typed safely (\(code)).")) {
            try await AttachCommand("zmx attach {session}").line(attaching: inZmx(session), in: ZmxAdapter(FakeZmx(listing: [session])))
        }
    }

    @Test(arguments: ["zmx attach\t{session}", "zmx attach {session}\u{15}", "zmx\u{1B}attach {session}"])
    func aCommandHoldingAControlIsRefused(command: String) {
        guard case .unprintable = AttachCommand(command).problem(for: .zmx) else {
            Issue.record("\(command.debugDescription) was not refused")
            return
        }
    }

    @Test func aValueOfSpacesAndOtherPrintingCharactersIsTyped() async throws {
        let line = try await AttachCommand("zmx attach {session}").line(attaching: inZmx(Self.kit), in: ZmxAdapter(FakeZmx()))

        #expect(line == "zmx attach 'kit · restore-card'")
    }

    /// zmx is asked whether it has the session, as `zmx attach` would make a session gone anew, empty.
    @Test func zmxIsAskedForItsSessionsAndOneItDoesNotListIsGone() async {
        let zmx = FakeZmx(listing: ["kit"])

        await #expect(throws: SessionGone.self) {
            try await AttachCommand("zmx attach {session}").line(attaching: inZmx(Self.kit), in: ZmxAdapter(zmx))
        }
        #expect(zmx.runs == [["list", "--short"]])
    }

    /// tmux's own asks tmux nothing: the socket and the pane are the heartbeat's.
    @Test func tmuxFillsTheSocketAndThePaneFromTheHeartbeatAskingTmuxNothing() async throws {
        let tmux = FakeTmux()
        let line = try await AttachCommand(AttachCommands.tmuxDefault).line(attaching: inTmux(), in: TmuxAdapter(tmux))

        #expect(line == "tmux -S /private/tmp/tmux-501/default attach -t %148")
        #expect(tmux.runs.isEmpty)
    }

    /// A tmux session can be renamed: its name is asked of tmux as the jump finds the window, by the pane, which never
    /// changes.
    @Test func tmuxsSessionIsTheNameOfTheSessionHoldingThePaneAskedOfTmux() async throws {
        let panes = [FakePane(pane: "%148", window: claudes, session: "$45")]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, names: ["$45": "work · renamed"])])
        let line = try await AttachCommand("tmux -S {socket} attach -t {session}").line(attaching: inTmux(), in: TmuxAdapter(tmux))

        #expect(line == "tmux -S /private/tmp/tmux-501/default attach -t 'work · renamed'")
        #expect(tmux.words == [["display-message", "-p", "-t", "%148", "#{session_name}"]])
    }

    @Test(arguments: [
        (FakeTmux(silent: true), "tmux, asked which session holds its pane, gave no answer."),
        (FakeTmux([socket: FakeServer()]), "tmux, asked which session holds its pane, said: can't find pane: %148"),
        (FakeTmux(), "tmux, asked which session holds its pane, said: no server running on /private/tmp/tmux-501/default"),
    ])
    func tmuxNotNamingTheSessionIsRefusedInItsWords(tmux: FakeTmux, words: String) async {
        await #expect(throws: Unattachable(description: words)) {
            try await AttachCommand("tmux attach -t {session}").line(attaching: inTmux(), in: TmuxAdapter(tmux))
        }
    }

    /// Never typed as written: `zmx attach` makes a session of a name it does not have.
    @Test(arguments: [
        ("zmx attach {pane}", MultiplexerKind.zmx, "the zmx attach command in Settings names {pane}, which SitRep cannot fill for zmx: use {session}."),
        ("zmx attach {sesion} {Session}", .zmx, "the zmx attach command in Settings names {sesion} and {Session}, which SitRep cannot fill for zmx: use {session}."),
        ("tmux attach -t {window}", .tmux, "the tmux attach command in Settings names {window}, which SitRep cannot fill for tmux: use {socket}, {pane} or {session}."),
    ])
    func aPlaceholderTheMultiplexerCannotFillIsRefusedNamingIt(command: String, kind: MultiplexerKind, words: String) async {
        let tmux = FakeTmux()
        let zmx = FakeZmx()
        let multiplexer: any Multiplexer = kind == .zmx ? ZmxAdapter(zmx) : TmuxAdapter(tmux)
        let window = kind == .zmx ? inZmx("kit") : inTmux()

        await #expect(throws: Unattachable(description: words)) {
            try await AttachCommand(command).line(attaching: window, in: multiplexer)
        }
        #expect(tmux.runs.isEmpty && zmx.runs.isEmpty)
    }

    /// Settings says what is wrong as Lee types, in a sentence of its own; nothing for SitRep's own, or for one left
    /// empty.
    @Test(arguments: [
        ("zmx attach {pane}", "Names {pane}, which SitRep cannot fill for zmx: use {session}."),
        (#"zmx attach "{session}""#, "Puts {session} in quotes: SitRep quotes each value itself."),
        ("zmx attach\t{session}", "Holds a character that cannot be typed safely (U+0009)."),
    ])
    func settingsWarnsOfACommandAsItIsTyped(command: String, warning: String) {
        #expect(AttachCommands.warning(about: command, for: .zmx) == warning)
    }

    @Test(arguments: ["", "portal open -s {session}", AttachCommands.zmxDefault])
    func settingsWarnsOfNothingForACommandFitToType(command: String) {
        #expect(AttachCommands.warning(about: command, for: .zmx) == nil)
    }
}
