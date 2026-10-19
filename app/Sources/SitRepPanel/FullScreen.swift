import CoreGraphics

/// A window an app has on the screen, as the window list has it, in screen coordinates.
public struct AppWindow: Equatable, Sendable {
    public let number: Int
    public let app: Int32
    public let frame: CGRect

    public init(number: Int, app: Int32, frame: CGRect) {
        self.number = number
        self.app = app
        self.frame = frame
    }
}

/// The app in front, and whether it says it has the screen: full screen, or the menu bar hidden.
public struct FrontApp: Equatable, Sendable {
    public let id: Int32
    public let isFullScreen: Bool

    public init(id: Int32, isFullScreen: Bool) {
        self.id = id
        self.isFullScreen = isFullScreen
    }
}

/// Whether a full-screen app has the panel's display, which the panel then leaves to it: nothing goes over a
/// full-screen window (Lee). The app in front says whether it is full screen, which a window's size can't: on a
/// display with a notch, a full-screen window sits under it, exactly where a maximised one does. Its window filling
/// the panel's display says the display is the one it has; and while that window stands on the screen as it was, the
/// display is still its, whichever app comes to the front, until its own app, in front, says it is full screen no
/// longer.
public struct FullScreen: Equatable, Sendable {
    /// The full-screen window that has the panel's display.
    public private(set) var window: AppWindow?

    public init() {}

    public var hasDisplay: Bool { window != nil }

    /// What the Mac shows now: the app in front, and the apps' windows on the screen.
    public mutating func take(front: FrontApp?, windows: [AppWindow], on edge: ScreenEdge) {
        if let front, front.isFullScreen,
           let filling = windows.first(where: { $0.app == front.id && edge.isFilled(by: $0.frame) })
        {
            window = filling
        } else if let held = window, !windows.contains(held) || front == FrontApp(id: held.app, isFullScreen: false) {
            window = nil
        }
    }
}

extension ScreenEdge {
    /// Whether a window fills the screen as a full-screen one does: within its sides, from its bottom to the menu
    /// bar's place or higher. Split View's two windows each fill it.
    func isFilled(by window: CGRect) -> Bool {
        let slack = 1.0

        return window.minX >= frame.minX - slack && window.maxX <= frame.maxX + slack
            && window.minY <= frame.minY + slack && window.maxY >= visible.maxY - slack
    }
}
