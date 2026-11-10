import Darwin
import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

/// A click on a session a live window holds that no terminal shows opens a new Ghostty window attached to it, on the
/// Space showing, where a jump refused it as not on screen (stage 7, C): which sessions open, jump or are refused, the
/// command typed, Ghostty not running, the focus after opening, and the front kept.
struct OpenWindowTests {
    private static let leeway = "agentic-workflows-v2 · leeway-build"

    /// A zmx session with no client, only its server.
    private static func detachedZmx() -> FakeTable {
        var mac = Mac()

        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxServer(leeway)
        return FakeTable(mac.tree)
    }

    /// Claude's tmux pane, on a server with no client.
    private static let detachedTmux = server([])

    @Test func aZmxSessionNoWindowShowsOpensAGhosttyWindowTypingItsAttachCommandThenFocusesIt() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())

        #expect(await jumping.run([inZmx(Self.leeway)]) == .jumped)
        #expect(jumping.ghostty.told == ["open zmx attach 'agentic-workflows-v2 · leeway-build'", "focus NEW-TERMINAL"])
        #expect(jumping.ghostty.asked.isEmpty, "no terminal looked for")
    }

    /// Lee's own, through Portal: SitRep knows no Portal, only the command it is given.
    @Test func leesOwnCommandIsTypedInPlaceOfSitRepsOwn() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), commands: AttachCommands(zmx: "portal open -s {session}"))

        #expect(await jumping.run([inZmx(Self.leeway)]) == .jumped)
        #expect(jumping.ghostty.opened == ["portal open -s 'agentic-workflows-v2 · leeway-build'"])
    }

    @Test func aTmuxPaneNoClientShowsOpensAWindowAttachingByThePaneOnItsSocketAskingTmuxNoMore() async {
        let jumping = Jumping(Self.detachedTmux, FakeTable(Mac().tree))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.told == ["open tmux -S /private/tmp/tmux-501/default attach -t %148", "focus NEW-TERMINAL"])
        #expect(Set(jumping.tmux.runs) == [[socket, "list-panes"], [socket, "list-clients"]])
    }

    @Test func aTmuxCommandNamingTheSessionGetsTheNameOfTheSessionHoldingThePaneAsTheWindowOpens() async {
        let panes = [FakePane(pane: "%148", window: claudes, session: "$45")]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, names: ["$45": "switchboard"])])
        let jumping = Jumping(tmux, FakeTable(Mac().tree), commands: AttachCommands(tmux: "tmux attach -t {session}"))

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.opened == ["tmux attach -t switchboard"])
        #expect(tmux.runs.last == [socket, "display-message"])
    }

    /// The sessions a jump still refuses, each by why, with no window opened: none is held by a multiplexer to attach
    /// to, or whether one shows is unknown.
    private static func refused() -> [(String, [Where], FakeTmux, FakeTable, JumpAnswer)] {
        let couldNotTell = JumpAnswer.refused("Could not tell whether \(named) is on screen: the process table gave no answer.")

        return [
            ("no live window, as an away row's session has none", [], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("a window in no multiplexer", [Where(device: "/dev/ttys041", terminal: "Unknown")], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("no tmux server on its socket", [inTmux()], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("its pane gone from its server", [inTmux("%9")], Self.detachedTmux, FakeTable(Mac().tree), offScreen),
            ("its zmx session unknown, the table not answering", [inZmx(leeway)], FakeTmux(), FakeTable(nil), couldNotTell),
            ("tmux not answering", [inTmux()], FakeTmux(silent: true), FakeTable(Mac().tree), .refused("Could not tell whether \(named) is on screen: tmux gave no answer.")),
        ]
    }

    @Test func aSessionNoMultiplexerHoldsOrWhoseScreenIsUnknownIsRefusedAsBeforeAndOpensNothing() async {
        for (why, windows, tmux, table, answer) in Self.refused() {
            let jumping = Jumping(tmux, table, terminals: [])

            #expect(await jumping.run(windows) == answer, "\(why)")
            #expect(jumping.ghostty.opened.isEmpty, "\(why)")
        }
    }

    @Test func aSessionOnScreenIsJumpedToNeverOpened() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// From the board: a session with no live window, as an away row's, has nothing to attach to.
    @Test func aSessionOnTheBoardWithNoLiveWindowOpensNothing() async throws {
        let line = try board([], sessions: ["sr-q": "Quiet one"])
        let jumping = Jumping()

        #expect(
            await jumping.jump.run(to: "sr-q", on: GivenBoard(line))
                == .refused("Quiet one is not on screen: no terminal window on this Mac shows it.")
        )
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// The first window, in core's order, that a multiplexer holds: one in none passed over.
    @Test func theWindowAttachedToIsTheFirstAMultiplexerHolds() async {
        let jumping = Jumping(Self.detachedTmux, Self.detachedZmx(), terminals: [])
        let outside = Where(device: "/dev/ttys041", terminal: "Unknown")

        #expect(await jumping.run([outside, inZmx(Self.leeway), inTmux()]) == .jumped)
        #expect(jumping.ghostty.opened == ["zmx attach 'agentic-workflows-v2 · leeway-build'"])
    }

    /// A window in tmux run inside zmx, or zmx inside tmux, attaches to the innermost, as a jump reads it.
    @Test(arguments: [
        ("/dev/ttys043", "tmux -S /private/tmp/tmux-501/default attach -t %148"),
        ("/dev/ttys087", "zmx attach kit"),
    ])
    func aWindowInTwoMultiplexersAttachesToTheInnermost(device: String, command: String) async {
        let pane = FakePane(pane: "%148", window: claudes, session: "$45", device: "/dev/ttys043")
        let both = Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: "%148"), zmx: Where.Zmx(session: "kit"))
        var mac = Mac()

        mac.zmxServer("kit")

        let jumping = Jumping(FakeTmux([socket: FakeServer(panes: [pane])]), FakeTable(mac.tree))

        #expect(await jumping.run([both]) == .jumped)
        #expect(jumping.ghostty.opened == [command])
    }

    /// `new window` would launch Ghostty, which opens a first window of its own as it starts.
    @Test func withGhosttyNotRunningAWindowIsRefusedInPlainWordsAndNothingOpened() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), running: false)

        #expect(
            await jumping.run([inZmx(Self.leeway)])
                == .refused("\(named) is not on screen, and SitRep can open a window for it only in a Ghostty already running.")
        )
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func aCommandSitRepCannotFillIsRefusedInPlainWordsAndNothingOpened() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), commands: AttachCommands(zmx: "zmx attach {pane}"))

        #expect(
            await jumping.run([inZmx(Self.leeway)])
                == .refused("\(named) is not on screen, and SitRep cannot open a window for it: the zmx attach command in Settings names {pane}, which SitRep cannot fill for zmx: it fills {session}.")
        )
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// A jump to Claude's tmux pane on a server with no client, tmux naming sessions as `tmux` does, Ghostty as given.
    private static func jump(naming tmux: NamingTmux, _ ghostty: FakeGhostty) -> Jump {
        let workspace = FakeWorkspace()
        let clock = TestClock()

        return Jump(
            reader: ScreenReader(tmux: tmux, table: FakeTable(Mac().tree)), tmux: tmux,
            drivers: [.ghostty: GhosttyDriver(scripting: ghostty, workspace: workspace, clock: clock)],
            workspace: workspace, clock: clock, commands: AttachCommands(tmux: "tmux attach -t {session}")
        )
    }

    @Test func tmuxNotNamingTheSessionIsRefusedInItsWordsAndNothingOpened() async throws {
        let ghostty = FakeGhostty()
        let jumped = try await Self.jump(naming: NamingTmux(Self.detachedTmux, silent: true), ghostty).jump(to: [inTmux()])

        #expect(
            jumped.answer(named: named)
                == .refused("\(named) is not on screen, and SitRep cannot open a window for it: tmux, asked which session holds its pane, gave no answer.")
        )
        #expect(ghostty.told.isEmpty)
    }

    @Test(arguments: [
        (GhosttyFailure.gave(-1743, said: nil), "Not authorized to send Apple events to Ghostty. (-1743)"),
        (.cannotOpen, "This Ghostty cannot open a window for SitRep: update Ghostty to 1.4 or later."),
        (.noAnswer, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."),
    ])
    func ghosttyFailingToOpenIsRefusedInItsWords(failure: GhosttyFailure, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), failing: failure)

        #expect(await jumping.run([inZmx(Self.leeway)]) == .refused(words))
        #expect(jumping.ghostty.focused.isEmpty)
    }

    /// As a jump keeps it: macOS handing the front back to the app in front as the click came, Ghostty is brought
    /// forward again, once.
    @Test func ghosttyIsKeptInFrontAfterOpeningAsAJumpKeepsIt() async {
        let workspace = FakeWorkspace(front: finder, focused: [ghosttyBundle, finder])
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: workspace)

        #expect(await jumping.run([inZmx(Self.leeway)]) == .jumped)
        #expect(workspace.brought == [bundled(ghosttyBundle).absoluteString])
        #expect(workspace.listening == 0)
    }

    @Test func withGhosttyInFrontNoWatchIsKept() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())

        #expect(await jumping.run([inZmx(Self.leeway)]) == .jumped)
        #expect(jumping.workspace.listened == 0)
        #expect(jumping.workspace.brought.isEmpty)
    }

    /// Stopped by a later click as tmux names the session, the window is never opened.
    @Test func anOpeningStoppedBeforeTheWindowOpensOpensNothing() async {
        let gate = Gate()
        let ghostty = FakeGhostty()
        let jump = Self.jump(naming: NamingTmux(Self.detachedTmux, held: gate), ghostty)
        let jumped = Task { try await jump.jump(to: [inTmux()]) }

        await until { gate.arrived == 1 }
        jumped.cancel()
        gate.open()

        await #expect(throws: CancellationError.self) { try await jumped.value }
        #expect(ghostty.told.isEmpty)
    }

    @Test func aWindowOpensOnTheSpaceShowingTheOnlyChoiceUntilTheSpacePicker() {
        #expect(Jumping().jump.space == .current)
    }
}

/// tmux answering as the tmux given, but in its naming of a session: held at the gate, where one is given, and giving
/// no answer, where `silent`.
private final class NamingTmux: TmuxProgram {
    let tmux: FakeTmux
    let gate: Gate?
    let isSilent: Bool

    init(_ tmux: FakeTmux, held gate: Gate? = nil, silent: Bool = false) {
        self.tmux = tmux
        self.gate = gate
        isSilent = silent
    }

    func run(on socket: String, _ words: [String]) async -> Ran? {
        guard words.first == "display-message" else {
            return await tmux.run(on: socket, words)
        }

        await gate?.pass()
        return isSilent ? nil : await tmux.run(on: socket, words)
    }
}
