import Darwin
import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport

let finder = "com.apple.finder"
let ghosttyBundle = GhosttyDriver.bundle

/// A terminal of the fake Ghostty: its id, and the device it is on.
struct FakeTerminal: Sendable {
    let id: String
    let device: String
}

/// A window of the fake Ghostty: its tabs, each of its terminals, a split's among them, and which tab is selected.
struct FakeWindow: Sendable {
    let id: String
    let tabs: [[FakeTerminal]]
    var selected = 0
}

/// Ghostty windows each of one tab of one terminal.
func ownWindows(_ terminals: FakeTerminal...) -> [FakeWindow] {
    terminals.map { FakeWindow(id: "\($0.id)-WINDOW", tabs: [[$0]]) }
}

/// The board a jump reads, as `read` gives it, and why there is none, as a watch that has printed none says it.
struct GivenBoard: JumpBoardSource {
    static let missing = "SitRep has no board yet: sitrep watch has printed none."

    let read: @Sendable () async -> JumpBoard.Read

    init(_ read: @escaping @Sendable () async -> JumpBoard.Read) {
        self.read = read
    }

    /// The board, at once.
    init(_ board: Board) {
        read = { .board(board) }
    }

    func current() async -> JumpBoard.Read {
        await read()
    }

    func missing() async -> String {
        Self.missing
    }
}

/// A gate a double waits at until the test opens it, as a program, or an event in flight, still answering: it never
/// heeds a task cancelled.
final class Gate: Sendable {
    private let state = OSAllocatedUnfairLock(
        initialState: (isOpen: false, arrived: 0, passed: 0, waiting: [CheckedContinuation<Void, Never>]())
    )

    /// How many have come to it.
    var arrived: Int { state.withLock(\.arrived) }
    /// How many have gone on through it, each counted as its caller takes up again.
    var passed: Int { state.withLock(\.passed) }

    func pass() async {
        await withCheckedContinuation { continuation in
            let isOpen = state.withLock { state in
                state.arrived += 1
                if !state.isOpen {
                    state.waiting.append(continuation)
                }
                return state.isOpen
            }

            if isOpen {
                continuation.resume()
            }
        }
        state.withLock { $0.passed += 1 }
    }

    func open() {
        state.withLock { state in
            defer { state.waiting = [] }
            state.isOpen = true
            return state.waiting
        }.forEach { $0.resume() }
    }
}

/// A Ghostty of windows, tabs and terminals, playing what the real one does with what it is told: the terminal on a
/// device found, its tab's selection told, its window activated, it focused; a new window opened, its terminal
/// `NEW-TERMINAL`. It keeps every device it was asked about and everything it was told, and, told something, tells
/// `onTold`, as an app comes to the front when it is. Not running, it finds nothing and opens nothing; failing, its
/// every question fails so; held, its first question waits at the gate. Opening a window, as the real one does, it
/// sends nothing once stopped, and says as `new window` goes; then that event may fail on its own, wait in flight at a
/// gate of its own, or name no window; and its focus may fail on its own.
final class FakeGhostty: GhosttyScripting {
    static let opened = "NEW-TERMINAL"

    private let windows: [FakeWindow]
    private let isRunning: Bool
    private let failure: GhosttyFailure?
    private let gate: Gate?
    private let namesNewWindow: Bool
    private let windowFailure: GhosttyFailure?
    private let windowGate: Gate?
    private let focusFailure: GhosttyFailure?
    private let onTold: @Sendable (String) -> Void
    private let state = OSAllocatedUnfairLock(initialState: (asked: [String](), told: [String]()))

    init(
        _ windows: [FakeWindow] = [], running: Bool = true, failing failure: GhosttyFailure? = nil, held gate: Gate? = nil,
        namesNewWindow: Bool = true, windowFailing windowFailure: GhosttyFailure? = nil, windowHeld windowGate: Gate? = nil,
        focusFailing focusFailure: GhosttyFailure? = nil, onTold: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.windows = windows
        isRunning = running
        self.failure = failure
        self.gate = gate
        self.namesNewWindow = namesNewWindow
        self.windowFailure = windowFailure
        self.windowGate = windowGate
        self.focusFailure = focusFailure
        self.onTold = onTold
    }

    /// Each device it was asked for a terminal on.
    var asked: [String] { state.withLock(\.asked) }
    /// What it was told: `activate window <id>`, `focus <id>`, `open <command>`.
    var told: [String] { state.withLock(\.told) }
    /// The terminals it focused.
    var focused: [String] { told.filter { $0.hasPrefix("focus ") }.map { String($0.dropFirst("focus ".count)) } }
    /// The commands each window it opened runs.
    var opened: [String] { told.filter { $0.hasPrefix("open ") }.map { String($0.dropFirst("open ".count)) } }

    func terminal(on device: String) async throws -> GhosttyObject? {
        let isFirst = state.withLock { state in
            state.asked.append(device)
            return state.asked.count == 1
        }

        if isFirst, let gate {
            await gate.pass()
        }
        guard isRunning else {
            return nil
        }
        if let failure {
            throw failure
        }

        return holding(device).map { GhosttyObject(descriptor: NSAppleEventDescriptor(string: $0.terminal.id)) }
    }

    func isTabSelected(holding device: String) async throws -> Bool {
        guard let held = holding(device) else {
            return true
        }

        return held.window.selected == held.tab
    }

    func activateWindow(holding device: String) async throws {
        if let held = holding(device) {
            tell("activate window \(held.window.id)")
        }
    }

    func focus(_ terminal: GhosttyObject) async throws {
        if let focusFailure {
            throw focusFailure
        }

        tell("focus \(terminal.descriptor.stringValue ?? "")")
    }

