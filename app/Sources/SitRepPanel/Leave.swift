import Foundation

/// The open edge's hold on the pointer.
struct Cling {
    /// The pointer has been inside, and the edge holds it on the way out.
    var attached = false
    var ripple: Ripple?
    /// When the tongue reached Hold, sim ms.
    var hang: Double?
    /// The outline's taper where the pointer went out: under 0.5 it went back over a flare.
    var out: Double?
}

/// A tongue widening along the edge after a break: from its own width, once it starts (a ring's dents are held
/// narrow until the collapse).
struct Ripple {
    var t0: Double?
    let sigma0: Double
}

/// The tongue snapping home after it broke, then denting, before the collapse.
final class Snap {
    /// How fast the pointer went away from the edge.
    let speed: Double
    /// How far the tongue had stretched, against Hold, smoothed.
    let q: Double
    /// Where the pointer left (exitE).
    let e: Double
    let t0: Double
    /// The return spring it let go on, and whether a fast leave flung it out first ...
    let ret: SpringParams
    let flung: Bool
    /// ... and is still flinging it out.
    var flying: Bool
    /// The tongue at the last frame, and when.
    var x: Double
    var v: Double
    var tPrev: Double
    /// How many times it has gone in through its line, and how fast the first time.
    var ins = 0
    var vCross = 0.0
    /// The ring for the swing back out from the dent's deepest, and whether the dent's slower inward swing still has it.
    var ring: SpringParams?
    var inward = false
    /// When the collapse starts, sim ms.
    var tStar: Double?
    /// Since the break: when the dent was deepest, when it came back out through its line, and when it peaked after.
    var deep: Double?
    var back: Double?
    var peakT: Double?
    var burst = false

    init(speed: Double, q: Double, e: Double, t0: Double, x: Double, v: Double, ret: SpringParams, flung: Bool) {
        self.speed = speed
        self.q = q
        self.e = e
        self.t0 = t0
        tPrev = t0
        self.x = x
        self.v = v
        self.ret = ret
        self.flung = flung
        flying = flung
    }
}

/// The dent's inward swing: from the line at speed v to depth D in T ms, braking hard, on an overdamped spring
/// x = v/(b-a)·(e^(-at) - e^(-bt)), b = k·a: its deepest is at ln k/(a(k-1)), and D/(T·v) fixes k. A dent too quick
/// for that (D/(T·v) at or over 1/e) takes the ring itself, so there is none.
func dentSpring(_ v: Double, _ D: Double, _ T: Double) -> SpringParams? {
    let R = D / max(1e-6, T * v)
    guard R > 0, R < 1 / M_E - 1e-3 else {
        return nil
    }

    func f(_ k: Double) -> Double { pow(k, -1 / (k - 1)) * (k - 1) / (k * log(k)) }
    var lo = 1.0001, hi = 1e4
    for _ in 0 ..< 60 {
        let m = (lo * hi).squareRoot()
        if f(m) > R { lo = m } else { hi = m }
    }
    let k = (lo * hi).squareRoot(), a = log(k) / (T * (k - 1)), b = k * a, w = (a * b).squareRoot()
    return SpringParams(response: 2 * Double.pi / w / 1000, damping: (a + b) / (2 * w))
}

extension Meniscus {
    /// How a tongue lets go: through the edge, or back over a flare.
    enum Route {
        case edge, side
    }

    /// While open, the edge bows toward a pointer near it, and once the pointer has been inside, holds it on the way
    /// out, wherever it leaves: a tongue stretches after it with its tip just past the pointer, on a spring quick
    /// enough to keep up with a slow leave, and follows it round a corner. It breaks when it has stretched to Hold and
    /// hung there a beat, or when the pointer gets `outrun` ahead of its tip: a fast leave outruns it almost at once.
    /// Only a pointer going back over a flare into the bezel gets the grace.
    func updateCling(_ g: Geometry) {
        guard phase == .open, settings.pull > 0 else {
            if phase == .open, S.ba.target != 0 {
                S.ba.to(0, 120)
            }
            cling.attached = false
            cling.hang = nil
            cling.out = nil
            return
        }

        let O = outlineOf(g)
        let q = sp.map { Vec($0.x, $0.y - O.top) }
        let near = q.map { nearestOn(O, $0) }
        if let near, near.inside {
            // inside, the edge holds the pointer afresh
            cling = Cling(attached: true)
        } else if cling.attached {
            holdOrBreak(O, q, near)
        }
        // broke: the ring and the collapse have the shape now
        guard phase == .open else {
            return
        }

        bowOrStretch(O, near)
    }

