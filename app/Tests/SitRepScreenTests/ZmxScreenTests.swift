import Darwin
@testable import SitRepScreen
import Testing

/// Claude in zmx: on the session's own pty, which no terminal is on, Ghostty's `$TERM_PROGRAM` passed on.
func inZmx(_ session: String) -> Where {
    Where(device: "/dev/ttys087", terminal: "ghostty", zmx: Where.Zmx(session: session))
}

struct ZmxScreenTests {
    private static let portals = "sitrep-iFpz7T"
    private static let kit = "kit · restore-card"
    private static let leeway = "agentic-workflows-v2 · leeway-build"

    /// Sessions in zmx: one Portal attached in a Ghostty window, one attached in a Terminal window, and one with no
    /// client, only its server; beside a session in tmux a Ghostty window shows.
    private static func lees() async -> (screen: Screen, tmux: FakeTmux, table: FakeTable, zmx: [pid_t]) {
        var mac = Mac()
        let clients = [
            mac.throughPortal(portals, relay: "/dev/ttys032", window: "/dev/ttys036"),
            mac.zmxInTerminal(kit, on: "/dev/ttys030"),
        ]

        let servers = [
            mac.zmxServer(portals, running: ["/opt/homebrew/bin/portal", "state", "hydrate"]),
            mac.zmxServer(kit),
            mac.zmxServer(leeway, running: ["/opt/homebrew/bin/portal", "state", "hydrate"]),
        ]

        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@1")
        let tmux = FakeTmux([socket: FakeServer(panes: [FakePane(pane: "%1", window: "@1", session: "$1")], clients: [client])])
        let table = FakeTable(mac.tree)
        let windows = [inZmx(portals), inZmx(kit), inZmx(leeway), inTmux("%1")]

        return (await read(windows, tmux, table), tmux, table, clients + servers)
    }

    @Test func aSessionInZmxIsOnScreenWhereAClientIsInATerminalAppOnItsOwnChildsDeviceThroughPortalsRelay() async {
        let screen = await Self.lees().screen

        #expect(screen.reach(of: [inZmx(Self.portals)]) == .onScreen([Place(app: ghostty, device: "/dev/ttys036")]))
        #expect(screen.reach(of: [inZmx(Self.kit)]) == .onScreen([Place(app: terminal, device: "/dev/ttys030")]))
        #expect(screen.reach(of: [inZmx(Self.leeway)]) == .offScreen, "its server is no client")
        #expect(screen.reach(of: [inTmux("%1")]).app == ghostty)
    }

    @Test func tmuxIsAskedOnlyForTheSessionInTmuxAndOnlyZmxsProcessesHaveTheirCommandLinesRead() async {
        let lees = await Self.lees()

        #expect(lees.tmux.runs.map(\.[0]) == [socket, socket])
        #expect(lees.table.looks == 1)
        #expect(lees.table.argumentsRead == lees.zmx.sorted(), "its clients' and servers', never a shell's or tmux's")
    }

    /// An away session's last window has no live window to prove its zmx session alive: it runs while a process of
    /// zmx's attaches to it, its server or a client, so a window can be opened onto it; one with neither is gone, as
    /// after a restart Portal did not bring back, or a session ended (stage 8).
    @Test func anAwayWindowsZmxSessionIsAliveWhileItsServerOrAClientRunsAndGoneWithNeither() async {
        let screen = await Self.lees().screen

        #expect(screen.leftOf(inZmx(Self.leeway)) == .attachable(Attachable(where: inZmx(Self.leeway), kind: .zmx)))
        #expect(screen.leftOf(inZmx(Self.portals)) == .attachable(Attachable(where: inZmx(Self.portals), kind: .zmx)))
        #expect(screen.leftOf(inZmx("gone · session")) == .gone)
        #expect(await read([inZmx(Self.kit)], FakeTmux(), FakeTable(Mac().tree)).leftOf(inZmx(Self.kit)) == .gone)
    }

    /// A live window in zmx is its session's proof of life, as step C has it: the table is never asked, and a command
    /// line that did not read, of zmx's or another's, leaves where it shows as it was.
    @Test func aLiveWindowsZmxSessionIsHeldByTheWindowAloneAskingTheTableNothing() async {
        var mac = Mac()

        mac.zmxUnread()

        let shell = Processes([5: Proc(parent: 1, program: "/bin/zsh")], unreadable: [5])

        for screen in [Screen(readings: [ZmxReading()], processes: shell), await read([inZmx("kit")], FakeTmux(), FakeTable(mac.tree))] {
            #expect(screen.attachable([inZmx("kit")]) == Attachable(where: inZmx("kit"), kind: .zmx))
            #expect(screen.reach(of: [inZmx("kit")]) == .offScreen)
        }
    }

