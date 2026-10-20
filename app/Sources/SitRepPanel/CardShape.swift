import CoreGraphics
import Foundation

// The card: one rectangle from notch to panel, square where it meets the screen's edge. Its coordinates are the
// edge's own, as Meniscus's are.

/// Only its two outer corners round, with its depth: 6 at 7 deep, 10 at 15, growing to the panel's 24 by 60 deep.
func cornerAt(_ w: Double) -> Double {
    w <= 15
        ? lerp(6, 10, clamp((w - 7) / 8, 0, 1))
        : 10 + (Tuning.panelR - 10) * clamp((w - 15) / 45, 0, 1)
}

/// The live card: its depth, the nudge and all, its length, its centre along the edge, and its outer corners'
/// radius, which neither its depth nor half its length can hold less than.
struct CardGeometry {
    let w, h, cy, r: Double

    /// The prototype's `cardAt`: centred at y as the band lets it be.
    init(w: Double, h: Double, near y: Double, on stage: Stage) {
        self.w = max(0, w)
        self.h = max(0, h)
        cy = stage.centre(self.h, near: y)
        r = max(0, min(cornerAt(self.w), self.w, self.h / 2))
    }

    var top: Double { cy - h / 2 }
    var bottom: Double { cy + h / 2 }
}

/// The card as a path in stage coordinates: it starts and ends a few points past the screen's edge, so no seam shows
/// where its black meets the bezel's.
func shapePath(_ g: CardGeometry) -> CGPath {
    let path = CGMutablePath()
    guard g.w >= 0.01, g.h >= 0.01 else {
        return path
    }

    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: g.top + y) }
    let (w, h, r) = (g.w, g.h, g.r), k = Tuning.k * r

    path.move(to: pt(-4, 0))
    path.addLine(to: pt(w - r, 0))
    path.addCurve(to: pt(w, r), control1: pt(w - r + k, 0), control2: pt(w, r - k))
    path.addLine(to: pt(w, h - r))
    path.addCurve(to: pt(w - r, h), control1: pt(w, h - r + k), control2: pt(w - r + k, h))
    path.addLine(to: pt(-4, h))
    path.closeSubpath()
    return path
}
