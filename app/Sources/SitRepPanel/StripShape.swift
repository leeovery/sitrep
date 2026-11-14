import CoreGraphics
import Foundation

// The strip and its tabs: one black, drawn as paths in the edge's own coordinates, x into the screen from its edge.
// Its two ends are the board's S, the same in every frame: at the top, and at the bottom mirrored back into the bezel;
// at Full under the menu bar and 26pt over the screen's bottom, at Grows wherever its springs carry them. With nothing
// running, Grows, the strip narrows and shortens into the notch at rest, its ends morphing into the notch's. A tab near
// either end fits into the strip's shape: its edge runs back into the strip and meets the S's lower curve in a fillet.

/// A tab as drawn: its depth out of the strip (a dent below 0), its body's height and centre, its front corners'
/// radius, and a dent's flares, each shortened where the straight edge runs out under the top end or over the bottom.
struct TabGeometry {
    let w, h, cy, r, ft, fb: Double

    var yt: Double { cy - h / 2 }
    var yb: Double { cy + h / 2 }
}

extension Strip {
    /// Where the full strip's bottom end leaves the screen's edge, over the screen's bottom.
    var bottomEnd: Double { stage.height - StripTuning.bottomEnd }

    /// From an end's top to a mark's centre at the end of the strip: the end, the board's pad, half a ring and Room.
    var endPad: Double { StripTuning.topEnd + StripTuning.padTop + StripTuning.mark / 2 + feel.room }

    /// The full strip's first mark's centre: Room further under the top end's S than the board has it.
    var firstY: Double { stage.menu + endPad }

    /// How many places the full strip holds, each hairline between two sections taking 13pt more than a step: Full,
    /// where Max's slider runs to.
    func fullPlaces(hairlines: Int) -> Int {
        let hair = Double(hairlines) * StripTuning.hairExtra
        var places = 1
        while firstY + Double(places) * StripTuning.pitch + hair <= bottomEnd - endPad {
            places += 1
        }
        return places
    }

    /// How far the column has drawn back into the notch at rest, 0 to 1.
    var inNotch: Double { clamp(drawnIn.x, 0, 1) }

    /// How deep the strip is as it crosses to the other edge, against its 36: 1 but while it drains and grows back.
    var across: Double { max(0, sw.x) / StripTuning.width }

    /// The column's depth now: the strip's 36, narrowing to the notch's 7, and as it crosses.
    var front: Double { lerp(StripTuning.width, StripTuning.notchWidth, inNotch) * across }

    /// Its ends now, in the top end's frame: the board's S, becoming the notch's S-curve, at its depth as it crosses;
    /// and how long.
    var endCurve: [Vec] {
        let sx = across
        return zip(StripTuning.sCurve, StripTuning.notchCurve).map { q, n in
            let p = lerp(q, n, inNotch)
            return Vec(p.x * sx, p.y)
        }
    }
    var endLength: Double { lerp(StripTuning.topEnd, StripTuning.notchEnd, inNotch) }

    /// How far inside an end a tab's edge may come: the first mark's open tab's, its fillet meeting the S; out of the
    /// notch at rest, its tab centred on it.
    private var tabClear: Double { lerp(StripTuning.tabTop + feel.room, StripTuning.notchClear, inNotch) }

    /// The highest a tab's top may be, and the lowest its body may reach, the mirror of the top.
    var topClear: Double { yt.x + tabClear }
    var botClear: Double { yb.x - tabClear }

    /// The highest a tab's body may be centred under a limit.
    func minCy(_ h: Double, _ lim: Double) -> Double { lim + h / 2 }

    /// Where a tab settles for a mark: centred on it, held between the two.
    func tabTargetY(_ key: MarkKey, _ h: Double) -> Double {
        clamp(yOf(key), minCy(h, topClear), botClear - h / 2)
    }

