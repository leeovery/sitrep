import CoreGraphics
import Foundation

// One shape from lip to panel. Its coordinates are the edge's own: x is depth from the screen's edge into the
// screen, y runs down; the view mirrors them for the right edge.

/// The lip family, through the two drawn lips: 7 deep × 76 long, and 15 × 124. Each end is an S-curve of length
/// e = r + f, and r and f split it as the panel does (24 : 18).
struct LipShape: Equatable {
    var w, h, r, f: Double

    /// The prototype's `lipShape(w)`.
    init(_ w: Double) {
        let e = 29 + (w - 7) * 19 / 8
        self.w = w
        h = 76 + (w - 7) * 6
        r = e * 4 / 7
        f = e * 3 / 7
    }

    static let rest = LipShape(7), needs = LipShape(15)
    /// The deepest a new ask can swell it, on the Swell dial.
    static let deepestSwell = LipShape(Dial.swell.range.upperBound)
}

/// A cubic Bézier; a line is one too.
struct Cubic {
    var p0, p1, p2, p3: Vec
}

func bezAt(_ q: Cubic, _ t: Double) -> Vec {
    let u = 1 - t
    let a = u * u * u * q.p0 + 3 * u * u * t * q.p1
    return a + 3 * u * t * t * q.p2 + t * t * t * q.p3
}

func segLine(_ a: Vec, _ b: Vec) -> Cubic {
    Cubic(p0: a, p1: lerp(a, b, 1.0 / 3), p2: lerp(a, b, 2.0 / 3), p3: b)
}

func splitCubic(_ p0: Vec, _ p1: Vec, _ p2: Vec, _ p3: Vec) -> [Vec] {
    func m(_ a: Vec, _ b: Vec) -> Vec { (a + b) / 2 }
    let p01 = m(p0, p1), p12 = m(p1, p2), p23 = m(p2, p3)
    let p012 = m(p01, p12), p123 = m(p12, p23), mid = m(p012, p123)
    return [p01, p012, mid, mid, p123, p23, p3]
}

/// One end of the shape: from the edge point (0, 0) to the front at (w, e), y down from the shape's top, as the
/// seven points after (0, 0) of a cubic, a line and a cubic. Two forms share them and are blended by depth:
///  - the lip: the drawn S-curve (0,0) (0,a) (w,a-4) (w,e), split in two halves;
///  - the panel: a concave flare of radius f, a straight run, a convex corner of radius r, squeezed sideways while
///    the depth can't yet hold both arcs.
func endCurve(_ w: Double, _ r: Double, _ f: Double) -> [Vec] {
    let e = r + f
    let a = 17 + (e - 29) * 10 / 19
    let lip = splitCubic(Vec(0, 0), Vec(0, a), Vec(w, a - 4), Vec(w, e))
    let sc = min(1, w / max(e, 1e-6))
    let fx = f * sc, rx = r * sc, k = Tuning.k
    let pan = [
        Vec(0, k * f), Vec(fx - k * fx, f), Vec(fx, f),
        Vec(w - rx, f),
        Vec(w - rx + k * rx, f), Vec(w, f + r - k * r), Vec(w, e),
    ]
    let s = smooth(clamp((w - 24) / 66, 0, 1))
    return zip(lip, pan).map { lerp($0, $1, s) }
}

/// The tongue as drawn: how far it stands out (a dent below 0), where along the edge it is, stage y, and its
/// profile's tip and flanks.
struct Bump {
    var a, y, sigma, lambda: Double
}

/// The live shape, from the springs. The two ends may differ (rt, ft against rb, fb); they don't now, but the
/// drawing keeps them apart.
struct Geometry {
    var w, h, cy: Double
    var rt, ft, rb, fb: Double
    var bump: Bump?

    var top: Double { cy - h / 2 }
}

/// The outline's seven pieces, y down from the shape's top: the top flare, the top run, the top corner, the front
/// run, the bottom corner, the bottom run, the bottom flare. On the lip the runs are nothing and the rest are its
/// S-curves.
func outlineSegs(_ g: Geometry) -> [Cubic] {
    let top = endCurve(g.w, g.rt, g.ft)
    let bottom = endCurve(g.w, g.rb, g.fb).map { Vec($0.x, g.h - $0.y) }
    let (c1, c2, j1, j2, c3, c4, p) = (top[0], top[1], top[2], top[3], top[4], top[5], top[6])
    let (b1, b2, k1, k2, b3, b4, bp) = (bottom[0], bottom[1], bottom[2], bottom[3], bottom[4], bottom[5], bottom[6])
    return [
        Cubic(p0: Vec(0, 0), p1: c1, p2: c2, p3: j1), segLine(j1, j2), Cubic(p0: j2, p1: c3, p2: c4, p3: p),
        segLine(p, bp),
        Cubic(p0: bp, p1: b4, p2: b3, p3: k2), segLine(k2, k1), Cubic(p0: k1, p1: b2, p2: b1, p3: Vec(0, g.h)),
    ]
}

