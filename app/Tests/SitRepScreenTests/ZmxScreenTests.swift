import Darwin
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// Claude in zmx: on the session's own pty, which no terminal is on, Ghostty's `$TERM_PROGRAM` passed on.
func inZmx(_ session: String) -> Where {
    Where(device: "/dev/ttys087", terminal: "ghostty", zmx: Where.Zmx(session: session))
}

@Suite(.backstop)
struct ZmxScreenTests {
    private static let portals = "proseware-Qm4tZ8"
    private static let litware = "litware · restore-card"
    private static let proseware = "adventure-works-v2 · proseware-build"

    /// Sessions in zmx: one Portal attached in a Ghostty window, one attached in a Terminal window, and one with no
    /// client, only its server; beside a session in tmux a Ghostty window shows.
    private static func lees() async -> (screen: Screen, tmux: FakeTmux, table: FakeTable, clients: [pid_t]) {
        var mac = Mac()
        let clients = [
            mac.throughPortal(portals, relay: "/dev/ttys032", window: "/dev/ttys036"),
            mac.zmxInTerminal(litware, on: "/dev/ttys030"),
        ]

        mac.zmxServer(portals, running: ["/opt/homebrew/bin/portal", "state", "hydrate"])
        mac.zmxServer(litware)
        mac.zmxServer(proseware, running: ["/opt/homebrew/bin/portal", "state", "hydrate"])

        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@1")
        let tmux = FakeTmux([socket: FakeServer(panes: [FakePane(pane: "%1", window: "@1", session: "$1")], clients: [client])])
        let table = FakeTable(mac.tree)
        let windows = [inZmx(portals), inZmx(litware), inZmx(proseware), inTmux("%1")]

        return (await read(windows, tmux, table), tmux, table, clients)
    }

    @Test func aSessionInZmxIsOnScreenWhereAClientIsInATerminalAppOnItsOwnChildsDeviceThroughPortalsRelay() async {
        let screen = await Self.lees().screen

        #expect(screen.reach(of: [inZmx(Self.portals)]) == .onScreen([Place(app: ghostty, device: "/dev/ttys036")]))
        #expect(screen.reach(of: [inZmx(Self.litware)]) == .onScreen([Place(app: terminal, device: "/dev/ttys030")]))
        #expect(screen.reach(of: [inZmx(Self.proseware)]) == .offScreen, "its server is no client")
        #expect(screen.reach(of: [inTmux("%1")]).app == ghostty)
    }

    @Test func tmuxIsAskedOnlyForTheSessionInTmuxAndOnlyZmxsProcessesOnATtyHaveTheirCommandLinesRead() async {
        let lees = await Self.lees()

        #expect(lees.tmux.runs.map(\.[0]) == [socket, socket])
        #expect(lees.table.looks == 1)
        #expect(lees.table.argumentsRead == lees.clients.sorted(), "never a server's, a shell's or tmux's")
    }

