import Darwin
import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// A click on a session no terminal on this Mac shows opens a new window for it, in the terminal Lee chose, typing his
/// resume command (stage 8's rethink): the jump answers what is openable, checked, and the opening follows apart from
/// it. The line typed; the terminal not running; whether a terminal shows it unknown; a second click; the focus after
/// opening; the front kept; and stopping.
struct OpenWindowTests {
    private static let leeway = "agentic-workflows-v2 · leeway-build"
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"
    /// Lee's own command, through Portal: SitRep knows no Portal, only the command it is given.
    private static let portal = "portal open --claude {claude}"
    private static let portalLine = "portal open --claude '\(claude)'"
    private static let notRunning = JumpAnswer.unopened(
        "SitRep opens a window only in a Ghostty already running. Open Ghostty, then click \(JumpWorld.named) again."
    )

    /// The window the session is carried on from: Claude in Leeway's zmx session.
    private static let held = Board.LastWindow(
        writer: claude, where: inZmx(leeway), ownsDevice: true, directory: "/Users/lee/Code/leeway"
    )

    /// A zmx session with no client, only its server.
    private static func detachedZmx() -> FakeTable {
        var mac = Mac()

        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxServer(leeway)
        return FakeTable(mac.tree)
    }

    /// A world whose `sr-a` runs in Leeway's zmx session with no client, Lee's command given.
    private static func world(
        workspace: FakeWorkspace = FakeWorkspace(), running: Bool = true, failing: GhosttyFailure? = nil,
        windowFailing: GhosttyFailure? = nil, openings: RecentOpenings = RecentOpenings()
    ) -> Jumping {
        Jumping(
            FakeTmux(), detachedZmx(), running: running, failing: failing, windowFailing: windowFailing,
            workspace: workspace, resume: portal, openings: openings
        )
    }

    /// A click on `sr-a`, held, no terminal showing it, then its window opened.
    private static func open(_ jumping: Jumping) async -> JumpAnswer {
        await jumping.open([inZmx(leeway)], from: held, isHeld: true)
    }

    // MARK: Openable, and opened

    /// The jump opens nothing itself: it answers openable, and the window opens apart from it.
    @Test func aClickOnASessionNoTerminalHereShowsAnswersOpenableOpeningNothingItself() async {
        let jumping = Self.world()

        #expect(await jumping.outcome([inZmx(Self.leeway)], from: Self.held, isHeld: true).answer == .openable)
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func theOpeningOpensAWindowTypingTheCommandFilledThenFocusesIt() async {
        let jumping = Self.world()

        #expect(await Self.open(jumping) == .opened)
        #expect(jumping.ghostty.told == ["open \(Self.portalLine)", "focus \(FakeGhostty.opened)"])
        #expect(jumping.ghostty.asked.isEmpty, "no terminal looked for")
    }

    /// The opening goes through the driver of the terminal Lee chose, and its refusals name that terminal.
    @Test func theOpeningGoesThroughTheChosenTerminalsDriver() async {
        let other = Driver(name: "Other", program: "other", executable: "other")
        let driver = RecordingDriver()
        let jumping = Self.world()
        let jump = Jump(
            reader: ScreenReader(tmux: FakeTmux(), table: Self.detachedZmx()), tmux: FakeTmux(),
            drivers: [.ghostty: jumping.driver, other: driver], workspace: jumping.workspace, clock: jumping.clock,
            opening: OpenSettings(terminal: other, resumeCommand: Self.portal)
        )
        let outcome = await jump.click("sr-a", named: JumpWorld.named, at: [inZmx(Self.leeway)], from: Self.held, isHeld: true)

        #expect(await outcome.opening?.open() == .opened)
        #expect(driver.opened == [Self.portalLine])
        #expect(jumping.ghostty.told.isEmpty)

        driver.isRunning = false
        #expect(
            await outcome.opening?.open()
                == .unopened("SitRep opens a window only in a Other already running. Open Other, then click \(JumpWorld.named) again.")
        )
    }

    // MARK: Refused, and nothing opened

