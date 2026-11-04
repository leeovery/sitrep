import Foundation
import SitRepCore

/// Which sessions show on a terminal of this Mac, as the SitRep window reads them: `sitrep screen` run only while the
/// window shows, at once as it opens, comes back from the Dock or out from under other windows, or becomes key, then
/// `every` seconds after each look ends, never two at once. On screen changes with Lee's tmux and terminal windows,
/// not with the board, so `watch` cannot carry it. The last reading stands while the window is minimised or covered,
/// and goes as it closes, as it opens afresh.
struct ScreenLooks {
    /// How long after one look ends the next is due, while the window shows.
    static let every: TimeInterval = 5

    private enum Window {
        case closed, minimised, open
    }

    /// The last look's reading; none before the first, after one that failed, or once the window closed.
    private var reading: ScreenReading?
    private var window = Window.closed
    /// What macOS last said of it: open and not covered, on the Space Lee is on.
    private var isVisible = false
    private var isLooking = false
    /// When the next look is due, while the window shows.
    private var due: Date?

    /// Due at once, whatever the time.
    private static let atOnce = Date.distantPast

    private var isShowing: Bool {
        window == .open && isVisible
    }

    /// Whether a jump could reach the session, as the last reading says; unknown with none.
    func onScreen(of session: String) -> OnScreen {
        reading?.onScreen(of: session) ?? .unknown
    }

    /// When the next look is due; none while one runs, or while the window does not show.
    var nextLook: Date? {
        isLooking ? nil : due
    }

    /// The window opens, or comes back from the Dock: brought forward, it shows until macOS says otherwise, and looks
    /// at once.
    mutating func open() {
        window = .open
        isVisible = true
        due = Self.atOnce
    }

    mutating func close() {
        window = .closed
        reading = nil
        due = nil
    }

    mutating func minimise() {
        window = .minimised
        due = nil
    }

    /// macOS says whether the window is visible: covered or on another Space, it looks no more; uncovered, it looks at
    /// once.
    mutating func visible(_ isVisible: Bool) {
        let wasShowing = isShowing

        self.isVisible = isVisible
        if !isShowing {
            due = nil
        } else if !wasShowing {
            due = Self.atOnce
        }
    }

    /// The window became key: it looks at once, unless a look under way stands for it.
    mutating func key() {
        if isShowing, !isLooking {
            due = Self.atOnce
        }
    }

    /// Whether to run `sitrep screen` at this time: the window shows, no look is under way, and one is due. Until
    /// `looked` hears what it came to, the look is under way.
    mutating func look(at time: Date) -> Bool {
        guard isShowing, !isLooking, let due, due <= time else {
            return false
        }

        isLooking = true
        self.due = nil
        return true
    }

    /// What the look came to, heard at this time: its reading, kept unless the window closed meanwhile; none for a run
    /// that failed. The next is due `every` seconds on, while the window shows. Whether what it says changed.
    mutating func looked(_ answer: ScreenAnswer, at time: Date) -> Bool {
        let before = reading

        isLooking = false
        if window != .closed {
            reading = answer.reading
        }
        due = isShowing ? time.addingTimeInterval(Self.every) : nil
        return reading != before
    }
}
