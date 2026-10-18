import CoreGraphics
import Foundation

/// A pointer sample, on the view's clock.
struct Sample {
    let p: Vec
    let t: Double
}

/// What the pointer is over: the lip's hit area, or the panel's content.
enum Hover {
    case lip, panel
}

/// The approach as it stands: the pointer's depth inside the field (infinite outside it), the gap from the
/// tongue's tip to the pointer, and whether a snap may come.
struct Attract {
    var dx = Double.infinity
    var gap = Double.infinity
    var armed = true
}

/// Inside a rect or on its edge: unlike `CGRect.contains`, its far edges count too, as the prototype's do.
func inRect(_ p: Vec, _ r: CGRect) -> Bool {
    p.x >= r.minX && p.x <= r.maxX && p.y >= r.minY && p.y <= r.maxY
}

/// A quick pointer can cross the lip between two frames.
func crosses(_ a: Vec, _ b: Vec, _ r: CGRect) -> Bool {
    let n = min(40, Int(((b - a).length / 4).rounded(.up)))
    return stride(from: 1, to: n, by: 1).contains { i in inRect(lerp(a, b, Double(i) / Double(n)), r) }
}

/// The notch's hit area: the live notch and a little, reaching past the edge; only a sliver once the panel is out.
func hitArea(w: Double, h: Double, cy: Double, live: Bool) -> CGRect {
    let reach = live ? 4 : max(12, w + Tuning.hitPad)
    let into = 8.0, hh = h + 8
    return CGRect(x: -into, y: cy - hh / 2, width: reach + into, height: hh)
}

/// The pointer's recent samples, on the view's clock, for its speed.
struct Trail {
    private var samples: [Sample] = []

    mutating func add(_ p: Vec, at now: Double) {
        samples.append(Sample(p: p, t: now))
        while samples.count > 2, now - samples[0].t > 150 {
            samples.removeFirst()
        }
    }

    /// The pointer has moved in the last 60ms: its trail still gives it a speed.
    func isFresh(at now: Double) -> Bool { samples.last.map { now - $0.t <= 60 } ?? false }

    /// The pointer's velocity over the last 50ms or so, points per ms; nothing for a pointer at rest.
    func velocity(at now: Double) -> Vec {
        guard samples.count >= 2, isFresh(at: now), let a = samples.last else {
            return Vec(0, 0)
        }

        // the oldest sample within the window: a pause before it doesn't stretch it
        var b: Sample?
        for i in stride(from: samples.count - 2, through: 0, by: -1) {
            if a.t - samples[i].t > 70 {
                break
            }
            b = samples[i]
            if a.t - samples[i].t >= 50 {
                break
            }
        }
        // the first move after a pause: its travel happened within about one event's interval, not the pause
        let dt = b.map { a.t - $0.t } ?? 16
        let from = b ?? samples[samples.count - 2]
        guard dt >= 8 else {
            return Vec(0, 0)
        }

        return (a.p - from.p) / dt
    }
}

/// The pointer touching the notch's hit area, which opens it.
struct Contact {
    enum Change {
        /// It came onto the notch, and is armed: fast, toward the edge, it opens at once.
        case touched(fast: Bool)
        case left
    }

    var touching = false
    /// A pointer left sitting on the notch as it closes doesn't open it again until it leaves.
    var armed = true
    /// The pointer at the last check.
    private var prev: Vec?

    /// The pointer this frame against the hit area, with its speed toward the edge: what changed.
    mutating func update(_ p: Vec?, _ hit: CGRect, approach: Double) -> Change? {
        let q = prev
        prev = p
        let fast = approach > Tuning.fast
        var c = p.map { inRect($0, hit) } ?? false
        if !c, fast, let p, let q, crosses(q, p, hit) {
            c = true
        }
        guard c else {
            armed = true
            defer { touching = false }
            return touching ? .left : nil
        }
        guard !touching else {
            return nil
        }

        touching = true
        return armed ? .touched(fast: fast) : nil
    }
}

