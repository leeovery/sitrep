import AppKit
import os
import SitRepCore
import SitRepPanel

/// Whether a full-screen app has the panel's display, read off the window list whenever it may have changed: a
/// display's Space changing, another app coming to the front or quitting, the screens changing. Nothing polls, so at
/// rest it costs nothing. It reads only what needs no Screen Recording: the windows' owners, layers and bounds.
@MainActor
final class FullScreenWatch {
    var onChange: (() -> Void)?
    private(set) var hasDisplay = false
    /// Whether it has looked yet: the first look is logged too, to show it is watching.
    private var looked = false
    private var observers: [any NSObjectProtocol] = []
    private var settled: Task<Void, Never>?
    private let logger = Logger(sitrep: "fullscreen")

    /// How long after a change to look again: going into full screen, the backdrop is still sliding onto the display
    /// when its Space changes.
    private static let transition: Duration = .seconds(1)

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let changes = [
            NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]

        observers = changes.map { name in
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed() }
            }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        })
        look()
    }

    private func changed() {
        look()
        settled?.cancel()
        settled = Task { [weak self] in
            try? await Task.sleep(for: Self.transition)
            guard !Task.isCancelled else {
                return
            }

            self?.look()
        }
    }

    private func look() {
        guard let display = Self.display else {
            return
        }

        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let isFullScreen = FullScreen.backdrop(on: display, in: list) != nil

        guard isFullScreen != hasDisplay || !looked else {
            return
        }

        looked = true
        hasDisplay = isFullScreen
        log(display, list)
        onChange?()
    }

    /// What it saw, each time it changes its mind: `log show --predicate 'category == "fullscreen"'`. At notice, not
    /// info, as the Mac keeps info only in memory, where `log show` afterwards won't find it.
    private func log(_ display: CGRect, _ list: [[String: Any]]) {
        let shown = hasDisplay ? "hidden" : "shown", at = Self.describe(display)
        let docks = list.compactMap(ListedWindow.init).filter { $0.owner == "Dock" }
            .map { "layer \($0.layer) at \(Self.describe($0.bounds))" }.joined(separator: "; ")
        let seen = docks.isEmpty ? "none" : docks

        logger.notice("""
        Display \(at, privacy: .public): the panel \(shown, privacy: .public); \
        the Dock's windows: \(seen, privacy: .public)
        """)
    }

    private static func describe(_ rect: CGRect) -> String {
        "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
    }

    /// The panel's display in the window list's coordinates.
    private static var display: CGRect? {
        let number = NSScreen.screens.first?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]

        return (number as? CGDirectDisplayID).map(CGDisplayBounds)
    }
}
