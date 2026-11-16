import SitRepCore
@testable import SitRepScreen
import Testing

/// The resume command, as Lee sets it in Settings, the default until he gives another: its placeholders `{claude}`,
/// `{dir}` and `{tty}` filled with the facts of the window a click carries a session on from, each quoted for the
/// shell, and nothing typed that is not fit to type (stage 8's rethink).
struct ResumeCommandTests {
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"
    private static let window = Board.LastWindow(writer: claude, directory: "/Users/lee/Code/lee's work")

    private static func line(
        _ command: String, _ window: Board.LastWindow = window, tty: String? = nil
    ) async throws -> String {
        try await ResumeCommand(command).line(from: ResumeFacts(window: window, tty: tty), named: JumpWorld.named)
    }

    @Test func theDefaultResumesTheConversationInItsFolder() async throws {
        #expect(OpenSettings.defaultResumeCommand == "cd {dir} && claude --resume {claude}")
        #expect(OpenSettings().resumeCommand == OpenSettings.defaultResumeCommand)
        #expect(
            try await Self.line(OpenSettings.defaultResumeCommand)
                == #"cd '/Users/lee/Code/lee'\''s work' && claude --resume '\#(Self.claude)'"#
        )
    }

    /// The default is told by its text, as the shell reads it, the spaces round it aside: any other is Lee's.
    @Test func theDefaultIsToldByItsText() {
        #expect(ResumeCommand(OpenSettings.defaultResumeCommand).isDefault)
        #expect(ResumeCommand(" \(OpenSettings.defaultResumeCommand)\n").isDefault)
        #expect(!ResumeCommand("cd {dir} &&  claude --resume {claude}").isDefault)
        #expect(!ResumeCommand("cd {dir} && claude --resume {claude} --verbose").isDefault)
        #expect(!ResumeCommand("").isDefault)
    }

    /// `{tty}` is the device its Claude still runs on, where SitRep sees it there; otherwise empty, typed as `''`.
    @Test func ttyIsTheDeviceItsClaudeRunsOnElseEmpty() async throws {
        #expect(try await Self.line("attach {tty}", tty: "/dev/ttys041") == "attach '/dev/ttys041'")
        #expect(try await Self.line("attach {tty}") == "attach ''")
    }

    /// The examples DESIGN records, through the fill exactly as written: Lee's Portal one-liner, and tmux by `{tty}`.
    @Test func leesPortalOneLinerFillsAsWritten() async throws {
        let command = #"s=$(portal hook list | awk -F'\t' -v id={claude} 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && portal open -s "$s" || portal open -p {dir} -- claude --resume {claude}"#
        let window = Board.LastWindow(writer: Self.claude, directory: "/Users/lee/Code/leeway")

        #expect(ResumeCommand(command).problem == nil)
        #expect(try await Self.line(command, window) == #"s=$(portal hook list | awk -F'\t' -v id='\#(Self.claude)' 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && portal open -s "$s" || portal open -p '/Users/lee/Code/leeway' -- claude --resume '\#(Self.claude)'"#)
    }

    @Test func tmuxByTtyFillsAsWritten() async throws {
        let command = "t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d={tty} '$1==d {print $2; exit}'); [ -n \"$t\" ] && tmux attach -t \"$t\" || tmux new -c {dir} claude --resume {claude}"
        let window = Board.LastWindow(writer: Self.claude, directory: "/Users/lee/Code/leeway")
        let filled = { (tty: String) in
            "t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d='\(tty)' '$1==d {print $2; exit}'); [ -n \"$t\" ] && tmux attach -t \"$t\" || tmux new -c '/Users/lee/Code/leeway' claude --resume '\(Self.claude)'"
        }

        #expect(ResumeCommand(command).problem == nil)
        #expect(try await Self.line(command, window, tty: "/dev/ttys041") == filled("/dev/ttys041"))
        #expect(try await Self.line(command, window) == filled(""))
    }

    /// `{session}`, `{socket}` and `{pane}` went with the open command: SitRep keeps no multiplexer knowledge for
    /// resuming.
    @Test(arguments: [
        ("portal open -s {session}", "The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
        ("tmux -S {socket} attach -t {pane}", "The resume command in Settings has {socket} and {pane}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
        (#"cd "{dir}" && claude"#, "The resume command in Settings puts {dir} in quotes or backticks. Remove them: SitRep quotes each value itself."),
        ("claude\t--resume {claude}", "The resume command in Settings has a tab, which can't be typed."),
    ])
    func aCommandSitRepCannotFillOrTypeIsRefusedInPlainWords(command: String, words: String) async {
        await #expect(throws: Unopenable(description: words)) {
            try await Self.line(command)
        }
    }

    @Test(arguments: ["", "  "])
    func anEmptyCommandSaysToSetOneOrRestoreTheDefault(given: String) async {
        await #expect(throws: Unopenable(description: "The resume command in Settings is empty. To carry \(JumpWorld.named) on, set one, or restore the default.")) {
            try await Self.line(given)
        }
    }

    /// A window on an older build said no folder: `{dir}` has nothing to fill it, so a command naming it is refused.
    @Test func aCommandNamingDirIsRefusedWhereTheWindowSaidNoFolder() async throws {
        let older = Board.LastWindow(writer: Self.claude)

        await #expect(throws: Unopenable(description: "\(JumpWorld.named)'s last window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep has nothing to put for {dir}.")) {
            try await Self.line("cd {dir} && claude --resume {claude}", older)
        }
        #expect(try await Self.line("claude --resume {claude} {tty}", older) == "claude --resume '\(Self.claude)' ''")
    }

    /// A folder's name may hold a control, which the terminal and the line editor would act on before any quoting.
    @Test func aFolderHoldingACharacterThatPrintsNothingIsRefused() async {
        let window = Board.LastWindow(writer: Self.claude, directory: "/tmp/x\u{15}; touch pwned")

        await #expect(throws: Unopenable(description: "For \(JumpWorld.named), the folder its Claude ran in has a character that can't be typed (U+0015).")) {
            try await Self.line("cd {dir}", window)
        }
    }
}
