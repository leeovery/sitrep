import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import Testing

/// A click on a session no terminal on this Mac shows, held or away, carries it on (stage 8's rethink): a Claude of it
/// suspended where a terminal here shows it is Lee's to bring back, the jump taking him there; otherwise a new window
/// types the resume command, filled from the window a jump tries first, or the one an away session was last in. The
/// default refuses while the session's Claude is still alive; a command Lee wrote always runs.
struct CarryOnTests {
    private static let leeway = "agentic-workflows-v2 · leeway-build"
    private static let claude = "b1c2d3e4-0000-4000-8000-000000000001"
    private static let folder = "/Users/lee/Code/leeway"
    private static let resumed = "cd '/Users/lee/Code/leeway' && claude --resume '\(claude)'"
    /// A command Lee wrote, naming every placeholder.
    private static let lees = "attach {tty} {dir} {claude}"

    /// The last window, in the zmx session given, else where given, its folder said unless none is, its device its
    /// conversation's unless said.
    private static func last(
        _ where: Where? = inZmx(leeway), ownsDevice: Bool? = true, directory: String? = folder
    ) -> Board.LastWindow {
        Board.LastWindow(writer: claude, where: `where`, ownsDevice: ownsDevice, directory: directory)
    }

    /// The line Lee's command types for the last window, its device given where its Claude runs there.
    private static func leesLine(tty: String = "") -> String {
        "attach '\(tty)' '\(folder)' '\(claude)'"
    }

    /// A window in no multiplexer, on Kit's Ghostty window's device.
    private static let inGhostty = Where(device: kitTerminal.device, terminal: "ghostty")

    private static let suspended = "\(named) is suspended in this window: type fg to bring it back."

    /// The zmx session Portal shows in a Ghostty window, and that window's terminal, with a Claude on the session's pty
    /// as given.
    private static func shown(claude: Bool? = nil) -> (FakeTable, [FakeWindow]) {
        var mac = Mac()

        mac.throughPortal(leeway, relay: "/dev/ttys032", window: "/dev/ttys036")
        if let isStopped = claude {
            mac.claude(on: inZmx(leeway).device ?? "", isStopped: isStopped)
        }
        return (FakeTable(mac.tree), ownWindows(FakeTerminal(id: "PORTAL-TERMINAL", device: "/dev/ttys036")))
    }

    /// A Mac with a Claude on the device given, running or stopped, and a Ghostty window's shell on it where `isShown`.
    private static func withClaude(on device: String, isStopped: Bool = false, isShown: Bool = false) -> FakeTable {
        var mac = Mac()

        mac.claude(on: device, isStopped: isStopped)
        if isShown {
            _ = mac.tree.window(of: mac.ghostty, on: device)
        }
        return FakeTable(mac.tree)
    }

    // MARK: Here, the jump

