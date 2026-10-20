extension Meniscus {
    /// The prototype's `beginDrag`: the panel closes, the notch is carried from where the reach had it, its slide
    /// becoming its place, and it lifts off the edge over 140ms.
    public func carry() {
        close()
        isCarried = true
        notchY = Self.home(S.y.x + S.ay.x, on: stage, feel)
        S.y.snap(notchY)
        S.ay.snap(0)
        to(\.lift, 1, 140)
    }

    /// The drag's place for it: the notch follows on a 50ms spring.
    public func carried(to y: Double) {
        notchY = Self.home(y, on: stage, feel)
        to(\.y, notchY, 50)
    }

    /// The prototype's `endPointer` after a drag: the notch sets down over 220ms, and a pointer left on it doesn't
    /// open it; let go across the screen's middle, it moves to the other edge (`cross`).
    public func drop(across: Bool) {
        isCarried = false
        contact.armed = false
        attract.armed = false
        to(\.lift, 0, 220)
        guard across else {
            return
        }

        if phase == .closed {
            cross()
        } else {
            later(.moveStart, 240) { $0.cross() }
        }
    }

    /// The prototype's `moveEdge`: the notch drains into this edge, three tenths shorter, in 150ms, its light out in
    /// 90; at 160 it swaps to the other edge (`Frame.swapsEdge`) and grows back out of it over 300, its light back
    /// over 260; at 420 it is home. Under reduced motion it swaps at once, cross-fading to the notch.
    func cross() {
        cancel(.dwell, .grace)
        isCrossing = true
        guard !reducesMotion else {
            swapsEdge = true
            setShape(w: resting.w, h: resting.h, r: resting.r, f: resting.f)
            later(.moveDone, 160) { $0.isCrossing = false }
            return
        }

        let l = resting
        setShape(w: 0, h: l.h * 0.7, r: l.r * 0.7, f: l.f * 0.7, 150)
        to(\.ay, 0, 150)
        to(\.ba, 0, 150)
        to(\.vis, 0, 90)
        later(.moveSwap, 160) { m in
            let l = m.resting
            m.swapsEdge = true
            m.snapReach()
            m.setShape(w: l.w, h: l.h, r: l.r, f: l.f, 300)
            m.to(\.vis, 1, 260)
        }
        later(.moveDone, 420) { $0.isCrossing = false }
    }

    /// Lifted by a drag, the notch stands out of the edge by up to 2 more.
    func lifted(_ g: MeniscusGeometry) -> MeniscusGeometry {
        var g = g
        if !isLive {
            g.w += 2 * S.lift.x
        }
        return g
    }

    /// Whether the pointer may draw the notch out: not while a drag has it, nor as it crosses.
    var isFree: Bool { !isCarried && !isCrossing }
}
