import Foundation

/// The menu's working arcs turning, once a second as the panel's, while the menu is open: a step to the next of the
/// arc's frames (`MenuImages.arc`) each 30th of a second, by a timer that runs in the menu's tracking mode, from the
/// menu opening to its closing. Under reduced motion it never starts, and the arcs hold still at the first frame.
@MainActor
final class MenuTurn {
    static let frames = 30

    /// The frame the arcs show.
    private(set) var frame = 0
    private var timer: Timer?
    /// Each step's frame shown.
    private let show: () -> Void

    init(show: @escaping () -> Void) {
        self.show = show
    }

    var isTurning: Bool { timer != nil }

    /// The menu opening: turning from the frame the arcs show, unless motion is reduced.
    func start(reducesMotion: Bool) {
        guard !reducesMotion, timer == nil else {
            return
        }

        let timer = Timer(timeInterval: 1 / Double(Self.frames), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }

        // common modes take in the event tracking a menu runs its loop in while open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// The menu closing: nothing runs, and the arcs are still again, at the first frame, as it next opens.
    func stop() {
        timer?.invalidate()
        timer = nil
        frame = 0
        show()
    }

    /// To the next frame, which is shown.
    func step() {
        frame = (frame + 1) % Self.frames
        show()
    }
}
