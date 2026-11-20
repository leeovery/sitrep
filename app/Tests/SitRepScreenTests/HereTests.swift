import Darwin
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// Whether a session is here (stage 8's "Here"): a terminal on this Mac that SitRep can take Lee to shows it, by the
/// process table, and tmux where a window runs in it; never by the heartbeat's `$TERM_PROGRAM`; unknown where what was
/// asked gave no answer.
@Suite(.backstop)
struct HereTests {
    private static let portals = "proseware-Qm4tZ8"

    /// Whether the session the windows hold is here, read through tmux and the table given.
    private static func here(_ windows: [Where], _ tmux: FakeTmux = FakeTmux(), _ table: FakeTable) async -> Here {
        await HereReader(tmux: tmux, table: table).read(windows)
    }

    /// A Claude outside any multiplexer on the device, under the shell given.
    private static func claude(under shell: pid_t, on device: String, in tree: inout Tree) {
        tree.add(under: shell, "/Users/me/.local/share/claude/versions/2.1.322", on: device)
    }

    // MARK: Outside a multiplexer

    /// Its device's shell descends from a terminal app, whichever: Ghostty by its driver, the others whole, as the jump
    /// brings them forward. Its `$TERM_PROGRAM` is never read: one naming no app is here all the same.
    @Test(arguments: [ghosttyProgram, terminalProgram, codeHelper])
    func aWindowWhoseDeviceATerminalAppHoldsIsHere(app: String) async {
        var mac = Mac()
        let device = "/dev/ttys041"

        let shell = mac.tree.window(of: mac.tree.app(app), on: device)

        Self.claude(under: shell, on: device, in: &mac.tree)

        #expect(await Self.here([Where(device: device)], FakeTmux(), FakeTable(mac.tree)) == .here)
    }

    /// Through a relaying pty, Portal's or `script`'s, its shell still descends from the terminal app.
    @Test func aWindowOnARelayingPtyInATerminalAppIsHere() async {
        var mac = Mac()
        let relay = mac.tree.relay(under: mac.tree.window(of: mac.ghostty, on: "/dev/ttys036"), on: "/dev/ttys036")

        let shell = mac.tree.add(under: relay, "/bin/zsh", on: "/dev/ttys032")

        Self.claude(under: shell, on: "/dev/ttys032", in: &mac.tree)

        #expect(await Self.here([Where(device: "/dev/ttys032")], FakeTmux(), FakeTable(mac.tree)) == .here)
    }

    /// Reached over ssh, or from Lee's phone, its shell descends from a remote login, never a terminal app here: not
    /// here, though its heartbeat carries Ghostty's `$TERM_PROGRAM`, and Ghostty here holds a terminal on a device of
    /// the same name.
    @Test(arguments: [["/usr/sbin/sshd", "/usr/libexec/sshd-session"], ["/opt/homebrew/bin/mosh-server"]])
    func aWindowReachedByARemoteLoginIsNotHereWhateverItsTermProgramSays(login: [String]) async {
        var mac = Mac()
        let device = "/dev/ttys080"

        let shell = mac.tree.shell(under: login, on: device)

        Self.claude(under: shell, on: device, in: &mac.tree)

        let ghosttys = Where(device: device, terminal: "ghostty")

        #expect(await Self.here([ghosttys], FakeTmux(), FakeTable(mac.tree)) == .notHere)
    }

    /// A remote login is no window of this Mac's even run from a terminal's shell: its sessions are not here.
    @Test func anSshdStartedInATerminalShowsNoneOfItsSessionsHere() async {
        var mac = Mac()
        let sshd = mac.tree.add(under: mac.tree.window(of: mac.ghostty, on: "/dev/ttys000"), "/usr/sbin/sshd")
        let session = mac.tree.add(under: sshd, "/usr/libexec/sshd-session")

        let shell = mac.tree.add(under: session, "/bin/zsh", on: "/dev/ttys080")

        Self.claude(under: shell, on: "/dev/ttys080", in: &mac.tree)

        #expect(await Self.here([Where(device: "/dev/ttys080")], FakeTmux(), FakeTable(mac.tree)) == .notHere)
    }

    /// Nothing on its device a terminal app holds, or no device said: not here.
    @Test(arguments: [Where(device: "/dev/ttys099", terminal: "ghostty"), Where(terminal: "ghostty")])
    func aWindowNoTerminalAppHoldsIsNotHere(where: Where) async {
        var mac = Mac()

        mac.claude(on: "/dev/ttys099")

        #expect(await Self.here([`where`], FakeTmux(), FakeTable(mac.tree)) == .notHere)
    }

    /// The table giving no answer: unknown, never not here.
    @Test func aWindowOutsideAnyMultiplexerWithNoTableIsUnknown() async {
        #expect(await Self.here([inGhosttyWindow], FakeTmux(), FakeTable(nil)) == .unknown([.processes]))
    }

    // MARK: In a multiplexer

    /// tmux: a client seated in a terminal app shows its pane's tmux window, or is attached to a tmux session holding
    /// it, where a select would show it; the phone's and an ssh client's are seated in none.
    @Test func aWindowInTmuxIsHereWhereAClientOfItsSessionIsSeatedInATerminalApp() async {
        var mac = Mac()
        let showing = mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)
        let selectable = mac.terminalClient("/dev/ttys030", showing: JumpWorld.beside, in: "$45")
        let elsewhere = [mac.phoneClient(JumpWorld.phone, showing: JumpWorld.claudes), mac.sshClient("/dev/ttys080", showing: JumpWorld.claudes)]
        let table = FakeTable(mac.tree)

