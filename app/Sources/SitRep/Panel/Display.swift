import AppKit
import SitRepPanel

/// What the panel's forms read off the display each frame, the notch's and the strip's alike.
@MainActor
enum Display {
    /// The screen with the menu bar, which the panel lives on.
    static var edge: ScreenEdge {
        let screen = NSScreen.screens.first

        return ScreenEdge(frame: screen?.frame ?? .zero, visible: screen?.visibleFrame ?? .zero)
    }

    /// The display's clock, ms.
    static var now: Double { CACurrentMediaTime() * 1000 }

    /// Whether to reduce motion: SitRep's own switch on, or the Mac's.
    static func reducesMotion(_ dials: PanelDials) -> Bool {
        dials.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
