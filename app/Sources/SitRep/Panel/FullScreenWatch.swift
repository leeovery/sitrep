import AppKit
import SitRepPanel

/// Whether a full-screen app has the panel's display, read off the Mac whenever it may have changed: a display's
/// Space changing, another app coming to the front or quitting, the screens changing. Nothing polls, so at rest it
/// costs nothing. It reads only what needs no permission: the system's presentation options, which the app in front
/// puts into effect, and the apps' windows on the screen by their number, owner and bounds.
@MainActor
final class FullScreenWatch {
    var onChange: (() -> Void)?
    private(set) var fullScreen = FullScreen()
    private var observers: [any NSObjectProtocol] = []
    private var settled: Task<Void, Never>?

    /// How long after a change to look again: a window going into full screen or out of it is still moving when its
    /// Space changes.
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

    var hasDisplay: Bool { fullScreen.hasDisplay }

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
        let had = hasDisplay

        fullScreen.take(front: Self.front, windows: Self.windows, on: Display.edge)
        if hasDisplay != had {
            onChange?()
        }
    }

    private static var front: FrontApp? {
        let options = NSApplication.shared.currentSystemPresentationOptions

        return NSWorkspace.shared.frontmostApplication.map {
            FrontApp(id: $0.processIdentifier, isFullScreen: !options.isDisjoint(with: [.fullScreen, .hideMenuBar]))
        }
    }

    /// The apps' windows on the screen, front to back, in screen coordinates: the window list's run down from the
    /// main screen's top.
    private static var windows: [AppWindow] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let top = NSScreen.screens.first?.frame.maxY ?? 0

        return (list as? [[String: Any]] ?? []).compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  let number = info[kCGWindowNumber as String] as? Int,
                  let app = info[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else {
                return nil
            }

            return AppWindow(
                number: number, app: app,
                frame: CGRect(x: frame.minX, y: top - frame.maxY, width: frame.width, height: frame.height)
            )
        }
    }
}
