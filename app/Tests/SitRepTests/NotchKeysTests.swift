import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch's keys on the Mac (DESIGN, "Keys"): the tap made as the panel opens where macOS gives the leave, on while
/// the panel is out or one of its menus is open and off at rest; the panel taking no keys without the leave or under
/// secure input, read again as macOS turns the tap off for input it can't see; a snooze menu on its own taking its
/// digits and `z`, the row's menu keeping AppKit's keys; the keys the tap hands on acting as their clicks; and the tap
/// told `⌘Z` is the panel's while the asks panel's sending line shows. No tap is real here: the Mac is the test's own.
@MainActor
@Suite(.backstop)
struct NotchKeysTests {
    // MARK: The tap

    @Test func theTapIsMadeAsThePanelOpensAndIsOnOnlyWhileItIsOut() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)

        keys.follow(isOut: false, holding: .none)
        #expect(world.taps.isEmpty)

        keys.follow(isOut: true, holding: .none)
        let tap = try #require(world.taps.first)

        #expect(tap.isOn && keys.allowed)
        keys.follow(isOut: true, holding: .panel(hold: 1))
        #expect(tap.snapshot == .panel(hold: 1))
        // in, it decides by nothing, though the run has yet to step past the hold
        keys.follow(isOut: false, holding: .panel(hold: 1))
        #expect(!tap.isOn && tap.snapshot == KeySnapshot.none)

        keys.follow(isOut: true, holding: .none)
        #expect(world.taps.count == 1 && tap.isOn)
    }

    /// An open without the leave lets the tap go, so it is never on without it; one with the leave makes another.
    @Test func anOpenWithoutTheLeaveLetsGoOfTheTap() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)

        keys.follow(isOut: true, holding: .none)
        try #require(keys.tap != nil)
        keys.follow(isOut: false, holding: .none)

        world.isTrusted = false
        keys.follow(isOut: true, holding: .panel(hold: 1))
        #expect(keys.tap == nil && !keys.allowed)

        world.isTrusted = true
        keys.follow(isOut: false, holding: .none)
        keys.follow(isOut: true, holding: .none)
        #expect(world.taps.count == 2 && keys.tap === world.taps.last && keys.allowed)
    }

    /// The screens sleeping, the screen locking with the display awake, as at ⌃⌘Q, or the session going to another
    /// user, tells the notch to let go of the keys.
    @Test func theScreensSleepingTheScreenLockingOrTheSessionGoingLetsGoOfTheKeys() {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        var away = 0

        keys.onAway = { away += 1 }
        world.workspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        world.workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        world.distributed.post(name: NotchKeys.screenIsLocked, object: nil)
        #expect(away == 3)
    }

    /// Secure input turning on, as the lock screen's password field or a sudo prompt takes it, lets go of the keys,
    /// read as the pointer moves or as macOS turns the tap off for it; on already, or on as the panel opens, where no
    /// hold has begun, it lets go of nothing more.
    @Test func secureInputTurningOnLetsGoOfTheKeys() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        var away = 0

        keys.onAway = { away += 1 }
        world.isSecure = true
        keys.follow(isOut: true, holding: .none)
        keys.pointerMoved()
        #expect(away == 0)

        world.isSecure = false
        keys.pointerMoved()
        world.isSecure = true
        keys.pointerMoved()
        #expect(away == 1)

        world.isSecure = false
        keys.pointerMoved()
        world.isSecure = true
        try #require(world.taps.first).offForInput()
        #expect(away == 2)
    }

    /// Gone, the keys leave the centres they observed: the workspace's two and the distributed centre's lock.
    @Test func goneTheKeysLeaveTheirCentres() {
        let workspace = CountingCentre(), distributed = CountingCentre()
        var mac = KeysWorld().mac

        mac.workspace = workspace
        mac.distributed = distributed

        var keys: NotchKeys? = NotchKeys(mac)

        #expect(keys != nil)
        keys = nil
        #expect(workspace.removed == 2 && distributed.removed == 1)
    }

    /// Without the leave there is no tap and the panel takes no keys; a leave given while SitRep runs works from the next
    /// open.
    @Test func withoutTheLeaveThereIsNoTapUntilAnOpenAfterItIsGiven() {
        let world = KeysWorld(), keys = NotchKeys(world.mac)

        world.isTrusted = false
        keys.follow(isOut: true, holding: .none)
        #expect(world.taps.isEmpty && !keys.allowed)

        world.isTrusted = true
        keys.follow(isOut: true, holding: .none)
        #expect(world.taps.isEmpty && !keys.allowed)
        keys.follow(isOut: false, holding: .none)
        keys.follow(isOut: true, holding: .none)
        #expect(world.taps.count == 1 && keys.allowed)
    }

    /// While a window holds secure input, as Ghostty does at a password prompt, the panel takes no keys: read as the
    /// panel opens, as the pointer moves on it, and as macOS turns the tap off for input it can't see.
    @Test func underSecureInputThePanelTakesNoKeysUntilItIsReadAgain() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)

        world.isSecure = true
        keys.follow(isOut: true, holding: .none)
        #expect(!keys.allowed)

        world.isSecure = false
        keys.pointerMoved()
        #expect(keys.allowed)

        world.isSecure = true
        try #require(world.taps.first).offForInput()
        #expect(!keys.allowed)
    }

    /// A snooze menu shown on its own takes its digits and `z`, the tap on for it though the panel is in; the row's
    /// menu keeps AppKit's keys alone; closed, the panel's hold is what the tap decides by again.
    @Test func aSnoozeMenuOnItsOwnTakesItsKeysAndTheRowsMenuKeepsAppKits() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        let menu = SnoozeMenu.forRow(offering: SnoozeSettings(), at: Date(), in: WakeTime.calendar) { _ in }

        keys.follow(isOut: true, holding: .panel(hold: 3))
        keys.follow(isOut: false, holding: .none)

        let tap = try #require(world.taps.first)

        keys.shows(menu)
        #expect(tap.isOn && tap.snapshot == .menu(choices: menu.choiceItems.count))
        keys.menuClosed()
        #expect(!tap.isOn && tap.snapshot == KeySnapshot.none)

        keys.follow(isOut: true, holding: .panel(hold: 3))
        keys.showsRowMenu()
        #expect(tap.snapshot == .menu(choices: nil))
        keys.menuClosed()
        #expect(tap.snapshot == .panel(hold: 3))
    }

    @Test func aDigitTheTapHandsOnChoosesTheSnoozeMenusChoice() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        var untils: [Date?] = []
        let now = Date()
        let menu = SnoozeMenu.forRow(offering: SnoozeSettings(), at: now, in: WakeTime.calendar) { untils.append($0) }

        _ = NSApplication.shared
        keys.follow(isOut: true, holding: .none)
        keys.shows(menu)
        try #require(world.taps.first).heard(.choose(menu.choiceItems.count))
        #expect(untils == [nil])

        keys.menuClosed()
        try #require(world.taps.first).heard(.choose(1))
        #expect(untils == [nil])
    }

    /// Keys handed on faster than the main thread woke make one choice at most: a second digit, or a digit after `z`,
    /// does nothing.
    @Test(arguments: [[KeyAction.choose(1), .choose(2)], [.closeMenu, .choose(1)]])
    func aSnoozeMenuTakesOneChoiceOrCloseAlone(_ actions: [KeyAction]) throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        var untils: [Date?] = []
        let menu = SnoozeMenu.forRow(offering: SnoozeSettings(), at: Date(), in: WakeTime.calendar) { untils.append($0) }

        _ = NSApplication.shared
        keys.follow(isOut: true, holding: .none)
        keys.shows(menu)
        for action in actions {
            try #require(world.taps.first).heard(action)
        }
        #expect(untils.count == (actions.first == .closeMenu ? 0 : 1))
    }

    @Test func thePanelsKeysAndALetGoGoToTheNotch() throws {
        let world = KeysWorld(), keys = NotchKeys(world.mac)
        var heard: [String] = []

        keys.onKey = { heard.append("\($0)") }
        keys.onLetGo = { heard.append("let go of \($0)") }
        keys.follow(isOut: true, holding: .panel(hold: 1))

        let tap = try #require(world.taps.first)

        tap.heard(.panel(.open))
        tap.heard(.letGo(hold: 1))
        #expect(heard == ["open", "let go of 1"])
    }

    // MARK: The notch

    private static let display = NotchAsksWindowTests.display
    private static let frameMS = NotchAsksWindowTests.frameMS
    private static let helpDesk = "needs:sr-nw0001", asleep = "snoozed:sr-ct0002"

    /// Help desk redesign of Northwind in Needs you, asking a yes the asks panel answers, and Shift schedules of
    /// Contoso in Snoozed.
    private static func board() -> PanelBoard {
        let at = Int(Date().timeIntervalSince1970 * 1000)
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [.init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Ship it?", since: at - 240_000)]
            ),
        ]
        let snoozed = [
            WatchLine.SnoozedRow(
                session: "sr-ct0002", name: "Shift schedules", projectName: "Contoso",
                lines: [.init("ask:sr-ct0002:k1", ask: "k1", first: "Map the rota?", wakesAt: at + 3_600_000)]
            ),
        ]
        let projects = [
            WatchLine.Project(name: "Northwind", sessions: [
                WatchLine.Session(id: "sr-nw0001", name: "Help desk redesign", state: .needsYou, asks: [
                    WatchLine.Ask(id: "k1", wants: .yes, yes: "Ship", title: "Ship it?"),
                ]),
            ]),
        ]
        var last = LastBoard()

        _ = last.hear(
            .line(WatchLine(at: at, rows: rows, snoozed: snoozed, projects: projects).text),
            at: Date(timeIntervalSince1970: Double(at) / 1000)
        )
        return PanelBoard(last)
    }

    /// A notch on the far-off display over the board, Snoozed unfolded, its panel opened by the pointer held on the
    /// notch, frame by frame, until it is at rest.
    private static func opened(_ world: KeysWorld) throws -> (NotchController, ScreenEdge, () -> Double) {
        let folding = Folding(), edge = ScreenEdge(display, EdgeSettings())

        folding.set(.snoozed, folded: false)

        let notch = NotchController(EdgeSettings(), on: display, folding: folding, keys: world.mac) { SnoozeSettings() }
        var time = Displays.now

        notch.isShown = true
        notch.show(board())
        while time < Displays.now + 3000, notch.run.phase != .open || notch.run.frame.isMoving {
            time += frameMS
            notch.step(at: time, pointer: CGPoint(x: 3, y: edge.stage.notchY))
        }
        try #require(notch.run.phase == .open)
        return (notch, edge, { time += frameMS; return time })
    }

    /// A row's words on the stage.
    private static func words(_ key: String, _ run: NotchRun) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: key))
        let row = run.list.content.laidFrame(index)

        return CGPoint(x: panel.frame.minX + row.minX + 60, y: panel.frame.minY + row.midY - run.scroll)
    }

    /// The tap is told what the panel holds as each frame draws: nothing as it opens under a resting pointer, its hold
    /// once the pointer moves on a row.
    @Test func eachFrameTellsTheTapWhatThePanelHolds() throws {
        let world = KeysWorld(), (notch, _, next) = try Self.opened(world)

        defer { notch.window.close() }

        let tap = try #require(world.taps.first)

        #expect(tap.isOn && tap.snapshot == KeySnapshot.none)
        notch.step(at: next(), pointer: try Self.words(Self.helpDesk, notch.run))
        #expect(tap.snapshot == .panel(hold: 1))
    }

    /// `o`, then `⏎` within the jump: the tap is told at once that the panel holds nothing, before a frame draws, so
    /// `⏎` goes through to the window jumped to, and the pointer moving on the draining panel starts no hold.
    @Test func returnAfterOWithinTheJumpGoesThrough() throws {
        let world = KeysWorld(), (notch, _, next) = try Self.opened(world)
        let tap = try #require(world.taps.first), enter = TapKey(code: KeyCode.enter)

        defer { notch.window.close() }

        var pointer = try Self.words(Self.helpDesk, notch.run)

        notch.step(at: next(), pointer: pointer)
        try #require(tap.snapshot == .panel(hold: 1))
        notch.heard(.open, pointer: pointer)
        #expect(tap.snapshot == KeySnapshot.none)
        #expect(tap.read(enter) == .pass)

        notch.step(at: next(), pointer: pointer)
        #expect(notch.run.frame.panel?.pressed == Self.helpDesk)
        for _ in 0 ..< 120 where notch.run.frame.panel?.pressed != nil {
            pointer.y += 1
            notch.step(at: next(), pointer: pointer)
            #expect(tap.snapshot == KeySnapshot.none)
        }
    }

    /// The screens sleeping lets go of the keys, so what is typed on coming back goes to the window in front.
    @Test func theScreensSleepingLetsGoOfThePanelsKeys() throws {
        let world = KeysWorld(), (notch, _, next) = try Self.opened(world)
        let tap = try #require(world.taps.first)

        defer { notch.window.close() }
        notch.step(at: next(), pointer: try Self.words(Self.helpDesk, notch.run))
        try #require(tap.snapshot == .panel(hold: 1))
        world.workspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        #expect(!notch.run.holdsKeys && tap.snapshot == KeySnapshot.none)
    }

    @Test func underSecureInputTheNotchsPanelHoldsNothing() throws {
        let world = KeysWorld()

        world.isSecure = true

        let (notch, _, next) = try Self.opened(world)

        defer { notch.window.close() }
        notch.step(at: next(), pointer: try Self.words(Self.helpDesk, notch.run))
        #expect(!notch.run.holdsKeys)
    }

    /// `o` jumps to the lit row's window as its click does; `z` on a row in Snoozed wakes its session; `esc` closes the
    /// panel, and the tap goes off once it is in.
    @Test func theKeysActAsTheirClicks() throws {
        let world = KeysWorld(), (notch, _, next) = try Self.opened(world)
        var jumped: [String] = [], woken: [String] = []

        defer { notch.window.close() }
        notch.onJump = { target, _ in jumped.append(target) }
        notch.onWake = { woken.append($0) }

        let asleep = try Self.words(Self.asleep, notch.run)

        notch.step(at: next(), pointer: asleep)
        notch.heard(.snooze, pointer: asleep)
        #expect(woken == ["sr-ct0002"])

        let helpDesk = try Self.words(Self.helpDesk, notch.run)

        notch.step(at: next(), pointer: helpDesk)
        notch.heard(.open, pointer: helpDesk)
        #expect(jumped == ["sr-nw0001"])

        let closing = try Self.opened(world)

        defer { closing.0.window.close() }
        let point = try Self.words(Self.helpDesk, closing.0.run)

        closing.0.step(at: closing.2(), pointer: point)
        closing.0.heard(.escape, pointer: point)
        for _ in 0 ..< 120 where closing.0.run.phase != .closed {
            closing.0.step(at: closing.2(), pointer: point)
        }
        #expect(closing.0.run.phase == .closed)
        #expect(world.taps.last?.isOn == false)
    }

    /// On the asks panel `1` answers with its row and `⌘Z` takes the answer back, as their clicks do; the tap is told
    /// `⌘Z` is the panel's while the sending line shows, and not once it goes.
    @Test func onTheAsksPanelADigitAnswersAndCommandZUndoes() throws {
        let world = KeysWorld(), (notch, _, next) = try Self.opened(world)
        let tap = try #require(world.taps.first), undo = TapKey(code: 6, typed: "z", flags: .maskCommand)
        let ship = Answering(.words("Ship"), to: "k1", of: "sr-nw0001", wanting: .yes)
        var answered: [Answering] = [], undone = 0

        defer { notch.window.close() }
        notch.onAnswer = { answered.append($0) }
        notch.onUndo = { undone += 1 }

        let pointer = try Self.words(Self.helpDesk, notch.run)

        notch.step(at: next(), pointer: pointer)
        notch.heard(.enter, pointer: pointer)
        notch.heard(.digit(1), pointer: pointer)
        #expect(answered == [ship])

        let now = Date()

        // the news comes with the real pointer, off the far-off display: the test's comes back onto the row after it
        notch.heard(.held(HeldAnswer(answering: ship, heldAt: now, goesAt: now.addingTimeInterval(2))))
        notch.step(at: next(), pointer: pointer)
        try #require(notch.run.asksShown?.sending != nil)
        guard case .panel(_, undoes: true) = tap.snapshot else {
            Issue.record("the tap was not told the sending line undoes: \(tap.snapshot)")
            return
        }
        #expect(tap.read(undo) == .take(.panel(.undo)))
        notch.heard(.undo, pointer: pointer)
        #expect(undone == 1)

        notch.heard(.undone(ship))
        notch.step(at: next(), pointer: pointer)
        guard case let .panel(hold, undoes: false) = tap.snapshot else {
            Issue.record("the tap was still told the sending line undoes: \(tap.snapshot)")
            return
        }
        #expect(tap.read(undo) == .letGo(hold: hold))
    }

    /// A menu holding the card has the keys: as the row's right-click menu opens, the asks panel is drawn without its
    /// keycaps before the menu tracks, so no number shows beside the menu's own.
    @Test func aMenuHoldingTheCardDrawsTheAsksPanelWithoutKeycaps() throws {
        let world = KeysWorld(), (notch, edge, next) = try Self.opened(world)
        let pointer = try Self.words(Self.helpDesk, notch.run)

        defer { notch.window.close() }
        notch.step(at: next(), pointer: pointer)
        notch.heard(.enter, pointer: pointer)
        notch.step(at: next(), pointer: pointer)
        try #require(notch.surface.scene?.asks?.keycaps == true)

        let onScreen = edge.screenRect(CGRect(origin: pointer, size: .zero)).origin
        let menu = try #require(notch.surface.pointer.menu(onScreen))

        notch.menuWillOpen(menu)
        #expect(notch.surface.scene?.asks?.keycaps == false)
    }

    /// `z` on a Needs you row offers the row's Snooze times numbered, a choice snoozing its session, naming the asks the
    /// row showed, as the row's menu's Snooze does.
    @Test func theRowsSnoozeMenuSnoozesItsSessionNamingItsAsks() throws {
        let world = KeysWorld(), (notch, _, _) = try Self.opened(world)
        var snoozed: [(String, [String], Date?)] = []

        defer { notch.window.close() }
        notch.onSnooze = { snoozed.append(($0, $1, $2)) }

        let session = try #require(notch.run.list.index(of: Self.helpDesk).flatMap { notch.run.list.item($0)?.session })
        let menu = notch.snoozeMenu(for: session)

        _ = NSApplication.shared
        #expect(menu.choiceItems.first?.keyEquivalent == "1")
        menu.choose(number: menu.choiceItems.count)
        #expect(snoozed.map(\.0) == ["sr-nw0001"] && snoozed.map(\.1) == [["k1"]] && snoozed.map(\.2) == [nil])
    }
}

/// A centre counting the observers taken off it.
private final class CountingCentre: NotificationCenter, @unchecked Sendable {
    private(set) var removed = 0

    override func removeObserver(_ observer: Any) {
        removed += 1
        super.removeObserver(observer)
    }
}
