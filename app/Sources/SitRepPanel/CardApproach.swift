import CoreGraphics
import Foundation

extension Card {
    /// Within the field, the closed notch eases out toward the pointer by up to Nudge; never under reduced motion.
    func updateNudge() {
        let target = feel.nudge * nudgeShare()
        if abs(S.n.target - target) > 1e-3 {
            springTo(\.n, target, feel.sp(.nudge))
        }
    }

    /// How far out the nudge goes, as a share of Nudge: growing as the gap from the notch's resting front to the
    /// pointer closes, as 1/(gap + 10), all the way out by the time the pointer touches its hit area (a gap of Nudge
    /// and the hit area's pad), and fading along the edge away from the notch's centre.
    func nudgeShare() -> Double {
        let field = CardTuning.field
        guard let p = sp, !reducesMotion, phase == .closed, isFree, feel.nudge > 0, p.x < field else {
            return 0
        }

        let dy = abs(p.y - notchY)
        guard dy < Tuning.fieldY else {
            return 0
        }

        func inv(_ x: Double) -> Double { 1 / (x + CardTuning.nudgeD0) }
        let rest = resting.w
        let gap = max(0, p.x - rest), out = max(1, field - rest), full = min(out - 1, feel.nudge + Tuning.hitPad)
        let near = clamp((inv(gap) - inv(out)) / (inv(full) - inv(out)), 0, 1)
        let along = 1 - smooth(clamp((dy - CardTuning.fieldYFull) / (Tuning.fieldY - CardTuning.fieldYFull), 0, 1))
        return near * along
    }

    /// Touching the card opens it: after the dwell, or at once if the pointer arrives fast.
    func updateContact(_ g: CardGeometry) {
        switch contact.update(sp, hitRect(g), approach: approachSpeed()) {
        case .left:
            cancel(.dwell)
        case let .touched(fast) where isFree && (phase == .closed || phase == .closing):
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

    /// The hit area: the live card and a little, reaching past the edge; only a sliver once the panel is out.
    func hitRect(_ g: CardGeometry) -> CGRect {
        guard phase != .closed else {
            return hitArea(w: g.w, h: g.h, cy: g.cy, live: false)
        }

        let rest = resting
        return hitArea(w: rest.w, h: rest.h, cy: stage.centre(rest.h, near: notchY), live: isLive)
    }
}
