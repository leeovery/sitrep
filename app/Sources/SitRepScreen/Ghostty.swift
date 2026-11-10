import Foundation
import os
import SitRepCore

/// A terminal app's driver: brings forward its window on a device, for a jump, and opens a new window running a
/// command, for a session no window shows. One per terminal app with a driver (`Driver`); an app with none is brought
/// forward whole.
public protocol TerminalDriver: Sendable {
    /// Brings forward the window on the device, given the app in front as the jump began, by its bundle id: whether
    /// it came, false where nothing on the device answered, for the next place to be tried. Throws, in plain words (its
    /// description), where its app cannot be asked; and `CancellationError`, between its steps, once the jump is
    /// stopped.
    func bringForward(on device: String, front: String?) async throws -> Bool
    /// Whether it can open a window now: its app running, as opening one would launch it.
    func canOpen() async -> Bool
    /// Opens a new window on the Space showing, Lee's own login shell in it with the command typed in, and brings it
    /// forward, given the app in front as the opening began: whether it opened, false where the app is not running.
    /// `sending` is called as the window is about to be asked for: from then, one may open whatever comes of the
    /// asking, and before it, none can. Once the app has answered that it opened one, it has, whatever follows; before
    /// then, it throws as `bringForward` does.
    func openWindow(running command: String, front: String?, sending: @escaping @Sendable () -> Void) async throws
        -> Bool
}

/// Ghostty, asked about its terminals by device, and told to bring one forward. The real one sends Apple Events
/// (`GhosttyEvents`); the tests' plays a Ghostty of windows, tabs and terminals.
public protocol GhosttyScripting: Sendable {
    /// The first terminal on the device; nil for none, or Ghostty not running, as telling it anything would launch it.
    func terminal(on device: String) async throws -> GhosttyObject?
    /// Whether the tab holding the terminal on the device is its window's selected tab: true for a terminal in no
    /// window, which is focused as one selected.
    func isTabSelected(holding device: String) async throws -> Bool
    /// Activates the window holding the terminal on the device.
    func activateWindow(holding device: String) async throws
    /// Focuses the terminal, bringing its window to the front.
    func focus(_ terminal: GhosttyObject) async throws
    /// Opens a new window whose shell has the command typed into it, with a return, once the shell starts; nothing for
    /// Ghostty not running, as `new window` would launch it, which opens a first window of its own as it starts.
    /// `sending` is called as `new window` is about to go to Ghostty: where it was not, no window was asked for.
    func openWindow(running command: String, sending: @escaping @Sendable () -> Void) async throws -> NewWindow
}

/// What asking Ghostty for a new window came to: Ghostty not running, so nothing asked; or a window opened, with its
/// terminal where Ghostty's answer named the window.
public enum NewWindow: Sendable {
    case notRunning
    case opened(GhosttyObject?)
}

/// A Ghostty object as Ghostty named it in an answer, to be named back to it. Never changed once made, so safe to hand
/// between threads.
public struct GhosttyObject: @unchecked Sendable {
    let descriptor: NSAppleEventDescriptor
}

/// Why Ghostty could not be asked, in plain words.
public enum GhosttyFailure: Error, Equatable, CustomStringConvertible {
    /// A question waited its whole time, as with the screen locked, when Ghostty answers nothing about its terminals.
    case noAnswer
    /// It does not know the terms of its terminals' devices, as a Ghostty before 1.4 does not.
    case tooOld
    /// It does not know how to open a window running a command, as a Ghostty before 1.4 does not.
    case cannotOpen
    /// Told to open a window, it gave no answer in time: one may open all the same.
    case windowUnanswered
    /// It, or macOS, gave an error, by its number, with any words that came with it.
    case gave(Int, said: String?)

    /// The first Ghostty whose terminals say their device (`tty`).
    static let leastVersion = "1.4"

    /// macOS's refusal of the leave to control an app: errAEEventNotPermitted.
    static let notPermitted = -1743

