import CoreGraphics
import Foundation

// The strip and its tabs: one black, drawn as paths in the edge's own coordinates, x into the screen from its edge.

/// A tab as drawn: its depth out of the strip (a dent below 0), its body's height and centre, and its two ends: the
/// front corners' radius and each flare, shortened where the top end or the screen's bottom leaves less room.
struct TabGeometry {
    let w, h, cy, r, ft, fb: Double

    var yt: Double { cy - h / 2 }
    var yb: Double { cy + h / 2 }
}

extension Strip {
    /// How deep under the menu bar the top end reaches: as far as Give way has drawn its curve up now.
    var topEndDepth: Double { clamp(give.x, StripTuning.giveMin, StripTuning.topEnd) }

    /// The highest a tab's top flare may leave the straight edge: `spare` under the top end as it is now, or with
    /// tightest, under it as far as Give way can draw it up.
    func topClear(tightest: Bool = false) -> Double {
        stage.menu + (tightest ? StripTuning.giveMin : topEndDepth) + StripTuning.spare
    }

    /// The highest a tab's body may be centred under that: its full top flare above it.
    func minCy(_ h: Double, _ lim: Double) -> Double { lim + StripTuning.flare + h / 2 }

    /// Where a tab settles for a mark: centred on it, unless that would take it into the top end, and clear of the
    /// screen's bottom.
    func tabTargetY(_ key: MarkKey, _ h: Double) -> Double {
        clamp(yOf(key), minCy(h, topClear(tightest: true)), stage.height - StripTuning.keep - h / 2)
    }

    /// A tab's body, centred on its mark's height, held under the top end as above and clear of the screen's bottom,
    /// where the bottom flare shrinks if there's no room for it; never taller than the room between, even as its
    /// spring overshoots (the count's tab, at its tallest).
    func tabGeometry(_ tab: StripTab) -> TabGeometry {
        let lim = topClear(), H = stage.height, keep = StripTuning.keep
        let h = clamp(tab.h.x, 0, H - keep - minCy(0, lim))
        let cy = clamp(tab.y.x, minCy(h, lim), H - keep - h / 2)
        var w = tab.w.x - tab.press.x
        if w < 0 {
            w = -StripTuning.dentGive * tanh(-w / StripTuning.dentGive)
        }
        let yt = cy - h / 2, yb = cy + h / 2
        return TabGeometry(
            w: w, h: h, cy: cy, r: min(StripTuning.corner, h / 2),
            ft: min(StripTuning.flare, max(0, yt - lim)), fb: min(StripTuning.flare, max(0, H - yb))
        )
    }

    /// Give way: how deep the top end may reach and still leave `spare` of straight edge above every tab's top flare,
    /// by where the tabs that are out are going (ahead), or by where every tab is now, its dent included.
    func giveNeed(ahead: Bool) -> Double {
        var e = StripTuning.topEnd
        for tab in tabs where !(ahead && tab.phase == .closing) {
            let h = max(0, ahead ? tab.h.target : tab.h.x), y = ahead ? tab.y.target : tab.y.x
            let cy = min(y, stage.height - StripTuning.keep - h / 2)
            e = min(e, cy - h / 2 - StripTuning.flare - StripTuning.spare - stage.menu)
        }
        return clamp(e, StripTuning.giveMin, StripTuning.topEnd)
    }

    /// Before the springs step: the curve heads, on the give spring, for where the tabs out will need it.
    func aimGive() {
        let e = giveNeed(ahead: true)
        if abs(e - give.target) > 1e-3 {
            springTo(&give, e, .give)
        }
    }

    /// After: drawing up, the curve leads and a tab waits under it (`tabGeometry` holds it there); springing back to
    /// the S, the curve waits on any tab still in its way, following its top down as it draws back, then its dent.
    func holdGive() {
        guard give.target >= give.x else {
            return
        }

        let e = giveNeed(ahead: false)
        if give.x > e {
            give.x = e
            give.v = min(0, give.v)
        }
    }