    func openWindow(running command: String, sending: @escaping @Sendable () -> Void) async throws -> NewWindow {
        guard isRunning else {
            return .notRunning
        }
        try Task.checkCancellation()
        if let failure {
            throw failure
        }
        try Task.checkCancellation()

        sending()
        tell("open \(command)")
        await windowGate?.pass()
        if let windowFailure {
            throw windowFailure
        }

        return .opened(namesNewWindow ? GhosttyObject(descriptor: NSAppleEventDescriptor(string: Self.opened)) : nil)
    }

    private func tell(_ line: String) {
        state.withLock { $0.told.append(line) }
        onTold(line)
    }

    /// The first terminal on the device, with its window and the place of its tab there.
    private func holding(_ device: String) -> (terminal: FakeTerminal, window: FakeWindow, tab: Int)? {
        for window in windows {
            for (tab, terminals) in window.tabs.enumerated() {
                if let terminal = terminals.first(where: { $0.device == device }) {
                    return (terminal, window, tab)
                }
            }
        }

        return nil
    }
}

/// The Mac's apps, played: the app in front as a jump begins, the apps running, by bundle id or path, and whether one
/// brought forward comes, nil for LaunchServices never answering. Told by Ghostty of a focus or an activation, it
/// brings to the front, one after another, the apps given for it, as macOS hands the front about. It keeps every
/// question and everything brought forward.
final class FakeWorkspace: Workspace {
    private struct State {
        var listeners: [Int: @Sendable (String?) -> Void] = [:]
        var listened = 0
        var fronts = 0
        var running: [[String]] = []
        var paths: [String] = []
        var brought: [String] = []
    }

    private let front: String?
    private let bundles: Set<String>
    private let atPaths: Set<String>
    private let isForward: Bool?
    private let focused: [String?]
    private let activated: [String?]
    private let frontGate: Gate?
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(
        front: String? = ghosttyBundle, running bundles: Set<String> = [ghosttyBundle], at paths: Set<String> = [],
        forward: Bool? = true, focused: [String?] = [], activated: [String?] = [], frontHeld: Gate? = nil
    ) {
        self.front = front
        self.bundles = bundles
        atPaths = paths
        isForward = forward
        self.focused = focused
        self.activated = activated
        frontGate = frontHeld
    }

    /// How many times the app in front was asked for.
    var fronts: Int { state.withLock(\.fronts) }
    /// Each asking for an app running by its bundle ids.
    var runningAsked: [[String]] { state.withLock(\.running) }
    /// Each asking for an app running from a path.
    var pathsAsked: [String] { state.withLock(\.paths) }
    /// Each app brought forward, by `bundled` or `atPath`.
    var brought: [String] { state.withLock(\.brought) }
    /// How many listenings began, and how many are under way.
    var listened: Int { state.withLock(\.listened) }
    var listening: Int { state.withLock(\.listeners.count) }

    func frontmost() async -> String? {
        state.withLock { $0.fronts += 1 }
        await frontGate?.pass()
        return front
    }

    func listen(_ heard: @escaping @Sendable (String?) -> Void) -> any Listening {
        let id = state.withLock { state in
            state.listened += 1
            state.listeners[state.listened] = heard
            return state.listened
        }

        return FakeListening { [state] in state.withLock { _ = $0.listeners.removeValue(forKey: id) } }
    }

    func running(_ bundles: [String]) async -> RunningApp? {
        state.withLock { $0.running.append(bundles) }
        return bundles.first(where: self.bundles.contains).map { RunningApp(url: bundled($0)) }
    }

    func running(at path: String) async -> RunningApp? {
        state.withLock { $0.paths.append(path) }
        return atPaths.contains(path) ? RunningApp(url: atPath(path)) : nil
    }

    func bringForward(_ app: RunningApp) async -> Bool {
        state.withLock { $0.brought.append(app.url.absoluteString) }
        guard let isForward else {
            try? await Task.sleep(for: .seconds(3600))
            return false
        }

        return isForward
    }

    /// What Ghostty was told, which brings apps to the front as given.
    func told(_ line: String) {
        let apps = line.hasPrefix("focus ") ? focused : line.hasPrefix("activate window ") ? activated : []
        let listeners = state.withLock { Array($0.listeners.values) }

        for app in apps {
            listeners.forEach { $0(app) }
        }
    }
}

/// An app known by its bundle id, as the fake workspace names it.
func bundled(_ bundle: String) -> URL {
    URL(string: "bundle:\(bundle)") ?? URL(filePath: bundle)
}

/// An app known by its path, as the fake workspace names it.
func atPath(_ path: String) -> URL {
    URL(filePath: path, directoryHint: .notDirectory)
}

private struct FakeListening: Listening {
    let ended: @Sendable () -> Void

    func end() {
        ended()
    }
}

/// The test's clock stands in for the jump's.
extension TestClock: JumpClock {}

extension Set<Duration> {
    /// The jump's own pauses, Ghostty's and the watch of the front, which a test's clock lets pass at once.
    static var jumpsPauses: Self { [GhosttyDriver.pause, KeptInFront.watch] }
}

/// tmux that waits at the gate before each run, then answers as the tmux given.
final class HeldTmux: TmuxProgram {
    let tmux: FakeTmux
    let gate: Gate

    init(_ tmux: FakeTmux, at gate: Gate) {
        self.tmux = tmux
        self.gate = gate
    }

    func run(on socket: String, _ words: [String]) async throws -> Ran {
        await gate.pass()
        return try await tmux.run(on: socket, words)
    }
}