    public var description: String {
        switch self {
        case .noAnswer:
            "Ghostty did not answer within \(Int(GhosttyEvents.answerSeconds)) seconds: most likely the screen is locked, or macOS is asking whether SitRep may control Ghostty."
        case .tooOld:
            "This Ghostty cannot say which of its windows is on a device, so SitRep cannot jump to one: update Ghostty to \(Self.leastVersion) or later."
        case .cannotOpen:
            "This Ghostty cannot open a window for SitRep: update Ghostty to \(Self.leastVersion) or later."
        case .windowUnanswered:
            "Ghostty did not answer within \(Int(GhosttyEvents.answerSeconds)) seconds when asked to open a window; one may still appear."
        case .gave(Self.notPermitted, _):
            "Not authorized to send Apple events to Ghostty. (\(Self.notPermitted))"
        case let .gave(number, said?):
            "Ghostty got an error: \(said) (\(number))"
        case let .gave(number, nil):
            "Ghostty got an error (\(number))."
        }
    }
}

/// Ghostty's driver. Since Ghostty 1.4 its scripting gives each terminal the device it is on (`tty`, `/dev/ttys041`),
/// so the terminal on a device is asked for by it and focused, and Ghostty kept in front. A terminal in a tab not
/// selected has its window activated first, then, after a pause, is focused, so macOS takes Lee to the window's Space
/// rather than bringing the tab to his. An older Ghostty, which does not know the terms, is refused in plain words.
public struct GhosttyDriver: TerminalDriver {
    /// Ghostty's bundle id, by which it is found running and brought forward.
    public static let bundle = "com.mitchellh.ghostty"

    /// How long the driver waits between activating the window of a tab not selected and focusing its terminal.
    /// Focused straight away, or with the tab selected first, the terminal's window is brought to Lee's Space instead
    /// of macOS sliding to its own: half a second was enough, live, 6 November 2026.
    public static let pause = Duration.milliseconds(500)

    private static let logger = Logger(sitrep: "jump")

    let scripting: any GhosttyScripting
    let workspace: any Workspace
    let clock: any JumpClock

    public init(scripting: any GhosttyScripting, workspace: any Workspace, clock: any JumpClock) {
        self.scripting = scripting
        self.workspace = workspace
        self.clock = clock
    }

    public func bringForward(on device: String, front: String?) async throws -> Bool {
        let kept = KeptInFront(Self.bundle, after: front, on: workspace)

        defer { kept?.end() }

        guard let terminal = try await scripting.terminal(on: device) else {
            return false
        }

        try Task.checkCancellation()
        if try await !scripting.isTabSelected(holding: device) {
            try Task.checkCancellation()
            try await scripting.activateWindow(holding: device)
            try await clock.sleep(for: Self.pause)
        }

        try Task.checkCancellation()
        try await scripting.focus(terminal)
        await kept?.keep(on: clock)
        return true
    }

    public func canOpen() async -> Bool {
        await workspace.running([Self.bundle]) != nil
    }

    /// The window opened, then its terminal focused, which makes it key, and Ghostty kept in front as a jump keeps it.
    public func openWindow(
        running command: String, front: String?, sending: @escaping @Sendable () -> Void
    ) async throws -> Bool {
        let kept = KeptInFront(Self.bundle, after: front, on: workspace)

        defer { kept?.end() }

        guard case let .opened(terminal) = try await scripting.openWindow(running: command, sending: sending) else {
            return false
        }

        await focus(opened: terminal, kept: kept)
        return true
    }

    /// The new window's terminal focused, and Ghostty kept in front. Nothing here fails the opening, as the window is
    /// open: what went wrong is logged. None is focused where Ghostty named no window, or a later click has stopped it.
    private func focus(opened terminal: GhosttyObject?, kept: KeptInFront?) async {
        guard let terminal, !Task.isCancelled else {
            let why = terminal == nil ? "Ghostty named no window" : "a later click came"

            Self.logger.notice("A window opened, unfocused: \(why, privacy: .public)")
            return
        }

        do {
            try await scripting.focus(terminal)
            await kept?.keep(on: clock)
        } catch {
            Self.logger.notice("A window opened, but its focus failed: \(String(describing: error), privacy: .public)")
        }
    }
}
