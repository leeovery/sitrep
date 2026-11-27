import CoreGraphics
import Foundation

/// The approach as it stands: the pointer's depth inside the field (infinite outside it), the gap from the
/// tongue's tip to the pointer, and whether a snap may come.
struct Attract {
    var dx = Double.infinity
    var gap = Double.infinity
    var armed = true
}

extension Meniscus {
    /// The pointer since the last frame, read at this time, as the prototype's pointer events give it: a move adds to
    /// its trail, and entering or leaving the notch or the panel, as they were last drawn, cancels the grace or may
    /// start it. A still pointer gets no enter or leave as the shape pours under it. The pointer's own move onto a
    /// panel the shortcut opened (`movedOfItself`) is its coming onto it: what it was over is forgotten, so the move
    /// enters it, and leaving it starts the grace.
    func pointerMoved(_ p: Vec?, at time: Double, isHeld: Bool = false) {
        let isOwnMove = movedOfItself(to: p, isHeld: isHeld)

        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: time)
        }
        if awaitsPointer, isOwnMove, hoverOf(p) != nil || isOnShape(p) {
            awaitsPointer = false
            hover = nil
        }
        rehover()
    }

    /// Whether a point is on the black's own shape as last drawn: the flares by the screen's edge too, outside the
    /// content.
    private func isOnShape(_ p: Vec?) -> Bool {
        p.map { lastShape?.contains(CGPoint($0)) == true } ?? false
    }

    /// What the pointer is over, read again, and the grace started or cancelled as it changes: as the pointer moves,
    /// or, under a still pointer, as the room beside the panel changes (`Input.beside`), the way to it expiring.
    func rehover() {
        let over = hoverOf(sp)
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

    /// How hard the closed notch is pulled toward the pointer, and where its tongue aims. The pull goes as
    /// 1/(distance + `attractD0`), so it grows sharply as the gap closes; it reaches the cap at a distance of the cap
    /// plus Reach, where the tongue would touch the pointer's reach and snap. The tongue never reaches past the
    /// pointer. Under reduced motion there is none: only touching the notch opens it.
    func attraction() -> (reach: Double, ty: Double, dx: Double) {
        let none = (reach: 0.0, ty: notchY, dx: Double.infinity)
        guard let p = sp, !reducesMotion, phase == .closed, isFree, feel.pull > 0 else {
            return none
        }

        let dx = p.x
        let R = Tuning.fieldR * feel.pull, dy = p.y - notchY
        guard dx < R, abs(dy) < Tuning.fieldY else {
            return none
        }

        let notchW = max(0, S.w.x)
        // the tip's aim along the edge, held near home
        let off = Tuning.attractY * tanh(dy / Tuning.attractY)
        // from the notch's crest, where the tip would aim
        let d = hypot(max(0, dx - notchW), dy - off)
        let cap = Tuning.attractCap * feel.pull
        func inv(_ x: Double) -> Double { 1 / (x + Tuning.attractD0) }
        let dFull = cap + feel.reach, dOut = max(dFull + 1, R - notchW)
        let k = clamp((inv(d) - inv(dOut)) / (inv(dFull) - inv(dOut)), 0, 1)
        let wy = 1 - smooth(clamp((abs(dy) - 90) / (Tuning.fieldY - 90), 0, 1))
        return (min(cap * k * wy, d), notchY + off, dx)
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
        let p = feel.sp(live ? .attract : .relax)
        // a leave's ring plays out on its own spring
        if !ringing {
            springTo(\.ba, A.reach, p)
            // its aim along the edge follows without overshoot: a pointer passing by stays a steady lag ahead of it
            springTo(\.by, A.ty, live ? SpringParams(response: p.response, damping: 1) : p)
        }
        // the base stays home: only the tongue reaches
        springTo(\.ay, 0, feel.sp(.home))
        // the gap from the tongue's tip to the pointer, as drawn; below Reach it can't hold back
        guard live, let sp else {
            attract.gap = .infinity
            attract.armed = true
            return
        }

        attract.gap = hypot(max(0, A.dx - max(0, S.w.x) - max(0, S.ba.x)), sp.y - S.by.x)
        if attract.gap > feel.reach + 8 {
            attract.armed = true
        }
        let slip = abs(trailVelocity().y - S.by.v)
        if attract.armed, attract.gap < feel.reach, S.ba.x >= Tuning.catch * A.reach, slip < Tuning.captureV {
            snapOpen(sp)
        }
    }

    /// The tongue can't hold back: its tip jumps to the pointer and the pour starts from there.
    func snapOpen(_ sp: Vec) {
        let tongue = feel.sp(.tongue)
        springTo(\.ba, max(S.ba.x, attract.dx - max(0, S.w.x) + Tuning.grip), tongue)
        springTo(\.by, sp.y, tongue)
        open()
    }

    /// Contact with the notch opens it: after the dwell, or at once if the pointer arrives fast.
    func updateContact(_ g: MeniscusGeometry) {
        switch contact.update(sp, hitRect(g), approach: approachSpeed()) {
        case .left:
            cancel(.dwell)
        case let .touched(fast) where isFree && (phase == .closed || phase == .closing):
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