    /// A terminal here shows it: the jump, as ever, whatever the window it would be carried on from.
    @Test func aSessionATerminalHereShowsIsJumpedToNeverOpened() async {
        let (table, terminals) = Self.shown()
        let jumping = Jumping(FakeTmux(), table, terminals: terminals, resume: Self.lees)

        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .jumped)
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// Whether a terminal shows it unknown, refused in the jump's words, and nothing opens: unknown is never taken for
    /// not here.
    @Test func whetherATerminalShowsItUnknownIsRefusedInTheJumpsWordsAndNothingOpens() async {
        let jumping = Jumping(FakeTmux(silent: true), FakeTable(Mac().tree), resume: Self.lees)

        #expect(await jumping.open([inTmux()], from: Self.last(inTmux()), isHeld: true) == .refused(
            "Could not tell whether \(named) is on screen: tmux gave no answer."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Shown, its window not coming forward: refused in the jump's words, and nothing starts.
    @Test func aSessionShownWhoseJumpFailsIsRefusedInTheJumpsWordsAndNothingOpens() async {
        var mac = Mac()

        _ = mac.tree.window(of: mac.ghostty, on: "/dev/ttys080")

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: [], resume: Self.lees)
        let lost = Where(device: "/dev/ttys080", terminal: "ghostty")

        #expect(await jumping.open([lost], from: Self.last(lost), isHeld: true) == noneAnswered("/dev/ttys080"))
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// Where the read and the jump disagree, the read decides: a window whose heartbeat carries Ghostty's
    /// `$TERM_PROGRAM`, reached over ssh, is not here, though Ghostty here holds a terminal on a device of its name, so
    /// it is carried on, never jumped to.
    @Test func aWindowReachedOverSshIsCarriedOnThoughItsTermProgramSaysGhostty() async {
        var mac = Mac()

        _ = mac.tree.shell(under: ["/usr/sbin/sshd", "/usr/libexec/sshd-session"], on: kitTerminal.device)

        let jumping = Jumping(FakeTmux(), FakeTable(mac.tree), resume: Self.lees)

        #expect(await jumping.open([Self.inGhostty], from: Self.last(Self.inGhostty), isHeld: true) == .opened)
        #expect(jumping.ghostty.focused == [FakeGhostty.opened])
    }

    /// Here by its ancestry, in a terminal app its `$TERM_PROGRAM` does not name, so the jump's own reading finds it on
    /// no screen: refused in the jump's words, and nothing opens.
    @Test func aSessionHereTheJumpFindsOnNoScreenIsRefusedInItsWordsAndNothingOpens() async {
        let unnamed = Where(device: kitTerminal.device)
        let jumping = Jumping(resume: Self.lees)

        #expect(await jumping.open([unnamed], from: Self.last(unnamed), isHeld: true) == offScreen)
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// A session read as here forgets the window opened for it: once its window is gone again, a click opens another.
    @Test func aSessionReadAsHereForgetsItsOpening() async {
        let (table, terminals) = Self.shown()
        let openings = RecentOpenings()

        openings.remember("sr-a", wasHeld: true)
        #expect(await Jumping(FakeTmux(), table, terminals: terminals, openings: openings).open([inZmx(Self.leeway)]) == .jumped)
        #expect(!openings.isOpening("sr-a"))
    }

    // MARK: Held, not here

    /// A window holds it, in a zmx session no terminal here shows, or reached only over ssh, its shell carrying no
    /// terminal app: Lee's command runs, filled from the window a jump tries first.
    @Test(arguments: [inZmx(leeway), Where(device: "/dev/ttys080")])
    func aHeldSessionNoTerminalHereShowsRunsTheResumeCommand(where: Where) async {
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), resume: Self.lees)

        #expect(await jumping.open([`where`], from: Self.last(`where`), isHeld: true) == .opened)
        #expect(jumping.ghostty.opened == [Self.leesLine()])
    }

