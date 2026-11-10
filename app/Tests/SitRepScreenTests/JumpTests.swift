import Darwin
import SitRepCore
@testable import SitRepScreen
import Testing

/// SitRep's jump, each rule of the CLI's (tests/jump.test.ts, retired with it) pinned again: where it looks, what it
/// asks Ghostty, and the words it refuses in.
struct JumpTests {
    @Test func aJumpFocusesTheGhosttyWindowOnTheSessionsTmuxSession() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
    }

    @Test func aJumpAsksTmuxOnlyToListTheTableOnceAndTheFrontOnceThenGhosttyOnceForTheTerminalOnTheClientsDevice() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        _ = await jumping.run([inTmux()])

        #expect(tmux.runs.count == 2)
        #expect(Set(tmux.runs) == [[socket, "list-panes"], [socket, "list-clients"]])
        #expect(table.looks == 1)
        #expect(jumping.workspace.fronts == 1)
        #expect(jumping.ghostty.asked == [window])
        #expect(jumping.ghostty.told == ["focus SWITCHBOARD-TERMINAL"])
    }

    @Test func aJumpOutsideTmuxAsksGhosttyForTheTerminalOnTheWindowsOwnDeviceAskingTmuxAndTheTableNothing() async {
        let jumping = Jumping()

        #expect(await jumping.run([inGhosttyWindow]) == .jumped)
        #expect(jumping.ghostty.focused == ["KIT-TERMINAL"])
        #expect(jumping.ghostty.asked == [kitTerminal.device])
        #expect(jumping.tmux.runs.isEmpty)
        #expect(jumping.table.looks == 0)
    }

    /// One Ghostty window of two tabs, the first selected: the tab holding the session's terminal at `place`.
    private static func twoTabs(_ place: Int, holding held: [FakeTerminal] = [switchboardTerminal]) -> [FakeWindow] {
        var tabs = [[FakeTerminal(id: "SPARE-TERMINAL", device: "/dev/ttys091")]]

        tabs.insert(held, at: place)
        return [FakeWindow(id: "TABBED-WINDOW", tabs: tabs, selected: 0)]
    }

    @Test func aTerminalInItsWindowsSelectedTabIsOnlyFocused() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, terminals: Self.twoTabs(0))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["focus SWITCHBOARD-TERMINAL"])
        #expect(jumping.clock.sleeps.isEmpty)
    }

    @Test(arguments: [
        [switchboardTerminal], [FakeTerminal(id: "SPLIT-TERMINAL", device: "/dev/ttys092"), switchboardTerminal],
    ])
    func aTerminalInATabNotSelectedAloneOrInASplitHasItsWindowActivatedThenAPauseThenIsFocused(held: [FakeTerminal]) async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, terminals: Self.twoTabs(1, holding: held))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["activate window TABBED-WINDOW", "focus SWITCHBOARD-TERMINAL"])
        #expect(jumping.clock.sleeps == [GhosttyDriver.pause])
        #expect(jumping.ghostty.asked == [window])
    }

    @Test func thePauseBeforeFocusingATabNotSelectedIsHalfASecondWhichWasEnoughLiveWhereNoneWasNot() {
        #expect(GhosttyDriver.pause == .milliseconds(500))
    }

    /// Not on screen, never unknown, so a window can be opened for its pane.
    @Test func withNoClientOnTheSessionsTmuxServerTheTableGoesUnusedSoItGivingNoAnswerIsNoMatter() async {
        #expect(await Jumping(server([]), FakeTable(nil)).run([inTmux()]) == .openable)
    }

    @Test func aTmuxSessionThePhoneAndAGhosttyWindowBothShowGoesToTheGhosttyWindowAndGhosttyIsNeverAskedForThePhonesDevice() async {
        var mac = Mac()
        let clients = [mac.phoneClient(phone, showing: claudes), mac.ghosttyClient(window, showing: claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), terminals: terminals + ownWindows(FakeTerminal(id: "NOT-THE-PHONE", device: phone)))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.ghostty.asked == [window])
    }

    @Test func aClientTmuxGivesNoDeviceIsNoPlaceTheJumpGoesToTheGhosttyWindowAfterItNeverAskingForAnEmptyDevice() async {
        var mac = Mac()
        let clients = [mac.controlClient(showing: claudes), mac.ghosttyClient(window, showing: claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [window])
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
    }

    @Test func aClientWithNoDeviceAloneOnThePanesWindowIsOffScreenNeverAJumpLandedAndGhosttyIsAskedNothing() async {
        var mac = Mac()
        let clients = [mac.controlClient(showing: claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), workspace: FakeWorkspace(front: finder))

        #expect(await jumping.run([inTmux()]) == .openable)
        #expect(jumping.ghostty.asked.isEmpty)
        #expect(jumping.workspace.listened == 0, "no watch of the front")
    }

    /// The sessions no Ghostty window shows, each by why, and what the jump answers: a window to open where tmux holds
    /// the pane, else not on screen.
    private static func notShown() -> [(String, [Where], FakeTmux, FakeTable, JumpAnswer)] {
        var detached = Mac(), phoned = Mac(), sshed = Mac()

        return [
            ("no window saying where it is", [], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("a detached tmux session", [inTmux()], server([detached.ghosttyClient(kitTerminal.device, showing: kit)]), FakeTable(detached.tree), .openable),
            ("a tmux session only the phone shows", [inTmux()], server([phoned.phoneClient(phone, showing: claudes)]), FakeTable(phoned.tree), .openable),
            ("only a Ghostty on another Mac shows it, over ssh", [inTmux()], server([sshed.sshClient("/dev/ttys080", showing: claudes)]), FakeTable(sshed.tree), .openable),
            ("tmux answering that no server runs on the socket", [inTmux()], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("a window in a terminal app unknown to sitrep", [Where(device: "/dev/ttys041", terminal: "Unknown")], FakeTmux(), FakeTable(Mac().tree), offScreen),
        ]
    }

    @Test func aSessionNoGhosttyWindowShowsIsNotOnScreenAndGhosttyIsAskedNothing() async {
        for (why, windows, tmux, table, answer) in Self.notShown() {
            let jumping = Jumping(tmux, table, terminals: terminals + ownWindows(FakeTerminal(id: "LOOKALIKE", device: "/dev/ttys080")))

            #expect(await jumping.run(windows) == answer, "\(why)")
            #expect(jumping.ghostty.asked.isEmpty, "\(why)")
        }
    }

    @Test func aJumpThatCouldNotAskTmuxOrTheTableSaysItCouldNotTellNamingWhichAndAsksGhosttyNothing() async {
        let (tmux, table) = shown()
        let cases: [(Jumping, String)] = [
            (Jumping(FakeTmux(silent: true), table), "tmux"),
            (Jumping(tmux, FakeTable(nil)), "the process table"),
            (Jumping(FakeTmux(silent: true), FakeTable(nil)), "tmux"),
        ]

        for (jumping, unanswered) in cases {
            #expect(await jumping.run([inTmux()]) == .refused("Could not tell whether \(named) is on screen: \(unanswered) gave no answer."))
            #expect(jumping.ghostty.asked.isEmpty)
        }
    }

    @Test func aDeviceNoGhosttyTerminalIsOnFailsSayingWhichWithNothingFocused() async {
        var mac = Mac()
        let elsewhere = server([mac.ghosttyClient("/dev/ttys099", showing: claudes)])
        let (tmux, table) = shown()
        let cases: [(String, Jumping, Where, String)] = [
            ("a client of a Ghostty window on a device none of its terminals is on", Jumping(elsewhere, FakeTable(mac.tree)), inTmux(), "/dev/ttys099"),
            ("Ghostty not running", Jumping(tmux, table, running: false), inTmux(), window),
            ("Ghostty with no window open", Jumping(terminals: []), inGhosttyWindow, kitTerminal.device),
        ]

        for (why, jumping, place, device) in cases {
            #expect(await jumping.run([place]) == noneAnswered(device), "\(why)")
            #expect(jumping.ghostty.asked == [device], "\(why)")
            #expect(jumping.ghostty.focused.isEmpty, "\(why)")
        }
    }

    @Test(arguments: [
        (GhosttyFailure.gave(-1743, said: nil), "Not authorized to send Apple events to Ghostty. (-1743)"),
        (.noAnswer, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."),
        (.tooOld, "This Ghostty cannot say which of its windows is on a device, so SitRep cannot jump to one: update Ghostty to 1.4 or later."),
        (.gave(-1728, said: "Can’t get terminal 1."), "Ghostty got an error: Can’t get terminal 1. (-1728)"),
        (.gave(-600, said: nil), "Ghostty got an error (-600)."),
    ])
    func ghosttyThatCannotBeAskedIsRefusedInPlainWordsInTmuxOrOutWithNothingFocused(failure: GhosttyFailure, words: String) async {
        for place in [inTmux(), inGhosttyWindow] {
            let (tmux, table) = shown()
            let jumping = Jumping(tmux, table, failing: failure)

            #expect(await jumping.run([place]) == .refused(words))
            #expect(jumping.ghostty.asked.count == 1)
            #expect(jumping.ghostty.focused.isEmpty)
        }
    }

    @Test func aDeviceNoGhosttyTerminalIsOnIsPassedOverForTheNextWhichIsFocused() async {
        var mac = Mac()
        let clients = [mac.ghosttyClient("/dev/ttys099", showing: claudes), mac.ghosttyClient(window, showing: claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.ghostty.asked == ["/dev/ttys099", window])
    }

    @Test func whenNoGhosttyDeviceAnswersTheFailureNamesEveryOneAskedFor() async {
        var mac = Mac()
        let clients = ["/dev/ttys097", "/dev/ttys098", "/dev/ttys099"].map { mac.ghosttyClient($0, showing: claudes) }
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == noneAnswered("/dev/ttys097, /dev/ttys098 and /dev/ttys099"))
        #expect(jumping.ghostty.asked.count == 3)
    }

    @Test func ghosttyIsAskedOnlyOnceTheScreenIsReadNothingGoesToGhosttyWhileTmuxIsStillAnswering() async {
        let (tmux, table) = shown()
        let gate = Gate()
        let jumping = Jumping(tmux, table, tmuxHeld: gate)
        let jumped = Task { await jumping.run([inTmux()]) }

        await until { gate.arrived == 2 }
        await settle()
        #expect(jumping.ghostty.asked.isEmpty)
        #expect(jumping.workspace.fronts == 1, "the front is read as the jump begins, before tmux answers")

        gate.open()
        #expect(await jumped.value == .jumped)
        #expect(jumping.ghostty.asked == [window])
    }

    @Test func theFocusWaitsForTheReadOfWhichAppIsInFrontHoweverSlowSoTheJumpNeverReadsItsOwnFocus() async {
        let (tmux, table) = shown()
        let gate = Gate()
        let jumping = Jumping(tmux, table, workspace: FakeWorkspace(front: finder, frontHeld: gate))
        let jumped = Task { await jumping.run([inTmux()]) }

        await until { gate.arrived == 1 && tmux.runs.count == 2 && table.looks == 1 }
        await settle()
        #expect(tmux.runs.count == 2)
        #expect(jumping.ghostty.asked.isEmpty, "nothing asked or focused yet")

        gate.open()
        #expect(await jumped.value == .jumped)
        #expect(jumping.workspace.listened == 1, "the watch ran: Finder was in front")
    }

    @Test func aTmuxClientBehindARelayingPtyInAGhosttyWindowJumpsToTheTerminalOnTheDeviceOfGhosttysOwnChild() async {
        var mac = Mac()
        let shell = mac.tree.window(of: mac.ghostty, on: window)
        let client = mac.tree.tmux(under: mac.tree.relay(under: shell, on: "/dev/ttys050", "/usr/bin/script"), on: "/dev/ttys050")
        let jumping = Jumping(server([FakeClient(device: "/dev/ttys050", pid: client, window: claudes)]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [window])
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
    }

    @Test func aWindowInZmxFocusesTheGhosttyWindowHoldingItsClientThroughPortalsRelayAskingTheTableOnceAndTmuxNothing() async {
        var mac = Mac()

        mac.throughPortal("agentic-workflows-v2 · leeway-build", relay: "/dev/ttys032", window: "/dev/ttys036")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))

        #expect(await jumping.run([inZmx("agentic-workflows-v2 · leeway-build")]) == .jumped)
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
        #expect(jumping.ghostty.asked == ["/dev/ttys036"])
        #expect(jumping.table.looks == 1)
        #expect(jumping.tmux.runs.isEmpty)
    }

    @Test func aZmxSessionWithNoClientOrOnlyOtherSessionsClientsIsNotOnScreenAndGhosttyIsAskedNothing() async {
        var mac = Mac()

        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxServer("leeway")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree))

        #expect(await jumping.run([inZmx("leeway")]) == .openable)
        #expect(jumping.ghostty.asked.isEmpty)
    }

    @Test func inZmxTmuxMissingChangesNothingAsTmuxIsNeverAskedAndTheTableGivingNoAnswerLeavesItUnknownNeverOff() async {
        var mac = Mac()

        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys036")

        let missing = Jumping(FakeTmux(silent: true), FakeTable(mac.tree), terminals: ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))

        #expect(await missing.run([inZmx("kit")]) == .jumped)
        #expect(missing.tmux.runs.isEmpty)
        #expect(
            await Jumping(FakeTmux(), FakeTable(nil)).run([inZmx("kit")])
                == .refused("Could not tell whether \(named) is on screen: the process table gave no answer.")
        )
    }
}