/// The outline as one curve, from the top edge point round the front to the bottom one: samples about 3 apart
/// with their arc length s, outward normal n, the normal blurred along the curve (nb), and the taper that keeps a
/// tongue off the flares. Its coordinate u along it is stage y on the front run, and runs on round the corners by
/// arc length: a tongue's place (`S.by`) is a u.
struct Outline {
    let pts: [Vec]
    let s: [Double]
    let n: [Vec]
    let nb: [Vec]
    let taper: [Double]
    let sFlareTop, sFlareBot, sFront: Double
    let top, yFront: Double

    var count: Int { pts.count }

    func uOf(_ sv: Double) -> Double { sv - sFront + yFront + top }

    func sOf(_ u: Double) -> Double { u - top - yFront + sFront }
}

func outlineOf(_ g: Geometry) -> Outline {
    var pts = [Vec(0, 0)], ends: [Int] = []
    for q in outlineSegs(g) {
        var len = 0.0, prev = q.p0
        for i in 1 ... 16 {
            let a = bezAt(q, Double(i) / 16)
            len += (a - prev).length
            prev = a
        }
        if len > 0.01 {
            let n = max(1, Int((len / 3).rounded(.up)))
            for i in 1 ... n {
                pts.append(bezAt(q, Double(i) / Double(n)))
            }
        }
        ends.append(pts.count - 1)
    }

    let count = pts.count
    var sa = [Double](repeating: 0, count: count)
    for i in 1 ..< count {
        sa[i] = sa[i - 1] + (pts[i] - pts[i - 1]).length
    }
    let n: [Vec] = (0 ..< count).map { i in
        let t = pts[min(count - 1, i + 1)] - pts[max(0, i - 1)]
        return Vec(t.y, -t.x) / t.divisor
    }
    let blur = Tuning.normalBlur
    let nb: [Vec] = (0 ..< count).map { i in
        func weight(_ j: Int) -> Double { exp(-pow(abs(sa[i] - sa[j]) / blur, 2) / 2) }
        var sum = Vec(0, 0)
        var j = i
        while j >= 0, sa[i] - sa[j] < 3 * blur {
            sum += weight(j) * n[j]
            j -= 1
        }
        j = i + 1
        while j < count, sa[j] - sa[i] < 3 * blur {
            sum += weight(j) * n[j]
            j += 1
        }
        return sum / sum.divisor
    }
    let sFlareTop = sa[ends[0]], sFlareBot = sa[ends[5]]
    let taper = sa.map { smooth(clamp(($0 - sFlareTop) / Tuning.taper, 0, 1)) * smooth(clamp((sFlareBot - $0) / Tuning.taper, 0, 1)) }
    return Outline(
        pts: pts, s: sa, n: n, nb: nb, taper: taper,
        sFlareTop: sFlareTop, sFlareBot: sFlareBot, sFront: sa[ends[2]],
        top: g.top, yFront: pts[ends[2]].y
    )
}

/// The outline at an arc length: its point, normal and taper.
struct OutlinePoint {
    let p: Vec
    let n: Vec
    let taper: Double
}

func outlineAt(_ O: Outline, _ s: Double) -> OutlinePoint {
    let S0 = O.s
    var lo = 0, hi = O.count - 1
    if s <= 0 {
        hi = 1
    } else if s >= S0[hi] {
        lo = hi - 1
    } else {
        while hi - lo > 1 {
            let m = (lo + hi) >> 1
            if S0[m] <= s { lo = m } else { hi = m }
        }
    }
    let t = clamp((s - S0[lo]) / max(1e-6, S0[hi] - S0[lo]), 0, 1)
    let n = lerp(O.n[lo], O.n[hi], t)
    return OutlinePoint(p: lerp(O.pts[lo], O.pts[hi], t), n: n / n.divisor, taper: lerp(O.taper[lo], O.taper[hi], t))
}

/// The outline's point nearest q (y down from the shape's top): how far, its arc length, and whether q is inside
/// the shape.
struct Nearest {
    let d: Double
    let s: Double
    let inside: Bool
}

