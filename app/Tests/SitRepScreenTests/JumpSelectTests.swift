import Darwin
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// tmux's select in a jump, and the order places are tried in, a place that fails giving way to the next.
@Suite(.backstop)
struct JumpSelectTests {
    /// Claude's tmux session `$7` of two windows, its Ghostty window on the other.
    private static func besideIt(select: Ran? = Ran(status: 0, stdout: "", stderr: "")) -> Jumping {
        var mac = Mac()
        let clients = [mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.beside, in: "$7")]

        return Jumping(server(clients, sessions: ["$7"], select: select), FakeTable(mac.tree))
    }

    @Test func aPanesWindowNoClientShowsIsShownByTmuxSelectingItInTheSessionHoldingItThenThatSessionsGhosttyWindowIsFocused() async {
        let jumping = Self.besideIt()

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.tmux.selects == [[socket, "-t", "$7:@45"]])
        #expect(jumping.tmux.runs.last == [socket, "select-window"], "after tmux's two lists")
        #expect(jumping.ghostty.asked == [JumpWorld.window])
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }

    @Test func aClientWithNoDeviceOnThePanesWindowDoesNotStopTheSelectThatMakesTheSessionsGhosttyWindowShowIt() async {
        var mac = Mac()
        let clients = [mac.controlClient(showing: JumpWorld.claudes, in: "$8"), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.beside, in: "$7")]
        let jumping = Jumping(server(clients, sessions: ["$7", "$8"]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.selects == ["$7:@45"])
        #expect(jumping.ghostty.asked == [JumpWorld.window])
    }

    @Test func aGroupedSessionsGhosttyWindowOnAnotherWindowHasThePanesWindowSelectedInItsOwnSessionNeverTheOneThePhoneShows() async {
        for (shows, selects) in [(JumpWorld.beside, ["$8:@45"]), (JumpWorld.claudes, [])] {
            var mac = Mac()
            let clients = [mac.phoneClient(JumpWorld.phone, showing: JumpWorld.claudes, in: "$7"), mac.ghosttyClient(JumpWorld.window, showing: shows, in: "$8")]
            let jumping = Jumping(server(clients, sessions: ["$7", "$8"]), FakeTable(mac.tree))

            #expect(await jumping.run([inTmux()]) == .jumped)
            #expect(jumping.selects == selects, "shown already, so nothing is selected")
            #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
        }
    }

    @Test func aWindowLinkedIntoAnotherSessionHasThePanesWindowSelectedInThatSessionWhoseGhosttyWindowShowsAnother() async {
        var mac = Mac()
        let clients = [mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.litware, in: "$8")]
        let panes = [
            FakePane(pane: "%12", window: JumpWorld.claudes, session: "$7"), FakePane(pane: "%12", window: JumpWorld.claudes, session: "$8"),
            FakePane(pane: "%54", window: JumpWorld.litware, session: "$8"),
        ]
        let jumping = Jumping(FakeTmux([socket: FakeServer(panes: panes, clients: clients)]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.selects == ["$8:@45"])
    }

    @Test func aClientAttachedToASessionNotHoldingThePanesWindowHasNothingSelectedOffScreen() async {
        var mac = Mac()
        let jumping = Jumping(server([mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.litware, in: "$52")], sessions: ["$7"]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == JumpWorld.offScreen)
        #expect(jumping.selects.isEmpty)
    }

    @Test(arguments: [
        (Ran(status: 1, stdout: "", stderr: "can't find window: @45\n"), "tmux would not select it: can't find window: @45"),
        (Ran(status: 1, stdout: "", stderr: ""), "tmux would not select it."),
        (nil, "tmux gave no answer when asked to select it."),
    ])
    func aSelectTmuxRefusesOrDoesNotAnswerRefusesTheJumpInPlainWordsWithNothingFocused(select: Ran?, why: String) async {
        let jumping = Self.besideIt(select: select)

        #expect(await jumping.run([inTmux()]) == .refused("\(JumpWorld.named) is in a tmux window no terminal shows, and \(why)"))
        #expect(jumping.ghostty.asked.isEmpty)
    }

    @Test func aGhosttyWindowOnThePanesWindowShowsItSoNoOtherIsMadeToByASelect() async {
        var mac = Mac()
        let clients = [mac.ghosttyClient(JumpWorld.litwareTerminal.device, showing: JumpWorld.beside, in: "$7"), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes, in: "$7")]
        let jumping = Jumping(server(clients, sessions: ["$7"]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.selects.isEmpty)
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }

    /// The session's two windows: the first in tmux, on a window no Ghostty window shows, its Ghostty window on
    /// another; the second in its own window outside tmux, on the device given.
    private static func stoppedBeside(_ device: String, select: Ran?) -> (Jumping, [Where]) {
        let jumping = besideIt(select: select)

        return (jumping, [inTmux(), Where(device: device, terminal: "ghostty")])
    }

    @Test func aSelectTmuxDoesNotMakeGivesWayToTheNextPlaceTheNextWindowsWhichIsBroughtForward() async {
        let (jumping, windows) = Self.stoppedBeside(JumpWorld.litwareTerminal.device, select: Ran(status: 1, stdout: "", stderr: "can't find window: @45"))

        #expect(await jumping.run(windows) == .jumped)
        #expect(jumping.selects == ["$7:@45"])
        #expect(jumping.ghostty.focused == ["LITWARE-TERMINAL"])
    }

    @Test func withNoPlaceLeftTheJumpIsRefusedInTheWordsOfWhatStoppedTheMostWantedThoughALaterWindowDidNotAnswer() async {
        let (jumping, windows) = Self.stoppedBeside("/dev/ttys099", select: nil)

        #expect(await jumping.run(windows) == .refused("\(JumpWorld.named) is in a tmux window no terminal shows, and tmux gave no answer when asked to select it."))
        #expect(jumping.ghostty.asked == ["/dev/ttys099"], "the later window was tried")
    }

    @Test func aSelectTwoPlacesNeedIsAskedOfTmuxOnceSoOneThatHangsCostsItsTimeOnce() async {
        var mac = Mac()
        let clients = [mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.beside, in: "$7"), mac.terminalClient("/dev/ttys030", showing: JumpWorld.beside, in: "$7")]
        let jumping = Jumping(server(clients, sessions: ["$7"], select: nil), FakeTable(mac.tree), workspace: FakeWorkspace(at: [JumpWorld.terminalApp]))

        #expect(await jumping.run([inTmux()]) != .jumped)
        #expect(jumping.selects == ["$7:@45"])
        #expect(jumping.workspace.brought.isEmpty)
    }

    @Test func ofTwoWindowsEachWindowsPlacesAreTriedBeforeTheNextsSoOneWhereNoTerminalShowsItGivesWayToTheOther() async {
        var mac = Mac()
        let jumping = Jumping(server([mac.ghosttyClient(JumpWorld.litwareTerminal.device, showing: JumpWorld.litware)]), FakeTable(mac.tree))

        #expect(await jumping.run([inTmux(), Where(device: JumpWorld.window, terminal: "ghostty")]) == .jumped)
        #expect(jumping.ghostty.asked == [JumpWorld.window])
        #expect(jumping.ghostty.focused == ["WOODGROVE-TERMINAL"])
    }
}