    /// The pointer is out and the edge holds it: it lets go over a flare, or when outrun, or after hanging at Hold.
    private func holdOrBreak(_ O: Outline, _ q: Vec?, _ near: Nearest?) {
        guard let q, let near else {
            letGo(cling.out != nil && S.ba.x > 1 ? .edge : .side, pointerSpeed())
            return
        }

        // where it went out
        let out = cling.out ?? outlineAt(O, near.s).taper
        cling.out = out
        // over a flare: back into the bezel
        guard out >= 0.5 else {
            letGo(.side, pointerSpeed())
            return
        }

        let at = outlineAt(O, O.sOf(S.by.x)), a = S.ba.x * at.taper
        let r = q - at.p
        let along = r.x * at.n.x + r.y * at.n.y, side = abs(r.y * at.n.x - r.x * at.n.y)
        let ahead = hypot(max(0, along - a), max(0, side - Tuning.outrunSide))
        if ahead > Tuning.outrun {
            letGo(.edge)
        } else if a >= settings.hold - 0.5 {
            let hang = cling.hang ?? t
            cling.hang = hang
            if t - hang >= Tuning.hang {
                letGo(.edge)
            }
        }
    }

    /// The open edge reaches for the pointer: bowing toward it from inside or near outside, or stretching after it as
    /// the tongue once it has left; otherwise it settles.
    private func bowOrStretch(_ O: Outline, _ near: Nearest?) {
        // how far the pointer stands out of the edge (below 0: inside)
        let s = near.map { $0.inside ? -$0.d : $0.d } ?? -Double.infinity
        let bow = Tuning.clingA * settings.pull
        var a = 0.0, tongue = false
        if near != nil, cling.attached {
            if s <= 0 {
                a = bow * smooth(clamp(1 + s / Tuning.clingNear, 0, 1))
            } else {
                a = min(settings.hold, max(bow, s + Tuning.grip))
                tongue = true
            }
        } else if let near, s > 0, s < Tuning.clingNear, outlineAt(O, near.s).taper > 0.5, cling.ripple == nil, snap == nil {
            // reaching for a pointer outside
            a = bow * smooth(1 - s / Tuning.clingNear)
        }

        guard let near, a > 0 || cling.attached else {
            // it keeps its spring: the ring's settle, or the cling's
            S.ba.target = 0
            if let t0 = cling.ripple?.t0, t - t0 > 2 * Tuning.rippleMS, abs(S.ba.x) < 0.05 {
                cling.ripple = nil
            }
            return
        }

        let u = O.uOf(near.s)
        // a new bump starts at the pointer
        if abs(S.ba.x) < 0.1, abs(S.ba.v) < 0.01 {
            S.by.snap(u)
        }
        S.ba.springTo(a, settings.sp(tongue ? .tongue : .cling))
        S.by.springTo(u, settings.sp(tongue ? .tongue : .clingY))
    }

    /// Where the pointer left, against home: 0 at home, ±1 at the front run's end on that side and anything past it
    /// (a corner, the top, the bottom).
    func exitE(_ y: Double?, _ g: Geometry) -> Double {
        guard let y else {
            return 0
        }

        let runTop = g.top + g.ft + g.rt, runBot = g.top + g.h - g.fb - g.rb, home = lipY
        return y >= home
            ? clamp((y - home) / max(1, runBot - home), 0, 1)
            : -clamp((home - y) / max(1, home - runTop), 0, 1)
    }

    /// The tongue breaks. Through the edge, the bulge travels back to its line on the return spring while the panel
    /// holds still, quicker the less it had stretched; a fast leave first throws it out after the cursor, by as much
    /// as the pointer's speed gives it, so it still pulls before it pings. As it passes through its line the collapse
    /// starts, and it goes over to the ring, which plays on during the collapse: a dent, back out, in again
    /// (watchRing). Back over a flare, it lets go and the grace runs, shorter the faster it went.
    func letGo(_ route: Route, _ speed: Double = 0) {
        cling.attached = false
        let g = geometry(), O = outlineOf(g), at = outlineAt(O, O.sOf(S.by.x))
        let letGoY = O.top + at.p.y
        cling.hang = nil
        cling.out = nil
        guard route == .edge else {
            cling.ripple = Ripple(t0: t, sigma0: bumpOf().sigma)
            S.ba.springTo(0, settings.sp(.letGo))
            maybeClose(speed)
            return
        }

        let stretch = max(0, S.ba.x * at.taper), tv = trailVelocity()
        let away = max(0, tv.x * at.n.x + tv.y * at.n.y), along = tv.x * -at.n.y + tv.y * at.n.x
        let q = smooth(clamp(stretch / settings.hold, 0, 1))
        var rp = settings.sp(.ret)
        rp.response = lerp(Tuning.returnFast, rp.response, q)
        S.ba.springTo(0, rp)
        let flung = fling(away: away, along: along, rp)
        let sn = Snap(speed: away, q: q, e: exitE(letGoY, g), t0: t, x: S.ba.x, v: S.ba.v, ret: rp, flung: flung)
        snap = sn
        // a return too damped to cross still lets go
        later(.closeBurst, 2.2 * rp.response * 1000) { m in
            if let sn = m.snap, !sn.burst {
                sn.vCross = max(0, -m.S.ba.v)
                m.burst()
            }
        }
        close(.pop)
    }

