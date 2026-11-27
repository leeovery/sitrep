import SitRepPanel

/// A horizontal swipe on the asks panel, as it pages it (DESIGN, "Paging"). A trackpad's gesture runs from its fingers'
/// first touch to their lift, and its momentum after is no gesture: once it has gone `slop`, more across than down, the
/// slide follows its travel along, to its lift or its cancel; more down than across, it is no swipe. A mouse's wheel,
/// with no phases, has no lift to follow: its scrolls are one gesture until `wheelGap` passes with none, which steps
/// once it has gone `reach` across, more across than down. Along is toward the next ask as the asks lie, out from the
/// notch: with natural scrolling, fingers moving toward the notch.
struct AsksSwipe {
    /// What a scroll comes to on the slide (`AsksSlide`).
    enum Move: Equatable {
        /// The fingers have travelled this far along since their gesture began.
        case follow(Double)
        /// The fingers lifted, or the Mac cancelled their gesture.
        case lift, cancel
        /// A wheel's step: 1 to the next ask, -1 to the previous.
        case step(Int)
    }

    /// How far the gesture has gone, across and down, when its last scroll came, whether it is across, once that is
    /// known, and whether a wheel's has stepped.
    private struct Gesture {
        var along = 0.0, down = 0.0
        var last: Double
        var isAcross: Bool?
        var hasStepped = false

        /// A trackpad's scroll taken in, this far along: the travel the slide follows, once the gesture is known to be
        /// across.
        mutating func follow(_ scroll: Scroll, along moved: Double) -> Move? {
            along += moved
            down += scroll.down
            if isAcross == nil, max(abs(along), abs(down)) >= AsksSwipe.slop {
                isAcross = abs(along) > abs(down)
            }
            return isAcross == true ? .follow(along) : nil
        }

        /// A wheel's scroll taken in at this time, this far along: its step, once the gesture has gone far enough
        /// across and has taken none.
        mutating func step(_ scroll: Scroll, along moved: Double, at time: Double) -> Move? {
            along += moved
            down += scroll.down
            last = time
            guard !hasStepped, abs(along) >= AsksSwipe.reach, abs(along) > abs(down) else {
                return nil
            }

            hasStepped = true
            return .step(along > 0 ? 1 : -1)
        }
    }

    private var gesture: Gesture?

    /// How far, pt, a trackpad's gesture goes before it is known to be across or down.
    static let slop = 6.0
    /// How far, pt, a wheel's gesture goes across before it steps: under a wheel's notch.
    static let reach = 12.0
    /// How long, ms, a wheel's scrolls are one gesture after the last.
    static let wheelGap = 300.0

    /// Whether a trackpad's gesture across is under way, which every scroll of goes to the asks panel until it ends.
    var isAcross: Bool { gesture?.isAcross == true }

    /// What a scroll at this time comes to on the slide, the asks lying right to left where the asks panel
    /// `pointsLeft`, on the right edge, so the Mac's scroll along goes the other way; nil where it comes to nothing.
    mutating func move(_ scroll: Scroll, at time: Double, pointsLeft: Bool) -> Move? {
        let along = pointsLeft ? -scroll.along : scroll.along

        switch scroll.phase {
        case .began:
            gesture = Gesture(last: time)
            return gesture?.follow(scroll, along: along)
        case .changed:
            return gesture?.follow(scroll, along: along)
        case .ended, .cancelled:
            defer { gesture = nil }
            guard isAcross else {
                return nil
            }

            return scroll.phase == .ended ? .lift : .cancel
        case .wheel:
            if gesture.map({ time - $0.last > Self.wheelGap }) ?? true {
                gesture = Gesture(last: time)
            }
            return gesture?.step(scroll, along: along, at: time)
        case .momentum:
            return nil
        }
    }
}
