extension Card {
    /// The prototype's `beginDrag`: the panel closes and the card lifts off the edge over 140ms.
    public func carry() {
        close()
        isCarried = true
        to(\.lift, 1, 140)
    }

    /// The drag's place for it: the card follows on a 50ms spring.
    public func carried(to y: Double) {
        notchY = Self.home(y, on: stage)
        to(\.y, notchY, 50)
    }

    /// The prototype's `endPointer` after a drag: the card sets down over 220ms, and a pointer left on it doesn't
    /// open it; let go across the screen's middle, it moves to the other edge once it is home (`cross`).
    public func drop(across: Bool) {
        isCarried = false
        contact.armed = false
        to(\.lift, 0, 220)
        guard across else {
            return
        }

        if phase == .closed {
            cross()
        } else {
            crossesOnceHome = true
        }
    }

    /// The prototype's `moveEdge`: the card slides into this edge in 150ms, its light out in 90; at 160 it swaps to
    /// the other edge (`Frame.swapsEdge`) and slides out of it over 300, its light back over 260; at 420 it is home,
    /// at whatever the rest is by then. Under reduced motion it swaps at once, cross-fading to the notch.
    func cross() {
        crossesOnceHome = false
        cancel(.dwell, .grace)
        cancelPrefix(CardTimer.swellPrefix)
        isCrossing = true
        guard !reducesMotion else {
            swapsEdge = true
            setShape(w: resting.w, h: resting.h)
            later(.moveDone, 160) { $0.isCrossing = false }
            return
        }

        to(\.w, 0, 150)
        to(\.n, 0, 150)
        to(\.vis, 0, 90)
        later(.moveSwap, 160) { c in
            c.swapsEdge = true
            c.setShape(w: c.resting.w, h: c.resting.h, 300)
            c.to(\.vis, 1, 260)
        }
        later(.moveDone, 420) { c in
            c.isCrossing = false
            c.settleRest()
        }
    }

    /// Whether the pointer may draw the card out: not while a drag has it, nor as it crosses.
    var isFree: Bool { !isCarried && !isCrossing }
}