func nearestOn(_ O: Outline, _ q: Vec) -> Nearest {
    var best = Double.infinity, bs = 0.0, inside = false
    let P = O.pts
    for i in 0 ..< O.count - 1 {
        let a = P[i], b = P[i + 1], dx = b.x - a.x, dy = b.y - a.y
        let l2 = dx * dx + dy * dy > 0 ? dx * dx + dy * dy : 1e-9
        let t = clamp(((q.x - a.x) * dx + (q.y - a.y) * dy) / l2, 0, 1)
        let d = hypot(a.x + t * dx - q.x, a.y + t * dy - q.y)
        if d < best {
            best = d
            bs = O.s[i] + t * (O.s[i + 1] - O.s[i])
        }
        if (a.y > q.y) != (b.y > q.y), q.x < a.x + (q.y - a.y) * dx / (b.y - a.y) {
            inside.toggle()
        }
    }
    // the edge's line closes it: a ray into the screen from q beyond the edge would cross it
    if q.x < 0, q.y > 0, q.y < P[O.count - 1].y {
        inside.toggle()
    }
    return Nearest(d: best, s: bs, inside: inside)
}

/// The tongue's profile along the edge, u from its tip: a rounded tip about sigma wide on concave flanks that fall
/// away over lambda, a liquid pulled thin. Near the tip it is a Gaussian of sigma; with lambda = sigma it is a
/// plain bell.
func profile(_ u: Double, _ sigma: Double, _ lambda: Double) -> Double {
    let c = sigma * sigma / lambda
    return exp(-((u * u + c * c).squareRoot() - c) / lambda)
}

/// The tongue (or a dent, or the ripple) moves the outline. On the open panel it can sit anywhere along the outline
/// short of the flares: centred at its place s0, each point moves by the profile in arc length, out along its own
/// normal far from the tip and along the tip's own direction near it, so a tongue at a corner is the same shape as
/// one on the front. On the lip it draws the whole lip out sideways, each point in proportion to how far it already
/// stands from the edge, so the lip's own S-curves stretch into the tongue's flanks. The two blend as the lip's form
/// blends into the panel's. A ring after a leave sits at its share of the way between the flares instead.
/// Gives the moved samples, and the outline where the bump is centred.
func displaced(_ g: Geometry, _ O: Outline, _ b: Bump, ringAt: Double?) -> (points: [Vec], centre: OutlinePoint) {
    let sB = smooth(clamp((g.w - 24) / 66, 0, 1))
    let s0 = ringAt.map { lerp(O.sFlareTop, O.sFlareBot, $0) } ?? O.sOf(b.y)
    let at = outlineAt(O, s0), n0 = at.n
    let wl = max(1, g.w), yc = ringAt == nil ? b.y - g.top : at.p.y
    let points = O.pts.indices.map { i in
        let p = O.pts[i]
        var d = Vec(0, 0)
        if sB < 1 {
            d.x += (1 - sB) * b.a * profile(p.y - yc, b.sigma, b.lambda) * clamp(p.x / wl, 0, 1)
        }
        if sB > 0 {
            let m = profile(O.s[i] - s0, b.sigma, b.lambda), D = b.a * m * O.taper[i]
            if abs(D) > 1e-4 {
                let u = O.nb[i] * (1 - m) + n0 * m
                d += sB * D * u / u.divisor
            }
        }
        return p + d
    }
    return (points, at)
}

/// The outline as a path in stage coordinates: the plain curves, or a smooth curve through the moved samples
/// (Catmull-Rom, as cubics) when a bump has moved them.
func shapePath(_ g: Geometry, _ moved: [Vec]?) -> CGPath {
    let path = CGMutablePath()
    func pt(_ v: Vec) -> CGPoint { CGPoint(x: v.x, y: g.top + v.y) }

    // it starts and ends a few points past the screen's edge, so no seam shows where its black meets the bezel's
    path.move(to: pt(Vec(-4, 0)))
    path.addLine(to: pt(Vec(0, 0)))
    if let Q = moved {
        let n = Q.count
        for i in 0 ..< n - 1 {
            let a = Q[max(0, i - 1)], b = Q[i], c = Q[i + 1], d = Q[min(n - 1, i + 2)]
            path.addCurve(to: pt(c), control1: pt(b + (c - a) / 6), control2: pt(c - (d - b) / 6))
        }
    } else {
        for c in outlineSegs(g) {
            path.addCurve(to: pt(c.p3), control1: pt(c.p1), control2: pt(c.p2))
        }
    }
    path.addLine(to: pt(Vec(-4, g.h)))
    path.closeSubpath()
    return path
}
