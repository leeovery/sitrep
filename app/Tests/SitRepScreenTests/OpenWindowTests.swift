import Darwin
import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

/// A click on a session a live window holds that no terminal shows opens a new Ghostty window attached to it, where a
/// jump refused it as not on screen (stage 7, C): the jump answers what is openable, checked, and the opening follows
/// apart from it. Which sessions open, jump or are refused; the command typed; Ghostty not running; a zmx session gone;
/// a second click; the focus after opening; and the front kept.
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
    private static var detachedTmux: FakeTmux {
        server([])
    }

    // MARK: Openable, and opened

    /// The jump opens nothing itself: it answers openable, with the command, and the window opens apart from it.
    @Test func aJumpToASessionNoWindowShowsAnswersOpenableOpeningNothingItself() async throws {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())

        #expect(try await jumping.jump.jump(to: [inZmx(Self.leeway)]) == .openable(command: "zmx attach 'agentic-workflows-v2 · leeway-build'"))
        #expect(jumping.ghostty.told.isEmpty)
        #expect(jumping.zmx.runs == [["list", "--short"]])
    }

    @Test func theOpeningOpensAGhosttyWindowTypingTheCommandThenFocusesIt() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(jumping.ghostty.told == ["open zmx attach 'agentic-workflows-v2 · leeway-build'", "focus NEW-TERMINAL"])
        #expect(jumping.ghostty.asked.isEmpty, "no terminal looked for")
    }

    /// Lee's own, through Portal: SitRep knows no Portal, only the command it is given.
    @Test func leesOwnCommandIsTypedInPlaceOfSitRepsOwn() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), commands: AttachCommands(zmx: "portal open -s {session}"))

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(jumping.ghostty.opened == ["portal open -s 'agentic-workflows-v2 · leeway-build'"])
    }

    @Test func aTmuxPaneNoClientShowsOpensAWindowAttachingByThePaneOnItsSocketAskingTmuxNoMore() async {
        let jumping = Jumping(Self.detachedTmux, FakeTable(Mac().tree))

        #expect(await jumping.open([inTmux()]) == .opened)
        #expect(jumping.ghostty.told == ["open \(attachingClaudesPane)", "focus NEW-TERMINAL"])
        #expect(Set(jumping.tmux.runs) == [[socket, "list-panes"], [socket, "list-clients"]])
        #expect(jumping.zmx.runs.isEmpty)
    }

    @Test func aTmuxCommandNamingTheSessionGetsTheNameOfTheSessionHoldingThePaneAsTheJumpFindsIt() async {
        let panes = [FakePane(pane: "%148", window: claudes, session: "$45")]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, names: ["$45": "switchboard"])])
        let jumping = Jumping(tmux, FakeTable(Mac().tree), commands: AttachCommands(tmux: "tmux attach -t {session}"))

        #expect(await jumping.open([inTmux()]) == .opened)
        #expect(jumping.ghostty.opened == ["tmux attach -t switchboard"])
        #expect(tmux.runs.last == [socket, "display-message"])
    }

    // MARK: Refused, and nothing opened

    /// The sessions a jump still refuses, each by why, with nothing openable: none is held by a multiplexer to attach
    /// to, its zmx session has gone, or whether one shows is unknown.
    private static func refused() -> [(String, [Where], FakeTmux, FakeZmx, FakeTable, JumpAnswer)] {
        let couldNotTell = JumpAnswer.refused("Could not tell whether \(named) is on screen: the process table gave no answer.")

        return [
            ("no live window, as an away row's session has none", [], FakeTmux(), FakeZmx(), FakeTable(Mac().tree), offScreen),
            ("a window in no multiplexer", [Where(device: "/dev/ttys041", terminal: "Unknown")], FakeTmux(), FakeZmx(), FakeTable(Mac().tree), offScreen),
            ("no tmux server on its socket", [inTmux()], FakeTmux(), FakeZmx(), FakeTable(Mac().tree), offScreen),
            ("its pane gone from its server", [inTmux("%9")], Self.detachedTmux, FakeZmx(), FakeTable(Mac().tree), offScreen),
            ("its zmx session gone, which an attach would make anew", [inZmx(leeway)], FakeTmux(), FakeZmx(listing: ["kit"]), Self.detachedZmx(), offScreen),
            ("its zmx session unknown, the table not answering", [inZmx(leeway)], FakeTmux(), FakeZmx(), FakeTable(nil), couldNotTell),
            ("tmux not answering", [inTmux()], FakeTmux(silent: true), FakeZmx(), FakeTable(Mac().tree), .refused("Could not tell whether \(named) is on screen: tmux gave no answer.")),
        ]
    }

    @Test func aSessionNoMultiplexerHoldsWhoseSessionIsGoneOrWhoseScreenIsUnknownIsRefusedAndNothingIsOpenable() async {
        for (why, windows, tmux, zmx, table, answer) in Self.refused() {
            let jumping = Jumping(tmux, table, terminals: [], zmx: zmx)

            #expect(await jumping.run(windows) == answer, "\(why)")
            #expect(jumping.ghostty.told.isEmpty, "\(why)")
        }
    }

    /// zmx missing from Lee's PATH, silent, or failing: never opened, as whether the session is there is not known.
    @Test(arguments: [
        (FakeZmx(answering: nil), "zmx, asked which sessions it has, gave no answer."),
        (FakeZmx(answering: Ran(status: 1, stdout: "", stderr: "socket dir missing\n")), "zmx, asked which sessions it has, said: socket dir missing"),
        (FakeZmx(answering: Ran(status: 2, stdout: "", stderr: "")), "zmx, asked which sessions it has, failed (2)."),
    ])
    func zmxNotSayingWhichSessionsItHasIsRefusedInPlainWords(zmx: FakeZmx, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), zmx: zmx)

        #expect(await jumping.run([inZmx(Self.leeway)]) == .refused("\(named) is not on screen, and SitRep cannot open a window for it: \(words)"))
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func aSessionOnScreenIsJumpedToNeverOpenable() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table)

        #expect(await jumping.run([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// From the board: a session with no live window, as an away row's, has nothing to attach to.
    @Test func aSessionOnTheBoardWithNoLiveWindowIsNotOpenable() async throws {
        let line = try board([], sessions: ["sr-q": "Quiet one"])

        #expect(
            await Jumping().jump.answer(to: "sr-q", on: GivenBoard(line))
                == .refused("Quiet one is not on screen: no terminal window on this Mac shows it.")
        )
    }

    /// The first window, in core's order, that a multiplexer holds: one in none passed over.
    @Test func theWindowAttachedToIsTheFirstAMultiplexerHolds() async {
        let jumping = Jumping(Self.detachedTmux, Self.detachedZmx(), terminals: [])
        let outside = Where(device: "/dev/ttys041", terminal: "Unknown")

        #expect(await jumping.run([outside, inZmx(Self.leeway), inTmux()]) == .openable)
        #expect(await jumping.open([outside, inZmx(Self.leeway), inTmux()]) == .opened)
        #expect(jumping.ghostty.opened == ["zmx attach 'agentic-workflows-v2 · leeway-build'"])
    }

    /// A window in tmux run inside zmx, or zmx inside tmux, attaches to the innermost, as a jump reads it.
    @Test(arguments: [
        ("/dev/ttys043", "tmux -S /private/tmp/tmux-501/default attach -t %148"),
        ("/dev/ttys087", "zmx attach kit"),
    ])
    func aWindowInTwoMultiplexersAttachesToTheInnermost(device: String, command: String) async throws {
        let pane = FakePane(pane: "%148", window: claudes, session: "$45", device: "/dev/ttys043")
        let both = Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: "%148"), zmx: Where.Zmx(session: "kit"))
        var mac = Mac()

        mac.zmxServer("kit")

        let jumping = Jumping(FakeTmux([socket: FakeServer(panes: [pane])]), FakeTable(mac.tree))

        #expect(try await jumping.jump.jump(to: [both]) == .openable(command: command))
    }

    /// `new window` would launch Ghostty, which opens a first window of its own as it starts: found as the jump
    /// answers, so no Space is gone to for a window that cannot open.
    @Test func withGhosttyNotRunningTheJumpRefusesInPlainWordsAndNothingIsOpenable() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(running: []))

        #expect(
            await jumping.run([inZmx(Self.leeway)])
                == .refused("\(named) is not on screen, and SitRep can open a window for it only in a Ghostty already running.")
        )
        #expect(jumping.zmx.runs.isEmpty)
    }

    /// Quit between the jump and the opening: refused as the jump would have, Ghostty sent nothing.
    @Test func ghosttyQuitBeforeTheOpeningIsRefusedInTheSameWords() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), running: false)

        #expect(
            await jumping.open([inZmx(Self.leeway)])
                == .refused("\(named) is not on screen, and SitRep can open a window for it only in a Ghostty already running.")
        )
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test(arguments: [
        ("zmx attach {pane}", "the zmx attach command in Settings names {pane}, which SitRep cannot fill for zmx: use {session}."),
        ("zmx attach '{session}'", "the zmx attach command in Settings puts {session} in quotes: SitRep quotes each value itself."),
    ])
    func aCommandSitRepCannotTypeIsRefusedInPlainWordsAndNothingIsOpenable(command: String, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), commands: AttachCommands(zmx: command))

        #expect(await jumping.run([inZmx(Self.leeway)]) == .refused("\(named) is not on screen, and SitRep cannot open a window for it: \(words)"))
        #expect(jumping.zmx.runs.isEmpty, "the command is checked before zmx is asked")
    }

    /// The terminal and the line editor act on a control before any quoting: ^U erases the line typed so far, and what
    /// follows runs (reproduced in zsh on a pty, 10 November 2026).
    @Test func aSessionWhoseNameHoldsAControlIsRefusedAndNothingIsOpenable() async {
        let name = "x\u{15}touch pwned; echo '"
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), zmx: FakeZmx(listing: [name]))

        #expect(
            await jumping.run([inZmx(name)])
                == .refused("\(named) is not on screen, and SitRep cannot open a window for it: its {session} holds a character that cannot be typed safely (U+0015).")
        )
    }

    @Test func tmuxNotNamingTheSessionIsRefusedInItsWordsAndNothingIsOpenable() async {
        let ghostty = FakeGhostty()

        #expect(
            await Self.jump(naming: NamingTmux(Self.detachedTmux, silent: true), ghostty).answer(to: [inTmux()])
                == .refused("\(named) is not on screen, and SitRep cannot open a window for it: tmux, asked which session holds its pane, gave no answer.")
        )
        #expect(ghostty.told.isEmpty)
    }

    @Test(arguments: [
        (GhosttyFailure.gave(-1743, said: nil), "Not authorized to send Apple events to Ghostty. (-1743)"),
        (.cannotOpen, "This Ghostty cannot open a window for SitRep: update Ghostty to 1.4 or later."),
        (.noAnswer, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."),
        (.windowUnanswered, "Ghostty did not answer within 5 seconds when asked to open a window; one may still appear."),
    ])
    func ghosttyFailingToOpenIsRefusedInItsWords(failure: GhosttyFailure, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), failing: failure)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .refused(words))
        #expect(jumping.ghostty.focused.isEmpty)
    }

    // MARK: Once Ghostty answered, opened

    /// Once `new window` has answered, a window is open: a focus failing, or Ghostty naming no window, never makes the
    /// click a failure.
    @Test(arguments: [(true, GhosttyFailure?.some(.noAnswer)), (true, .gave(-1728, said: "Can’t get terminal.")), (false, nil)])
    func aWindowGhosttyAnsweredItOpenedIsOpenedHoweverItsFocusWent(namesWindow: Bool, focusFailure: GhosttyFailure?) async throws {
        let ghostty = FakeGhostty(namesNewWindow: namesWindow, focusFailing: focusFailure)
        let driver = GhosttyDriver(scripting: ghostty, workspace: FakeWorkspace(), clock: TestClock())

        #expect(try await driver.openWindow(running: "zmx attach kit", front: finder))
        #expect(ghostty.opened == ["zmx attach kit"])
        #expect(ghostty.focused.isEmpty)
    }

    /// Stopped by a later click once Ghostty has answered, the window is open all the same, and remembered.
    @Test func anOpeningStoppedAfterGhosttyAnsweredIsOpenUnfocusedAndRemembered() async throws {
        let ghostty = FakeGhostty()
        let openings = RecentOpenings()
        let driver = GhosttyDriver(scripting: ghostty, workspace: FakeWorkspace(), clock: TestClock())
        let opening = Opening(
            session: "sr-a", name: named, command: "zmx attach kit", driver: StoppingAfterOpen(driver), app: "Ghostty",
            workspace: FakeWorkspace(), clock: TestClock(), openings: openings
        )

        #expect(await opening.open(on: .current) == .opened)
        #expect(ghostty.opened == ["zmx attach kit"])
        #expect(ghostty.focused.isEmpty)
        #expect(openings.isOpening("sr-a"))
    }

    // MARK: A second click

    /// The window's shell takes a moment to start and attach: a click on the session within `RecentOpenings.lasts`
    /// answers that its window is opening, and never opens another; once it shows, the click jumps to it.
    @Test func aSecondClickWhileItsWindowOpensOpensNoOtherWindow() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, zmx: Self.leeway)])
        let clock = MovingClock()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), openings: RecentOpenings(now: clock.now))
        let first = try #require(await jumping.jump.run(to: "sr-a", on: GivenBoard(line)).opening)

        #expect(await first.open(on: .current) == .opened)
        clock.move(by: .seconds(9))
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .opening)
        #expect(jumping.ghostty.opened.count == 1)

        clock.move(by: .seconds(2))
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .openable, "forgotten after ten seconds")
    }

    @Test func aSecondClickOnceTheWindowShowsItJumpsToIt() async throws {
        var mac = Mac()

        mac.throughPortal(Self.leeway, relay: "/dev/ttys032", window: "/dev/ttys036")

        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, zmx: Self.leeway)])
        let openings = RecentOpenings()
        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")), openings: openings)

        openings.remember("sr-a")
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .jumped)
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
    }

    @Test func anOpeningIsRememberedForTenSeconds() {
        #expect(RecentOpenings.lasts == .seconds(10))
    }

    // MARK: The front, and stopping

    /// As a jump keeps it: macOS handing the front back to the app in front as the opening began, Ghostty is brought
    /// forward again, once.
    @Test func ghosttyIsKeptInFrontAfterOpeningAsAJumpKeepsIt() async {
        let workspace = FakeWorkspace(front: finder, focused: [ghosttyBundle, finder])
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: workspace)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(workspace.brought == [bundled(ghosttyBundle).absoluteString])
        #expect(workspace.listening == 0)
    }

    @Test func withGhosttyInFrontNoWatchIsKept() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(jumping.workspace.listened == 0)
        #expect(jumping.workspace.brought.isEmpty)
    }

    /// A jump to Claude's tmux pane on a server with no client, tmux naming sessions as `tmux` does, Ghostty as given.
    private static func jump(naming tmux: NamingTmux, _ ghostty: FakeGhostty) -> Jump {
        let workspace = FakeWorkspace()
        let clock = TestClock()

        return Jump(
            reader: ScreenReader(tmux: tmux, zmx: FakeZmx(), table: FakeTable(Mac().tree)), tmux: tmux,
            drivers: [.ghostty: GhosttyDriver(scripting: ghostty, workspace: workspace, clock: clock)],
            workspace: workspace, clock: clock, commands: AttachCommands(tmux: "tmux attach -t {session}")
        )
    }

    /// Stopped by a later click as tmux names the session, nothing is openable.
    @Test func aJumpStoppedBeforeItsCommandIsMadeIsStopped() async {
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

    @Test func anOpeningStoppedBeforeGhosttyIsToldOpensNothing() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: Gate()))
        let opening = jumping.opening("zmx attach kit")
        let opened = Task { await opening.open(on: .current) }

        await until { jumping.workspace.fronts == 1 }
        opened.cancel()

        #expect(await opened.value == .stopped)
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func anOpeningHasALimitOfItsOwnApartFromTheJumps() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: Gate()))
        let opened = Task { await jumping.opening("zmx attach kit").open(on: .current) }

        await until { jumping.clock.sleeps.contains(Opening.limit) }
        jumping.clock.pass(Opening.limit)
        #expect(await opened.value == .unanswered)
        #expect(Opening.limit == .seconds(20))
    }
}

extension Jump {
    /// The jump to the windows, in the words it answers in.
    func answer(to windows: [Where]) async -> JumpAnswer {
        (try? await jump(to: windows))?.answer(named: named) ?? .stopped
    }
}

/// A clock the test moves by hand, for what is remembered a while.
private final class MovingClock: Sendable {
    private let at = OSAllocatedUnfairLock(initialState: ContinuousClock.now)

    var now: @Sendable () -> ContinuousClock.Instant {
        { [at] in at.withLock { $0 } }
    }

    func move(by duration: Duration) {
        at.withLock { $0 += duration }
    }
}

/// A driver that opens through the one given, as if a later click came the moment Ghostty answered.
private struct StoppingAfterOpen: TerminalDriver {
    let driver: GhosttyDriver

    init(_ driver: GhosttyDriver) {
        self.driver = driver
    }

    func bringForward(on device: String, front: String?) async throws -> Bool {
        false
    }

    func canOpen() async -> Bool {
        true
    }

    func openWindow(running command: String, front: String?) async throws -> Bool {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await driver.openWindow(running: command, front: front)
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
