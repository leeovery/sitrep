@testable import SitRepScreen
import Testing

struct AppsTests {
    @Test func ghosttysDriverIsToldByItsProgramOutsideAMultiplexerAndByItsExecutableAmongProcesses() {
        #expect(Driver.all == [.ghostty])
        #expect(TerminalApp(program: "ghostty") == .driven(.ghostty))
        #expect(TerminalApp(path: ghosttyProgram) == .driven(.ghostty))
        #expect(TerminalApp(path: ghosttyProgram)?.name == "Ghostty")
    }

    @Test func anAppWithNoDriverIsToldByItsTermProgramInTheTable() {
        #expect(TerminalApp(program: "Apple_Terminal") == .bundled(name: "Terminal", bundles: ["com.apple.Terminal"]))
        #expect(TerminalApp(program: "iTerm.app")?.name == "iTerm2")
        #expect(TerminalApp(program: "WezTerm")?.name == "WezTerm")
        #expect(
            TerminalApp(program: "WarpTerminal") == .bundled(name: "Warp", bundles: ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"])
        )
    }

    @Test(arguments: ["tmux", "Unknown", "", "vscode", nil] as [String?])
    func anyOtherTermProgramIsNoApp(program: String?) {
        #expect(TerminalApp(program: program) == nil)
    }

    @Test func aProgramInsideABundleIsThatAppTheOutermostByItsPathThoughItsNameHoldsADash() {
        #expect(TerminalApp(path: "/Foo.app/Contents/MacOS/foo") == .atPath(name: "Foo", path: "/Foo.app"))
        #expect(
            TerminalApp(path: terminalProgram)
                == .atPath(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app")
        )
        #expect(TerminalApp(path: codeHelper) == .atPath(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app"))
        #expect(
            TerminalApp(
                path: "/Applications/Visual Studio Code - Insiders.app/Contents/Frameworks/Code - Insiders Helper (Plugin).app/Contents/MacOS/Code - Insiders Helper (Plugin)"
            )?.name == "Visual Studio Code - Insiders"
        )
    }

    @Test func iTerm2sServerOutsideItsBundleIsITerm2s() {
        #expect(
            TerminalApp(path: "/Users/me/Library/Application Support/iTerm2/iTermServer-3.5.4")
                == .bundled(name: "iTerm2", bundles: ["com.googlecode.iterm2"])
        )
    }

    @Test(arguments: [
        "/bin/zsh", "/usr/bin/login", "/opt/homebrew/bin/mosh-server", "/usr/sbin/sshd", "/opt/homebrew/bin/tmux",
        "/Applications/Foo.app", "/opt/ghostty-tools/bin/ghostty-launcher",
    ])
    func aProgramInNoAppIsNone(path: String) {
        #expect(TerminalApp(path: path) == nil)
    }

    @Test func aDriverNeedsADeviceToFindItsWindowAndAnAppWithNoDriverNeedsNone() {
        #expect(TerminalApp.driven(.ghostty).reaches("/dev/ttys000"))
        #expect(!TerminalApp.driven(.ghostty).reaches(nil))
        #expect(TerminalApp(program: "iTerm.app")?.reaches(nil) == true)
        #expect(TerminalApp(path: terminalProgram)?.reaches(nil) == true)
    }
}