    @Test func aZmxSessionIsMatchedByItsWholeName() async {
        var mac = Mac()

        mac.throughPortal(Self.litware, relay: "/dev/ttys041", window: "/dev/ttys051")
        mac.throughPortal("x litware", relay: "/dev/ttys042", window: "/dev/ttys052")
        mac.throughPortal("litware", relay: "/dev/ttys004", window: "/dev/ttys053")
        mac.throughPortal("adventure-works-v2", relay: "/dev/ttys044", window: "/dev/ttys054")
        mac.throughPortal("proseware-build", relay: "/dev/ttys045", window: "/dev/ttys055")
        mac.throughPortal(Self.proseware, relay: "/dev/ttys046", window: "/dev/ttys056")
        mac.zmxServer("litware")

        let sessions = ["litware", Self.litware, Self.proseware, "adventure-works-v2"]
        let screen = await read(sessions.map(inZmx), FakeTmux(), FakeTable(mac.tree))

        #expect(sessions.map { screen.places(showing: [inZmx($0)]).map(\.device) } == [
            ["/dev/ttys053"], ["/dev/ttys051"], ["/dev/ttys056"], ["/dev/ttys054"],
        ])
    }

    @Test func aZmxSessionInTwoWindowsIsTriedOldestClientFirstByProcessIdNotByTerminal() async {
        var mac = Mac()
        let older = mac.throughPortal("litware", relay: "/dev/ttys061", window: "/dev/ttys060")
        let newer = mac.throughPortal("litware", relay: "/dev/ttys032", window: "/dev/ttys036")
        let screen = await read([inZmx("litware")], FakeTmux(), FakeTable(mac.tree))

        #expect(older < newer)
        #expect(screen.places(showing: [inZmx("litware")]).map(\.device) == ["/dev/ttys060", "/dev/ttys036"])
    }

    @Test(arguments: [
        ["zmx", "attach", "litware"], ["/opt/homebrew/bin/zmx", "attach", "litware"], ["/Users/me/bin/zmx", "attach", "litware"],
    ])
    func aClientIsZmxAttachToTheSessionByAnyPathToZmx(arguments: [String]) {
        #expect(ZmxReading.attaches(arguments, to: "litware"))
    }

    @Test(arguments: [
        ["zmx", "a", "litware"], ["zmx", "attach", "--labels", "x", "litware"], ["zmx", "attach", "litware", "/bin/zsh"],
        ["notzmx", "attach", "litware"], ["zmx", "attach", "litware · restore-card"], ["zmx", "attach"], [],
    ])
    func anyOtherCommandLineIsNoClientOfIt(arguments: [String]) {
        #expect(!ZmxReading.attaches(arguments, to: "litware"))
    }

    @Test func aZmxClientCountsOnlyOnATtyOfItsOwnOneOverPipesIsNoPlaceThoughItsAppNeedsNoDevice() async {
        var mac = Mac()

        mac.zmxInTerminal("litware", on: "/dev/ttys030", isPiped: true)
        mac.throughPortal("litware", relay: "/dev/ttys032", window: "/dev/ttys060")

        let screen = await read([inZmx("litware")], FakeTmux(), FakeTable(mac.tree))

        #expect(seen(screen.places(showing: [inZmx("litware")])) == [["/dev/ttys060", "Ghostty", nil]])
    }

    @Test func withTmuxMissingASessionInZmxStillSaysWhereItIsAndOnlyTheOneInTmuxIsUnknown() async {
        var mac = Mac()

        mac.throughPortal(Self.portals, relay: "/dev/ttys032", window: "/dev/ttys036")

        let tmux = FakeTmux(silent: true)
        let windows = [inZmx(Self.portals), inZmx(Self.proseware), inTmux("%1")]
        let screen = await read(windows, tmux, FakeTable(mac.tree))

        #expect(screen.reach(of: [windows[0]]).app == ghostty)
        #expect(screen.reach(of: [windows[1]]) == .offScreen)
        #expect(screen.reach(of: [windows[2]]) == .unknown([.tmux]))
        #expect(screen.unanswered(for: windows) == [.tmux])

        _ = await read([inZmx(Self.portals)], tmux, FakeTable(mac.tree))

        #expect(tmux.runs.count == 2, "a window in zmx never asks tmux")
    }

    @Test func aSessionInZmxIsUnknownNeverOffWhenTheTableGivesNoAnswerAsOnlyTheTableTellsItsClients() async {
        let screen = await read([inZmx(Self.portals)], FakeTmux(), FakeTable(nil))

        #expect(screen.reach(of: [inZmx(Self.portals)]) == .unknown([.processes]))
    }

    /// Where a window recording tmux's pane and zmx's `litware` on the device given shows: a Ghostty window holds a
    /// tmux client on the pane's window, the pane on the device given, and another a Portal client of `litware`.
    private static func nestedPlaces(device: String, paneDevice: String) async -> [[String?]] {
        var mac = Mac()
        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45")

        mac.throughPortal("litware", relay: "/dev/ttys032", window: "/dev/ttys060")

        let pane = FakePane(pane: "%12", window: "@45", session: "$45", device: paneDevice)
        let window = Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: "%12"), zmx: Where.Zmx(session: "litware"))
        let screen = await read([window], FakeTmux([socket: FakeServer(panes: [pane], clients: [client])]), FakeTable(mac.tree))

        return seen(screen.places(showing: [window]))
    }

    @Test func aWindowInTmuxAndZmxIsInTheInnermostTmuxWhereItsPaneIsOnTheWindowsDeviceElseZmxBothTmuxFirstWhereTmuxCannotTell() async {
        #expect(await Self.nestedPlaces(device: "/dev/ttys004", paneDevice: "/dev/ttys004") == [["/dev/ttys000", "Ghostty", nil]], "tmux inside zmx")
        #expect(await Self.nestedPlaces(device: "/dev/ttys087", paneDevice: "/dev/ttys004") == [["/dev/ttys060", "Ghostty", nil]], "zmx inside tmux")
        #expect(
            await Self.nestedPlaces(device: "/dev/ttys087", paneDevice: "")
                == [["/dev/ttys000", "Ghostty", nil], ["/dev/ttys060", "Ghostty", nil]],
            "the pane saying no device"
        )
    }
}
