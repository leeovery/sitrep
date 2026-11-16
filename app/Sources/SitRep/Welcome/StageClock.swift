import AppKit

/// The time the welcome's stage keeps, ms; the wakes it sets while its frames sleep, the loop's next beat and the end
/// of a chime's light; and its frames' link run. The display's clock, the main run loop's timers and the display's
/// refreshes (`DisplayClock`); or a test's own, which moves only as the test moves it, and steps the frames itself.
@MainActor
protocol StageClock {
    var now: Double { get }
    /// `woken` called once this many ms have passed, unless the wake is invalidated first.
    func wake(in wait: Double, _ woken: @escaping @MainActor () -> Void) -> any StageWake
    /// The link's refreshes run, each a frame while it is not paused.
    func run(_ link: CADisplayLink)
}

/// A wake the stage set, which it calls off as frames run again, or as the window closes.
@MainActor
protocol StageWake: AnyObject {
    func invalidate()
}

extension Timer: StageWake {}

/// The display's clock, a timer on the main run loop, and the link on it.
struct DisplayClock: StageClock {
    var now: Double { Displays.now }

    func wake(in wait: Double, _ woken: @escaping @MainActor () -> Void) -> any StageWake {
        let timer = Timer(timeInterval: wait / 1000, repeats: false) { _ in
            MainActor.assumeIsolated(woken)
        }

        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    func run(_ link: CADisplayLink) {
        link.add(to: .main, forMode: .common)
    }
}