    /// A tab's body, centred on its mark's height, held between the strip's ends as above; never taller than the room
    /// between, even as its spring overshoots (the count's tab, at its tallest). A dent's flares stay on the straight
    /// edge, under the top end's S and over the bottom end's.
    func tabGeometry(_ tab: StripTab) -> TabGeometry {
        let lim = topClear, bot = botClear, flare = StripTuning.flare, end = endLength
        let h = clamp(tab.h.x, 0, bot - minCy(0, lim))
        let cy = clamp(tab.y.x, minCy(h, lim), bot - h / 2)
        var w = tab.w.x - tab.press.x
        if w < 0 {
            w = -StripTuning.dentGive * tanh(-w / StripTuning.dentGive)
        }
        let yt = cy - h / 2, yb = cy + h / 2
        return TabGeometry(
            w: w, h: h, cy: cy, r: min(StripTuning.corner, h / 2),
            ft: min(flare, max(0, yt - self.yt.x - end)), fb: min(flare, max(0, self.yb.x - end - yb))
        )
    }

    /// The strip: from its top end, curving into the bezel, down its straight edge to its bottom end, the top's
    /// mirrored, curving back into the bezel; with nothing running, Grows, the notch at rest. A tab drawn back past the
    /// edge dents it, always on the straight edge. Drained all the way as it crosses, there is none.
    func stripPath(_ geometries: [TabGeometry]) -> CGPath {
        let path = CGMutablePath(), q = endCurve, yT = yt.x, yB = yb.x
        guard sw.x >= 0.05 else {
            return path
        }

        func T(_ p: Vec) -> CGPoint { CGPoint(x: p.x, y: yT + p.y) }
        func B(_ p: Vec) -> CGPoint { CGPoint(x: p.x, y: yB - p.y) }
        path.move(to: CGPoint(x: -4, y: yT))
        path.addLine(to: T(q[0]))
        path.addCurve(to: T(q[3]), control1: T(q[1]), control2: T(q[2]))
        path.addCurve(to: T(q[6]), control1: T(q[4]), control2: T(q[5]))
        var y = yT + q[6].y
        for g in geometries.filter({ $0.w < -0.01 }).sorted(by: { $0.yt < $1.yt }) where g.yt - g.ft >= y {
            addDent(path, g, base: front)
            y = g.yb + g.fb
        }
        path.addLine(to: B(q[6]))
        path.addCurve(to: B(q[3]), control1: B(q[5]), control2: B(q[4]))
        path.addCurve(to: B(q[0]), control1: B(q[2]), control2: B(q[1]))
        path.addLine(to: CGPoint(x: -4, y: yB))
        path.closeSubpath()
        return path
    }

    /// A tab: its own outline, starting just inside the strip's edge so the two blacks meet with no seam, round its
    /// front and back, closing inside the strip. Its top fillet leaves the S's lower curve, or the straight edge under
    /// it; its bottom the same against the bottom end's S.
    func tabPath(_ g: TabGeometry) -> CGPath {
        let path = CGMutablePath()
        guard g.w > 0.01 else {
            return path
        }

        let ends = tabEnds(g), top = ends.top, bot = ends.bottom, rx = ends.rx, r = g.r, k = Tuning.k
        let xr = front + g.w, xin = min(top[0].x, bot[0].x) - 1
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
        path.move(to: P(xin, top[0].y))
        path.addLine(to: top[0])
        path.addCurve(to: top[3], control1: top[1], control2: top[2])
        path.addLine(to: P(xr - rx, g.yt))
        path.addCurve(to: P(xr, g.yt + r), control1: P(xr - rx + k * rx, g.yt), control2: P(xr, g.yt + r - k * r))
        path.addLine(to: P(xr, g.yb - r))
        path.addCurve(to: P(xr - rx, g.yb), control1: P(xr, g.yb - r + k * r), control2: P(xr - rx + k * rx, g.yb))
        path.addLine(to: bot[3])
        path.addCurve(to: bot[0], control1: bot[2], control2: bot[1])
        path.addLine(to: P(xin, bot[0].y))
        path.closeSubpath()
        return path
    }

