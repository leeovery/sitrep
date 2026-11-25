import SitRepPanel

/// A horizontal swipe on the asks panel, as it pages it (DESIGN, "Paging"): one step a gesture, to the next ask as the
/// scroll goes along, the previous one as it goes back, once it has gone `reach` across, more across than down. A
/// trackpad's gesture runs from its fingers' first touch to their lift, and its momentum after is no gesture; a mouse's
/// wheel, with no phases, scrolls one gesture until `wheelGap` passes with none.
struct AsksSwipe {
    /// How far the gesture has gone, across and down, when its last scroll came, and whether it has stepped.
    private struct Gesture {
        var along = 0.0, down = 0.0
        var last: Double
        var hasStepped = false

        /// The scroll taken in: its step, once the gesture has gone far enough across and has taken none.
        mutating func take(_ scroll: Scroll, at time: Double) -> Int? {
            along += scroll.along
            down += scroll.down
            last = time
            guard !hasStepped, abs(along) >= AsksSwipe.reach, abs(along) > abs(down) else {
                return nil
            }

            hasStepped = true
            return along > 0 ? 1 : -1
        }
    }

    private var gesture: Gesture?

    /// How far, pt, a swipe goes across before it steps: under a wheel's notch, a trackpad's deliberate flick.
    static let reach = 12.0
    /// How long, ms, a wheel's scrolls are one gesture after the last.
    static let wheelGap = 300.0

    /// The step a scroll at this time takes, 1 to the next ask or -1 to the previous; nil where it takes none.
    mutating func step(_ scroll: Scroll, at time: Double) -> Int? {
        switch scroll.phase {
        case .began:
            gesture = Gesture(last: time)
        case .wheel where gesture.map({ time - $0.last > Self.wheelGap }) ?? true:
            gesture = Gesture(last: time)
        case .momentum:
            return nil
        case .changed, .ended, .wheel:
            break
        }

        let step = gesture?.take(scroll, at: time)

        if scroll.phase == .ended {
            gesture = nil
        }
        return step
    }
}

