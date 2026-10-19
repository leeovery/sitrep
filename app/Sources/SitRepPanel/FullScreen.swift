import CoreGraphics

/// A window as the window list has it, by what it gives without Screen Recording: the app that owns it, its layer and
/// its bounds, in the list's coordinates, y down from the main display's top.
public struct ListedWindow: Equatable, Sendable {
    public let owner: String
    public let layer: Int
    public let bounds: CGRect

    public init(owner: String, layer: Int, bounds: CGRect) {
        self.owner = owner
        self.layer = layer
        self.bounds = bounds
    }

    /// A window from its entry in `CGWindowListCopyWindowInfo`; nil for an entry missing any of the three.
    public init?(_ info: [String: Any]) {
        guard let owner = info[kCGWindowOwnerName as String] as? String,
              let layer = info[kCGWindowLayer as String] as? Int,
              let bounds = info[kCGWindowBounds as String].flatMap(Self.rect)
        else {
            return nil
        }

        self.init(owner: owner, layer: layer, bounds: bounds)
    }

    private static func rect(_ bounds: Any) -> CGRect? {
        guard let bounds = bounds as? [String: Any] else {
            return nil
        }

        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }
}

/// Whether a full-screen app has a display, which the panel then leaves to it: nothing goes over a full-screen window
/// (Lee). While a display's Space is a full-screen app's, the Dock keeps a backdrop behind it covering that display,
/// and only then, whichever app is in front.
public enum FullScreen {
    /// The backdrop's layer, read off macOS 26 on Lee's Mac. Should it ever stop matching, no display is found full
    /// screen, and the panel shows over full-screen apps, as it did before.
    static let backdropLayer = -2_147_483_622

    /// The Dock's backdrop covering the display, in the window list's coordinates, among the windows on the screen.
    public static func backdrop(on display: CGRect, in windows: [ListedWindow]) -> ListedWindow? {
        let slack = 1.0
        let covered = display.insetBy(dx: slack, dy: slack)

        return windows.first { $0.owner == "Dock" && $0.layer == backdropLayer && $0.bounds.contains(covered) }
    }

    /// The same, from the window list's entries as `CGWindowListCopyWindowInfo` gives them.
    public static func backdrop(on display: CGRect, in list: [[String: Any]]) -> ListedWindow? {
        backdrop(on: display, in: list.compactMap(ListedWindow.init))
    }
}
