import Foundation

/// One end of the notch, collapsing home.
enum End {
    case top, bottom

    var key: WritableKeyPath<MeniscusSprings, Spring> { self == .top ? \.et : \.eb }
}

struct Ends {
    /// The end nearer where the pointer left, which leads.
    let near: End
    /// How far the notch arrives past home, away from the exit.
    let rebound: Double
    var landed: Set<End> = []
}

extension MeniscusSprings {
    /// The springs of the collapse, which a lag holds back.
    static var collapse: [WritableKeyPath<MeniscusSprings, Spring>] { [\.w, \.r, \.f, \.et, \.eb, \.rb] }
}

extension Meniscus {
    func open() {
        cancel(.dwell, .grace)
        guard !isLive else {
            return
        }

        cancelPrefix("close:")
        // reopened as it drained, after a click elsewhere cut a jump's press short
        cancel(.jump)
        jumping = nil
        cling = Cling()
        snap = nil
        landing = nil
        endsOff()
        ringOff()
        to(\.lw, 0, 80)
        phase = .opening
        reveal = .rowsIn(t)
        S.ct.snap(finalTop(panelTargetH))
        to(\.ct, S.ct.x, 170)
        // under reduced motion no tongue, and the shape cross-fades to the panel's
        guard !reducesMotion else {
            follow = true
            snapReach()
            setShape(w: Tuning.panelDepth, h: panelTargetH, r: Tuning.panelR, f: Tuning.panelF)
            to(\.vis, 0, 100)
            later(.openDone, 180) { $0.opened() }
            return
        }

        // The pour starts where the notch touched the pointer: the reach is the anticipation, so no separate swell.
        // Height leads; the centre migrates home on the same spring as it grows; width answers 30ms behind and its
        // front edge runs a few points past. The rows land from the top once the shape is mostly out (revealAlpha).
        to(\.vis, 0, 90)
        follow = true
        springShape(h: panelTargetH, feel.sp(.pourH))
        springTo(\.ay, 0, feel.sp(.pourH))
        later(.openW, 30) { m in
            // the width pours out past the tongue as the tongue goes back into it: its tip leads the pour
            let pourW = m.feel.sp(.pourW)
            m.springShape(w: Tuning.panelDepth, r: Tuning.panelR, f: Tuning.panelF, pourW)
            m.springTo(\.ba, 0, pourW)
        }
        later(.openDone, 400) { $0.opened() }
    }

    /// The attraction put away at once: no tongue, the notch at its own place.
    func snapReach() {
        S.ay.snap(0)
        S.ba.snap(0)
        S.by.snap(notchY)
        cling.ripple = nil
    }

    func opened() {
        phase = .open
        maybeClose(pointerSpeed())
    }

    /// Why the panel closes.
    enum CloseReason {
        /// The pointer popped through the edge.
        case pop
        /// It went back over a flare and the grace ran out.
        case grace
        /// A click off it, or on a row.
        case dismissed
    }

    /// Closed by a click off it, or on a row: it drains.
    func close() {
        close(.dismissed)
    }

    /// A pop or a grace collapses straight home on springs, the end nearer where the pointer left leading, quicker
    /// the faster it left. Anything else drains as the prototype's Pour does. Under reduced motion, any close
    /// cross-fades to the notch.
    func close(_ reason: CloseReason) {
        cancel(.dwell, .grace)
        // a pointer left on the notch doesn't reopen it until it leaves, nor one left within the attraction's reach
        contact.armed = false
        attract.armed = false
        guard isLive else {
            return
        }

        cancelPrefix("open:")
        let exit = reason == .grace ? exitE(lastStageY, geometry()) : 0
        cling.attached = false
        follow = false
        phase = .closing
        // after a pop the panel holds still, rows and all, while the tongue rings: in, out, and as it comes in again,
        // what is left of the ring goes into the panel and the collapse starts (burst)
        guard reason != .pop || reducesMotion else {
            return
        }

        reveal = .rowsOut(t)
        if reducesMotion {
            let l = resting
            setShape(w: l.w, h: l.h, r: l.r, f: l.f)
            to(\.vis, 1, 120)
            later(.closeDone, 160) { $0.closed() }
            return
        }
        if reason == .grace {
            drain(leaveSpeed, kick: 0, exit)
            return
        }

        to(\.ba, 0, 100)
        // the rows fade first (60ms), then the shape drains: width leads now, height follows
        later(.closeW, 50) { m in
            let l = m.resting
            m.setShape(w: l.w, r: l.r, f: l.f, 140)
        }
        later(.closeH, 75) { $0.setShape(h: $0.resting.h, 140) }
        later(.closeVis, 150) { $0.to(\.vis, 1, 140) }
        later(.closeDone, 230) { $0.closed() }
    }

