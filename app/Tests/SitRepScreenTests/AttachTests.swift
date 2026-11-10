import SitRepCore
@testable import SitRepScreen
import Testing

/// The attach commands, as Lee sets them in Settings: each multiplexer's, SitRep's own where left empty, its
/// placeholders filled from the window's heartbeat, each value quoted for the shell.
struct AttachTests {
    private static let kit = "kit · restore-card"

    @Test func sitRepsOwnAttachToTheZmxSessionAndToTheTmuxPaneOnItsSocket() {
        #expect(AttachCommands().command(for: .zmx).text == "zmx attach {session}")
        #expect(AttachCommands().command(for: .tmux).text == "tmux -S {socket} attach -t {pane}")
    }

    /// Empty, SitRep's own, so a default changed later reaches a Mac that never set one.
    @Test(arguments: ["", "  ", "\n"])
    func aCommandLeftEmptyIsSitRepsOwn(given: String) {
        let commands = AttachCommands(zmx: given, tmux: given)

        #expect(commands.command(for: .zmx).text == AttachCommands.zmxDefault)
        #expect(commands.command(for: .tmux).text == AttachCommands.tmuxDefault)
    }

    @Test func leesOwnIsTakenAsGivenLessTheSpacesAroundIt() {
        let commands = AttachCommands(zmx: " portal open -s {session} ", tmux: "tmux attach -t {session}")

        #expect(commands.command(for: .zmx).text == "portal open -s {session}")
        #expect(commands.command(for: .tmux).text == "tmux attach -t {session}")
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

    @Test func zmxFillsTheSessionByTheWindowsWholeName() async throws {
        let line = try await AttachCommand("zmx attach {session}").line(attaching: inZmx(Self.kit), in: ZmxAdapter())

        #expect(line == "zmx attach 'kit · restore-card'")
    }

    /// tmux's own asks tmux nothing: the socket and the pane are the heartbeat's.
    @Test func tmuxFillsTheSocketAndThePaneFromTheHeartbeatAskingTmuxNothing() async throws {
        let tmux = FakeTmux()
        let line = try await AttachCommand(AttachCommands.tmuxDefault).line(attaching: inTmux(), in: TmuxAdapter(tmux))

        #expect(line == "tmux -S /private/tmp/tmux-501/default attach -t %148")
        #expect(tmux.runs.isEmpty)
    }

    /// A tmux session can be renamed: its name is asked of tmux as the window opens, by the pane, which never changes.
    @Test func tmuxsSessionIsTheNameOfTheSessionHoldingThePaneAskedOfTmuxAsTheWindowOpens() async throws {
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
        ("zmx attach {pane}", MultiplexerKind.zmx, "the zmx attach command in Settings names {pane}, which SitRep cannot fill for zmx: it fills {session}."),
        ("zmx attach {sesion} {Session}", .zmx, "the zmx attach command in Settings names {sesion} and {Session}, which SitRep cannot fill for zmx: it fills {session}."),
        ("tmux attach -t {window}", .tmux, "the tmux attach command in Settings names {window}, which SitRep cannot fill for tmux: it fills {socket}, {pane} and {session}."),
    ])
    func aPlaceholderTheMultiplexerCannotFillIsRefusedNamingIt(command: String, kind: MultiplexerKind, words: String) async {
        let tmux = FakeTmux()
        let multiplexer: any Multiplexer = kind == .zmx ? ZmxAdapter() : TmuxAdapter(tmux)
        let window = kind == .zmx ? inZmx("kit") : inTmux()

        await #expect(throws: Unattachable(description: words)) {
            try await AttachCommand(command).line(attaching: window, in: multiplexer)
        }
        #expect(tmux.runs.isEmpty)
    }
}
