import Darwin
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// Terminal apps with no driver, brought forward whole once found running, never launched; and an app that cannot be
/// asked passed over for the next.
struct JumpAppsTests {
    @Test(arguments: [
        ("iTerm.app", "com.googlecode.iterm2", [["com.googlecode.iterm2"]]),
        ("Apple_Terminal", "com.apple.Terminal", [["com.apple.Terminal"]]),
        ("WezTerm", "com.github.wez.wezterm", [["com.github.wez.wezterm"]]),
        ("WarpTerminal", "dev.warp.Warp-Stable", [["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"]]),
        ("WarpTerminal", "dev.warp.Warp-Preview", [["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"]]),
    ])
    func aWindowOutsideTmuxInAnAppWithNoDriverIsBroughtForwardWholeByItsBundleOnceFoundRunningAndNothingMore(
        program: String, bundle: String, asked: [[String]]
    ) async {
        let jumping = Jumping(workspace: FakeWorkspace(front: finder, running: [bundle]))

        #expect(await jumping.run([Where(device: "/dev/ttys041", terminal: program)]) == .jumped)
        #expect(jumping.workspace.runningAsked == asked)
        #expect(jumping.workspace.brought == [bundled(bundle).absoluteString])
        #expect(jumping.tmux.runs.isEmpty && jumping.table.looks == 0 && jumping.ghostty.asked.isEmpty, "no tmux, table or Ghostty")
        #expect(jumping.workspace.listened == 0, "no watch of the front")
    }

    @Test func anAppWithNoDriverThatIsNotRunningIsNeverBroughtForwardWhichMightLaunchItItsPlaceDoesNotAnswer() async {
        let jumping = Jumping(workspace: FakeWorkspace(running: []))

        #expect(await jumping.run([Where(device: "/dev/ttys041", terminal: "iTerm.app")]) == noneAnswered("/dev/ttys041", "iTerm2"))
        #expect(jumping.workspace.runningAsked == [["com.googlecode.iterm2"]])
        #expect(jumping.workspace.brought.isEmpty)
    }

    @Test func aWindowOutsideTmuxInAnAppWithNoDriverNeedsNoDeviceTheAppIsBroughtForwardWhole() async {
        let running = Jumping(workspace: FakeWorkspace(running: ["com.googlecode.iterm2"]))
        let stopped = Jumping(workspace: FakeWorkspace(running: []))

        #expect(await running.run([Where(terminal: "iTerm.app")]) == .jumped)
        #expect(running.workspace.brought == [bundled("com.googlecode.iterm2").absoluteString])
        #expect(await stopped.run([Where(terminal: "iTerm.app")]) == .refused("\(JumpWorld.named) shows in iTerm2, which did not come forward."))
    }

    @Test func aTmuxClientInAnAppWithNoDriverIsBroughtForwardAsTheAppItDescendsFromByItsPathAndAfterASelectWhereItShowsAnother() async {
        var shownMac = Mac(), besideMac = Mac()
        let shown = Jumping(
            server([shownMac.terminalClient(JumpWorld.window, showing: JumpWorld.claudes)]), FakeTable(shownMac.tree),
            workspace: FakeWorkspace(at: [JumpWorld.terminalApp])
        )
        let elsewhere = Jumping(
            server([besideMac.terminalClient(JumpWorld.window, showing: JumpWorld.beside, in: "$7")], sessions: ["$7"]), FakeTable(besideMac.tree),
            workspace: FakeWorkspace(at: [JumpWorld.terminalApp])
        )

        for jumping in [shown, elsewhere] {
            #expect(await jumping.run([inTmux()]) == .jumped)
            #expect(jumping.workspace.pathsAsked == [JumpWorld.terminalApp])
            #expect(jumping.workspace.runningAsked.isEmpty)
            #expect(jumping.workspace.brought == [atPath(JumpWorld.terminalApp).absoluteString])
            #expect(jumping.ghostty.asked.isEmpty)
        }

        #expect(shown.selects.isEmpty)
        #expect(elsewhere.selects == ["$7:@45"])
    }

    @Test func anAppWithNoDriverThatDoesNotComeForwardIsPassedOverForTheNextPlaceAndTheFailureNamesEachAppTried() async {
        var mac = Mac()
        let clients = [mac.terminalClient("/dev/ttys099", showing: JumpWorld.claudes), mac.ghosttyClient("/dev/ttys098", showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), workspace: FakeWorkspace(at: [JumpWorld.terminalApp], forward: false))

        #expect(await jumping.run([inTmux()]) == noneAnswered("/dev/ttys099 and /dev/ttys098", "Terminal or Ghostty"))
        #expect(jumping.workspace.brought.count == 1)
        #expect(jumping.ghostty.asked == ["/dev/ttys098"])
    }

