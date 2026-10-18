import CoreGraphics
import Foundation

// The strip and its tabs: one black, drawn as paths in the edge's own coordinates, x into the screen from its edge.
// Its two ends are the board's S, the same in every frame: at the top under the menu bar, and at the bottom mirrored
// back into the bezel 26pt over the screen's bottom. A tab near either fits into the strip's shape: its edge runs
// back into the strip and meets the S's lower curve in a fillet.

/// A tab as drawn: its depth out of the strip (a dent below 0), its body's height and centre, its front corners'
/// radius, and a dent's flares, each shortened where the straight edge runs out under the top end or over the bottom.
struct TabGeometry {
    let w, h, cy, r, ft, fb: Double

    var yt: Double { cy - h / 2 }
    var yb: Double { cy + h / 2 }
}

extension Strip {
    /// Where the bottom end leaves the screen's edge, over the screen's bottom.
    var bottomEnd: Double { stage.height - StripTuning.bottomEnd }

    /// The first mark's centre: Room further under the top end's S than the board has it.
    var firstY: Double { stage.menu + StripTuning.topEnd + StripTuning.padTop + StripTuning.mark / 2 + settings.room }

    /// The lowest a mark's centre may be: over the bottom end's S as the first is under the top's, Room clear.
    var lastY: Double { bottomEnd - StripTuning.topEnd - StripTuning.padTop - StripTuning.mark / 2 - settings.room }

    /// The highest a tab's top may be: the first mark's open tab's, its fillet meeting the S.
    var topClear: Double { stage.menu + StripTuning.tabTop + settings.room }

    /// The lowest a tab's body may reach: the mirror of the top, its fillet meeting the bottom end's S.
    var botClear: Double { bottomEnd - StripTuning.tabTop - settings.room }

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
        let lim = topClear, bot = botClear, flare = StripTuning.flare, end = StripTuning.topEnd
        let h = clamp(tab.h.x, 0, bot - minCy(0, lim))
        let cy = clamp(tab.y.x, minCy(h, lim), bot - h / 2)
        var w = tab.w.x - tab.press.x
        if w < 0 {
            w = -StripTuning.dentGive * tanh(-w / StripTuning.dentGive)
        }
        let yt = cy - h / 2, yb = cy + h / 2
        return TabGeometry(
            w: w, h: h, cy: cy, r: min(StripTuning.corner, h / 2),
            ft: min(flare, max(0, yt - stage.menu - end)), fb: min(flare, max(0, bottomEnd - end - yb))
        )
    }

    /// The strip: from under the menu bar, its top end curving into the bezel, down its straight edge to its bottom
    /// end, the top's mirrored, curving back into the bezel. A tab drawn back past the edge dents it, always on the
    /// straight edge.
    func stripPath(_ geometries: [TabGeometry]) -> CGPath {
        let path = CGMutablePath(), sw = StripTuning.width, menu = stage.menu, yB = bottomEnd, q = StripTuning.sCurve
        func T(_ p: Vec) -> CGPoint { CGPoint(x: p.x, y: menu + p.y) }
        func B(_ p: Vec) -> CGPoint { CGPoint(x: p.x, y: yB - p.y) }
        path.move(to: CGPoint(x: -4, y: menu))
        path.addLine(to: T(q[0]))
        path.addCurve(to: T(q[3]), control1: T(q[1]), control2: T(q[2]))
        path.addCurve(to: T(q[6]), control1: T(q[4]), control2: T(q[5]))
        var y = menu + q[6].y
        for g in geometries.filter({ $0.w < -0.01 }).sorted(by: { $0.yt < $1.yt }) where g.yt - g.ft >= y {
            addDent(path, g, base: sw)
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
        let xr = StripTuning.width + g.w, xin = min(top[0].x, bot[0].x) - 1
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
        (StripFit(g.yt - stage.menu), StripFit(bottomEnd - g.yb))
    }

    /// A tab's top and bottom ends: from the strip's edge, along its fillet, into its edge, as cubics on the screen,
    /// the bottom's mirrored, and how far round its front corners reach across.
    private func tabEnds(_ g: TabGeometry) -> (top: [CGPoint], bottom: [CGPoint], rx: Double) {
        let sw = StripTuning.width, sc = min(1, g.w / (g.r + StripTuning.flare)), rx = g.r * sc
        let fit = tabFit(g), yT = g.yt - stage.menu, yB = bottomEnd - g.yb, menu = stage.menu, bottom = bottomEnd
        let top = fit.top.cubic(yT, sc, sw + g.w - rx).map { CGPoint(x: $0.x, y: menu + $0.y) }
        let bot = fit.bottom.cubic(yB, sc, sw + g.w - rx).map { CGPoint(x: $0.x, y: bottom - $0.y) }
        return (top, bot, rx)
    }
}

/// Where a tab's top or bottom edge meets the strip's own shape, which never changes. In the top end's frame (x out
/// from the screen's edge, y down from the menu bar; the bottom end mirrored into it), a circle of radius `rho` tangent
/// to the strip's edge at a point on the S's lower curve or the straight edge under it, and to the tab's edge, level
/// at `yr`. `rho` is the flare's unless that would leave the S higher than where it has turned 70°; then as big as fits
/// under there, never under 2.
struct StripFit: Equatable {
    /// Where the fillet leaves the strip's edge, and the edge's direction there.
    let x, y, phi: Double
    let rho: Double
    /// How far along the S's lower curve it leaves, 1 on the straight edge under it.
    let t: Double

    var onS: Bool { t < 1 }

    init(_ yr: Double) {
        let flare = StripTuning.flare
        let keep = Self.at(Self.solve { Self.at($0).phi >= StripTuning.fitKeep })
        var rho = flare
        if Self.off(keep, flare, yr) > 0 {
            rho = max(StripTuning.fitMin, (yr - keep.y) / (1 - cos(keep.phi)))
        }
        if yr - rho >= StripTuning.topEnd {
            self.init(x: StripTuning.width, y: yr - rho, phi: .pi / 2, rho: rho, t: 1)
            return
        }

        let start = Self.at(0)
        if Self.off(start, rho, yr) >= 0 {
            self.init(
                x: start.x, y: start.y, phi: start.phi, rho: max(0, (yr - start.y) / (1 - cos(start.phi))), t: 0
            )
            return
        }

        let on = Self.at(Self.solve { Self.off(Self.at($0), rho, yr) > 0 })
        self.init(x: on.x, y: on.y, phi: on.phi, rho: rho, t: on.t)
    }

    private init(x: Double, y: Double, phi: Double, rho: Double, t: Double) {
        self.x = x
        self.y = y
        self.phi = phi
        self.rho = rho
        self.t = t
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

    /// The S's lower curve, as drawn in Paper, at the strip's width.
    private static let lower = Array(StripTuning.sCurve[3 ... 6])

    /// A point on the lower curve, and its direction.
    private static func at(_ t: Double) -> (x: Double, y: Double, phi: Double, t: Double) {
        let c = lower, u = 1 - t
        let p = u * u * u * c[0] + 3 * u * u * t * c[1] + 3 * u * t * t * c[2] + t * t * t * c[3]
        let d = 3 * (u * u * (c[1] - c[0]) + 2 * u * t * (c[2] - c[1]) + t * t * (c[3] - c[2]))
        return (p.x, p.y, atan2(d.y, d.x), t)
    }

    /// How far below the tab's edge a fillet of this radius leaving the curve here would reach.
    private static func off(_ a: (x: Double, y: Double, phi: Double, t: Double), _ rho: Double, _ yr: Double) -> Double {
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