    /// Where a tab's top and its bottom meet the strip's ends: each fillet in the top end's frame (the bottom's
    /// mirrored into it), for the frame and the tests.
    func tabFit(_ g: TabGeometry) -> (top: StripFit, bottom: StripFit) {
        let q = endCurve, e = endLength, k = inNotch
        return (StripFit(g.yt - yt.x, curve: q, end: e, drawnIn: k), StripFit(yb.x - g.yb, curve: q, end: e, drawnIn: k))
    }

    /// A tab's top and bottom ends: from the strip's edge, along its fillet, into its edge, as cubics on the screen,
    /// the bottom's mirrored, and how far round its front corners reach across.
    private func tabEnds(_ g: TabGeometry) -> (top: [CGPoint], bottom: [CGPoint], rx: Double) {
        let sc = min(1, g.w / (g.r + StripTuning.flare)), rx = g.r * sc, xMax = front + g.w - rx
        let fit = tabFit(g), yT = g.yt - yt.x, yB = yb.x - g.yb, top = yt.x, bottom = yb.x
        let topEnd = fit.top.cubic(yT, sc, xMax).map { CGPoint(x: $0.x, y: top + $0.y) }
        let bottomEnd = fit.bottom.cubic(yB, sc, xMax).map { CGPoint(x: $0.x, y: bottom - $0.y) }
        return (topEnd, bottomEnd, rx)
    }
}

/// Where a tab's top or bottom edge meets the strip's own shape, which never changes. In the top end's frame (x out
/// from the screen's edge, y down from the end's top; the bottom end mirrored into it), a circle of radius `rho`
/// tangent to the strip's edge at a point on the S's lower curve or the straight edge under it, and to the tab's edge,
/// level at `yr`. `rho` is the flare's unless that would leave the S higher than where it has turned 70°; then as big
/// as fits under there, never under 2. The end is the board's S, or on its way to the notch's (`drawnIn` of the way),
/// whose tab rides higher up it: the notch has no bump to keep off, so its fillet is the flare's, and above the lower
/// curve it is on the upper one.
struct StripFit: Equatable {
    /// Where the fillet leaves the strip's edge, and the edge's direction there.
    let x, y, phi: Double
    let rho: Double
    /// How far along the S's lower curve it leaves, 1 on the straight edge under it, below 0 on the upper curve.
    let t: Double

    var onS: Bool { t < 1 }

    private typealias Point = (x: Double, y: Double, phi: Double, t: Double)

    init(_ yr: Double, curve q: [Vec] = StripTuning.sCurve, end: Double = StripTuning.topEnd, drawnIn: Double = 0) {
        let flare = StripTuning.flare, lower = Array(q[3 ... 6]), upper = Array(q[0 ... 3])
        func onLower(_ t: Double) -> Point { Self.at(lower, t, from: 0) }
        func onUpper(_ t: Double) -> Point { Self.at(upper, t, from: -1) }
        let keep = onLower(Self.solve { onLower($0).phi >= StripTuning.fitKeep })
        var rho = flare
        if Self.off(keep, flare, yr) > 0 {
            rho = max(StripTuning.fitMin, (yr - keep.y) / (1 - cos(keep.phi)))
        }
        rho = lerp(rho, flare, drawnIn)
        if yr - rho >= end {
            self.init((q[6].x, yr - rho, .pi / 2, 1), rho: rho)
        } else if Self.off(onLower(0), rho, yr) < 0 {
            self.init(onLower(Self.solve { Self.off(onLower($0), rho, yr) > 0 }), rho: rho)
        } else if Self.off(onUpper(0), rho, yr) < 0 {
            self.init(onUpper(Self.solve { Self.off(onUpper($0), rho, yr) > 0 }), rho: rho)
        } else {
            // a circle tangent to the edge where the end leaves it
            self.init(onUpper(0), rho: max(0, min(rho, yr)))
        }
    }

    private init(_ p: Point, rho: Double) {
        x = p.x
        y = p.y
        phi = p.phi
        self.rho = rho
        t = p.t
    }