    /// The sprung drain, after a leave. The width falls on the drain spring, kicked by what is left of the ring after a
    /// pop; the notch's two ends collapse straight home on springs of their own, the end nearer where the pointer left
    /// leading, and the notch arrives past home, away from the exit, swings back a little, and settles. A faster leave
    /// gives a quicker response.
    func drain(_ speed: Double, kick: Double, _ e: Double) {
        let d = feel.sp(.drain)
        // Close speeds the whole collapse up or slows it down: the same path, in less or more time
        let resp = lerp(d.response, Tuning.drainFast, smooth(clamp(speed / Tuning.fastLeave, 0, 1))) / feel.close
        let l = resting
        springShape(w: l.w - Tuning.drainPast, r: l.r, f: l.f, SpringParams(response: resp, damping: d.damping))
        S.w.v = min(0, S.w.v) - kick * feel.close
        endsOn(e, resp * Tuning.endsShare, min(1, Tuning.endsDamping * feel.bounceScale))
        landing = l.w
        // the light comes on as it lands, or by then
        later(.closeVis, resp * 900) { $0.to(\.vis, 1, 140) }
        later(.closeDone, resp * 1000) { $0.closed() }
    }

    /// The home of one of the notch's ends.
    func home(_ end: End) -> Double {
        notchY + (end == .top ? -1 : 1) * resting.h / 2
    }

    /// The notch's ends, from where the shape is now to home ± half the notch's length. e is where the pointer left
    /// (exitE): the end on its side is kicked toward home and leads, the other starts later.
    func endsOn(_ e: Double, _ resp: Double, _ damping: Double) {
        let g = geometry(), ae = abs(e)
        let near: End = e >= 0 ? .bottom : .top, far: End = e >= 0 ? .top : .bottom
        let farHome = home(far)
        S.et.snap(g.top)
        S.eb.snap(g.top + g.h)
        S.rb.snap(0)
        S.et.v = S.ay.v - S.h.v / 2
        S.eb.v = S.ay.v + S.h.v / 2
        springTo(near.key, home(near), SpringParams(response: resp * (1 - Tuning.endLead * ae), damping: damping))
        S[keyPath: near.key].v += (near == .bottom ? -1 : 1) * Tuning.endKick * ae
        let farGo = { (m: Meniscus) in m.springTo(far.key, farHome, SpringParams(response: resp, damping: damping)) }
        if Tuning.endDelay * ae >= 4, !reducesMotion {
            to(far.key, S[keyPath: far.key].x, 60)
            later(.closeFar, Tuning.endDelay * ae, farGo)
        } else {
            farGo(self)
        }
        ends = Ends(near: near, rebound: Tuning.rebound * ae)
    }

    /// Each end eases into home over its last few points, without overshoot; as the near end gets there it gives the
    /// notch its rebound past home, away from the exit. Once all of it is still, the ends hand back.
    func updateEnds() {
        guard var E = ends else {
            return
        }

        for end in [End.top, .bottom] where !E.landed.contains(end) && abs(S[keyPath: end.key].x - home(end)) <= Tuning.endLand {
            E.landed.insert(end)
            to(end.key, home(end), 160)
            if end == E.near, E.rebound > 0.05, !reducesMotion {
                rebound(E, from: S[keyPath: end.key], home(end))
            }
        }
        ends = E
        func still(_ s: Spring, _ t: Double) -> Bool { abs(s.x - t) < 0.05 && abs(s.v) < 0.002 }
        if phase == .closed, still(S.et, home(.top)), still(S.eb, home(.bottom)), still(S.rb, 0) {
            endsOff()
        }
    }

    /// The swing past home, away from the exit, as the near end lands at T.
    private func rebound(_ E: Ends, from s: Spring, _ T: Double) {
        let p = feel.sp(.rebound), omega = 2 * Double.pi / (p.response * 1000), dir: Double = E.near == .bottom ? -1 : 1
        // an end arriving slowly is still short of home as the swing peaks: the swing carries that much more, so the
        // notch still goes the rebound past home
        let z = min(0.99, p.damping), q = (1 - z * z).squareRoot(), tp = atan2(q, z) / (omega * q)
        let d0 = s.x - T, w = s.omega, dp = (d0 + (s.v + w * d0) * tp) * exp(-w * tp)
        springTo(\.rb, 0, p)
        S.rb.v = dir * (E.rebound + max(0, -dir * dp)) * omega / peakShare(p.damping)
    }