    /// The top end, from the menu bar down to where the straight edge starts, as the points of two cubics in the
    /// strip's own frame (x out from the screen's edge, y down from the menu bar): the board's S, drawn up toward a
    /// tight fillet as Give way gives. Drawn up as far as `giveSquash`, the S only gets shallower; further, it also
    /// narrows toward the strip's edge until it's a square corner, then rounds into the tight fillet: each step one
    /// clean shape, no hook between the two.
    func topEndPoints() -> [Vec] {
        let e = topEndDepth, strip = StripTuning.width
        func sCurve(_ xs: Double) -> [Vec] {
            StripTuning.sCurve.map { Vec(xs + $0.x * (strip - xs) / strip, $0.y * e / StripTuning.topEnd) }
        }
        guard e < StripTuning.giveSquash else {
            return sCurve(0)
        }

        let tight = StripTuning.giveMin
        let xs = (strip + tight) * (StripTuning.giveSquash - e) / (StripTuning.giveSquash - tight)
        guard xs > strip else {
            return sCurve(xs)
        }

        // a fillet of radius r from along the menu bar's underside into the strip's edge, then the edge down to e
        let r = xs - strip, k = Tuning.k * r
        return [
            Vec(strip + r, 0), Vec(strip + r - k, 0), Vec(strip, r - k), Vec(strip, r),
            Vec(strip, r + (e - r) / 3), Vec(strip, r + 2 * (e - r) / 3), Vec(strip, e),
        ]
    }

    /// The strip: from under the menu bar, its top end curving into the bezel, down to the screen's bottom. A tab
    /// drawn back past the edge dents it, always on the straight edge.
    func stripPath(_ geometries: [TabGeometry]) -> CGPath {
        let path = CGMutablePath(), sw = StripTuning.width, menu = stage.menu
        func T(_ p: Vec) -> CGPoint { CGPoint(x: p.x, y: menu + p.y) }
        let q = topEndPoints()
        path.move(to: CGPoint(x: -4, y: menu))
        path.addLine(to: T(q[0]))
        path.addCurve(to: T(q[3]), control1: T(q[1]), control2: T(q[2]))
        path.addCurve(to: T(q[6]), control1: T(q[4]), control2: T(q[5]))
        var y = menu + q[6].y
        for g in geometries.filter({ $0.w < -0.01 }).sorted(by: { $0.yt < $1.yt }) where g.yt - g.ft >= y {
            addEdge(path, g, base: sw, dir: -1)
            y = g.yb + g.fb
        }
        path.addLine(to: CGPoint(x: sw, y: stage.height + 4))
        path.addLine(to: CGPoint(x: -4, y: stage.height + 4))
        path.closeSubpath()
        return path
    }

    /// A tab: its own outline, starting just inside the strip's edge so the two blacks meet with no seam. It leaves
    /// the straight edge only, never the top end's curve.
    func tabPath(_ g: TabGeometry) -> CGPath {
        let path = CGMutablePath(), sw = StripTuning.width
        guard g.w > 0.01 else {
            return path
        }

        path.move(to: CGPoint(x: sw - 1, y: g.yt - g.ft))
        addEdge(path, g, base: sw, dir: 1)
        path.addLine(to: CGPoint(x: sw - 1, y: g.yb + g.fb))
        path.closeSubpath()
        return path
    }
}

/// One end of a tab, in local coordinates (x out of the strip's edge, y down from where the flare leaves it): a
/// concave flare of radius f into the strip, the top run, a convex corner of radius r; squeezed sideways while the
/// depth can't hold both, which makes it an S-curve.
func tabEnd(_ w: Double, _ r: Double, _ f: Double) -> [Vec] {
    let sc = min(1, w / max(r + f, 1e-6)), k = Tuning.k
    let fx = f * sc, rx = r * sc
    return [
        Vec(0, k * f), Vec(fx - k * fx, f), Vec(fx, f), Vec(w - rx, f), Vec(w - rx + k * rx, f), Vec(w, f + r - k * r),
        Vec(w, f + r),
    ]
}

/// Rounds a tab (dir 1) or a dent (dir -1) from where its top flare leaves the edge at x = base to where its bottom
/// flare meets it again.
private func addEdge(_ path: CGMutablePath, _ g: TabGeometry, base: Double, dir: Double) {
    let a = abs(g.w), top = tabEnd(a, g.r, g.ft), bottom = tabEnd(a, g.r, g.fb)
    let y0 = g.yt - g.ft, y1 = g.yb + g.fb
    func up(_ p: Vec) -> CGPoint { CGPoint(x: base + dir * p.x, y: y0 + p.y) }
    func down(_ p: Vec) -> CGPoint { CGPoint(x: base + dir * p.x, y: y1 - p.y) }
    path.addLine(to: CGPoint(x: base, y: y0))
    path.addCurve(to: up(top[2]), control1: up(top[0]), control2: up(top[1]))
    path.addLine(to: up(top[3]))
    path.addCurve(to: up(top[6]), control1: up(top[4]), control2: up(top[5]))
    path.addLine(to: down(bottom[6]))
    path.addCurve(to: down(bottom[3]), control1: down(bottom[5]), control2: down(bottom[4]))
    path.addLine(to: down(bottom[2]))
    path.addCurve(to: CGPoint(x: base, y: y1), control1: down(bottom[1]), control2: down(bottom[0]))
}
