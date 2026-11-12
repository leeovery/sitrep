import Darwin
import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

/// A click on a session a live window holds that no terminal shows opens a new window for it, in the terminal Lee chose,
/// running his open command, where a jump refused it as not on screen (stage 7, C): the jump answers what is openable,
/// checked, and the opening follows apart from it. Which sessions open, jump or are refused; the line typed; the
/// terminal not running; a second click; the focus after opening; the front kept; and stopping.
struct OpenWindowTests {
    private static let leeway = "agentic-workflows-v2 · leeway-build"
    /// Lee's own command, through Portal: SitRep knows no Portal, only the command it is given.
    private static let portal = "portal open -s {session}"
    private static let portalLine = "portal open -s 'agentic-workflows-v2 · leeway-build'"
    private static let notRunning = JumpAnswer.unopened(
        "SitRep opens a window only in a Ghostty already running. Open Ghostty, then click \(named) again."
    )

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

    /// The jump opens nothing itself: it answers openable, and the window opens apart from it.
    @Test func aJumpToASessionNoWindowShowsAnswersOpenableOpeningNothingItself() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), command: Self.portal)

        #expect(await jumping.outcome([inZmx(Self.leeway)]).answer == .openable)
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func theOpeningOpensAWindowTypingTheCommandFilledThenFocusesIt() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(jumping.ghostty.told == ["open \(Self.portalLine)", "focus \(FakeGhostty.opened)"])
        #expect(jumping.ghostty.asked.isEmpty, "no terminal looked for")
    }

    @Test func aTmuxPaneNoClientShowsOpensAWindowWithItsSocketAndPaneAskingTmuxNoMore() async {
        let jumping = Jumping(Self.detachedTmux, FakeTable(Mac().tree), command: "tmux -S {socket} attach -t {pane}")

        #expect(await jumping.open([inTmux()]) == .opened)
        #expect(jumping.ghostty.opened == ["tmux -S '/private/tmp/tmux-501/default' attach -t '%148'"])
        #expect(Set(jumping.tmux.runs) == [[socket, "list-panes"], [socket, "list-clients"]])
    }

    /// Asked of tmux at the click, as a tmux session can be renamed.
    @Test func aTmuxCommandNamingTheSessionGetsTheNameOfTheSessionHoldingThePaneAtTheClick() async {
        let panes = [FakePane(pane: "%148", window: claudes, session: "$45")]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, names: ["$45": "switchboard"])])
        let jumping = Jumping(tmux, FakeTable(Mac().tree), command: "tmux attach -t {session}")

        #expect(await jumping.open([inTmux()]) == .opened)
        #expect(jumping.ghostty.opened == ["tmux attach -t 'switchboard'"])
        #expect(tmux.runs.last == [socket, "display-message"])
    }

    /// The first window, in core's order, that a multiplexer holds: one in none passed over.
    @Test func theWindowOpenedForIsTheFirstAMultiplexerHolds() async {
        let jumping = Jumping(Self.detachedTmux, Self.detachedZmx(), terminals: [], command: "attach {session}")
        let outside = Where(device: "/dev/ttys041", terminal: "Unknown")

        #expect(await jumping.open([outside, inZmx(Self.leeway), inTmux()]) == .opened)
        #expect(jumping.ghostty.opened == ["attach 'agentic-workflows-v2 · leeway-build'"])
    }

    /// A window in tmux run inside zmx, or zmx inside tmux, is opened for the innermost, as a jump reads it.
    @Test(arguments: [("/dev/ttys043", "attach 'work'"), ("/dev/ttys087", "attach 'kit'")])
    func aWindowInTwoMultiplexersIsOpenedForTheInnermost(device: String, line: String) async {
        let pane = FakePane(pane: "%148", window: claudes, session: "$45", device: "/dev/ttys043")
        let both = Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: "%148"), zmx: Where.Zmx(session: "kit"))
        var mac = Mac()

        mac.zmxServer("kit")

        let jumping = Jumping(FakeTmux([socket: FakeServer(panes: [pane], names: ["$45": "work"])]), FakeTable(mac.tree), command: "attach {session}")

        #expect(await jumping.open([both]) == .opened)
        #expect(jumping.ghostty.opened == [line])
    }

    /// The opening goes through the driver of the terminal Lee chose, and its refusals name that terminal.
    @Test func theOpeningGoesThroughTheChosenTerminalsDriver() async {
        let other = Driver(name: "Other", program: "other", executable: "other")
        let driver = RecordingDriver()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx())
        let jump = Jump(
            reader: ScreenReader(tmux: FakeTmux(), table: Self.detachedZmx()), tmux: FakeTmux(),
            drivers: [.ghostty: jumping.driver, other: driver], workspace: jumping.workspace, clock: jumping.clock,
            opening: OpenSettings(terminal: other, command: Self.portal)
        )
        let outcome = await jump.jump(to: "sr-a", named: named, at: [inZmx(Self.leeway)])

        #expect(await outcome.opening?.open() == .opened)
        #expect(driver.opened == [Self.portalLine])
        #expect(jumping.ghostty.told.isEmpty)

        driver.isRunning = false
        #expect(
            await outcome.opening?.open()
                == .unopened("SitRep opens a window only in a Other already running. Open Other, then click \(named) again.")
        )
    }

    // MARK: Refused, and nothing opened

    /// SitRep has no built-in way to attach: with no command, the click says to set one, and nothing opens.
    @Test func withNoOpenCommandTheClickSaysToSetOneInSettingsAndNothingOpens() async {
        let jumping = Jumping(Self.detachedTmux, FakeTable(Mac().tree))

        #expect(await jumping.open([inTmux()]) == .unopened("No terminal window shows \(named). To open one for it, set an open command in Settings."))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// The sessions a jump still refuses, each by why, with nothing openable: none is held by a multiplexer, or whether
    /// one shows is unknown, which could make a second window of one already there.
    private static func refused() -> [(String, [Where], FakeTmux, FakeTable, JumpAnswer)] {
        let couldNotTell = { (what: String) in JumpAnswer.refused("Could not tell whether \(named) is on screen: \(what) gave no answer.") }

        return [
            ("no live window", [], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("a window in no multiplexer", [Where(device: "/dev/ttys041", terminal: "Unknown")], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("no tmux server on its socket", [inTmux()], FakeTmux(), FakeTable(Mac().tree), offScreen),
            ("its pane gone from its server", [inTmux("%9")], Self.detachedTmux, FakeTable(Mac().tree), offScreen),
            ("its zmx session unknown, the table not answering", [inZmx(leeway)], FakeTmux(), FakeTable(nil), couldNotTell("the process table")),
            ("tmux not answering", [inTmux()], FakeTmux(silent: true), FakeTable(Mac().tree), couldNotTell("tmux")),
            (
                "tmux failing on its socket, a server it could not talk to", [inTmux()],
                FakeTmux(failing: [socket: "protocol version mismatch (client 8, server 7)"]), FakeTable(Mac().tree),
                .refused("Could not tell whether \(named) is on screen: tmux said \"protocol version mismatch (client 8, server 7)\"."),
            ),
            (
                "tmux failing on one window's socket, though zmx holds another of its windows with no client", [inTmux(on: otherSocket), inZmx(leeway)],
                FakeTmux(failing: [otherSocket: "protocol version mismatch (client 8, server 7)"]), Self.detachedZmx(),
                .refused("Could not tell whether \(named) is on screen: tmux said \"protocol version mismatch (client 8, server 7)\"."),
            ),
        ]
    }

    @Test func aSessionNoMultiplexerHoldsOrWhoseScreenIsUnknownIsRefusedAndNothingOpens() async {
        for (why, windows, tmux, table, answer) in Self.refused() {
            let jumping = Jumping(tmux, table, terminals: [], command: "attach {session}")

            #expect(await jumping.open(windows) == answer, "\(why)")
            #expect(jumping.ghostty.told.isEmpty, "\(why)")
        }
    }

    @Test func aSessionOnScreenIsJumpedToNeverOpened() async {
        let (tmux, table) = shown()
        let jumping = Jumping(tmux, table, command: "attach {session}")

        #expect(await jumping.open([inTmux()]) == .jumped)
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// From the board: a session with no live window, nor any last one, as no window ever held it, has nothing to open
    /// a window for.
    @Test func aSessionOnTheBoardWithNoWindowAtAllIsRefusedAsNotOnScreen() async throws {
        let line = try board([], sessions: ["sr-q": "Quiet one"])

        #expect(
            await Jumping(command: "attach {session}").jump.answer(to: "sr-q", on: GivenBoard(line))
                == .refused("Quiet one is not on screen: no terminal window on this Mac shows it.")
        )
    }

    /// Refused at the click, before anything is asked or sent.
    @Test(arguments: [
        ("attach {pane}", "\(named) runs in zmx, which gives no {pane}. A zmx session gives {session}."),
        ("attach '{session}'", "The open command in Settings puts {session} in quotes or backticks. Remove them: SitRep quotes each value itself."),
        ("attach {window}", "The open command in Settings has {window}, which SitRep doesn't know. It knows {session}, {socket} and {pane}."),
    ])
    func aCommandSitRepCannotFillOrTypeIsRefusedAtTheClick(command: String, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), command: command)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .unopened(words))
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func tmuxNotNamingTheSessionIsRefusedInItsWordsAndNothingOpens() async {
        let jumping = Jumping(command: "tmux attach -t {session}")
        let jump = Self.jump(jumping, tmux: NamingTmux(Self.detachedTmux, silent: true))

        #expect(
            await jump.jump(to: "sr-a", named: named, at: [inTmux()]).answer
                == .unopened("tmux, asked which session holds Claude's pane, did not answer within 2 seconds.")
        )
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// `new window` would launch the terminal, which opens a first window of its own as it starts: never sent.
    @Test func withGhosttyNotRunningTheOpeningIsRefusedInPlainWordsAndNothingIsSent() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(running: []), command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == Self.notRunning)
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"))
    }

    /// Quit between the check and the asking: refused in the same words, Ghostty sent nothing, nothing remembered.
    @Test func ghosttyQuitBeforeTheWindowIsAskedForIsRefusedInTheSameWords() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), running: false, command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == Self.notRunning)
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"))
    }

    @Test(arguments: [
        (GhosttyFailure.gave(-1743, said: nil), "Not authorized to send Apple events to Ghostty. (-1743)"),
        (.cannotOpen, "This Ghostty cannot open a window for SitRep: update Ghostty to 1.4 or later."),
        (.noAnswer, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."),
    ])
    func ghosttyFailingBeforeTheWindowIsAskedForIsRefusedInItsWordsAndForgotten(failure: GhosttyFailure, words: String) async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), failing: failure, command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .unopened(words))
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"), "a click again may open one")
    }

    /// Once the window was asked for, one may open whatever Ghostty answers: refused in its words, and remembered.
    @Test func ghosttyFailingOnceTheWindowWasAskedForIsRefusedInItsWordsAndRemembered() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), windowFailing: .windowUnanswered, command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .unopened("Ghostty did not answer within 5 seconds when asked to open a window; one may still appear."))
        #expect(jumping.ghostty.opened == [Self.portalLine])
        #expect(jumping.ghostty.focused.isEmpty)
        #expect(jumping.openings.isOpening("sr-a"))
    }

    // MARK: Once Ghostty answered, opened

    /// Once `new window` has answered, a window is open: a focus failing, or Ghostty naming no window, never makes the
    /// click a failure.
    @Test(arguments: [(true, GhosttyFailure?.some(.noAnswer)), (true, .gave(-1728, said: "Can’t get terminal.")), (false, nil)])
    func aWindowGhosttyAnsweredItOpenedIsOpenedHoweverItsFocusWent(namesWindow: Bool, focusFailure: GhosttyFailure?) async throws {
        let ghostty = FakeGhostty(namesNewWindow: namesWindow, focusFailing: focusFailure)
        let driver = GhosttyDriver(scripting: ghostty, workspace: FakeWorkspace(), clock: TestClock())

        #expect(try await driver.openWindow(running: "attach kit", front: finder, sending: {}))
        #expect(ghostty.opened == ["attach kit"])
        #expect(ghostty.focused.isEmpty)
    }

    // MARK: A second click

    /// The window's shell takes a moment to start and attach: a click on the session within `RecentOpenings.lasts`
    /// answers that its window is opening, and never opens another, nor asks tmux or Ghostty anything for one.
    @Test func aSecondClickWhileItsWindowOpensOpensNoOtherWindow() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, zmx: Self.leeway)])
        let clock = MovingClock()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), command: Self.portal, openings: RecentOpenings(now: clock.now))
        let first = try #require(await jumping.jump.run(to: "sr-a", on: GivenBoard(line)).opening)

        #expect(await first.open() == .opened)
        clock.move(by: .seconds(9))
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .opening)
        #expect(jumping.ghostty.opened.count == 1)

        clock.move(by: .seconds(1))
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .openable, "forgotten after ten seconds")
    }

    /// Remembered from before the window is asked for, so a click as Ghostty answers opens no second.
    @Test func anOpeningIsRememberedBeforeTheWindowIsAskedFor() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { jumping.workspace.fronts == 1 }
        #expect(jumping.openings.isOpening("sr-a"))
        #expect(jumping.ghostty.told.isEmpty)

        gate.open()
        #expect(await opened.value == .opened)
    }

    /// Remembered again as the window is asked for, so a slow first event costs none of its ten seconds.
    @Test func anOpeningIsRememberedAfreshAsTheWindowIsAskedFor() async {
        let gate = Gate()
        let clock = MovingClock()
        let jumping = Jumping(
            FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate),
            openings: RecentOpenings(now: clock.now)
        )
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { jumping.workspace.fronts == 1 }
        clock.move(by: .seconds(9))
        gate.open()
        #expect(await opened.value == .opened)

        clock.move(by: .seconds(2))
        #expect(jumping.openings.isOpening("sr-a"))
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

    /// An opening that failed before its window was asked for forgets itself, never a later opening of the session.
    @Test func anOpeningForgetsOnlyItselfNeverALaterOne() {
        let clock = MovingClock()
        let openings = RecentOpenings(now: clock.now)
        let first = openings.remember("sr-a")

        clock.move(by: .seconds(1))
        openings.remember("sr-a")
        openings.forget("sr-a", remembered: first)
        #expect(openings.isOpening("sr-a"))
    }

    // MARK: The front, and stopping

    /// As a jump keeps it: macOS handing the front back to the app in front as the opening began, Ghostty is brought
    /// forward again, once.
    @Test func ghosttyIsKeptInFrontAfterOpeningAsAJumpKeepsIt() async {
        let workspace = FakeWorkspace(front: finder, focused: [ghosttyBundle, finder])
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: workspace, command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(workspace.brought == [bundled(ghosttyBundle).absoluteString])
        #expect(workspace.listening == 0)
    }

    @Test func withGhosttyInFrontNoWatchIsKept() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), command: Self.portal)

        #expect(await jumping.open([inZmx(Self.leeway)]) == .opened)
        #expect(jumping.workspace.listened == 0)
        #expect(jumping.workspace.brought.isEmpty)
    }

    /// Stopped by a later click while tmux names the session: nothing is openable, and nothing opens.
    @Test func aJumpStoppedWhileTmuxNamesTheSessionIsStopped() async {
        let gate = Gate()
        let jumping = Jumping(command: "tmux attach -t {session}")
        let jump = Self.jump(jumping, tmux: NamingTmux(Self.detachedTmux, held: gate))
        let jumped = Task { await jump.jump(to: "sr-a", named: named, at: [inTmux()]) }

        await until { gate.arrived == 1 }
        jumped.cancel()
        gate.open()

        #expect(await jumped.value.answer == .stopped)
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Stopped before the window is asked for: nothing is sent, and the opening is forgotten, so a click again opens it.
    @Test func anOpeningStoppedBeforeTheWindowIsAskedForSendsNothingAndIsForgotten() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { jumping.workspace.fronts == 1 }
        opened.cancel()
        #expect(await opened.value == .stopped)

        gate.open()
        await until { !jumping.openings.isOpening("sr-a") }
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Stopped once the window was asked for, its event in flight: the window opens all the same, unfocused, and is
    /// remembered.
    @Test func anOpeningStoppedOnceTheWindowWasAskedForIsRememberedAndLeftUnfocused() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), windowHeld: gate)
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { gate.arrived == 1 }
        opened.cancel()
        #expect(await opened.value == .stopped)

        gate.open()
        await settle()
        #expect(jumping.ghostty.told == ["open attach kit"])
        #expect(jumping.openings.isOpening("sr-a"))
    }

    /// The jump of the world given, but asking the tmux given, on a Mac of no clients.
    private static func jump(_ jumping: Jumping, tmux: any TmuxProgram) -> Jump {
        Jump(
            reader: ScreenReader(tmux: tmux, table: FakeTable(Mac().tree)), tmux: tmux,
            drivers: [.ghostty: jumping.driver], workspace: jumping.workspace, clock: jumping.clock,
            opening: jumping.opening, openings: jumping.openings
        )
    }

    /// Given up before the window was asked for, none can come.
    @Test func anOpeningHasALimitOfItsOwnApartFromTheJumps() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: Gate()))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { jumping.clock.sleeps.contains(Opening.limit) }
        jumping.clock.pass(Opening.limit)
        #expect(
            await opened.value
                == .unopened("SitRep gave up waiting for Ghostty to open a window for \(named) after 20 seconds.")
        )
        #expect(Opening.limit == .seconds(20))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Given up once the window was asked for, one may yet come, and says so.
    @Test func anOpeningGivenUpOnceItsWindowWasAskedForSaysOneMayStillAppear() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), windowHeld: gate)
        let opened = Task { await jumping.opening("attach kit").open() }

        await until { gate.arrived == 1 && jumping.clock.sleeps.contains(Opening.limit) }
        jumping.clock.pass(Opening.limit)
        #expect(
            await opened.value
                == .unopened("SitRep gave up waiting for Ghostty to open a window for \(named) after 20 seconds; one may still appear.")
        )
        gate.open()
    }
}

/// A terminal's driver that opens a window by recording the line, while its terminal runs.
private final class RecordingDriver: TerminalDriver {
    private let state = OSAllocatedUnfairLock(initialState: (running: true, opened: [String]()))

    var isRunning: Bool {
        get { state.withLock(\.running) }
        set { state.withLock { $0.running = newValue } }
    }

    var opened: [String] { state.withLock(\.opened) }

    func bringForward(on _: String, front _: String?) async throws -> Bool {
        false
    }

    func canOpen() async -> Bool {
        isRunning
    }

    func openWindow(running command: String, front _: String?, sending: @escaping @Sendable () -> Void) async throws -> Bool {
        sending()
        state.withLock { $0.opened.append(command) }
        return true
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

    func run(on socket: String, _ words: [String]) async throws -> Ran {
        guard words.first == "display-message" else {
            return try await tmux.run(on: socket, words)
        }

        await gate?.pass()
        if isSilent {
            throw FakeTmux.unanswered
        }
        return try await tmux.run(on: socket, words)
    }
}