    @Test func bringingAnAppForwardIsLetGoAtTwoSecondsAsTheCLIsOpenWasSoLaunchServicesNotAnsweringGivesWayToTheNextPlace() async {
        var mac = Mac()
        let clients = [mac.terminalClient("/dev/ttys030", showing: JumpWorld.claudes), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), workspace: FakeWorkspace(at: [JumpWorld.terminalApp], forward: nil))
        let jumped = Task { await jumping.run([inTmux()]) }

        await until(within: .seconds(10)) { jumping.clock.sleeps.contains(.seconds(2)) }
        jumping.clock.pass(.seconds(2))

        #expect(await jumped.value == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
    }

    @Test func aTmuxClientUnderITerm2sServerOutsideItsBundleIsITerm2sBroughtForwardByItsBundleOnceFoundRunning() async {
        var mac = Mac()
        let iTermServer = mac.tree.app("/Users/lee/Library/Application Support/iTerm2/iTermServer-3.5.4")
        let client = mac.tree.tmux(under: mac.tree.window(of: iTermServer, on: JumpWorld.window), on: JumpWorld.window)
        let jumping = Jumping(
            server([FakeClient(device: JumpWorld.window, pid: client, window: JumpWorld.claudes)]), FakeTable(mac.tree),
            workspace: FakeWorkspace(running: ["com.googlecode.iterm2"])
        )

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.workspace.runningAsked == [["com.googlecode.iterm2"]])
        #expect(jumping.workspace.brought == [bundled("com.googlecode.iterm2").absoluteString])
    }

    @Test func aZmxClientInATerminalAppWithNoDriverBringsThatAppForwardByItsPath() async {
        var mac = Mac()

        mac.zmxInTerminal("kit", on: "/dev/ttys030")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), workspace: FakeWorkspace(at: [JumpWorld.terminalApp]))

        #expect(await jumping.run([inZmx("kit")]) == .jumped)
        #expect(jumping.workspace.brought == [atPath(JumpWorld.terminalApp).absoluteString])
        #expect(jumping.ghostty.asked.isEmpty)
    }

    /// Claude's tmux window shown by two Ghostty windows, then a Terminal window.
    private static func ghosttyThenTerminal(
        terminals: [FakeWindow] = JumpWorld.terminals, failing: GhosttyFailure? = nil, forward: Bool = true
    ) -> Jumping {
        var mac = Mac()
        let clients = [
            mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes), mac.ghosttyClient("/dev/ttys031", showing: JumpWorld.claudes),
            mac.terminalClient("/dev/ttys030", showing: JumpWorld.claudes),
        ]

        return Jumping(
            server(clients), FakeTable(mac.tree), terminals: terminals, failing: failing,
            workspace: FakeWorkspace(at: [JumpWorld.terminalApp], forward: forward)
        )
    }

    @Test func clientsInGhosttyOnDevicesNoneOfItsTerminalsIsOnEachGiveWayInTurnAndTheNextAppIsBroughtForward() async {
        let jumping = Self.ghosttyThenTerminal(terminals: ownWindows(FakeTerminal(id: "ELSEWHERE", device: "/dev/ttys090")))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window, "/dev/ttys031"])
        #expect(jumping.workspace.brought == [atPath(JumpWorld.terminalApp).absoluteString])
        #expect(jumping.ghostty.focused.isEmpty)
    }

    @Test(arguments: [GhosttyFailure.noAnswer, .tooOld, .gave(-1743, said: nil)])
    func ghosttyUnableToBeAskedIsPassedOverAtItsPlacesAfterAndTheNextAppBroughtForward(failure: GhosttyFailure) async {
        let jumping = Self.ghosttyThenTerminal(failing: failure)

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window], "Ghostty asked once")
        #expect(jumping.workspace.brought == [atPath(JumpWorld.terminalApp).absoluteString])
    }

    @Test func whatStoppedGhosttyAtTheMostWantedPlaceIsWhatTheJumpIsRefusedForOnceNoPlaceIsLeft() async {
        let cases: [(Jumping, JumpAnswer)] = [
            (Self.ghosttyThenTerminal(terminals: [], forward: false), noneAnswered("\(JumpWorld.window), /dev/ttys031 and /dev/ttys030", "Ghostty or Terminal")),
            (Self.ghosttyThenTerminal(failing: .noAnswer, forward: false), .refused(GhosttyFailure.noAnswer.description)),
            (Self.ghosttyThenTerminal(failing: .tooOld, forward: false), .refused(GhosttyFailure.tooOld.description)),
            (Self.ghosttyThenTerminal(failing: .gave(-1743, said: nil), forward: false), .refused("Not authorized to send Apple events to Ghostty. (-1743)")),
        ]

        for (jumping, refused) in cases {
            #expect(await jumping.run([inTmux()]) == refused)
            #expect(jumping.workspace.brought.count == 1, "Terminal was tried")
        }
    }
}