    /// Whether a terminal shows it unknown, by any of its windows, though another shows nowhere: a window opened then
    /// could be a second of one already there.
    private static func unknown() -> [(String, [Where], FakeTmux, FakeTable, JumpAnswer)] {
        let couldNotTell = { (what: String) in JumpAnswer.refused("Could not tell whether \(JumpWorld.named) is on screen: \(what) gave no answer.") }
        let mismatch = JumpAnswer.refused(
            "Could not tell whether \(JumpWorld.named) is on screen: tmux said \"protocol version mismatch (client 8, server 7)\"."
        )

        return [
            ("its zmx session unknown, the table not answering", [inZmx(leeway)], FakeTmux(), FakeTable(nil), couldNotTell("the process table")),
            ("tmux not answering", [inTmux()], FakeTmux(silent: true), FakeTable(Mac().tree), couldNotTell("tmux")),
            (
                "tmux failing on its socket, a server it could not talk to", [inTmux()],
                FakeTmux(failing: [socket: "protocol version mismatch (client 8, server 7)"]), FakeTable(Mac().tree), mismatch
            ),
            (
                "tmux failing on one window's socket, though zmx holds another of its windows with no client", [inTmux(on: otherSocket), inZmx(leeway)],
                FakeTmux(failing: [otherSocket: "protocol version mismatch (client 8, server 7)"]), Self.detachedZmx(), mismatch
            ),
        ]
    }

    @Test func aSessionWhoseScreenIsUnknownIsRefusedAndNothingOpens() async {
        for (why, windows, tmux, table, answer) in Self.unknown() {
            let jumping = Jumping(tmux, table, terminals: [], resume: Self.portal)

            #expect(await jumping.open(windows, from: Self.held, isHeld: true) == answer, "\(why)")
            #expect(jumping.ghostty.told.isEmpty, "\(why)")
        }
    }

    /// `new window` would launch the terminal, which opens a first window of its own as it starts: never sent.
    @Test func withGhosttyNotRunningTheOpeningIsRefusedInPlainWordsAndNothingIsSent() async {
        let jumping = Self.world(workspace: FakeWorkspace(running: []))

        #expect(await Self.open(jumping) == Self.notRunning)
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"))
    }

    /// Quit between the check and the asking: refused in the same words, Ghostty sent nothing, nothing remembered.
    @Test func ghosttyQuitBeforeTheWindowIsAskedForIsRefusedInTheSameWords() async {
        let jumping = Self.world(running: false)

        #expect(await Self.open(jumping) == Self.notRunning)
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"))
    }

    @Test(arguments: [
        (GhosttyFailure.gave(-1743, said: nil), "Not authorized to send Apple events to Ghostty. (-1743)"),
        (.cannotOpen, "This Ghostty cannot open a window for SitRep: update Ghostty to 1.4 or later."),
        (.noAnswer, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."),
    ])
    func ghosttyFailingBeforeTheWindowIsAskedForIsRefusedInItsWordsAndForgotten(failure: GhosttyFailure, words: String) async {
        let jumping = Self.world(failing: failure)

        #expect(await Self.open(jumping) == .unopened(words))
        #expect(jumping.ghostty.told.isEmpty)
        #expect(!jumping.openings.isOpening("sr-a"), "a click again may open one")
    }

    /// Once the window was asked for, one may open whatever Ghostty answers: refused in its words, and remembered.
    @Test func ghosttyFailingOnceTheWindowWasAskedForIsRefusedInItsWordsAndRemembered() async {
        let jumping = Self.world(windowFailing: .windowUnanswered)

        #expect(await Self.open(jumping) == .unopened("Ghostty did not answer within 5 seconds when asked to open a window; one may still appear."))
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
        let driver = GhosttyDriver(scripting: ghostty, workspace: FakeWorkspace(), clock: TestClock(passing: .jumpsPauses))

        #expect(try await driver.openWindow(running: "attach kit", front: finder, sending: {}))
        #expect(ghostty.opened == ["attach kit"])
        #expect(ghostty.focused.isEmpty)
    }

    // MARK: A second click

    /// The window's shell takes a moment to start, and its Claude to reach the board: a click on the session meanwhile
    /// answers that its window is opening, and never opens another, nor asks Ghostty anything for one.
    @Test func aSecondClickWhileItsWindowOpensOpensNoOtherWindow() async throws {
        let line = try board([
            WatchLine.Window.jumping(Self.claude, session: "sr-a", order: 0, zmx: Self.leeway, directory: "/Users/lee/Code/leeway"),
        ])
        let jumping = Self.world()
        let first = try #require(await jumping.jump.run(to: "sr-a", on: GivenBoard(line)).opening)

        #expect(await first.open() == .opened)
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .opening)
        #expect(jumping.ghostty.told.count == 2, "its open and its focus alone")
    }

