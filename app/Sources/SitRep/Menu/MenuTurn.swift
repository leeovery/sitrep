import AppKit
import SitRepMenu
import SitRepPanel

/// The menu's working arcs turning, once a second as the panel's, while the menu is open with a working row in it:
/// the working rows' images set to the arc's frame for now (`MenuImages.arc`) each 30th of a second, by a timer that
/// runs in the menu's tracking mode. Its frame comes from the clock every arc turns by (`Arc.phase`), so the menu's
/// arcs turn in step with the panel's. With no working row showing, or the menu closed, or under reduced motion,
/// nothing runs, and the arcs hold still at the first frame.
@MainActor
final class MenuTurn {
    static let frames = 30

    private let menu: NSMenu
    /// What the menu's items show, one entry to an item, in its order.
    private var entries: [MenuEntry] = []
    private var timer: Timer?

    init(_ menu: NSMenu) {
        self.menu = menu
    }

    /// Internal only for the tests, which read it.
    var isTurning: Bool { timer != nil }

    /// The frame a working row's arc shows now: the clock's while turning, else the first.
    var frame: Int { isTurning ? Self.frame(at: CACurrentMediaTime()) : 0 }

    /// The frame of a turn once a second at this time on the clock every arc turns by.
    static func frame(at now: Double) -> Int {
        Int(Arc.phase(every: 1, at: now) * Double(frames)) % frames
    }

    /// The menu, drawn with these entries: turning while it is open with a working row in it and motion isn't
    /// reduced, else still.
    func follow(_ entries: [MenuEntry], isOpen: Bool, reducesMotion: Bool) {
        self.entries = entries
        if isOpen, !reducesMotion, entries.contains(where: { Self.working($0) != nil }) {
            start()
        } else {
            stop()
        }
    }

    /// Nothing runs, and the arcs are still again, at the first frame, as they next show.
    func stop() {
        guard let timer else {
            return
        }

        timer.invalidate()
        self.timer = nil
        show(0)
    }

    /// The working rows' arcs at the frame for this time.
    func step(at now: Double) {
        show(Self.frame(at: now))
    }

    private func start() {
        guard timer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1 / Double(Self.frames), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step(at: CACurrentMediaTime()) }
        }

        // common modes take in the event tracking a menu runs its loop in while open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Only the working rows' images set, each to this frame of the arc.
    private func show(_ frame: Int) {
        for (offset, entry) in entries.enumerated() {
            if let session = Self.working(entry), offset < menu.numberOfItems {
                menu.item(at: offset)?.image = MenuImages.mark(session, turn: frame)
            }
        }
    }

    private static func working(_ entry: MenuEntry) -> Session? {
        guard case let .row(session, _) = entry, session.kind == .working else {
            return nil
        }

        return session
    }
}
