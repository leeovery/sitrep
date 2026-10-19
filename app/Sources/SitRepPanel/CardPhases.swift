import Foundation

extension Card {
    /// Out: the depth springs out of the notch to the panel's, the nudge carried into it, motion and all, and Lag
    /// into the slide (÷ Slide) the length springs out to the panel's too, both ways from its centre; reopened while
    /// the length was still shrinking back, it goes straight back out. Under reduced motion it cross-fades to the
    /// panel's shape.
    func open() {
        cancel(.dwell, .grace)
        guard !isLive else {
            return
        }

        cancelPrefix("close:")
        cancelPrefix(CardTimer.swellPrefix)
        // reopened as it went in, after a click elsewhere cut a jump's press short
        cancel(.jump)
        jumping = nil
        phase = .opening
        motion = Motion(kind: .open)
        S.w.x += S.n.x
        S.w.v += S.n.v
        S.n.snap(0)
        reveal = .none

        guard !reducesMotion else {
            setShape(w: Tuning.panelDepth, h: panelLength)
            motion?.lengthOn = true
            to(\.vis, 0, 100)
            return landRows()
        }

        to(\.vis, 0, 90)
        springTo(\.w, Tuning.panelDepth, feel.sp(.slide))
        if S.h.x > resting.h + 1 {
            growLength()
        } else {
            later(.openLength, feel.lag / feel.slide) { $0.growLength() }
        }
    }

    /// The length springs out to the panel's while the depth is still sliding.
    func growLength() {
        motion?.lengthOn = true
        springTo(\.h, panelLength, feel.sp(.length))
    }

    /// The card is out: the rows land, from the top, 25ms apart.
    func landRows() {
        reveal = .rowsIn(t)
        phase = .open
    }

    /// Back in: the rows fade, the length starts back 50ms in, and Lag later the depth, both ÷ Close; the depth
    /// seats in `updateMotion`. Under reduced motion it cross-fades to the notch.
    func close() {
        cancel(.dwell, .grace)
        // a pointer left sitting on the notch doesn't reopen it until it leaves
        contact.armed = false
        guard isLive else {
            return
        }

        cancelPrefix("open:")
        phase = .closing
        motion = Motion(kind: .close)
        reveal = .rowsOut(t)

        guard !reducesMotion else {
            setShape(w: resting.w, h: resting.h)
            to(\.vis, 1, 120)
            return later(.closeDone, 160) { $0.closed() }
        }

        later(.closeLength, CardTuning.closeAt / feel.close) { $0.shrinkLength() }
        later(.closeDepth, (CardTuning.closeAt + feel.lag) / feel.close) { $0.slideHome() }
    }

    func shrinkLength() {
        springTo(\.h, resting.h, feel.sp(.shrink))
    }

    func slideHome() {
        motion?.homing = true
        springTo(\.w, resting.w, feel.sp(.home))
    }

    /// Home: the light is back, and the card rests at whatever the rest is now, an ask having perhaps come meanwhile.
    func closed() {
        phase = .closed
        jumping = nil
        to(\.vis, 1, 140)
        settleRest()
    }

    /// Back to rest, wherever the card is, on the follow spring.
    func settleRest() {
        if abs(S.w.target - resting.w) > 0.01 {
            springTo(\.w, resting.w, feel.sp(.follow))
        }
        if abs(S.h.target - resting.h) > 0.01 {
            springTo(\.h, resting.h, feel.sp(.follow))
        }
    }

    /// The open and the close, staged once a frame on where the springs have got to, so Slide, Close and Bounce all
    /// carry through. Opening, the rows land once the length and the depth are both there; closing, the light comes
    /// back over the depth's last 30, and the card is home once the depth is seated.
    func updateMotion() {
        guard let M = motion, !reducesMotion else {
            return
        }

        switch M.kind {
        case .open:
            let there = abs(S.h.x - panelLength) <= CardTuning.lengthLands
                && abs(S.w.x - Tuning.panelDepth) <= CardTuning.depthLands
            if phase == .opening, M.lengthOn, there {
                landRows()
            }
        case .close:
            guard phase == .closing, M.homing else {
                return
            }

            let home = resting.w
            if !M.lit, S.w.x <= home + CardTuning.lightBack {
                motion?.lit = true
                to(\.vis, 1, 140)
            }
            // a critically damped spring never passes it, but its steps might
            if S.w.x <= home + CardTuning.seated {
                S.w.snap(home)
                closed()
            }
        }
    }

    /// Once its length is out, the card's length follows the panel's content as it changes: while it is still
    /// springing out, on the same spring.
    func followLength() {
        guard phase == .open || phase == .opening && motion?.lengthOn == true else {
            return
        }

        let H = panelLength
        guard abs(S.h.target - H) >= 0.01 else {
            return
        }

        if phase == .opening {
            S.h.target = H
        } else {
            springTo(\.h, H, feel.sp(.follow))
        }
    }

    /// Open, once a frame: the pointer off the card starts the grace, shorter the faster it went; back on before it
    /// ends, the grace is off. Not while a jump's row is pressed in: the jump drains it.
    func updateLeave() {
        guard phase == .open, jumping == nil else {
            return
        }
        guard !pointerInside() else {
            return cancel(.grace)
        }
        guard !timers.has(.grace) else {
            return
        }

        let grace = lerp(Tuning.grace, Tuning.graceFast, smooth(clamp(pointerSpeed() / Tuning.fastLeave, 0, 1)))
        later(.grace, grace) { $0.close() }
    }
}
