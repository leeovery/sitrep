import Darwin
@testable import SitRepScreen
import Testing

let socket = "/private/tmp/tmux-501/default"
let otherSocket = "/private/tmp/tmux-501/session"
let ghostty = TerminalApp.driven(.ghostty)
let terminal = TerminalApp.atPath(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app")

/// Claude in tmux, on its pane's own device.
func inTmux(_ pane: String = "%148", on socket: String = socket, device: String = "/dev/ttys043") -> Where {
    Where(device: device, terminal: "tmux", tmux: Where.Tmux(socket: socket, pane: pane))
}

/// Claude in a Ghostty window of its own.
let inGhosttyWindow = Where(device: "/dev/ttys041", terminal: "ghostty")

/// The screen for the windows, read through tmux and the table given.
func read(_ windows: [Where], _ tmux: FakeTmux, _ table: FakeTable) async -> Screen {
    await ScreenReader(tmux: tmux, table: table).read(windows)
}

/// Each place as its device, its app's name, and the tmux session a select makes the pane's window current in.
func seen(_ places: [Place]) -> [[String?]] {
    places.map { [$0.device, $0.app.name, $0.select?.session] }
}

struct TmuxScreenTests {
    /// Claude's pane, the tmux window holding it, and its tmux session.
    private static let panes = [
        FakePane(pane: "%148", window: "@45", session: "$45"),
        FakePane(pane: "%149", window: "@46", session: "$45"),
        FakePane(pane: "%54", window: "@52", session: "$52"),
    ]

    /// Claude's window shown by Ghostty windows, the phone and a Ghostty over ssh; another of its tmux session by a
    /// Ghostty window; and a window of another session by a Ghostty window.
    private static func shown() async -> (Screen, FakeTmux, FakeTable) {
        var mac = Mac()
        let clients = [
            FakeClient(device: "/dev/ttys067", pid: mac.onPhone("/dev/ttys067"), window: "@45"),
            FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45"),
            FakeClient(device: "/dev/ttys041", pid: mac.inGhostty("/dev/ttys041"), window: "@52"),
            FakeClient(device: "/dev/ttys080", pid: mac.overSsh("/dev/ttys080"), window: "@45"),
            FakeClient(device: "/dev/ttys056", pid: mac.inGhostty("/dev/ttys056"), window: "@46", session: "$45"),
            FakeClient(device: "/dev/ttys055", pid: mac.inGhostty("/dev/ttys055"), window: "@45"),
        ]
        let tmux = FakeTmux([socket: FakeServer(panes: panes, clients: clients)])
        let table = FakeTable(mac.tree)

        return (await read([inTmux(), inGhosttyWindow], tmux, table), tmux, table)
    }

    @Test func aWindowInTmuxShowsOnTheClientsInATerminalAppOnItsPanesWindowInTmuxsOrderAndNoneIsSelectedForIt() async {
        let (screen, _, _) = await Self.shown()

        #expect(seen(screen.places(showing: [inTmux()])) == [["/dev/ttys000", "Ghostty", nil], ["/dev/ttys055", "Ghostty", nil]])
    }

    @Test func aPanesWindowNoClientShowsIsShownByASelectInEachSessionHoldingItAClientInATerminalAppIsAttachedTo() async {
        var mac = Mac()
        let panes = ["$7", "$8"].flatMap { session in
            [FakePane(pane: "%148", window: "@45", session: session), FakePane(pane: "%149", window: "@46", session: session)]
        } + [FakePane(pane: "%54", window: "@52", session: "$9")]
        let clients = [
            FakeClient(device: "/dev/ttys067", pid: mac.onPhone("/dev/ttys067"), window: "@46", session: "$7"),
            FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@46", session: "$8"),
            FakeClient(device: "/dev/ttys041", pid: mac.inGhostty("/dev/ttys041"), window: "@52", session: "$9"),
            FakeClient(device: "/dev/ttys030", pid: mac.inTerminal("/dev/ttys030"), window: "@46", session: "$7"),
        ]
        let screen = await read([inTmux()], FakeTmux([socket: FakeServer(panes: panes, clients: clients)]), FakeTable(mac.tree))

        #expect(
            screen.places(showing: [inTmux()]) == [
                Place(app: ghostty, device: "/dev/ttys000", select: Select(socket: socket, session: "$8", window: "@45")),
                Place(app: terminal, device: "/dev/ttys030", select: Select(socket: socket, session: "$7", window: "@45")),
            ]
        )
    }

    @Test func thePhoneShowingThePaneDoesNotStopASelectForAGhosttyWindow() async {
        var mac = Mac()
        let clients = [
            FakeClient(device: "/dev/ttys067", pid: mac.onPhone("/dev/ttys067"), window: "@45", session: "$7"),
            FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@46", session: "$7"),
        ]
        let panes = [FakePane(pane: "%148", window: "@45", session: "$7"), FakePane(pane: "%149", window: "@46", session: "$7")]
        let screen = await read([inTmux()], FakeTmux([socket: FakeServer(panes: panes, clients: clients)]), FakeTable(mac.tree))

        #expect(seen(screen.places(showing: [inTmux()])) == [["/dev/ttys000", "Ghostty", "$7"]])
    }

    @Test func aClientOnNoTtyOfItsOwnIsNoPlaceAndStopsNoSelectAloneOnThePanesWindowItIsOffScreen() async {
        var mac = Mac()
        let control = FakeClient(device: "", pid: mac.inGhostty("/dev/ttys040", own: ""), window: "@45")
        let window = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@46", session: "$45")
        let panes = [FakePane(pane: "%148", window: "@45", session: "$45")]
        let alone = await read([inTmux()], FakeTmux([socket: FakeServer(panes: panes, clients: [control])]), FakeTable(mac.tree))
        let beside = await read(
            [inTmux()], FakeTmux([socket: FakeServer(panes: panes, clients: [control, window])]), FakeTable(mac.tree)
        )

        #expect(alone.reach(of: [inTmux()]) == .offScreen)
        #expect(seen(beside.places(showing: [inTmux()])) == [["/dev/ttys000", "Ghostty", "$45"]])
    }

    @Test func aClientWhoseProcessTheTableLacksShowsNothing() async {
        let clients = [FakeClient(device: "/dev/ttys000", pid: 9999, window: "@45")]
        let screen = await read(
            [inTmux()], FakeTmux([socket: FakeServer(panes: Self.panes, clients: clients)]), FakeTable(Mac().tree)
        )

        #expect(screen.reach(of: [inTmux()]) == .offScreen)
    }

    @Test func aWindowInTmuxShowsNowhereWhenItsPaneOrItsServerIsGoneOrItsSocketWasNotAsked() async {
        let (screen, _, _) = await Self.shown()
        let gone = await read([inTmux(on: otherSocket)], FakeTmux(), FakeTable(Mac().tree))

        #expect(screen.reach(of: [inTmux("%9")]) == .offScreen)
        #expect(gone.reach(of: [inTmux(on: otherSocket)]) == .offScreen)
        #expect(screen.reach(of: [inTmux(on: "/tmp/never-asked")]) == .offScreen)
    }

    @Test func aWindowOutsideAMultiplexerShowsOnItsOwnDeviceInGhosttyOrAnAppItsTermProgramNamesWhichNeedsNoDevice() async {
        let (screen, _, _) = await Self.shown()
        let places = { (windows: [Where]) in seen(screen.places(showing: windows)) }

        #expect(places([inGhosttyWindow]) == [["/dev/ttys041", "Ghostty", nil]])
        #expect(places([Where(device: "/dev/ttys041", terminal: "iTerm.app")]) == [["/dev/ttys041", "iTerm2", nil]])
        #expect(places([Where(device: "/dev/ttys041", terminal: "Unknown")]) == [])
        #expect(places([Where(terminal: "ghostty")]) == [], "Ghostty without a device")
        #expect(places([Where(terminal: "iTerm.app")]) == [[nil, "iTerm2", nil]])
        #expect(places([Where(terminal: "iTerm.app"), Where(terminal: "Apple_Terminal")]) == [[nil, "iTerm2", nil], [nil, "Terminal", nil]])
        #expect(places([Where(terminal: "iTerm.app"), Where(terminal: "iTerm.app")]) == [[nil, "iTerm2", nil]], "one app, once")
    }

    @Test func aDeviceThatIsNoTtyIsNoneAsCoreDropsIt() async {
        let (screen, _, _) = await Self.shown()
        let places = { (windows: [Where]) in seen(screen.places(showing: windows)) }

        #expect(places([Where(device: "/dev/null", terminal: "ghostty")]) == [])
        #expect(places([Where(device: "/dev/null", terminal: "iTerm.app")]) == [[nil, "iTerm2", nil]])
        #expect(
            await Self.paneOnItsPty(device: "/dev/null") == nil,
            "a window on no tty cannot be told on its pane's pty or off it"
        )
        #expect(await Self.paneOnItsPty(device: "/dev/ttys043") == true)
    }

    /// Whether tmux's reading says a window on the device is on its pane's pty, the pane on `/dev/ttys043`.
    private static func paneOnItsPty(device: String) async -> Bool? {
        let pane = FakePane(pane: "%148", window: "@45", session: "$45", device: "/dev/ttys043")
        let window = inTmux(device: device)

        return await TmuxAdapter(FakeTmux([socket: FakeServer(panes: [pane])])).read([window]).isOnItsPty(window)
    }

    @Test func severalWindowsShowOnEachOnesDevicesTheFirstWindowsFirstEachDeviceOnce() async {
        let (screen, _, _) = await Self.shown()
        var mac = Mac()
        let twoPanes = [FakePane(pane: "%148", window: "@45", session: "$45"), FakePane(pane: "%149", window: "@45", session: "$45")]
        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45")
        let windows = [inTmux(), inTmux("%149"), inGhosttyWindow, inTmux()]
        let oneWindow = await read(windows, FakeTmux([socket: FakeServer(panes: twoPanes, clients: [client])]), FakeTable(mac.tree))

        #expect(screen.places(showing: [inGhosttyWindow, inTmux()]).map(\.device) == ["/dev/ttys041", "/dev/ttys000", "/dev/ttys055"])
        #expect(oneWindow.places(showing: windows).map(\.device) == ["/dev/ttys000", "/dev/ttys041"])
    }

    @Test func aJumpReachesWindowsAPlaceShowsWithThePlacesAndNoneWhereNothingShowsThemAndEverythingAskedAnswered() async {
        let (screen, _, _) = await Self.shown()

        #expect(screen.reach(of: [inTmux()]) == .onScreen(screen.places(showing: [inTmux()])))
        #expect(screen.reach(of: [inTmux()]).app == ghostty)
        #expect(screen.reach(of: [inGhosttyWindow]).app == ghostty)
        #expect(screen.reach(of: [inTmux("%9")]) == .offScreen)
        #expect(screen.reach(of: [inTmux("%9")]).app == nil)
        #expect(screen.reach(of: []) == .offScreen)
    }

    @Test func theAppShowingWindowsIsTheFirstPlacesTheFirstClientAsTmuxListsThem() async {
        var mac = Mac()
        let inTerminal = FakeClient(device: "/dev/ttys030", pid: mac.inTerminal("/dev/ttys030"), window: "@45")
        let inGhostty = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45")
        let appOf = { (clients: [FakeClient]) in
            await read([inTmux()], FakeTmux([socket: FakeServer(panes: Self.panes, clients: clients)]), FakeTable(mac.tree))
                .reach(of: [inTmux()]).app
        }

        #expect(await appOf([inTerminal, inGhostty]) == terminal)
        #expect(await appOf([inGhostty, inTerminal]) == ghostty)
    }

    @Test func tmuxGivingNoAnswerForASocketAWindowRunsUnderMakesItUnknownNeverOffScreenForAnotherSocketOnlyOffScreen() async {
        let table = FakeTable(Mac().tree)
        let silent = await read([inTmux(), inTmux(on: otherSocket)], FakeTmux(silentOn: [socket]), table)
        let (shown, _, _) = await Self.shown()
        var mac = Mac()
        let client = FakeClient(device: "/dev/ttys000", pid: mac.inGhostty("/dev/ttys000"), window: "@45")
        let found = await read(
            [inTmux(), inTmux(on: otherSocket)],
            FakeTmux([socket: FakeServer(panes: Self.panes, clients: [client])], silentOn: [otherSocket]),
            FakeTable(mac.tree)
        )

        #expect(silent.reach(of: [inTmux()]) == .unknown([.tmux]))
        #expect(silent.reach(of: [inTmux(on: otherSocket)]) == .offScreen)
        #expect(silent.unanswered(for: [inTmux(), inTmux(on: otherSocket)]) == [.tmux])
        #expect(found.reach(of: [inTmux(), inTmux(on: otherSocket)]).app == ghostty, "a place found stands, whatever else gave no answer")
        #expect(shown.unanswered(for: [inTmux()]) == [])
    }

    @Test func theTableGivingNoAnswerMakesAWindowUnknownWhereItsServerHasClientsWhoseAppsItTellsOffScreenWhereItHasNone() async {
        let clients = [FakeClient(device: "/dev/ttys000", pid: 100, window: "@45")]
        let withClients = await read([inTmux()], FakeTmux([socket: FakeServer(panes: Self.panes, clients: clients)]), FakeTable(nil))
        let without = await read([inTmux()], FakeTmux([socket: FakeServer(panes: Self.panes)]), FakeTable(nil))

        #expect(withClients.reach(of: [inTmux()]) == .unknown([.processes]))
        #expect(without.reach(of: [inTmux()]) == .offScreen)
    }

    @Test func aWindowOutsideAMultiplexerIsNeverUnknownAndAsksNeitherTmuxNorTheTable() async {
        let tmux = FakeTmux(silent: true)
        let table = FakeTable(nil)
        let windows = [inGhosttyWindow, Where(device: "/dev/ttys041", terminal: "Unknown")]
        let screen = await read(windows, tmux, table)

        #expect(screen.reach(of: [inGhosttyWindow]).app == ghostty)
        #expect(screen.reach(of: [windows[1]]) == .offScreen)
        #expect(tmux.runs.isEmpty)
        #expect(table.looks == 0)
    }

    @Test func theScreenIsReadOnceForManySessionsTmuxAskedTwiceForEachSocketAndTheTableOnce() async {
        let tmux = FakeTmux()
        let table = FakeTable(Mac().tree)
        let gone = "/private/tmp/tmux-501/gone"

        _ = await read([inTmux("%1"), inTmux("%2"), inTmux("%9", on: otherSocket), inTmux(on: gone), inGhosttyWindow], tmux, table)

        #expect(
            tmux.runs.sorted { $0.joined() < $1.joined() } == [
                [socket, "list-clients"], [socket, "list-panes"], [otherSocket, "list-clients"], [otherSocket, "list-panes"],
                [gone, "list-clients"], [gone, "list-panes"],
            ].sorted { $0.joined() < $1.joined() }
        )
        #expect(table.looks == 1)
    }

    @Test func withNoWindowNothingIsAsked() async {
        let tmux = FakeTmux()
        let table = FakeTable(Mac().tree)
        let screen = await read([], tmux, table)

        #expect(screen.unanswered(for: []) == [])
        #expect(tmux.runs.isEmpty)
        #expect(table.looks == 0)
    }

    @Test func aTmuxClientUnderITerm2sServerOutsideItsBundleIsITerm2s() async {
        var mac = Mac()
        let server = mac.tree.app("/Users/me/Library/Application Support/iTerm2/iTermServer-3.5.4")
        let pid = mac.tree.tmux(under: mac.tree.add(under: server, "/bin/zsh", on: "/dev/ttys070"), on: "/dev/ttys070")
        let clients = [FakeClient(device: "/dev/ttys070", pid: pid, window: "@45")]
        let screen = await read([inTmux()], FakeTmux([socket: FakeServer(panes: Self.panes, clients: clients)]), FakeTable(mac.tree))

        #expect(screen.reach(of: [inTmux()]).app == .bundled(name: "iTerm2", bundles: ["com.googlecode.iterm2"]))
    }
}