extension Meniscus {
    /// The pointer since the last frame, as the prototype's pointer events give it: a move adds to its trail, and
    /// entering or leaving the lip or the panel, as they were last drawn, cancels the grace or may start it. A still
    /// pointer gets no enter or leave as the shape pours under it.
    func pointerMoved(_ p: Vec?) {
        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: now)
        }
        let over = hoverOf(p)
        guard over != hover else {
            return
        }

        let was = hover
        hover = over
        if was != nil {
            maybeClose(pointerSpeed())
        }
        if over != nil {
            cancel(.grace)
        }
    }

    /// How hard the closed lip is pulled toward the pointer, and where its tongue aims. The pull goes as
    /// 1/(distance + `attractD0`), so it grows sharply as the gap closes; it reaches the cap at a distance of the cap
    /// plus Reach, where the tongue would touch the pointer's reach and snap. The tongue never reaches past the pointer.
    /// Under reduced motion there is none: only touching the lip opens it.
    func attraction() -> (reach: Double, ty: Double, dx: Double) {
        let none = (reach: 0.0, ty: lipY, dx: Double.infinity)
        guard let p = sp, !reducesMotion, phase == .closed, settings.pull > 0 else {
            return none
        }

        let dx = p.x
        let R = Tuning.fieldR * settings.pull, dy = p.y - lipY
        guard dx < R, abs(dy) < Tuning.fieldY else {
            return none
        }

        let lipW = max(0, S.w.x)
        // the tip's aim along the edge, held near home
        let off = Tuning.attractY * tanh(dy / Tuning.attractY)
        // from the lip's crest, where the tip would aim
        let d = hypot(max(0, dx - lipW), dy - off)
        let cap = Tuning.attractCap * settings.pull
        func inv(_ x: Double) -> Double { 1 / (x + Tuning.attractD0) }
        let dFull = cap + settings.reach, dOut = max(dFull + 1, R - lipW)
        let k = clamp((inv(d) - inv(dOut)) / (inv(dFull) - inv(dOut)), 0, 1)
        let wy = 1 - smooth(clamp((abs(dy) - 90) / (Tuning.fieldY - 90), 0, 1))
        return (min(cap * k * wy, d), lipY + off, dx)
    }

    func updateField() {
        let A = attraction()
        attract.dx = A.dx
        guard phase == .closed else {
            attract.gap = .infinity
            return
        }

        let live = A.reach > 0.01
        // the pointer is back: the attraction has the edge again
        if ringing, live {
            ringOff()
        }
        let p = settings.sp(live ? .attract : .relax)
        // a leave's ring plays out on its own spring
        if !ringing {
            springTo(\.ba, A.reach, p)
            // its aim along the edge follows without overshoot: a pointer passing by stays a steady lag ahead of it
            springTo(\.by, A.ty, live ? SpringParams(response: p.response, damping: 1) : p)
        }
        // the base stays home: only the tongue reaches
        springTo(\.ay, 0, settings.sp(.home))
        // the gap from the tongue's tip to the pointer, as drawn; below Reach it can't hold back
        guard live, let sp else {
            attract.gap = .infinity
            attract.armed = true
            return
        }

        attract.gap = hypot(max(0, A.dx - max(0, S.w.x) - max(0, S.ba.x)), sp.y - S.by.x)
        if attract.gap > settings.reach + 8 {
            attract.armed = true
        }
        let slip = abs(trailVelocity().y - S.by.v)
        if attract.armed, attract.gap < settings.reach, S.ba.x >= Tuning.catch * A.reach, slip < Tuning.captureV {
            snapOpen(sp)
        }
    }

    /// The tongue can't hold back: its tip jumps to the pointer and the pour starts from there.
    func snapOpen(_ sp: Vec) {
        let tongue = settings.sp(.tongue)
        springTo(\.ba, max(S.ba.x, attract.dx - max(0, S.w.x) + Tuning.grip), tongue)
        springTo(\.by, sp.y, tongue)
        open()
    }

    /// Contact with the lip opens it: after the dwell, or at once if the pointer arrives fast.
    func updateContact(_ g: Geometry) {
        switch contact.update(sp, hitRect(g), approach: approachSpeed()) {
        case .left:
            cancel(.dwell)
        case let .touched(fast) where phase == .closed || phase == .closing:
            cancel(.grace)
            if fast {
                open()
            } else {
                // leaving first cancels it: a pass doesn't open
                later(.dwell, Tuning.dwell) { $0.open() }
            }
        case .touched, nil:
            break
        }
    }
}
