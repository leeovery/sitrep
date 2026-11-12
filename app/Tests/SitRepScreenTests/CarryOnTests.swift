import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

/// A click on an away row, no window holding its session, carries it on from what is left of its last window, read at
/// the click as a jump reads the screen (stage 8): the jump, where a terminal shows its multiplexer session; the open
/// command, where that is alive and none shows it; the resume command, where nothing is left; refused, where whether a
/// terminal shows it is unknown.
struct CarryOnTests {
    private static let leeway = "agentic-workflows-v2 · leeway-build"
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"
    private static let folder = "/Users/lee/Code/leeway"
    private static let portal = "portal open -s {session}"
    private static let resume = "portal open -p {dir} -- claude --resume {claude}"
    private static let resumed = "portal open -p '/Users/lee/Code/leeway' -- claude --resume '\(claude)'"

    /// The last window, in the zmx session given, else where given, on the device given, its folder said unless none
    /// is.
    private static func last(_ where: Where? = inZmx(leeway), device: String? = nil, directory: String? = folder)
        -> Board.LastWindow
    {
        Board.LastWindow(writer: claude, where: `where`, device: device, directory: directory)
    }

    /// The zmx session Portal shows in a Ghostty window, and that window's terminal.
    private static func shown() -> (FakeTable, [FakeWindow]) {
        var mac = Mac()

        mac.throughPortal(leeway, relay: "/dev/ttys032", window: "/dev/ttys036")
        return (FakeTable(mac.tree), ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))
    }

    /// The zmx session alive, its server alone, no client.
    private static func detached() -> FakeTable {
        var mac = Mac()

        mac.zmxServer(leeway)
        return FakeTable(mac.tree)
    }

    // MARK: The four cases

    @Test func aTerminalShowingItsMultiplexerSessionIsJumpedTo() async {
        let (table, terminals) = Self.shown()
        let jumping = Jumping(FakeTmux(), table, terminals: terminals, command: Self.portal, resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last()) == .jumped)
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// As after a restart, Portal bringing each zmx session back: attached by the open command, as step C runs it.
    @Test func itsMultiplexerSessionAliveAndUnshownIsOpenedByTheOpenCommand() async {
        let jumping = Jumping(FakeTmux(), Self.detached(), command: Self.portal, resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        #expect(jumping.ghostty.opened == ["portal open -s 'agentic-workflows-v2 · leeway-build'"])
    }

    /// A pane id does not outlive its server, so a pane of the id the last window was in may be any pane now: never
    /// attached, as core never names one (stage 8), the session resumed.
    @Test func aTmuxPaneOfItsIdUnshownIsNeverAttachedButResumed() async {
        let jumping = Jumping(server([]), FakeTable(Mac().tree), command: "tmux -S {socket} attach -t {pane}", resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(inTmux())) == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed])
    }

    /// Nothing left to attach to: its zmx session gone, its tmux server gone, its pane gone from its server, or its last
    /// window in no multiplexer, or saying no where. A window in none is never jumped to by its device, which a
    /// terminal may show still, its Claude gone from it.
    @Test(arguments: [
        ("its zmx session gone", inZmx(leeway), FakeTmux()),
        ("its tmux server gone", inTmux(), FakeTmux()),
        ("its pane gone from its server", inTmux("%9"), server([])),
        ("in no multiplexer", Where(device: kitTerminal.device, terminal: "ghostty"), FakeTmux()),
        ("saying no where", nil, FakeTmux()),
    ] as [(String, Where?, FakeTmux)])
    func nothingLeftRunsTheResumeCommand(why: String, where: Where?, tmux: FakeTmux) async {
        let jumping = Jumping(tmux, FakeTable(Mac().tree), command: Self.portal, resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(`where`)) == .opened, "\(why)")
        #expect(jumping.ghostty.opened == [Self.resumed], "\(why)")
        #expect(jumping.ghostty.focused == [FakeGhostty.opened], "\(why)")
    }

    /// Whether a terminal shows it unknown, as a jump's, nothing opens: a window opened then could be a second of one
    /// already there.
    @Test(arguments: [
        (inZmx(leeway), FakeTmux(), FakeTable(nil), "the process table gave no answer"),
        (inTmux(), FakeTmux(silent: true), FakeTable(Mac().tree), "tmux gave no answer"),
        (inZmx(leeway), FakeTmux(), unread(), "a zmx process's command line gave no answer"),
    ])
    func whetherATerminalShowsItUnknownIsRefusedAndNothingOpens(where: Where, tmux: FakeTmux, table: FakeTable, why: String) async {
        let jumping = Jumping(tmux, table, command: Self.portal, resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(`where`)) == .refused("Could not tell whether \(named) is on screen: \(why)."))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// A zmx process whose command line does not read, as one gone as it was read.
    private static func unread() -> FakeTable {
        var mac = Mac()

        mac.zmxUnread()
        return FakeTable(mac.tree)
    }

    // MARK: A Claude still there

    /// A heartbeat gone stale says only that the beat stopped: its plugin no longer loading, or its process suspended,
    /// stops it too. A Claude Code process on the device its Claude ran on refuses the resume, whichever installer's;
    /// one with none there, a shell alone, resumes.
    @Test(arguments: ["/Users/lee/.local/share/claude/versions/2.1.322", "/opt/homebrew/bin/claude"])
    func aClaudeStillOnItsDeviceRefusesTheResumeAndNothingOpens(program: String) async {
        var mac = Mac()

        mac.claude(on: "/dev/ttys041", program: program)

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(nil, device: "/dev/ttys041")) == .unopened(
            "\(named)'s Claude may still be running in its window, on /dev/ttys041, so SitRep starts no second. Quit it "
                + "there, or carry it on in that window."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func noClaudeOnItsDeviceResumes() async {
        var mac = Mac()

        mac.claude(on: "/dev/ttys042")
        _ = mac.tree.window(of: mac.ghostty, on: "/dev/ttys041")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(inTmux(), device: "/dev/ttys041")) == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed])
    }

    @Test func aTableGivingNoAnswerRefusesTheResumeAsAJumpIsRefused() async {
        let jumping = Jumping(FakeTmux(), FakeTable(nil), resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last(nil, device: "/dev/ttys041")) == .unopened(
            "Could not tell whether \(named)'s Claude is still running: the process table gave no answer."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: The resume command's refusals

    @Test func withNoResumeCommandTheClickSaysToSetOneInSettingsAndNothingOpens() async {
        let jumping = Jumping(command: Self.portal)

        #expect(await jumping.carryOn(from: Self.last()) == .unopened("No window holds \(named). To carry it on, set a resume command in Settings."))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// A window on an older build said no folder: a command naming `{dir}` is refused; one naming only `{claude}` runs.
    @Test func aLastWindowSayingNoFolderRefusesACommandNamingDirAlone() async {
        let refusing = Jumping(resume: Self.resume)
        let running = Jumping(resume: "claude --resume {claude}")

        #expect(await refusing.carryOn(from: Self.last(directory: nil)) == .unopened(
            "\(named)'s last window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep has nothing to put for {dir}."
        ))
        #expect(refusing.ghostty.told.isEmpty)
        #expect(await running.carryOn(from: Self.last(directory: nil)) == .opened)
        #expect(running.ghostty.opened == ["claude --resume '\(Self.claude)'"])
    }

    @Test func ghosttyNotRunningIsRefusedAsAnOpeningIsAndNothingIsSent() async {
        let jumping = Jumping(workspace: FakeWorkspace(running: []), resume: Self.resume)

        #expect(await jumping.carryOn(from: Self.last()) == .unopened(
            "SitRep opens a window only in a Ghostty already running. Open Ghostty, then click \(named) again."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: One window per click

    /// A resumed Claude reaches the board only once it has started, its plugin loaded, taken the session up and beaten,
    /// which can run past the open command's ten seconds: a resume is remembered until the board shows a window holding
    /// the session, two minutes at most.
    @Test func aSecondClickWhileItsResumeOpensOpensNoOtherWindowForTwoMinutes() async {
        let clock = MovingClock()
        let jumping = Jumping(resume: Self.resume, openings: RecentOpenings(now: clock.now))

        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        clock.move(by: .seconds(11))
        #expect(await jumping.carryOn(from: Self.last()) == .opening)
        clock.move(by: .seconds(108))
        #expect(await jumping.carryOn(from: Self.last()) == .opening)
        #expect(jumping.ghostty.opened == [Self.resumed])

        clock.move(by: .seconds(1) + .milliseconds(1))
        #expect(await jumping.carryOn(from: Self.last()) == .opened, "forgotten after two minutes")
        #expect(jumping.ghostty.opened == [Self.resumed, Self.resumed])
    }

    /// Its Claude back on the board, the resume is done: once away again, a click carries it on afresh. An open
    /// command's opening keeps its ten seconds, as the board shows a window holding its session before its client shows.
    @Test func aResumeIsForgottenOnceTheBoardShowsAWindowHoldingItsSession() async throws {
        let clock = MovingClock()
        let openings = RecentOpenings(now: clock.now)
        let jumping = Jumping(resume: Self.resume, openings: openings)
        let held = try board([LineWindow(writer: Self.claude, session: "sr-a", order: 0, zmx: Self.leeway)])

        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        clock.move(by: .seconds(11))
        openings.heard(try board([LineWindow(writer: "w2", session: "sr-b", order: 0, zmx: "other")]))
        #expect(await jumping.carryOn(from: Self.last()) == .opening, "another session held tells nothing of this one")

        openings.heard(held)
        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed, Self.resumed])

        openings.remember("sr-a", as: .attach)
        openings.heard(held)
        #expect(openings.isOpening("sr-a"))
    }

    // MARK: From the board

    /// The board names an away session's last window; the click carries it on from that, as read at the click.
    @Test func anAwaySessionOnTheBoardIsCarriedOnFromItsLastWindow() async throws {
        let place: [String: Any] = ["device": "/dev/ttys087", "terminal": "ghostty", "tmux": NSNull(), "zmx": ["session": Self.leeway]]
        let line = try board([], sessions: ["sr-q": "Quiet one"], last: [
            "sr-q": ["writer": Self.claude, "where": place, "directory": Self.folder],
        ])
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), command: Self.portal, resume: Self.resume)
        let opening = try #require(await jumping.jump.run(to: "sr-q", on: GivenBoard(line)).opening)

        #expect(line.lastWindow(of: "sr-q") == Self.last())
        #expect(await opening.open() == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed])
    }

    /// One a window holds again, its live windows on the line, is jumped to as any session, its last window none.
    @Test func aSessionAWindowHoldsIsJumpedToAsAnySession() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, device: kitTerminal.device)], sessions: ["sr-a": named])
        let jumping = Jumping(resume: Self.resume)

        #expect(line.lastWindow(of: "sr-a") == nil)
        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .jumped)
        #expect(jumping.ghostty.opened.isEmpty)
    }
}

/// A clock the test moves by hand, for what is remembered a while.
final class MovingClock: Sendable {
    private let at = OSAllocatedUnfairLock(initialState: ContinuousClock.now)

    var now: @Sendable () -> ContinuousClock.Instant {
        { [at] in at.withLock { $0 } }
    }

    func move(by duration: Duration) {
        at.withLock { $0 += duration }
    }
}