    /// The fillet as a cubic, from where it leaves the strip's edge, on its tangent, into the tab's edge, level:
    /// across, squeezed with the tab's depth as a flare is (`sc`), and never past where the tab's front corner starts.
    func cubic(_ yr: Double, _ sc: Double, _ xMax: Double) -> [Vec] {
        let length = rho * tan(phi / 2), k = 4.0 / 3 * tan(phi / 4) / tan(phi / 2)
        let dx = cos(phi), dy = sin(phi), cx = x + length * dx
        let x2 = min(cx + sc * length, xMax)
        return [
            Vec(x, y), Vec(x + k * length * dx, y + k * length * dy), Vec(x2 - k * max(0, x2 - cx), yr), Vec(x2, yr),
        ]
    }

    /// A point on one of the end's two curves, and its direction, `t` counted on from where that curve's own starts.
    private static func at(_ c: [Vec], _ t: Double, from start: Double) -> Point {
        let u = 1 - t
        let p = u * u * u * c[0] + 3 * u * u * t * c[1] + 3 * u * t * t * c[2] + t * t * t * c[3]
        let d = 3 * (u * u * (c[1] - c[0]) + 2 * u * t * (c[2] - c[1]) + t * t * (c[3] - c[2]))
        return (p.x, p.y, atan2(d.y, d.x), start + t)
    }

    /// How far below the tab's edge a fillet of this radius leaving the curve here would reach.
    private static func off(_ a: Point, _ rho: Double, _ yr: Double) -> Double {
        a.y + rho * (1 - cos(a.phi)) - yr
    }

    /// Where along the curve a condition first holds, by halves.
    private static func solve(_ holds: (Double) -> Bool) -> Double {
        var a = 0.0, b = 1.0
        for _ in 0 ..< 36 {
            let m = (a + b) / 2
            if holds(m) {
                b = m
            } else {
                a = m
            }
        }
        return (a + b) / 2
    }
}

/// One end of a dent, in local coordinates (x out of the strip's edge, y down from where the flare leaves it): a
/// concave flare f across and f high into the strip, the run, a convex corner of radius r; squeezed sideways while
/// the depth can't hold both, which makes it an S-curve.
func dentEnd(_ w: Double, _ r: Double, _ f: Double) -> [Vec] {
    let sc = min(1, w / max(r + f, 1e-6)), k = Tuning.k
    let fx = f * sc, rx = r * sc
    return [
        Vec(0, k * f), Vec(fx - k * fx, f), Vec(fx, f), Vec(w - rx, f), Vec(w - rx + k * rx, f), Vec(w, f + r - k * r),
        Vec(w, f + r),
    ]
}

/// A dent, from where its top flare leaves the edge at x = base, back into the strip, to where its bottom flare meets
/// the edge again.
private func addDent(_ path: CGMutablePath, _ g: TabGeometry, base: Double) {
    let a = abs(g.w), top = dentEnd(a, g.r, g.ft), bottom = dentEnd(a, g.r, g.fb)
    let y0 = g.yt - g.ft, y1 = g.yb + g.fb
    func up(_ p: Vec) -> CGPoint { CGPoint(x: base - p.x, y: y0 + p.y) }
    func down(_ p: Vec) -> CGPoint { CGPoint(x: base - p.x, y: y1 - p.y) }
    path.addLine(to: CGPoint(x: base, y: y0))
    path.addCurve(to: up(top[2]), control1: up(top[0]), control2: up(top[1]))
    path.addLine(to: up(top[3]))
    path.addCurve(to: up(top[6]), control1: up(top[4]), control2: up(top[5]))
    path.addLine(to: down(bottom[6]))
    path.addCurve(to: down(bottom[3]), control1: down(bottom[5]), control2: down(bottom[4]))
    path.addLine(to: down(bottom[2]))
    path.addCurve(to: CGPoint(x: base, y: y1), control1: down(bottom[1]), control2: down(bottom[0]))
}