    /// Its Claude is still running where this Mac doesn't show it: the default would resume beside it.
    @Test func aHeldSessionNoTerminalHereShowsIsRefusedByTheDefaultAndNothingOpens() async {
        let jumping = Jumping(FakeTmux(), Self.withClaude(on: inZmx(Self.leeway).device ?? ""))

        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == stillRunning)
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// Held, with no Claude on its device, as a tab just closed whose window holds it until its heartbeat goes stale:
    /// the default refuses, saying to try again in a moment, not to set a command.
    @Test func aHeldSessionWithNoClaudeOnItsDeviceIsRefusedByTheDefaultAsJustStopped() async {
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree))

        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == justStopped)
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// The board's held session: carried on from the live window a jump tries first, its writer and its folder.
    @Test func aHeldSessionOnTheBoardIsCarriedOnFromTheWindowAJumpTriesFirst() async throws {
        let line = try board([
            LineWindow(writer: "w1", session: "sr-a", order: 1, zmx: "kit", directory: "/Users/lee/Code/kit"),
            LineWindow(writer: Self.claude, session: "sr-a", order: 0, zmx: Self.leeway, directory: Self.folder),
        ])
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), resume: "claude --resume {claude} -- {dir}")
        let opening = try #require(await jumping.jump.run(to: "sr-a", on: GivenBoard(line)).opening)

        #expect(line.isHeld("sr-a"))
        #expect(line.resumeWindow(of: "sr-a") == Board.LastWindow(
            writer: Self.claude, where: inZmx(Self.leeway), ownsDevice: true, directory: Self.folder
        ))
        #expect(await opening.open() == .opened)
        #expect(jumping.ghostty.opened == ["claude --resume '\(Self.claude)' -- '\(Self.folder)'"])
    }

    /// A line from a CLI before windows said their folder: `{dir}` has nothing to fill it.
    @Test func aHeldSessionWhoseWindowSaysNoFolderRefusesACommandNamingDir() async throws {
        let line = try board([LineWindow(writer: Self.claude, session: "sr-a", order: 0, zmx: Self.leeway)])
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), resume: Self.lees)

        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .unopened(
            "\(named)'s window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep has nothing to put for {dir}."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: Away

    /// Its Claude ended: the default resumes the conversation in its folder.
    @Test(arguments: [inZmx(leeway), inTmux(), inGhostty, nil] as [Where?])
    func anAwaySessionWithNoClaudeOnItsDeviceIsResumedByTheDefault(where: Where?) async {
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), terminals: [])

        #expect(await jumping.carryOn(from: Self.last(`where`)) == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed])
        #expect(jumping.ghostty.focused == [FakeGhostty.opened])
    }

    /// An away session with no last window, as its conversation would take up another: as one no window holds.
    @Test func anAwaySessionWithNoLastWindowIsRefusedAsNotOnScreen() async throws {
        let line = try board([], sessions: ["sr-q": "Quiet one"])

        #expect(await Jumping().jump.answer(to: "sr-q", on: GivenBoard(line)) == .refused(
            "Quiet one is not on screen: no terminal window on this Mac shows it."
        ))
    }

    /// The board names an away session's last window; the click carries it on from that.
    @Test func anAwaySessionOnTheBoardIsCarriedOnFromItsLastWindow() async throws {
        let place: [String: Any] = ["device": "/dev/ttys087", "terminal": "ghostty", "tmux": NSNull(), "zmx": ["session": Self.leeway]]
        let line = try board([], sessions: ["sr-q": "Quiet one"], last: [
            "sr-q": ["writer": Self.claude, "where": place, "ownsDevice": true, "directory": Self.folder],
        ])
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree))
        let opening = try #require(await jumping.jump.run(to: "sr-q", on: GivenBoard(line)).opening)

        #expect(!line.isHeld("sr-q"))
        #expect(line.resumeWindow(of: "sr-q") == Self.last())
        #expect(await opening.open() == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed])
    }

    // MARK: Its Claude still alive: the guard and {tty}

    /// A Claude Code process on its device, whichever installer's, its device its conversation's: the default refuses;
    /// Lee's command runs, `{tty}` the device.
    @Test(arguments: ["/Users/lee/.local/share/claude/versions/2.1.322", "/opt/homebrew/bin/claude"])
    func aClaudeRunningOnItsDeviceRefusesTheDefaultAndFillsTty(program: String) async {
        var mac = Mac()

        mac.claude(on: kitTerminal.device, program: program)

        let byDefault = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: [])
        let lees = Jumping(FakeTmux(), FakeTable(mac.tree), terminals: [], resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last(Self.inGhostty)) == stillRunning)
        #expect(byDefault.ghostty.told.isEmpty)
        #expect(await lees.carryOn(from: Self.last(Self.inGhostty)) == .opened)
        #expect(lees.ghostty.opened == [Self.leesLine(tty: kitTerminal.device)])
    }

    /// A device a later conversation was seen on is that one's: its Claude refuses nothing, and is no `{tty}`.
    @Test func aClaudeOfALaterConversationOnTheDeviceIsNotTheSessions() async {
        let table = Self.withClaude(on: kitTerminal.device)
        let byDefault = Jumping(FakeTmux(), table, terminals: [])
        let lees = Jumping(FakeTmux(), table, terminals: [], resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last(Self.inGhostty, ownsDevice: false)) == .opened)
        #expect(byDefault.ghostty.opened == [Self.resumed])
        #expect(await lees.carryOn(from: Self.last(Self.inGhostty, ownsDevice: false)) == .opened)
        #expect(lees.ghostty.opened == [Self.leesLine()])
    }

    /// A line from a CLI that does not say whether the device is still the conversation's: its Claude may be the
    /// session's, so the default refuses, but whose it is is not known, so it is no `{tty}`.
    @Test func aClaudeOnADeviceNotSaidToBeTheConversationsMayBeAliveButIsNoTty() async {
        let table = Self.withClaude(on: kitTerminal.device)
        let byDefault = Jumping(FakeTmux(), table, terminals: [])
        let lees = Jumping(FakeTmux(), table, terminals: [], resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last(Self.inGhostty, ownsDevice: nil)) == stillRunning)
        #expect(await lees.carryOn(from: Self.last(Self.inGhostty, ownsDevice: nil)) == .opened)
        #expect(lees.ghostty.opened == [Self.leesLine()])
    }

    /// No Claude on its device, a shell alone there: `{tty}` is empty.
    @Test func noClaudeOnItsDeviceFillsTtyEmpty() async {
        let table = Self.withClaude(on: "/dev/ttys042")
        let jumping = Jumping(FakeTmux(), table, terminals: [], resume: Self.lees)

        #expect(await jumping.carryOn(from: Self.last(Self.inGhostty)) == .opened)
        #expect(jumping.ghostty.opened == [Self.leesLine()])
    }

    /// The default is told by its text, so a command saved the same as it, spaces round it or not, is the default.
    @Test(arguments: [OpenSettings.defaultResumeCommand, "  \(OpenSettings.defaultResumeCommand) "])
    func aCommandSavedTheSameAsTheDefaultIsTheDefault(command: String) async {
        let jumping = Jumping(FakeTmux(), Self.withClaude(on: kitTerminal.device), terminals: [], resume: command)

        #expect(await jumping.carryOn(from: Self.last(Self.inGhostty)) == stillRunning)
    }

    /// Away, its Claude on its device is read before anything opens; held, whether it is here is read first, from the
    /// same table, so unknown, refused in the jump's words.
    @Test func aTableGivingNoAnswerRefusesBeforeAnythingOpens() async {
        let jumping = Jumping(FakeTmux(), FakeTable(nil), resume: Self.lees)
        let overSsh = Where(device: "/dev/ttys080")

        #expect(await jumping.carryOn(from: Self.last(Self.inGhostty)) == .unopened(
            "Could not tell whether \(named)'s Claude is still running: the process table gave no answer."
        ))
        #expect(await jumping.open([overSsh], from: Self.last(overSsh), isHeld: true) == .refused(
            "Could not tell whether \(named) is on screen: the process table gave no answer."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: A Claude suspended

    /// Lee suspended it, with Ctrl-Z, where a terminal here shows it: SitRep takes him to its window, starts nothing,
    /// never types `fg`, and says why, whoever was seen on the device after, before any command is checked.
    @Test(arguments: [true, false])
    func aSuspendedClaudeATerminalHereShowsTakesLeeToItsWindowStartingNothing(ownsDevice: Bool) async {
        let table = Self.withClaude(on: kitTerminal.device, isStopped: true, isShown: true)

        for jumping in [Jumping(FakeTmux(), table, resume: Self.lees), Jumping(FakeTmux(), table, resume: "")] {
            #expect(await jumping.carryOn(from: Self.last(Self.inGhostty, ownsDevice: ownsDevice)) == .jumpedSaying(Self.suspended))
            #expect(jumping.ghostty.focused == [kitTerminal.id])
            #expect(jumping.ghostty.opened.isEmpty)
        }
    }

    /// In zmx, taken to the terminal showing its session.
    @Test func aSuspendedClaudeInZmxATerminalHereShowsTakesLeeToItsSession() async {
        let (table, terminals) = Self.shown(claude: true)
        let jumping = Jumping(FakeTmux(), table, terminals: terminals, resume: Self.lees)

        #expect(await jumping.carryOn(from: Self.last()) == .jumpedSaying(Self.suspended))
        #expect(jumping.ghostty.focused == ["PORTAL-TERMINAL"])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// In tmux, taken to the Ghostty window showing its pane's tmux window, by the pane.
    @Test func aSuspendedClaudeInTmuxTakesLeeToItsPane() async {
        var mac = Mac()
        let client = mac.ghosttyClient(window, showing: claudes)

        mac.claude(on: inTmux().device ?? "", isStopped: true)

        let jumping = Jumping(server([client]), FakeTable(mac.tree), resume: Self.lees)

        #expect(await jumping.carryOn(from: Self.last(inTmux())) == .jumpedSaying(Self.suspended))
        #expect(jumping.ghostty.focused == [switchboardTerminal.id])
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// No terminal here shows it: carried on as any session not here, its Claude still alive, so the default refuses
    /// and Lee's command runs, `{tty}` the device it is suspended on.
    @Test func aSuspendedClaudeNoTerminalHereShowsIsCarriedOnByTheCommand() async {
        let device = inZmx(Self.leeway).device ?? ""
        let table = Self.withClaude(on: device, isStopped: true)
        let byDefault = Jumping(FakeTmux(), table)
        let lees = Jumping(FakeTmux(), table, resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last()) == stillRunning)
        #expect(byDefault.ghostty.told.isEmpty)
        #expect(await lees.carryOn(from: Self.last()) == .opened)
        #expect(lees.ghostty.opened == [Self.leesLine(tty: device)])
    }

    /// Shown, but its window not coming forward: it still says the Claude is suspended, and where, and nothing opens.
    @Test func aSuspendedClaudeWhoseWindowDoesNotComeForwardStillSaysItIsSuspended() async {
        let lost = Where(device: "/dev/ttys080", terminal: "ghostty")
        let table = Self.withClaude(on: "/dev/ttys080", isStopped: true, isShown: true)
        let jumping = Jumping(FakeTmux(), table, terminals: [], resume: Self.lees)

        #expect(await jumping.carryOn(from: Self.last(lost)) == .refused(
            "\(named) is suspended in its window, which SitRep could not bring forward: type fg there to bring it back."
        ))
        #expect(jumping.ghostty.opened.isEmpty)
    }

    /// Suspended over ssh from another Mac, its heartbeat carrying Ghostty's `$TERM_PROGRAM`, and Ghostty here holding
    /// a terminal on a device of its name: not here by the read, so carried on, never jumped to; the default refusing,
    /// as its Claude is alive.
    @Test func aSuspendedClaudeOverSshIsCarriedOnNeverJumpedTo() async {
        var mac = Mac()
        let shell = mac.tree.shell(under: ["/usr/sbin/sshd", "/usr/libexec/sshd-session"], on: kitTerminal.device)

        mac.tree.add(under: shell, "/opt/homebrew/bin/claude", on: kitTerminal.device, isStopped: true)

        let byDefault = Jumping(FakeTmux(), FakeTable(mac.tree))
        let lees = Jumping(FakeTmux(), FakeTable(mac.tree), resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last(Self.inGhostty)) == stillRunning)
        #expect(byDefault.ghostty.told.isEmpty)
        #expect(await lees.carryOn(from: Self.last(Self.inGhostty)) == .opened)
        #expect(lees.ghostty.focused == [FakeGhostty.opened])
    }

    /// A Claude suspended on its device that a later conversation took, as one started in the shell it was suspended
    /// in, then detached: still alive, so the default refuses rather than resume beside it; it is no `{tty}`.
    @Test func aSuspendedClaudeOnADeviceALaterConversationTookRefusesTheDefault() async {
        let table = Self.withClaude(on: inZmx(Self.leeway).device ?? "", isStopped: true)
        let byDefault = Jumping(FakeTmux(), table)
        let lees = Jumping(FakeTmux(), table, resume: Self.lees)

        #expect(await byDefault.carryOn(from: Self.last(ownsDevice: false)) == stillRunning)
        #expect(byDefault.ghostty.told.isEmpty)
        #expect(await lees.carryOn(from: Self.last(ownsDevice: false)) == .opened)
        #expect(lees.ghostty.opened == [Self.leesLine()])
    }

    /// Whether a terminal shows its window unknown: refused in the jump's words, and nothing opens.
    @Test func aSuspendedClaudeWhoseWindowsShowingIsUnknownIsRefusedInTheJumpsWords() async {
        let jumping = Jumping(FakeTmux(silent: true), Self.withClaude(on: inTmux().device ?? "", isStopped: true), resume: Self.lees)

        #expect(await jumping.carryOn(from: Self.last(inTmux())) == .refused(
            "Could not tell whether \(named) is on screen: tmux gave no answer."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: The command's refusals

    /// A field cleared to empty: nothing opens, and the click says to set one or restore the default.
    @Test(arguments: ["", "  "])
    func anEmptyCommandSaysToSetOneOrRestoreTheDefaultAndNothingOpens(command: String) async {
        let jumping = Jumping(resume: command)

        #expect(await jumping.carryOn(from: Self.last()) == .unopened(
            "The resume command in Settings is empty. To carry \(named) on, set one, or restore the default."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    /// A window on an older build said no folder: a command naming `{dir}` is refused; one naming only `{claude}` runs.
    @Test func aLastWindowSayingNoFolderRefusesACommandNamingDirAlone() async {
        let refusing = Jumping()
        let running = Jumping(resume: "claude --resume {claude}")

        #expect(await refusing.carryOn(from: Self.last(directory: nil)) == .unopened(
            "\(named)'s last window did not say which folder it ran in, as a window on an older sitrep does not, so SitRep has nothing to put for {dir}."
        ))
        #expect(refusing.ghostty.told.isEmpty)
        #expect(await running.carryOn(from: Self.last(directory: nil)) == .opened)
        #expect(running.ghostty.opened == ["claude --resume '\(Self.claude)'"])
    }

    @Test func ghosttyNotRunningIsRefusedAsAnOpeningIsAndNothingIsSent() async {
        let jumping = Jumping(workspace: FakeWorkspace(running: []))

        #expect(await jumping.carryOn(from: Self.last()) == .unopened(
            "SitRep opens a window only in a Ghostty already running. Open Ghostty, then click \(named) again."
        ))
        #expect(jumping.ghostty.told.isEmpty)
    }

    // MARK: One window per click

    /// A resumed Claude reaches the board only once it has started, its plugin loaded, taken the session up and beaten:
    /// a click while its window opens opens no second, two minutes at most.
    @Test func aSecondClickWhileItsWindowOpensOpensNoOtherForTwoMinutes() async {
        let clock = MovingClock()
        let jumping = Jumping(openings: RecentOpenings(now: clock.now))

        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        clock.move(by: .seconds(11))
        #expect(await jumping.carryOn(from: Self.last()) == .opening)
        clock.move(by: .seconds(108))
        #expect(await jumping.carryOn(from: Self.last()) == .opening)
        #expect(jumping.ghostty.opened == [Self.resumed])

        clock.move(by: .seconds(1) + .milliseconds(1))
        #expect(await jumping.carryOn(from: Self.last()) == .opened, "forgotten after two minutes")
        #expect(jumping.ghostty.opened == [Self.resumed, Self.resumed])
        #expect(RecentOpenings.lasts == .seconds(120))
    }

    /// Its Claude back on the board, an away session's opening is done: once away again, a click carries it on afresh.
    /// A session a window held at the click is held already, so the board holding it tells nothing.
    @Test func anOpeningIsForgottenOnceTheBoardHoldsASessionNoWindowHeldAtTheClick() async throws {
        let openings = RecentOpenings()
        let jumping = Jumping(openings: openings)
        let held = try board([LineWindow(writer: Self.claude, session: "sr-a", order: 0, zmx: Self.leeway)])

        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        openings.heard(try board([LineWindow(writer: "w2", session: "sr-b", order: 0, zmx: "other")]))
        #expect(openings.isOpening("sr-a"), "another session held tells nothing of this one")

        openings.heard(held)
        #expect(!openings.isOpening("sr-a"))
        #expect(await jumping.carryOn(from: Self.last()) == .opened)
        #expect(jumping.ghostty.opened == [Self.resumed, Self.resumed])

        openings.remember("sr-a", wasHeld: true)
        openings.heard(held)
        #expect(openings.isOpening("sr-a"))
    }

    /// A held session's command reaches a Claude already running, which reads as here within a read or two: its
    /// opening lasts 10 seconds, so one that failed holds back no click for long.
    @Test func aHeldSessionsOpeningLastsTenSeconds() async {
        let clock = MovingClock()
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), resume: Self.lees, openings: RecentOpenings(now: clock.now))

        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .opened)
        clock.move(by: .seconds(9))
        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .opening)
        clock.move(by: .seconds(1))
        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .opened)
        #expect(RecentOpenings.heldLasts == .seconds(10))
    }

    /// A held session's opening is remembered as held, so the board, which holds it already, never forgets it.
    @Test func aHeldSessionsOpeningOutlivesTheBoardHoldingIt() async throws {
        let openings = RecentOpenings()
        let jumping = Jumping(FakeTmux(), FakeTable(Mac().tree), resume: Self.lees, openings: openings)

        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .opened)
        openings.heard(try board([LineWindow(writer: Self.claude, session: "sr-a", order: 0, zmx: Self.leeway)]))
        #expect(await jumping.open([inZmx(Self.leeway)], from: Self.last(), isHeld: true) == .opening)
        #expect(jumping.ghostty.opened.count == 1)
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
