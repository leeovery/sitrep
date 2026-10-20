import CoreGraphics
import Foundation

/// A pointer sample, on the view's clock.
struct Sample {
    let p: Vec
    let t: Double
}

/// What the pointer is over: the notch's hit area, or the panel's content.
enum Hover {
    case notch, panel
}

/// Inside a rect or on its edge: unlike `CGRect.contains`, its far edges count too, as the prototype's do.
func inRect(_ p: Vec, _ r: CGRect) -> Bool {
    p.x >= r.minX && p.x <= r.maxX && p.y >= r.minY && p.y <= r.maxY
}

/// A quick pointer can cross the notch between two frames.
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

    /// A gap between frames no display refresh leaves: the frames slept.
    static let sleep = 100.0

    /// A frame at `now`, the last at `last`: frames that slept never saw the pointer move meanwhile, so its samples
    /// from before say nothing of its speed now, and the trail starts again.
    mutating func frame(at now: Double, after last: Double) {
        if now - last > Self.sleep {
            samples.removeAll()
        }
    }

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
