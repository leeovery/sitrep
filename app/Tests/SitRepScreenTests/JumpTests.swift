import Darwin
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// SitRep's jump, each rule of the CLI's (tests/jump.test.ts, retired with it) pinned again: where it looks, what it
/// asks Ghostty, and the words it refuses in.
@Suite(.backstop)
struct JumpTests {
    @Test func aJumpFocusesTheGhosttyWindowOnTheSessionsTmuxSession() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }

    @Test func aJumpAsksTmuxOnlyToListTheTableOnceAndTheFrontOnceThenGhosttyOnceForTheTerminalOnTheClientsDevice() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        _ = await jumping.run([inTmux()])

        #expect(tmux.runs.count == 2)
        #expect(Set(tmux.runs) == [[socket, "list-panes"], [socket, "list-clients"]])
        #expect(table.looks == 1)
        #expect(jumping.workspace.fronts == 1)
        #expect(jumping.ghostty.asked == [JumpWorld.window])
        #expect(jumping.ghostty.told == ["focus WOODGROVE-TERMINAL"])
    }

    @Test func aJumpOutsideTmuxAsksGhosttyForTheTerminalOnTheWindowsOwnDeviceAskingTmuxAndTheTableNothing() async {
        let jumping = Jumping()

        #expect(await jumping.run([inGhosttyWindow]) == .jumped)
        #expect(jumping.ghostty.focused == ["LITWARE-TERMINAL"])
        #expect(jumping.ghostty.asked == [JumpWorld.litwareTerminal.device])
        #expect(jumping.tmux.runs.isEmpty)
        #expect(jumping.table.looks == 0)
    }

    /// One Ghostty window of two tabs, the first selected: the tab holding the session's terminal at `place`.
    private static func twoTabs(_ place: Int, holding held: [FakeTerminal] = [JumpWorld.woodgroveTerminal]) -> [FakeWindow] {
        var tabs = [[FakeTerminal(id: "SPARE-TERMINAL", device: "/dev/ttys091")]]

        tabs.insert(held, at: place)
        return [FakeWindow(id: "TABBED-WINDOW", tabs: tabs, selected: 0)]
    }

    @Test func aTerminalInItsWindowsSelectedTabIsOnlyFocused() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, terminals: Self.twoTabs(0))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["focus WOODGROVE-TERMINAL"])
        #expect(jumping.clock.sleeps.isEmpty)
    }

    @Test(arguments: [
        [JumpWorld.woodgroveTerminal], [FakeTerminal(id: "SPLIT-TERMINAL", device: "/dev/ttys092"), JumpWorld.woodgroveTerminal],
    ])
    func aTerminalInATabNotSelectedAloneOrInASplitHasItsWindowActivatedThenAPauseThenIsFocused(held: [FakeTerminal]) async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, terminals: Self.twoTabs(1, holding: held))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["activate window TABBED-WINDOW", "focus WOODGROVE-TERMINAL"])
        #expect(jumping.clock.sleeps == [.milliseconds(500)], "which was enough live where none was not")
        #expect(jumping.ghostty.asked == [JumpWorld.window])
    }

    @Test func withNoClientOnTheSessionsTmuxServerTheTableGoesUnusedSoItGivingNoAnswerIsNoMatter() async {
        #expect(await Jumping(server([]), FakeTable(nil)).run([inTmux()]) == JumpWorld.offScreen)
    }

    @Test func aTmuxSessionThePhoneAndAGhosttyWindowBothShowGoesToTheGhosttyWindowAndGhosttyIsNeverAskedForThePhonesDevice() async {
        var mac = Mac()
        let clients = [mac.phoneClient(JumpWorld.phone, showing: JumpWorld.claudes), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), terminals: JumpWorld.terminals + ownWindows(FakeTerminal(id: "NOT-THE-PHONE", device: JumpWorld.phone)))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
        #expect(jumping.ghostty.asked == [JumpWorld.window])
    }

    @Test func aClientTmuxGivesNoDeviceIsNoPlaceTheJumpGoesToTheGhosttyWindowAfterItNeverAskingForAnEmptyDevice() async {
        var mac = Mac()
        let clients = [mac.controlClient(showing: JumpWorld.claudes), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window])
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }

    @Test func aClientWithNoDeviceAloneOnThePanesWindowIsOffScreenNeverAJumpLandedAndGhosttyIsAskedNothing() async {
        var mac = Mac()
        let clients = [mac.controlClient(showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree), workspace: FakeWorkspace(front: finder))

        #expect(await jumping.run([inTmux()]) == JumpWorld.offScreen)
        #expect(jumping.ghostty.asked.isEmpty)
        #expect(jumping.workspace.listened == 0, "no watch of the front")
    }

    /// The sessions no Ghostty window shows, each by why.
    private static func notShown() -> [(String, [Where], FakeTmux, FakeTable)] {
        var detached = Mac(), phoned = Mac(), sshed = Mac()

        return [
            ("no window saying where it is", [], FakeTmux(), FakeTable(Mac().tree)),
            ("a detached tmux session", [inTmux()], server([detached.ghosttyClient(JumpWorld.litwareTerminal.device, showing: JumpWorld.litware)]), FakeTable(detached.tree)),
            ("a tmux session only the phone shows", [inTmux()], server([phoned.phoneClient(JumpWorld.phone, showing: JumpWorld.claudes)]), FakeTable(phoned.tree)),
            ("only a Ghostty on another Mac shows it, over ssh", [inTmux()], server([sshed.sshClient("/dev/ttys080", showing: JumpWorld.claudes)]), FakeTable(sshed.tree)),
            ("tmux answering that no server runs on the socket", [inTmux()], FakeTmux(), FakeTable(Mac().tree)),
            ("a window in a terminal app unknown to sitrep", [Where(device: "/dev/ttys041", terminal: "Unknown")], FakeTmux(), FakeTable(Mac().tree)),
        ]
    }

    @Test func aSessionNoGhosttyWindowShowsIsNotOnScreenAndGhosttyIsAskedNothing() async {
        for (why, windows, tmux, table) in Self.notShown() {
            let jumping = Jumping(tmux, table, terminals: JumpWorld.terminals + ownWindows(FakeTerminal(id: "LOOKALIKE", device: "/dev/ttys080")))

            #expect(await jumping.run(windows) == JumpWorld.offScreen, "\(why)")
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
            #expect(await jumping.run([inTmux()]) == .refused("Could not tell whether \(JumpWorld.named) is on screen: \(unanswered) gave no answer."))
            #expect(jumping.ghostty.asked.isEmpty)
        }
    }

    @Test func aJumpTmuxFailedForSaysWhatTmuxSaidWhereOnlyARealSilenceGaveNoAnswer() {
        let mismatch = "protocol version mismatch (client 8, server 7)"
        let cases: [([Unanswered], String)] = [
            ([.tmuxSaid(mismatch)], "tmux said \"\(mismatch)\""),
            ([.tmuxSaid("")], "tmux failed without saying why"),
            ([.tmuxSaid(mismatch), .processes], "the process table gave no answer, and tmux said \"\(mismatch)\""),
            ([.tmux, .tmuxSaid(mismatch)], "tmux gave no answer, and tmux said \"\(mismatch)\""),
            (
                [.tmux, .tmuxSaid(mismatch), .processes],
                "tmux and the process table gave no answer, and tmux said \"\(mismatch)\""
            ),
            ([.tmux, .processes], "tmux and the process table gave no answer"),
        ]

        for (unanswered, why) in cases {
            #expect(Jumped.unknown(unanswered).answer(named: JumpWorld.named) == .refused("Could not tell whether \(JumpWorld.named) is on screen: \(why)."))
        }
    }

    @Test func aDeviceNoGhosttyTerminalIsOnFailsSayingWhichWithNothingFocused() async {
        var mac = Mac()
        let elsewhere = server([mac.ghosttyClient("/dev/ttys099", showing: JumpWorld.claudes)])
        let (tmux, table) = shown()
        let cases: [(String, Jumping, Where, String)] = [
            ("a client of a Ghostty window on a device none of its terminals is on", Jumping(elsewhere, FakeTable(mac.tree)), inTmux(), "/dev/ttys099"),
            ("Ghostty not running", Jumping(tmux, table, running: false), inTmux(), JumpWorld.window),
            ("Ghostty with no window open", Jumping(terminals: []), inGhosttyWindow, JumpWorld.litwareTerminal.device),
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
        let clients = [mac.ghosttyClient("/dev/ttys099", showing: JumpWorld.claudes), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)]
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
        #expect(jumping.ghostty.asked == ["/dev/ttys099", JumpWorld.window])
    }

    @Test func whenNoGhosttyDeviceAnswersTheFailureNamesEveryOneAskedFor() async {
        var mac = Mac()
        let clients = ["/dev/ttys097", "/dev/ttys098", "/dev/ttys099"].map { mac.ghosttyClient($0, showing: JumpWorld.claudes) }
        let jumping = Jumping(server(clients), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == noneAnswered("/dev/ttys097, /dev/ttys098 and /dev/ttys099"))
        #expect(jumping.ghostty.asked.count == 3)
    }

    @available(macOS 15, *)
    @Test func ghosttyIsAskedOnlyOnceTheScreenIsReadNothingGoesToGhosttyWhileTmuxIsStillAnswering() async throws {
        let (tmux, table) = shown()
        let gate = Gate()
        let idling = Idling()
        let jumping = Jumping(tmux, table, tmuxHeld: gate)
        let jumped = Task(executorPreference: idling) { await jumping.run([inTmux()]) }

        try await until(
            within: .seconds(10), "for tmux's two asks, the screen's read, the front's read, and the jump idle on tmux"
        ) { gate.arrived == 2 && table.looks == 1 && jumping.workspace.fronts == 1 && idling.isIdle }
        #expect(jumping.ghostty.asked.isEmpty)

        gate.open()
        #expect(try await value(of: jumped, within: .seconds(10)) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window])
    }

    @available(macOS 15, *)
    @Test func theFocusWaitsForTheReadOfWhichAppIsInFrontHoweverSlowSoTheJumpNeverReadsItsOwnFocus() async throws {
        let (tmux, table) = shown()
        let gate = Gate()
        let idling = Idling()
        let jumping = Jumping(tmux, table, workspace: FakeWorkspace(front: finder, frontHeld: gate))
        let jumped = Task(executorPreference: idling) { await jumping.run([inTmux()]) }

        try await until(within: .seconds(10), "for tmux's two runs, the screen's read, and the jump idle on the front") {
            gate.arrived == 1 && tmux.runs.count == 2 && table.looks == 1 && idling.isIdle
        }
        #expect(jumping.ghostty.asked.isEmpty, "nothing asked or focused yet")

        gate.open()
        #expect(try await value(of: jumped, within: .seconds(10)) == .jumped)
        #expect(jumping.workspace.listened == 1, "the watch ran: Finder was in front")
    }

    @Test func aTmuxClientBehindARelayingPtyInAGhosttyWindowJumpsToTheTerminalOnTheDeviceOfGhosttysOwnChild() async {
        var mac = Mac()
        let shell = mac.tree.window(of: mac.ghostty, on: JumpWorld.window)
        let client = mac.tree.tmux(under: mac.tree.relay(under: shell, on: "/dev/ttys050", "/usr/bin/script"), on: "/dev/ttys050")
        let jumping = Jumping(server([FakeClient(device: "/dev/ttys050", pid: client, window: JumpWorld.claudes)]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window])
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }

    @Test func aWindowInZmxFocusesTheGhosttyWindowHoldingItsClientThroughPortalsRelayAskingTheTableOnceAndTmuxNothing() async {
        var mac = Mac()

        mac.throughPortal("adventure-works-v2 · proseware-build", relay: "/dev/ttys032", window: "/dev/ttys036")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))

        #expect(await jumping.run([inZmx("adventure-works-v2 · proseware-build")]) == .jumped)
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
        #expect(jumping.ghostty.asked == ["/dev/ttys036"])
        #expect(jumping.table.looks == 1)
        #expect(jumping.tmux.runs.isEmpty)
    }

    @Test func aZmxSessionWithNoClientOrOnlyOtherSessionsClientsIsNotOnScreenAndGhosttyIsAskedNothing() async {
        var mac = Mac()

        mac.throughPortal("litware", relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxServer("proseware")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree))

        #expect(await jumping.run([inZmx("proseware")]) == JumpWorld.offScreen)
        #expect(jumping.ghostty.asked.isEmpty)
    }

    @Test func inZmxTmuxMissingChangesNothingAsTmuxIsNeverAskedAndTheTableGivingNoAnswerLeavesItUnknownNeverOff() async {
        var mac = Mac()

        mac.throughPortal("litware", relay: "/dev/ttys032", window: "/dev/ttys036")

        let missing = Jumping(FakeTmux(silent: true), FakeTable(mac.tree), terminals: ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))

        #expect(await missing.run([inZmx("litware")]) == .jumped)
        #expect(missing.tmux.runs.isEmpty)
        #expect(
            await Jumping(FakeTmux(), FakeTable(nil)).run([inZmx("litware")])
                == .refused("Could not tell whether \(JumpWorld.named) is on screen: the process table gave no answer.")
        )
    }
}