        #expect(await Self.here([inTmux()], server([showing]), table) == .here)
        #expect(await Self.here([inTmux()], server([selectable]), table) == .here)
        #expect(await Self.here([inTmux()], server(elsewhere), table) == .notHere)
        #expect(await Self.here([inTmux()], server([]), table) == .notHere)
        #expect(await Self.here([inTmux()], FakeTmux(), table) == .notHere, "no server on its socket")
    }

    /// tmux not answering, or answering an error other than no server, and the table giving no answer where its
    /// clients are told by it: unknown.
    @Test func aWindowInTmuxWhoseShowingIsNotToldIsUnknown() async {
        var mac = Mac()
        let showing = mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)

        #expect(await Self.here([inTmux()], FakeTmux(silent: true), FakeTable(mac.tree)) == .unknown([.tmux]))
        #expect(await Self.here([inTmux()], FakeTmux(failing: [socket: "lost server"]), FakeTable(mac.tree))
            == .unknown([.tmuxSaid("lost server")]))
        #expect(await Self.here([inTmux()], server([showing]), FakeTable(nil)) == .unknown([.processes]))
    }

    /// zmx: a client attached to its session seated in a terminal app, through Portal's relay; one with only its
    /// server, or attached only from Lee's phone, not here; the table giving no answer, unknown.
    @Test func aWindowInZmxIsHereWhereAClientOfItsSessionIsSeatedInATerminalApp() async {
        var shown = Mac(), phoned = Mac()

        shown.throughPortal(Self.portals, relay: "/dev/ttys032", window: "/dev/ttys036")
        shown.zmxServer(Self.portals)
        let mosh = phoned.tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: JumpWorld.phone)

        phoned.tree.zmx(Self.portals, under: mosh, on: JumpWorld.phone)
        phoned.zmxServer(Self.portals)

        #expect(await Self.here([inZmx(Self.portals)], FakeTmux(), FakeTable(shown.tree)) == .here)
        #expect(await Self.here([inZmx(Self.portals)], FakeTmux(), FakeTable(phoned.tree)) == .notHere)
        #expect(await Self.here([inZmx(Self.portals)], FakeTmux(), FakeTable(nil)) == .unknown([.processes]))
    }

    /// A click asks only whether this Mac's screen shows the session, so its read of here reads no environment, nor any
    /// zmx server's command line, both of which the read for `here.json` reads: Lee's case, a zmx session attached from
    /// his phone over ssh, read both ways.
    @Test func aClicksReadOfHereReadsNoEnvironmentNorAnyZmxServersCommandLine() async {
        var mac = Mac()
        let client = mac.zmxOverSsh(Self.portals, on: "/dev/ttys050")
        let server = mac.zmxServer(Self.portals, tty: "/dev/ttys087")
        let clicked = FakeTable(mac.tree), viewed = FakeTable(mac.tree)

        _ = await Jumping(FakeTmux(), clicked).outcome([inZmx(Self.portals)])
        _ = await HereReader(tmux: FakeTmux(), table: viewed).read(["sr-a": [inZmx(Self.portals)]])

        #expect(clicked.addressReaders == 0)
        #expect(!clicked.argumentsRead.contains(server))
        #expect(viewed.addressesRead == [client])
        #expect(viewed.argumentsRead.contains(server))
    }

    // MARK: A session

    /// Of a session's windows, here where any is, though another's showing is unknown; unknown where none is here and
    /// any is unknown; and with none, never here, as a session no window holds is away.
    @Test func aSessionIsHereWhereAnyOfItsWindowsIsAndUnknownOnlyWhereNoneIs() async {
        var mac = Mac()

        _ = mac.tree.window(of: mac.ghostty, on: inGhosttyWindow.device ?? "")

        let table = FakeTable(mac.tree)
        let silent = FakeTmux(silent: true)

        #expect(await Self.here([inTmux(), inGhosttyWindow], silent, table) == .here)
        #expect(await Self.here([inTmux(), Where(device: "/dev/ttys099")], silent, table) == .unknown([.tmux]))
        #expect(await Self.here([Where(device: "/dev/ttys099")], silent, table) == .notHere)
        #expect(await Self.here([], silent, table) == .notHere)
    }

    /// Every session read at once: the table looked at once, tmux asked once for each socket a window runs under, and
    /// not at all where none does.
    @Test func everySessionIsReadAtOnceTheTableOnceAndTmuxOnlyForItsSockets() async {
        var mac = Mac()

        _ = mac.tree.window(of: mac.ghostty, on: inGhosttyWindow.device ?? "")

        let showing = mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.claudes)
        let tmux = server([showing]), table = FakeTable(mac.tree)
        let read = await HereReader(tmux: tmux, table: table).read([
            "sr-a": [inTmux()], "sr-b": [inGhosttyWindow], "sr-c": [inTmux("%54"), Where(device: "/dev/ttys099")],
        ])

        #expect(read.sessions.mapValues(\.here) == ["sr-a": .here, "sr-b": .here, "sr-c": .notHere])
        #expect(table.looks == 1)
        #expect(tmux.runs.map(\.[1]).sorted() == ["list-clients", "list-panes"])

        let untouched = FakeTmux()

        _ = await HereReader(tmux: untouched, table: FakeTable(mac.tree)).read(["sr-b": [inGhosttyWindow]])
        #expect(untouched.runs.isEmpty)
    }
}