    /// Thrown out after the cursor: a fling past what the tongue would swing out to by itself on its return spring.
    /// Whether it was.
    private func fling(away: Double, along: Double, _ rp: SpringParams) -> Bool {
        let omega = 2 * Double.pi / (rp.response * 1000)
        let fling = min(settings.hold, Tuning.fling * settings.pull * tanh(away / Tuning.flingV))
        let want = max(Tuning.ringMin, fling), out = S.ba.x + max(0, S.ba.v) / omega * peakShare(rp.damping)
        guard out < want else {
            return false
        }

        let fo = SpringParams(response: Tuning.flingOut, damping: rp.damping), wo = 2 * Double.pi / (Tuning.flingOut * 1000)
        S.ba.springTo(0, fo)
        S.ba.v = (want - S.ba.x) * wo / peakShare(fo.damping)
        if abs(along) > 0.05 {
            S.by.to(S.by.x + Tuning.flingAlong * along * 40, 90)
            S.by.v = Tuning.flingAlong * along
        }
        return true
    }

    /// The release, once a frame: the bulge's peak out, where it passes through its line (the collapse starts, and it
    /// goes over to the ring, keeping its speed), the dent's deepest (the ripple starts to spread), back out past its
    /// line, and its peak out. Watched until it has swung back out.
    func watchRing() {
        guard let sn = snap else {
            return
        }

        let x = S.ba.x, v = S.ba.v, since = t - sn.t0
        // flung out to its peak: from here it returns
        if sn.flying, v <= 0 {
            sn.flying = false
            S.ba.springTo(0, sn.ret)
        }
        if sn.x > 0, x <= 0 {
            sn.ins += 1
            if sn.ins == 1 {
                throughLine(sn, x, v)
            }
        } else if sn.x < 0, x >= 0, sn.back == nil {
            sn.back = since
        }
        sn.tPrev = t
        if sn.v < 0, v >= 0, x < 0, sn.deep == nil {
            sn.deep = since
            // from its deepest the ring takes it back out
            if sn.inward, let ring = sn.ring {
                sn.inward = false
                S.ba.springTo(0, ring)
            }
            spreadRipple()
        }
        if sn.v > 0, v <= 0, x > 0, sn.back != nil, sn.peakT == nil {
            sn.peakT = since
        }
        sn.x = x
        sn.v = v
        if sn.peakT != nil || since > 1200 {
            snap = nil
            spreadRipple()
        }
    }

    /// The bulge goes in through its line the first time: the ring, the dent it swings into, and when the collapse
    /// starts.
    private func throughLine(_ sn: Snap, _ x: Double, _ v: Double) {
        sn.vCross = max(0, -v)
        // the ring, for the swing back out from the deepest; the inward swing to there is slower, as deep
        var rp = settings.sp(.ring)
        rp.response = lerp(Tuning.ringFast, rp.response, sn.q)
        sn.ring = rp
        let wr = 2 * Double.pi / (lerp(Tuning.dentRefFast, Tuning.dentRef, sn.q) * 1000)
        let inward = dentSpring(sn.vCross, sn.vCross / wr * peakShare(rp.damping), lerp(Tuning.dentInFast, Tuning.dentIn, sn.q))
        S.ba.springTo(0, inward ?? rp)
        sn.inward = inward != nil
        cling.ripple = Ripple(t0: nil, sigma0: Tuning.ringSigma)
        // when the dent will be deepest, from its spring alone; the collapse starts Push of that time after the line,
        // to the ms: when that fell inside this frame, it has run only since then
        var look = S.ba, toDeepest = 0.0
        while toDeepest < 600, look.v < 0 {
            look.step(1)
            toDeepest += 1
        }
        let tCross = sn.tPrev + (t - sn.tPrev) * sn.x / max(1e-6, sn.x - x)
        let tStar = tCross + settings.push / 100 * (t + toDeepest - tCross)
        sn.tStar = tStar
        if tStar <= t {
            burst()
        } else {
            later(.closePush, tStar - t) { m in
                if m.snap === sn, !sn.burst {
                    m.burst()
                }
            }
        }
    }

    /// A ring's ripple, held narrow until now, starts to spread.
    private func spreadRipple() {
        if cling.ripple != nil, cling.ripple?.t0 == nil {
            cling.ripple?.t0 = t
        }
    }

    /// The tongue as drawn: its tip narrows and its flanks hollow as it stretches, against Hold leaving and against
    /// the attraction's cap approaching; after a break it widens as it pings back, a ripple running along the edge.
    func bumpOf() -> Bump {
        let a = S.ba.x
        if let ripple = cling.ripple {
            let sg = ripple.t0.map { lerp(ripple.sigma0, Tuning.rippleSigma, easeOut(clamp((t - $0) / Tuning.rippleMS, 0, 1))) } ?? ripple.sigma0
            return Bump(a: a, y: S.by.x, sigma: sg, lambda: sg)
        }

        let full = phase == .open || phase == .closing ? settings.hold : Tuning.attractCap * max(0.05, settings.pull)
        // a flung bulge is as narrow as a stretched tongue
        let q = snap.map { $0.flung && $0.ins == 0 } == true ? 1 : smooth(clamp(a / full, 0, 1))
        return Bump(a: a, y: S.by.x, sigma: lerp(Tuning.sigmaWide, Tuning.sigmaTip, q), lambda: lerp(Tuning.flankWide, Tuning.flankTip, q))
    }
}
