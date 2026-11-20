import Darwin
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// Who views a session (DESIGN, "The board in a terminal", 20 November 2026): every client showing it gives a viewer,
/// `mac` where it is seated in a terminal app here, `ssh:` and its address where an SSH login reached it, and none
/// otherwise; and each tty inside a multiplexer session is viewed by that session's clients, for the board in a
/// terminal to look itself up. The notch's here is `mac` among them, as before.
@Suite(.backstop)
struct ViewerTests {
    private static let helpDesk = "northwind · help-desk"
    private static let shifts = "contoso · shifts"

    private static func read(
        _ sessions: [String: [Where]], _ tmux: FakeTmux = FakeTmux(), table: FakeTable
    ) async -> HereRead {
        await HereReader(tmux: tmux, table: table).read(sessions)
    }

    private static func viewers(_ windows: [Where], _ tmux: FakeTmux = FakeTmux(), table: FakeTable) async -> Sighting? {
        await read(["sr-nw0001": windows], tmux, table: table).sessions["sr-nw0001"]
    }

    // MARK: A client's viewer

    /// Attached through a relay in a Ghostty window, `mac`; from Lee's phone over ssh, the phone's address, from the
    /// environment sshd gave its login; through mosh, or from a process launchd took in, none.
    @Test func aClientIsMacInATerminalAppSshUnderAnSSHLoginAndNoneOtherwise() async {
        var mac = Mac()

        mac.throughPortal(Self.helpDesk, relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxOverSsh(Self.shifts, on: "/dev/ttys050")
        mac.tree.zmx("tailspin · invoices", under: mac.tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: "/dev/ttys051"), on: "/dev/ttys051")
        mac.tree.zmx("fabrikam · import", under: 1, on: "/dev/ttys052")

        let read = await Self.read(
            [
                "sr-nw0001": [inZmx(Self.helpDesk)], "sr-ct0002": [inZmx(Self.shifts)],
                "sr-tw0003": [inZmx("tailspin · invoices")], "sr-fb0004": [inZmx("fabrikam · import")],
            ],
            table: FakeTable(mac.tree)
        )

        #expect(read.sessions == [
            "sr-nw0001": .seen([.mac]), "sr-ct0002": .seen([.ssh(Mac.phone)]), "sr-tw0003": .seen([]), "sr-fb0004": .seen([]),
        ])
    }

    /// Lee's phone reaches this Mac through tssh, whose server, tsshd, runs apart under launchd, its environment the
    /// SSH login's that started it: a zmx client attached through a relay in a tab is the phone's, as one under sshd
    /// is; every tab the phone opens, each its own tsshd, counts as the phone; the iPad's, as another.
    @Test func aClientUnderTsshdIsTheDeviceItsSSHLoginCameFrom() async {
        var mac = Mac()

        mac.throughTssh(Self.helpDesk, relay: "/dev/ttys024", tab: "/dev/ttys035")
        mac.throughTssh(Self.helpDesk, relay: "/dev/ttys028", tab: "/dev/ttys050")
        mac.throughTssh(Self.helpDesk, relay: "/dev/ttys038", tab: "/dev/ttys036", from: Mac.iPad)

        #expect(await Self.viewers([inZmx(Self.helpDesk)], table: FakeTable(mac.tree)) == .seen([.ssh(Mac.phone), .ssh(Mac.iPad)]))
    }

    /// A login over ssh whose environment holds no `SSH_CONNECTION`, as `env -i` leaves one, gives none.
    @Test func aClientWhoseEnvironmentHoldsNoSSHConnectionIsNone() async {
        var mac = Mac()

        mac.tree.zmx(Self.helpDesk, under: mac.tree.shell(under: Mac.sshd, on: "/dev/ttys050"), on: "/dev/ttys050")

        #expect(await Self.viewers([inZmx(Self.helpDesk)], table: FakeTable(mac.tree)) == .seen([]))
    }

    /// Environments hold tokens, so only the clients an SSH login reached have theirs read: never one seated here, nor one
    /// through mosh.
    @Test func onlyTheEnvironmentsOfClientsReachedOverSSHAreRead() async {
        var mac = Mac()

        mac.throughPortal(Self.helpDesk, relay: "/dev/ttys032", window: "/dev/ttys036")
        let ssh = mac.zmxOverSsh(Self.helpDesk, on: "/dev/ttys050")
        mac.tree.zmx(Self.helpDesk, under: mac.tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: "/dev/ttys051"), on: "/dev/ttys051")

        let table = FakeTable(mac.tree)

        #expect(await Self.viewers([inZmx(Self.helpDesk)], table: table) == .seen([.mac, .ssh(Mac.phone)]))
        #expect(table.addressesRead == [ssh])
    }

    /// Every terminal one device opens counts as that device: two tabs of the phone, each its own login and tty, are
    /// one viewer; the iPad is another.
    @Test func everyTerminalOfOneDeviceCountsAsOne() async {
        var mac = Mac()

        mac.zmxOverSsh(Self.helpDesk, on: "/dev/ttys050")
        mac.zmxOverSsh(Self.helpDesk, on: "/dev/ttys053")
        mac.zmxOverSsh(Self.helpDesk, on: "/dev/ttys054", from: Mac.iPad)

        #expect(await Self.viewers([inZmx(Self.helpDesk)], table: FakeTable(mac.tree)) == .seen([.ssh(Mac.phone), .ssh(Mac.iPad)]))
    }

    /// A window in no multiplexer is viewed from its terminal: a Ghostty window's, `mac`; a login over ssh, its address.
    @Test func aWindowInNoMultiplexerIsViewedFromItsTerminal() async {
        var mac = Mac()

        _ = mac.tree.window(of: mac.ghostty, on: "/dev/ttys041")
        mac.tree.add(under: mac.tree.shell(under: Mac.sshd, on: "/dev/ttys080", ssh: Mac.phone), Self.claude, on: "/dev/ttys080")

        let read = await Self.read(
            ["sr-nw0001": [Where(device: "/dev/ttys041")], "sr-ct0002": [Where(device: "/dev/ttys080", terminal: "ghostty")]],
            table: FakeTable(mac.tree)
        )

        #expect(read.sessions == ["sr-nw0001": .seen([.mac]), "sr-ct0002": .seen([.ssh(Mac.phone)])])
    }

    /// macOS hides its own programs' environments, a login shell's among them: so the address is the first another
    /// process on the shell's tty gives, Claude's there, every one of them the login's; none where none gives one.
    @Test func aLoginShellsHiddenEnvironmentIsReadThroughAnotherProcessOnItsTty() async {
        var mac = Mac()
        let shell = mac.tree.shell(under: Mac.sshd, on: "/dev/ttys080", ssh: Mac.phone)
        let claude = mac.tree.add(under: shell, Self.claude, on: "/dev/ttys080")
        let table = FakeTable(mac.tree)
        var bare = Mac()

        _ = bare.tree.shell(under: Mac.sshd, on: "/dev/ttys080", ssh: Mac.phone)

        #expect(await Self.viewers([Where(device: "/dev/ttys080")], table: table) == .seen([.ssh(Mac.phone)]))
        #expect(table.addressesRead == [shell, claude])
        #expect(await Self.viewers([Where(device: "/dev/ttys080")], table: FakeTable(bare.tree)) == .seen([]))
    }

    private static let claude = "/Users/me/.local/share/claude/versions/2.1.322"

    /// tmux: every client showing the pane's tmux window, or attached to a tmux session holding it, where a select would
    /// show it, gives its viewer; one attached to another tmux session gives none.
    @Test func aTmuxPaneIsViewedByEachClientOfItsTmuxSession() async {
        var mac = Mac()
        let clients = [
            mac.terminalClient("/dev/ttys030", showing: JumpWorld.beside, in: "$45"),
            mac.sshClient("/dev/ttys080", showing: JumpWorld.claudes),
            mac.phoneClient(JumpWorld.phone, showing: JumpWorld.claudes),
            FakeClient(device: "/dev/ttys081", pid: mac.overSsh("/dev/ttys081", from: Mac.iPad), window: JumpWorld.litware),
        ]

        #expect(await Self.viewers([inTmux()], server(clients), table: FakeTable(mac.tree)) == .seen([.mac, .ssh(Mac.phone)]))
        #expect(await Self.viewers([inTmux()], server(Array(clients.dropFirst())), table: FakeTable(mac.tree)) == .seen([.ssh(Mac.phone)]))
    }

    // MARK: A session

    /// A session's viewers are every window's; `mac` among them wins over a window unknown, as here does; else any
    /// unknown leaves it unknown, never seen by nobody.
    @Test func aSessionsViewersAreEveryWindowsAndMacWinsOverUnknown() {
        let phone = Sighting.seen([.ssh(Mac.phone)])
        let unknown = Sighting.unknown([.tmux])

        #expect(Sighting([phone, .seen([.ssh(Mac.iPad)])]) == .seen([.ssh(Mac.phone), .ssh(Mac.iPad)]))
        #expect(Sighting([phone, .seen([.mac]), unknown]) == .seen([.mac, .ssh(Mac.phone)]))
        #expect(Sighting([phone, unknown, .unknown([.tmux, .processes])]) == .unknown([.tmux, .processes]))
        #expect(Sighting([]) == .seen([]))
    }

    /// The notch's here is `mac` among a session's viewers: Lee's case, a zmx session attached from his phone over ssh
    /// and detached on the Mac, is not here, so the notch dims it as before; attached in Ghostty too, it is here.
    @Test func theNotchsHereIsMacAmongTheViewers() async {
        var phoned = Mac()

        phoned.zmxOverSsh(Self.helpDesk, on: "/dev/ttys050")
        phoned.zmxServer(Self.helpDesk, tty: "/dev/ttys087")

        var both = phoned

        both.throughPortal(Self.helpDesk, relay: "/dev/ttys032", window: "/dev/ttys036")

        #expect(await Self.viewers([inZmx(Self.helpDesk)], table: FakeTable(phoned.tree))?.here == .notHere)
        #expect(await HereReader(tmux: FakeTmux(), table: FakeTable(phoned.tree)).read([inZmx(Self.helpDesk)]) == .notHere)
        #expect(await HereReader(tmux: FakeTmux(), table: FakeTable(both.tree)).read([inZmx(Self.helpDesk)]) == .here)
        #expect(Sighting.unknown([.processes]).here == .unknown([.processes]))
    }

    // MARK: The ttys

    /// Each zmx session's tty, the shell its server started, maps to the viewers of the session's clients, a session
    /// holding no Claude among them, as the board in a terminal runs in one; a session with no viewer, detached or
    /// attached only through mosh, maps none.
    @Test func eachZmxSessionsTtyMapsToItsViewersThoseHoldingNoClaudeAmongThem() async {
        var mac = Mac()

        mac.zmxServer("litware · board", tty: "/dev/ttys060")
        mac.zmxOverSsh("litware · board", on: "/dev/ttys050")
        mac.throughPortal("litware · board", relay: "/dev/ttys032", window: "/dev/ttys036")
        mac.zmxServer(Self.helpDesk, running: ["claude"], tty: "/dev/ttys061")
        mac.zmxOverSsh(Self.helpDesk, on: "/dev/ttys053", from: Mac.iPad)
        mac.zmxServer("woodgrove · notes", tty: "/dev/ttys062")
        mac.zmxServer(Self.shifts, tty: "/dev/ttys063")
        mac.tree.zmx(Self.shifts, under: mac.tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: "/dev/ttys051"), on: "/dev/ttys051")

        let read = await Self.read(["sr-nw0001": [inZmx(Self.helpDesk)]], table: FakeTable(mac.tree))

        #expect(read.ttys == ["/dev/ttys060": [.mac, .ssh(Mac.phone)], "/dev/ttys061": [.ssh(Mac.iPad)]])
    }

    /// Each pane's tty of a tmux server a window on the board runs under maps to the viewers of the clients showing it.
    @Test func eachTmuxPanesTtyMapsToItsViewers() async {
        var mac = Mac()
        let clients = [mac.sshClient("/dev/ttys080", showing: JumpWorld.claudes), mac.ghosttyClient(JumpWorld.window, showing: JumpWorld.litware)]
        let panes = [
            FakePane(pane: "%12", window: JumpWorld.claudes, session: "$45", device: "/dev/ttys070"),
            FakePane(pane: "%54", window: JumpWorld.litware, session: "$52", device: "/dev/ttys071"),
            FakePane(pane: "%60", window: "@60", session: "$60", device: "/dev/ttys072"),
        ]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, clients: clients)])

        let read = await Self.read(["sr-nw0001": [inTmux()]], tmux, table: FakeTable(mac.tree))

        #expect(read.ttys == ["/dev/ttys070": [.ssh(Mac.phone)], "/dev/ttys071": [.mac]])
    }

    /// The table giving no answer tells no tty, which is not the same as none.
    @Test func noTableTellsNoTtys() async {
        #expect(await Self.read(["sr-nw0001": [inZmx(Self.helpDesk)]], table: FakeTable(nil)).ttys == nil)
    }
}
