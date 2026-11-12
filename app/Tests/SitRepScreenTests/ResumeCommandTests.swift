import SitRepCore
@testable import SitRepScreen
import Testing

/// The resume command, as Lee sets it in Settings: none by default, its placeholders `{claude}` and `{dir}` filled with
/// the facts of an away session's last window, each quoted for the shell, and nothing typed that is not fit to type,
/// by the open command's rules (stage 8).
struct ResumeCommandTests {
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"
    private static let last = Board.LastWindow(writer: claude, directory: "/Users/lee/Code/lee's work")

    private static func line(_ command: String, _ last: Board.LastWindow = last) async throws -> String {
        try await ResumeCommand(command).line(from: last, named: named)
    }

    /// Lee's two: through Portal, and without it.
    @Test func itsPlaceholdersAreTheLastWindowsClaudeAndFolderEachQuoted() async throws {
        #expect(
            try await Self.line("portal open -p {dir} -- claude --resume {claude}")
                == #"portal open -p '/Users/lee/Code/lee'\''s work' -- claude --resume '\#(Self.claude)'"#
        )
        #expect(
            try await Self.line("cd {dir} && claude --resume {claude}")
                == #"cd '/Users/lee/Code/lee'\''s work' && claude --resume '\#(Self.claude)'"#
        )
    }

    @Test(arguments: ["", "  "])
    func noCommandIsRefusedSayingToSetOneInSettings(given: String) async {
        await #expect(throws: Unopenable(description: "No window holds \(named). To carry it on, set a resume command in Settings.")) {
            try await Self.line(given)
        }
    }

    /// `{session}`, `{socket}` and `{pane}` are the open command's: the resume command knows none of them.
    @Test(arguments: [
        ("claude --resume {session}", "The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude} and {dir}."),
        ("tmux -S {socket} new {pane}", "The resume command in Settings has {socket} and {pane}, which SitRep doesn't know. It knows {claude} and {dir}."),
        (#"cd "{dir}" && claude"#, "The resume command in Settings puts {dir} in quotes or backticks. Remove them: SitRep quotes each value itself."),
        ("claude --resume={claude}", "The resume command in Settings joins {claude} to other text. Put a space before and after each placeholder."),
        ("claude\t--resume {claude}", "The resume command in Settings has a tab, which can't be typed."),
    ])
    func aCommandSitRepCannotFillOrTypeIsRefusedInPlainWords(command: String, words: String) async {
        await #expect(throws: Unopenable(description: words)) {
            try await Self.line(command)
        }
    }

    /// A window on an older build said no folder: `{dir}` has nothing to fill it, so a command naming it is refused.
    @Test func aCommandNamingDirIsRefusedWhereTheLastWindowSaidNoFolder() async throws {
        let older = Board.LastWindow(writer: Self.claude)

        await #expect(throws: Unopenable(description: "\(named)'s last window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep has nothing to put for {dir}.")) {
            try await Self.line("cd {dir} && claude --resume {claude}", older)
        }
        #expect(try await Self.line("claude --resume {claude}", older) == "claude --resume '\(Self.claude)'")
    }

    /// A folder's name may hold a control, which the terminal and the line editor would act on before any quoting.
    @Test func aFolderHoldingACharacterThatPrintsNothingIsRefused() async {
        let last = Board.LastWindow(writer: Self.claude, directory: "/tmp/x\u{15}; touch pwned")

        await #expect(throws: Unopenable(description: "For \(named), the folder its Claude ran in has a character that can't be typed (U+0015).")) {
            try await Self.line("cd {dir}", last)
        }
    }
}
