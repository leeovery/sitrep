import Foundation
import SitRepCore

/// A run of `sitrep screen` under way, handed back with what it came to, so one begun before the window closed is told
/// from one begun after.
public struct ScreenLook: Equatable, Sendable {
    let generation: Int
}

/// Which sessions show on a terminal of this Mac, as the SitRep window reads them: `sitrep screen` run only while the
/// window shows, at once as it opens, comes back from the Dock or out from under other windows, or becomes key with
/// its reading more than `fresh` old, then `every` seconds after each look ends, never two at once. On screen changes
/// with Lee's tmux and terminal windows, not with the board, so `watch` cannot carry it. The last reading stands while
/// the window is minimised or covered, and goes as it closes, as it opens afresh.
struct ScreenLooks {
    /// How long after one look ends the next is due, while the window shows.
    static let every: TimeInterval = 5
    /// How old the reading may be for the window becoming key to stand on it, rather than look again.
    static let fresh: TimeInterval = 1

    private enum Window {
        case closed, minimised, open
    }

    /// The last look's reading; none before the first, after one that failed, or once the window closed.
    private var reading: ScreenReading?
    /// When the last look kept ended.
    private var lastLook: Date?
    private var window = Window.closed
    /// What macOS last said of it: not covered, and on the Space Lee is on.
    private var isVisible = false
    private var isLooking = false
    /// When the next look is due, while the window shows. Set while a look runs, it is an at-once look asked for
    /// meanwhile, made as that one ends.
    private var due: Date?
    /// Moved on as the window closes: a look begun before is not kept.
    private var generation = 0

    /// Due at once, whatever the time.
    private static let atOnce = Date.distantPast

    /// The window is open, and macOS has it visible.
    var isShowing: Bool {
        window == .open && isVisible
    }

    /// Whether a jump could reach the session, as the last reading says: none with no reading, or for a session it
    /// does not list, as no window holds it.
    func onScreen(of session: String) -> OnScreen? {
        reading?.onScreen(of: session)
    }

    /// The terminal app showing the session, as the last reading says: none with no reading, or none known.
    func app(of session: String) -> String? {
        reading?.app(of: session)
    }

    /// When the next look is due; none while one runs, or while the window does not show.
    var nextLook: Date? {
        isLooking ? nil : due
    }

    /// The window opens, or comes back from the Dock: it looks at once, once macOS says it is visible.
    mutating func open() {
        window = .open
        due = Self.atOnce
    }

    mutating func close() {
        window = .closed
        generation += 1
        reading = nil
        lastLook = nil
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

    /// The window became key at this time: it looks at once where its reading is more than `fresh` old, unless a look
    /// under way stands for it.
    mutating func key(at time: Date) {
        guard isShowing, !isLooking else {
            return
        }

        if lastLook.map({ time.timeIntervalSince($0) > Self.fresh }) ?? true {
            due = Self.atOnce
        }
    }

    /// The look to run at this time: the window shows, no look is under way, and one is due; none otherwise. Until
    /// `looked` hears what it came to, it is under way.
    mutating func look(at time: Date) -> ScreenLook? {
        guard isShowing, !isLooking, let due, due <= time else {
            return nil
        }

        isLooking = true
        self.due = nil
        return ScreenLook(generation: generation)
    }

    /// What the look came to, heard at this time: its reading, none for a run that failed; the next due at once where
    /// one was asked for meanwhile, else `every` seconds on, while the window shows. One begun before the window closed
    /// is let go, the next as it stood. Whether what it says changed.
    mutating func looked(_ answer: ScreenAnswer, of look: ScreenLook, at time: Date) -> Bool {
        isLooking = false
        guard look.generation == generation else {
            return false
        }

        let before = reading

        reading = answer.reading
        lastLook = time
        due = isShowing ? (due ?? time.addingTimeInterval(Self.every)) : nil
        return reading != before
    }
}