    @Test func aZmxSessionIsMatchedByItsWholeName() async {
        var mac = Mac()

        mac.throughPortal(Self.kit, relay: "/dev/ttys041", window: "/dev/ttys051")
        mac.throughPortal("x kit", relay: "/dev/ttys042", window: "/dev/ttys052")
        mac.throughPortal("kit", relay: "/dev/ttys043", window: "/dev/ttys053")
        mac.throughPortal("agentic-workflows-v2", relay: "/dev/ttys044", window: "/dev/ttys054")
        mac.throughPortal("leeway-build", relay: "/dev/ttys045", window: "/dev/ttys055")
        mac.throughPortal(Self.leeway, relay: "/dev/ttys046", window: "/dev/ttys056")
        mac.zmxServer("kit")

        let sessions = ["kit", Self.kit, Self.leeway, "agentic-workflows-v2"]
        let screen = await read(sessions.map(inZmx), FakeTmux(), FakeTable(mac.tree))

        #expect(sessions.map { screen.places(showing: [inZmx($0)]).map(\.device) } == [
            ["/dev/ttys053"], ["/dev/ttys051"], ["/dev/ttys056"], ["/dev/ttys054"],
        ])
    }

    @Test func aZmxSessionInTwoWindowsIsTriedOldestClientFirstByProcessIdNotByTerminal() async {
        var mac = Mac()
        let older = mac.throughPortal("kit", relay: "/dev/ttys061", window: "/dev/ttys060")
        let newer = mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys036")
        let screen = await read([inZmx("kit")], FakeTmux(), FakeTable(mac.tree))

        #expect(older < newer)
        #expect(screen.places(showing: [inZmx("kit")]).map(\.device) == ["/dev/ttys060", "/dev/ttys036"])
    }

    @Test(arguments: [
        ["zmx", "attach", "kit"], ["/opt/homebrew/bin/zmx", "attach", "kit"], ["/Users/lee/bin/zmx", "attach", "kit"],
    ])
    func aClientIsZmxAttachToTheSessionByAnyPathToZmx(arguments: [String]) {
        #expect(ZmxReading.attaches(arguments, to: "kit"))
    }

    @Test(arguments: [
        ["zmx", "a", "kit"], ["zmx", "attach", "--labels", "x", "kit"], ["zmx", "attach", "kit", "/bin/zsh"],
        ["notzmx", "attach", "kit"], ["zmx", "attach", "kit · restore-card"], ["zmx", "attach"], [],
    ])
    func anyOtherCommandLineIsNoClientOfIt(arguments: [String]) {
        #expect(!ZmxReading.attaches(arguments, to: "kit"))
    }

    /// A session is named by any of zmx's forms, so its server or any client of it tells it alive (stage 8).
    @Test(arguments: [
        ["zmx", "attach", "kit"], ["/opt/homebrew/bin/zmx", "attach", "kit", "/opt/homebrew/bin/portal", "state", "hydrate"],
        ["zmx", "a", "kit"], ["zmx", "attach", "--labels", "k=v", "kit"], ["zmx", "a", "--labels=k=v", "kit", "/bin/zsh"],
        ["zmx", "attach", "--labels", "k=v", "--labels=x=y", "kit"], ["zmx", "run", "kit"], ["zmx", "r", "kit", "-d", "make"],
    ])
    func eachOfZmxsFormsNamesItsSession(arguments: [String]) {
        #expect(ZmxReading.sessionNamed(by: arguments) == "kit")
    }

    @Test(arguments: [
        ["zmx", "list"], ["zmx", "kill", "kit"], ["zmx", "attach"], ["zmx", "attach", "--labels", "k=v"], ["zmx"],
        ["notzmx", "attach", "kit"], [],
    ])
    func anyOtherCommandLineNamesNoSession(arguments: [String]) {
        #expect(ZmxReading.sessionNamed(by: arguments) == nil)
    }

    /// Alive by a process naming it in any form, a client attached by `a` or with labels too, though only `zmx attach
    /// <session>` alone is a client a jump reaches.
    @Test func anAwayWindowsSessionIsAliveByAProcessNamingItInAnyForm() {
        let processes = Processes([:], arguments: [7: ["zmx", "a", "--labels=k=v", "kit"], 9: ["zmx", "run", "ledger", "-d"]])

        #expect(ZmxReading().isAlive(inZmx("kit"), processes) == true)
        #expect(ZmxReading().isAlive(inZmx("ledger"), processes) == true)
        #expect(ZmxReading().isAlive(inZmx("kit · restore-card"), processes) == false)
    }

    @Test func aZmxClientCountsOnlyOnATtyOfItsOwnOneOverPipesIsNoPlaceThoughItsAppNeedsNoDevice() async {
        var mac = Mac()

        mac.zmxInTerminal("kit", on: "/dev/ttys030", isPiped: true)
        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys060")

        let screen = await read([inZmx("kit")], FakeTmux(), FakeTable(mac.tree))

        #expect(seen(screen.places(showing: [inZmx("kit")])) == [["/dev/ttys060", "Ghostty", nil]])
    }

    @Test func withTmuxMissingASessionInZmxStillSaysWhereItIsAndOnlyTheOneInTmuxIsUnknown() async {
        var mac = Mac()

        mac.throughPortal(Self.portals, relay: "/dev/ttys032", window: "/dev/ttys036")

        let tmux = FakeTmux(silent: true)
        let windows = [inZmx(Self.portals), inZmx(Self.leeway), inTmux("%1")]
        let screen = await read(windows, tmux, FakeTable(mac.tree))

        #expect(screen.reach(of: [windows[0]]).app == ghostty)
        #expect(screen.reach(of: [windows[1]]) == .offScreen)
        #expect(screen.reach(of: [windows[2]]) == .unknown([.tmux]))
        #expect(screen.unanswered(for: windows) == [.tmux])

        _ = await read([inZmx(Self.portals)], tmux, FakeTable(mac.tree))

        #expect(tmux.runs.count == 2, "a window in zmx never asks tmux")
    }

    /// A process whose program is zmx, by its path, whose command line does not read may be an away session's server
    /// or a client: whether it runs is unknown, never gone. Only such a process: one of another program's says nothing
    /// of zmx's sessions.
    @Test func aZmxProcessWhoseCommandLineDoesNotReadLeavesOnlyAnAwayWindowsSessionUnknown() async {
        var mac = Mac()

        mac.zmxUnread()

        let screen = await read([inZmx(Self.leeway)], FakeTmux(), FakeTable(mac.tree))
        let shell = Processes([5: Proc(parent: 1, program: "/bin/zsh")], unreadable: [5])

        #expect(screen.leftOf(inZmx(Self.leeway)) == .unknown([.commandLine(.zmx)]))
        #expect(screen.reach(of: [inZmx(Self.leeway)]) == .offScreen)
        #expect(ZmxReading().isAlive(inZmx(Self.leeway), shell) == false)
    }

    @Test func aSessionInZmxIsUnknownNeverOffWhenTheTableGivesNoAnswerAsOnlyTheTableTellsItsClients() async {
        let screen = await read([inZmx(Self.portals)], FakeTmux(), FakeTable(nil))

        #expect(screen.reach(of: [inZmx(Self.portals)]) == .unknown([.processes]))
    }

    /// Where a window recording tmux's pane and zmx's `kit` on the device given shows: a Ghostty window holds a tmux
    /// client on the pane's window, the pane on the device given, and another a Portal client of `kit`.
    private static func nestedPlaces(device: String, paneDevice: String) async -> [[String?]] {
        var mac = Mac()
        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45")

        mac.throughPortal("kit", relay: "/dev/ttys032", window: "/dev/ttys060")

        let pane = FakePane(pane: "%148", window: "@45", session: "$45", device: paneDevice)
        let window = Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: "%148"), zmx: Where.Zmx(session: "kit"))
        let screen = await read([window], FakeTmux([socket: FakeServer(panes: [pane], clients: [client])]), FakeTable(mac.tree))

        return seen(screen.places(showing: [window]))
    }

    @Test func aWindowInTmuxAndZmxIsInTheInnermostTmuxWhereItsPaneIsOnTheWindowsDeviceElseZmxBothTmuxFirstWhereTmuxCannotTell() async {
        #expect(await Self.nestedPlaces(device: "/dev/ttys043", paneDevice: "/dev/ttys043") == [["/dev/ttys000", "Ghostty", nil]], "tmux inside zmx")
        #expect(await Self.nestedPlaces(device: "/dev/ttys087", paneDevice: "/dev/ttys043") == [["/dev/ttys060", "Ghostty", nil]], "zmx inside tmux")
        #expect(
            await Self.nestedPlaces(device: "/dev/ttys087", paneDevice: "")
                == [["/dev/ttys000", "Ghostty", nil], ["/dev/ttys060", "Ghostty", nil]],
            "the pane saying no device"
        )
    }
}