    /// Remembered from before the window is asked for, so a click as Ghostty answers opens no second.
    @Test func anOpeningIsRememberedBeforeTheWindowIsAskedFor() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { jumping.workspace.fronts == 1 }
        #expect(jumping.openings.isOpening("sr-a"))
        #expect(jumping.ghostty.told.isEmpty)

        gate.open()
        #expect(await opened.value == .opened)
    }

    /// Remembered again as the window is asked for, so a slow first event costs none of its two minutes.
    @Test func anOpeningIsRememberedAfreshAsTheWindowIsAskedFor() async {
        let gate = Gate()
        let clock = MovingClock()
        let jumping = Jumping(
            FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate),
            openings: RecentOpenings(now: clock.now)
        )
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { jumping.workspace.fronts == 1 }
        clock.move(by: .seconds(119))
        gate.open()
        #expect(await opened.value == .opened)

        clock.move(by: .seconds(2))
        #expect(jumping.openings.isOpening("sr-a"))
    }

    @Test func aSecondClickOnceTheWindowShowsItJumpsToIt() async throws {
        var mac = Mac()

        mac.throughPortal(Self.leeway, relay: "/dev/ttys032", window: "/dev/ttys036")

        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a", order: 0, zmx: Self.leeway)])
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
        let jumping = Self.world(workspace: workspace)

        #expect(await Self.open(jumping) == .opened)
        #expect(workspace.brought == [bundled(ghosttyBundle).absoluteString])
        #expect(workspace.listening == 0)
    }

    @Test func withGhosttyInFrontNoWatchIsKept() async {
        let jumping = Self.world()

        #expect(await Self.open(jumping) == .opened)
        #expect(jumping.workspace.listened == 0)
        #expect(jumping.workspace.brought.isEmpty)
    }

    /// Stopped before the window is asked for: nothing is sent, and the opening is forgotten, so a click again opens it.
    @Test func anOpeningStoppedBeforeTheWindowIsAskedForSendsNothingAndIsForgotten() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: gate))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { jumping.workspace.fronts == 1 }
        opened.cancel()
        #expect(await opened.value == .stopped)

        gate.open()
        await until(within: .seconds(10)) { !jumping.openings.isOpening("sr-a") }
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Stopped once the window was asked for, its event in flight: the window opens all the same, unfocused, and is
    /// remembered.
    @Test func anOpeningStoppedOnceTheWindowWasAskedForIsRememberedAndLeftUnfocused() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), windowHeld: gate)
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { gate.arrived == 1 }
        opened.cancel()
        #expect(await opened.value == .stopped)

        gate.open()
        await settle()
        #expect(jumping.ghostty.told == ["open attach kit"])
        #expect(jumping.openings.isOpening("sr-a"))
    }

    /// Given up before the window was asked for, none can come.
    @Test func anOpeningHasALimitOfItsOwnApartFromTheJumps() async {
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), workspace: FakeWorkspace(frontHeld: Gate()))
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { jumping.clock.sleeps.contains(Opening.limit) }
        jumping.clock.pass(Opening.limit)
        #expect(
            await opened.value
                == .unopened("SitRep gave up waiting for Ghostty to open a window for \(JumpWorld.named) after 20 seconds.")
        )
        #expect(Opening.limit == .seconds(20))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Given up once the window was asked for, one may yet come, and says so.
    @Test func anOpeningGivenUpOnceItsWindowWasAskedForSaysOneMayStillAppear() async {
        let gate = Gate()
        let jumping = Jumping(FakeTmux(), Self.detachedZmx(), windowHeld: gate)
        let opened = Task { await jumping.opening("attach kit").open() }

        await until(within: .seconds(10)) { gate.arrived == 1 && jumping.clock.sleeps.contains(Opening.limit) }
        jumping.clock.pass(Opening.limit)
        #expect(
            await opened.value
                == .unopened("SitRep gave up waiting for Ghostty to open a window for \(JumpWorld.named) after 20 seconds; one may still appear.")
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