    /// Back to one height and one centre, carrying the ends' motion: on reopening, or once home.
    func endsOff() {
        guard ends != nil else {
            return
        }

        let top = S.et.x + S.rb.x, bot = S.eb.x + S.rb.x, vt = S.et.v + S.rb.v, vb = S.eb.v + S.rb.v
        ends = nil
        S.h.x = bot - top
        S.h.v = vb - vt
        S.ay.x = (top + bot) / 2 - S.y.x
        S.ay.v = (vt + vb) / 2
        S.h.target = resting.h
        S.ay.target = 0
        S.rb.snap(0)
    }

    /// The bulge has pushed through its line into the dent, Push of the way: the dent's energy goes into the panel,
    /// and in this same frame the width starts to fall, kicked by it. The bulge rings on while the panel collapses: on
    /// into the dent, back out past its line, and settled.
    func burst() {
        guard let sn = snap, !sn.burst else {
            return
        }

        sn.burst = true
        cancel(.closeBurst)
        guard sn.closes, phase == .closing else {
            return
        }

        // from here the outline shrinks: the ring keeps its share of the way along it, wherever it is, until the notch
        // has it, and rings on there on its own spring, past the panel's close
        let O = outlineOf(geometry())
        ringAt = clamp((O.sOf(S.by.x) - O.sFlareTop) / max(1, O.sFlareBot - O.sFlareTop), 0, 1)
        ringing = true
        reveal = .rowsOut(t)
        drain(sn.speed, kick: Tuning.kickCross * sn.vCross + Tuning.kickV * clamp(sn.speed, 0, 3), sn.e)
        // it started at that moment, which may have been inside this frame: the collapse has run only since then
        lag = clamp(t - (sn.tStar ?? t), 0, 50)
    }

    /// The collapse lands: near the notch's depth the width comes the rest of the way on a critically damped spring,
    /// quick enough not to pass the notch's depth, and the landing's wobble takes over the part of its speed that
    /// carries on: under the notch's depth, back out past it, a little under again, settled. The total speed carries
    /// across, so nothing jumps. Under reduced motion there is no landing.
    func land() {
        guard let target = landing else {
            return
        }

        landing = nil
        guard !reducesMotion else {
            return
        }

        let p = feel.sp(.land), omega = 2 * Double.pi / (p.response * 1000), dip = Tuning.landDip * feel.land
        let vw = dip > 0.01 ? -dip * omega / peakShare(p.damping) : 0
        let va = S.w.v - vw, wa = max(2 * Double.pi / 90, 1.2 * max(0, -va) / max(1, S.w.x - target))
        S.w.target = target
        S.w.mode = .under
        S.w.k = wa * wa
        S.w.c = 2 * wa
        S.w.v = va
        if dip > 0.01 {
            springTo(\.lw, 0, p)
            S.lw.v += vw
        }
        to(\.vis, 1, 140)
    }

    /// Closed: the attraction takes the notch from here, sliding it home on the home spring.
    func closed() {
        phase = .closed
        jumping = nil
        if !ringing {
            cling.ripple = nil
        }
    }

    /// The ring after a leave, done or overtaken: its place goes back to being a place along the edge.
    func ringOff() {
        guard ringing else {
            return
        }

        if let ringAt {
            let O = outlineOf(geometry())
            S.by.snap(O.uOf(lerp(O.sFlareTop, O.sFlareBot, ringAt)))
        }
        ringing = false
        ringAt = nil
        cling.ripple = nil
    }

    /// Left back over a flare into the bezel (or with the cling off): the grace, shorter the faster the pointer went.
    /// Leaving through any other part of the edge never comes here while it clings: the stretch is the grace. Not while
    /// a jump's row is pressed in: the jump drains it.
    func maybeClose(_ speed: Double) {
        guard phase == .open, jumping == nil, !cling.attached, !pointerInside() else {
            return
        }

        leaveSpeed = speed
        later(.grace, lerp(Tuning.grace, Tuning.graceFast, smooth(clamp(speed / Tuning.fastLeave, 0, 1)))) { m in
            if !m.pointerInside() {
                m.close(.grace)
            }
        }
    }
}
