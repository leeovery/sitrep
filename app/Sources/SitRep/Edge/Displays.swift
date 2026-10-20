import AppKit
import SitRepPanel

/// The displays as the edge knows them, and what it reads off them each frame.
@MainActor
enum Displays {
    /// Those connected, the main one, with the menu bar, first.
    static var all: [Display] { NSScreen.screens.compactMap(display) }

    /// Those connected, by the id the edge gives each and the name macOS does, for Settings' Display; the main one first.
    static var named: [(id: String, name: String)] {
        NSScreen.screens.compactMap { screen in display(screen).map { ($0.id, screen.localizedName) } }
    }

    /// The display the settings choose: the one chosen while it is connected, else the main one.
    static func chosen(_ settings: EdgeSettings) -> Display {
        Display.chosen(settings.display, among: all) ?? Display(id: "", frame: .zero, visible: .zero)
    }

    /// The chosen display in the window list's coordinates, which `FullScreen` judges.
    static func bounds(of settings: EdgeSettings) -> CGRect? {
        let id = chosen(settings).id

        return NSScreen.screens.first { display($0)?.id == id }.flatMap(number).map(CGDisplayBounds)
    }

    /// The display's clock, ms.
    static var now: Double { CACurrentMediaTime() * 1000 }

    /// The wall clock, ms, which the rows' times count on.
    static var wallNow: Double { Date().timeIntervalSince1970 * 1000 }

    /// Whether to reduce motion: SitRep's own setting on, or the Mac's.
    static func reducesMotion(_ settings: EdgeSettings) -> Bool {
        settings.reducesMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// A screen by the id the edge gives it, its display's UUID, which outlives a restart and a replug.
    private static func display(_ screen: NSScreen) -> Display? {
        guard let number = number(screen), let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue()
        else {
            return nil
        }

        let id = CFUUIDCreateString(nil, uuid) as String

        return Display(id: id, frame: screen.frame, visible: screen.visibleFrame)
    }

    private static func number(_ screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
